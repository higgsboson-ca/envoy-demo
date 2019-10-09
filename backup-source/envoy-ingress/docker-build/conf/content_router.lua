local soap = require "router.soap_router"
-- local jwtattach = require "router.jwt_attacher"
local validjwt = require "router.jwt_digest_validator"
-- local content = require "router.content_processor"

function envoy_on_request(request_handle)
    request_handle:logInfo("hey its jason - content_router::envoy_on_request")
    -- local rescode = content.process(request_handle)
    -- local jwt_return_code = jwtattach.process(request_handle)
    local vjwt_return_code = validjwt.process(request_handle)
    local soap_return_code = soap.process(request_handle)
end

-- function envoy_on_response(response_handle)
--     -- Do nothing
-- end
