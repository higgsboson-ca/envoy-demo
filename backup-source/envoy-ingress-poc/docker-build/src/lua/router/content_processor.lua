-- Use this filter in conjunction with envoy.filters.http.jwt_authn

local base64 = require "lockbox.util.base64"
local sha256 = require "sha2"

local DIGEST_HEADER = "etint-ingress-jws-digest"
local DIGEST_VALIDATED_HEADER = "etint-ingress-jws-digest-validated"
local DIGEST_KEY = "payload-digest"
local DIGEST_PATTERN = "\""..DIGEST_KEY.."\":%s-\"(%w-)\""

local SOAP_HEADER_PARTICIPANT_ID = "x-et-participant-id"

local processor = {}

processor.process = function(request)
    local request_body = nil
    
    -- //////////////////////////////////////////
    -- jwt_digest_validator
    -- //////////////////////////////////////////

    local encoded_payload = request:headers():get(DIGEST_HEADER)
    if encoded_payload ~= nil then
        -- Get the request body.
        local body = request:body()
        if body:length() > 0 then
            request_body = body:getBytes(0, body:length())
        end

        local actual_value = sha256.sha256(request_body)

        local payload = base64.toString(encoded_payload)
        local expected_value = payload:match(DIGEST_PATTERN)

        if expected_value ~= actual_value then
            request:respond({
                [":status"] = "403",
                [DIGEST_VALIDATED_HEADER] = "false"
            }, "content digest mismatch")
            return 403
        end

        request:headers():replace(DIGEST_VALIDATED_HEADER, "true")
    end

    -- //////////////////////////////////////////
    -- soap_router
    -- //////////////////////////////////////////

    if request:headers():get("content-type"):find("application/json") == nil then
        -- Reuse the request body if already set.
        if request_body == nil then
            local body = request:body()
            if body:length() > 0 then
                request_body = body:getBytes(0, body:length())
            end
        end

        local data = tostring(request_body)
        local match = data:match("participantId>%s-(%w-)%s-</.-:?participantId>")
    
        if match then
            request:headers():add(SOAP_HEADER_PARTICIPANT_ID, match)
        end
    end

    return 200
end

return processor
