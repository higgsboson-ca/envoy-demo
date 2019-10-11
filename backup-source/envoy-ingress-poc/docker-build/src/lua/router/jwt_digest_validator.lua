-- Use this filter in conjunction with envoy.filters.http.jwt_authn

local base64 = require "lockbox.util.base64"
local sha256 = require "sha2"

local DIGEST_HEADER = "etint-ingress-jws-digest"
local DIGEST_VALIDATED_HEADER = "etint-ingress-jws-digest-validated"
local DIGEST_KEY = "payload%-digest"
local DIGEST_PATTERN = "\""..DIGEST_KEY.."\":%s-\"(%w-)\""

local validator = {}

validator.process = function(request)
    request:logInfo("hey its jason - jwt_digest_validator::process")
    local encoded_payload = request:headers():get(DIGEST_HEADER)
    if encoded_payload == nil then return 200; end

    local body = request:body()
    if body:length() == 0 then return 400; end

    local payload = base64.toString(encoded_payload)
    local expected_value = payload:match(DIGEST_PATTERN)
    local actual_value = sha256.sha256(body:getBytes(0, body:length()))

    if expected_value ~= actual_value then
        request:respond({
            [":status"] = "403",
            [DIGEST_VALIDATED_HEADER] = "false"
        }, "content digest mismatch")
        return 403
    end

    request:headers():replace(DIGEST_VALIDATED_HEADER, "true")
    return 200
end

return validator
