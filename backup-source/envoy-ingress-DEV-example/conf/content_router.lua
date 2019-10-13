local soap = require "router.soap_router"
local validjwt = require "router.jwt_digest_validator"
local jwtBypass = require "router.jwt_bypass"

function envoy_on_request(request_handle)
    local vjwt_return_code = validjwt.process(request_handle)
    local soap_return_code = soap.process(request_handle)
    local jwt_bypass_code = jwtBypass.process(request_handle)
end

-- function envoy_on_response(response_handle)
--     -- Do nothing
-- end
