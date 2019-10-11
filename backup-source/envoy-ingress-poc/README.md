# Envoy Service Gateway (Ingress Proxy)

1. [Introduction](#introduction)  
2. [Traffic Management](#traffic-management)  
3. [Extending Envoy](#extending-envoy)  
   3.1. [Lua Script Configuration](#lua-script-configuration)  
   3.2. [SOAP Content Router](#soap-content-router)  
   3.3. [JWT Detached-Mode Verification](#jwt-detached-mode-verification)  
4. [Metrics and Monitoring](#metrics-and-monitoring)



---------------
## Introduction

The service gateway consists of the following configurable components:
- Rate limiter (external service)
- SOAP content router
- Header JWT verifier

----------------
## Traffic Management

Envoy supports the following ingress trottling methods:
- Circuit breaking
- Backpressure easing
- Rate limiting

Unlike the first two methods, Envoy requires an external service to manage its rate limiting. For more information, please refer to the [envoy-ratelimiter documentation](../envoy-ratelimiter/README.md).

------------------
## Extending Envoy

Envoy provides a lightweight scripting engine based on LuaJIT.

### Lua Script Configuration

Add the following configuration to the `http_filters` section of the `envoy.http_connection_manager` filter to enable it:

```yaml
# Place before the envoy.router filter
- name: envoy.lua
  config:
    inline_code: |
      loadfile("/path/to/lua/config/script.lua")()
```

The contents of ```src/lua/*``` are copied into the Docker image when building. Lua modules can then be referenced using standard Lua 5.1 syntax:

```lua
-- from src/lua/lockbox/util/base64.lua
local base64 = require "lockbox.util.base64"
local encoded_data = base64.fromString(...)
```

A reference configuration script can be found at ```conf/content_router.lua``` which enables the following behaviours within Envoy:

- SOAP content routing
- JWT verification in detached mode


-----------------------
### SOAP Content Router

```lua
local soap_router = require "router.soap_router"
soap_router.process(request_handle)
```

This script scans the body of a POST or PUT HTTP request for a ```participantId``` XML node and copies the value into the ```x-et-participant-id``` header.

The script will not run if the header ```content-type: application/json``` is present (for eTransfer API 3.5 and higher) because MIME types were not enforced for eTransfer API versions 3.4 and earlier.

The advantages that this script affords over other content routing solutions is twofold:
- Envoy can be deployed with no other dependencies
- Performance as an L7 router is nearly 99% of its L4 counterpart


----------------------------------
### JWT Detached-Mode Verification

```lua
local jwt = require "router.jwt_attacher"
jwt.process(request_handle)
```

Currently the ```envoy.filters.http.jwt_authn``` filter built into Envoy 1.10 does not support JWT verification of detached payloads. This script scans the ```x-api-signature``` header for a detached JWT as long as the request MIME type is ```application/json```. The ```x-api-signature``` header is then replaced with a full JWT.

Note that for versions of Envoy up to and including 1.10, the maximum request header size is limited to 64KB. See [Envoy issue #5626](https://github.com/envoyproxy/envoy/issues/5626) for progress on configurable header limits. This should not be an issue if only key values of the payload are signed and can be verified by the script once the values are determined.


-------------------------
## Metrics and Monitoring

TBD
