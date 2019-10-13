# Envoy Ingress Proxy

---------------
## Features

The Ingress Proxy consists of the following features:
- Simple routing rule to redirect the request to sb2-rest-http-logger
- gzip filter
- health check filter
- Lua filter for header injection

---------------
## Notes
- HTTP filters are executed in sequence. The last one should be the default envoy.router.
- If there is a health-check filter, it should be the first one to avoid unecessary processing on other filters if the backend is not healthy at all.
- Health check filter is using the backend springboot _context-root_/actuator/health endpoint.
- Lua source is loaded by a simple inline lua statement.
- gzip filter is for response. So, it should be after the request processing.

---------------
## Gzip Setting and Vary header
- When envoy and backend both turn on gzip
  1. No matter the request ask for gzip or not, the response will always have a header "Vary : Accept-Encoding".
  2. The client will get the content based on the header.
- When envoy turn on gzip, backend turn off gzip
  1. if client request does not ask for gzip, Vary header will not present and clear text will be served by Envoy
  2. if client request DO ask for gzip, Vary header will present and zipped content will be served by Envoy. the client will do decompresion by its own.
  3. the response from back end to Envoy will always present the Vary header

---------------
## TLS
- SPKI is prefered vs hash. As long as the CA cert is not rotated, the spki hash value no need to update even if the cert is rotated.
