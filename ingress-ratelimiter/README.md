# Envoy Rate Limiting

1. [Introduction](#introduction)  
2. [Running the Service](#running-the-service)  
3. [Service Configuration](#service-configuration)  
4. [Configuring Envoy for HTTP Limiting](#configuring-envoy-for-http-limiting)
5. [Testing the Limits](#testing-the-limits)

---------------
## Introduction

In addition to circuit breaking and backpressure easing, rate limiting can be configured at any granularity, even down to individual routes. Unlike the first two methods, rate limiting for Envoy must be an external service.

The creators of Envoy have created a reference implementation of a gRPC rate limiting service for Envoy that they use in production. One can also find blogs on the Internet that demonstrate simple proof-of-concept implementations in golang.

For our purposes, we will leverage the reference implementation to reduce troubleshooting and maintenance headaches down the line.

-----------------------
## Running the Service

You must have git and Docker installed because the service must be built from source. Run the following commands in bash or PowerShell:

```bash
git clone https://github.com/lyft/ratelimit.git
cd ratelimit
docker build -t envoy-ratelimiter:latest .
```

The service requires at least one instance of Redis to be running.

```bash
docker run --rm -d -p 6379:6379 --name envoy-redis \
  --network=<docker-network-name> --network-alias <redis-alias> redis:alpine
```

The following command to run the rate-limiting service can be tailored to your specific environment.

```bash
docker run --rm -d --name envoy-ratelimiter \
  --network=<docker-network-name> \
  --network-alias <service-alias> \
  -v <host-volume-path>:/data:Z \
  -p 8080:8080 -p 8081:8081 -p 6070:6070 \
  -e USE_STATSD=false \
  -e LOG_LEVEL=debug \
  -e REDIS_SOCKET_TYPE=tcp \
  -e REDIS_URL=<redis-alias>:6379 \
  -e RUNTIME_ROOT=/data \
  -e RUNTIME_SUBDIRECTORY=ratelimit \
  envoy-ratelimiter:latest /bin/ratelimit
```

Given the above command, your rate-limit configurations must be available in the host directory ```<host-volume-path>/ratelimit/config``` which are then mapped to ```/data/ratelimit/config``` inside the container.


------------------------
## Service Configuration

The service is designed to reload configuration files whenever it detects changes to the ```<host-volume-path>/ratelimit/config``` file system path.

Below is a sample configuration to limit requests destined for a specific cluster ```<envoy-cluster-name>```. In reality the ```key``` and ```value``` can be anything that you configure Envoy to send to the service, as we will see in the next section. Refer to the [lyft/ratelimit configuration](https://github.com/lyft/ratelimit#configuration) section for more examples.

```yaml
---
domain: <any-unique-id> # Does not have to match the Envoy virtual host values
descriptors:
  - key: destination_cluster
    value: <envoy-cluster-name>
    rate_limit:
      unit: minute
      requests_per_unit: 10
```

If you are running Docker for Windows, you may need to restart the service for the changes to take effect. To see the current configuration, run the following command:

```bash
$ curl http://localhost:6070/rlconfig
# Output for the above configuration should be similar to this:
<any-unique-id>.destination_cluster_<envoy-cluster-name>: unit=MINUTE requests_per_unit=10
```


--------------------------------------
## Configuring Envoy for HTTP Limiting

Add the following cluster configuration into your ```envoy.yaml```. Note that ```http2_protocol_options``` must be set to ensure optimal performance between Envoy and the rate limiter.

```yaml
- name: rate_limit_cluster
  type: strict_dns
  connect_timeout: 0.25s
  lb_policy: round_robin
  http2_protocol_options: {}
  hosts:
  - socket_address:
      address: <service-alias specified when running the Docker image>
      port_value: 8081
```

Enable rate limiting by adding the ```envoy.rate_limit``` HTTP filter. Refer to the [configuration documentation](https://www.envoyproxy.io/docs/envoy/latest/api-v2/config/filter/http/rate_limit/v2/rate_limit.proto#config-filter-http-rate-limit-v2-ratelimit) for more details.

```yaml
# Place before the envoy.router filter.
- name: envoy.rate_limit
  config:
    # Does NOT have to match any of the virtual_hosts.domains values
    # But it must match the value specified in the rate-limiter config
    domain: <any-unique-id>
    stage: 0
    rate_limit_service:
      grpc_service:
        envoy_grpc:
          cluster_name: rate_limit_cluster
          timeout: 0.25s
```

Add the ```rate_limits``` element to ```virtual_hosts``` if you want the rate limit to apply to all routes, or to the ```route``` element if you want to apply for an individual route. Set ```route.include_vh_rate_limits``` to ```true``` if you want all rules along the route to apply.

```yaml
rate_limits:
- actions:
  - destination_cluster: {}
```

The above configuration tells Envoy to insert the destination cluster ID automatically when it queries the rate limiter. For more information including other rate-limiting actions, refer to the [rate limit documentation](https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/route/route.proto#envoy-api-msg-route-ratelimit).


---------------------
## Testing the Limits

If everything has been configured properly, then you can run several queries against your Envoy rate-limited route to test:

```bash
$ for i in {1..20}; do curl -s -o /dev/null -D - -H "content-type: text/xml" -d "@test/bigsoap.xml" http://localhost:8000/xmlproxy/ws/3.4.1/manageContact; done

# Successful Response
HTTP/1.1 100 Continue

HTTP/1.1 200 OK
content-length: 341455
date: Tue, 05 Mar 2019 19:32:35 GMT
x-envoy-upstream-service-time: 5
server: envoy

# Rejected Response
HTTP/1.1 100 Continue

HTTP/1.1 429 Too Many Requests
x-envoy-ratelimited: true
date: Tue, 05 Mar 2019 19:32:37 GMT
server: envoy
content-length: 0
```
