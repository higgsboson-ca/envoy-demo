-- This lua script is intended to run before the jwt_authn plugin to do preprocessing before jwt validation
local jwtBypass = require "router.jwt_bypass"

function envoy_on_request(request_handle)
    local jwt_bypass_code = jwtBypass.preprocess(request_handle)
