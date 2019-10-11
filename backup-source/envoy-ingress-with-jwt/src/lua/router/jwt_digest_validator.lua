-- Use this filter in conjunction with envoy.filters.http.jwt_authn

local base64 = require "lockbox.util.base64"
local sha256 = require "sha2"

local DIGEST_HEADER = "etint-ingress-jws-digest"
local DIGEST_VALIDATED_HEADER = "etint-ingress-jws-digest-validated"
local DIGEST_KEY = "payload%-digest"
local TIMESTAMP_KEY = "signature%-timestamp"
local TIMESTAMP_HEADER = "x-et-transaction-time"
local DIGEST_PATTERN = "\""..DIGEST_KEY.."\":%s-\"(%w-)\""
local TIMESTAMP_PATTERN = "\""..TIMESTAMP_KEY.."\":%s-\"([%w%-%.:]-)\""
local UTC_TIMESTAMP_PATTERN = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)%.%d+Z"

local ALLOWED_OFFSET_SECONDS = 30

local validator = {}

validator.process = function(request)
    request:logDebug("jwt_digest_validator::process")
    local encoded_payload = request:headers():get(DIGEST_HEADER)
    request:logDebug(string.format("jwt_digest_validator::encoded_payload %s", encoded_payload))
    if encoded_payload == nil then 
        request:logDebug("jwt_digest_validator::no jwt to validate")
        return 200
    end

    local timestamp = request:headers():get(TIMESTAMP_HEADER)
    request:logDebug(string.format("jwt_digest_validator::timestamp %s", timestamp))
    if timestamp == nil then
        request:logDebug("jwt_digest_validator::timestamp not provided")
        request:respond({
            [":status"] = "401",
        }, "{\"code\":\"5001\",\"text\":\"Digital signature verification failure\"}")
        return 401
    end

    local payload = base64.toString(encoded_payload)

    request:logDebug(string.format("jwt_digest_validator::found timestamp from header: %s", timestamp))

    request:logDebug(string.format("jwt_digest_validator::payload body: %s", payload))

    local expected_timestamp = payload:match(TIMESTAMP_PATTERN)

    request:logDebug(string.format("jwt_digest_validator::found timestamp from jwt payload: %s", expected_timestamp))

    if expected_timestamp ~= timestamp then
        request:logInfo("jwt_digest_validator::timestamp mismatch")
        request:respond({
            [":status"] = "401",
        }, "{\"code\":\"5001\",\"text\":\"Digital signature verification failure\"}")
        return 401
    end 

    year,month,day,hour,min,sec=timestamp:match(UTC_TIMESTAMP_PATTERN)
    local timestamp_epoch = os.time({day=day, month=month, year=year, hour=hour, min=min, sec=sec})
    local current_epoch = os.time()

    request:logDebug(string.format("jwt_digest_validator::calculated timestamp epoch time: %d", timestamp_epoch))

    request:logDebug(string.format("jwt_digest_validator::calculated current epoch time: %d", current_epoch))

    local jwt_validity_config = os.getenv("jwt_validity_seconds")

    request:logDebug(string.format("jwt_digest_validator::configured jwt validity period: %s", jwt_validity_config))

    if jwt_validity_config ~= nil then
        ALLOWED_OFFSET_SECONDS = tonumber(jwt_validity_config)
    end

    if (current_epoch - timestamp_epoch) > ALLOWED_OFFSET_SECONDS then
        request:logInfo("jwt_digest_validator::timestamp invalid")
        request:respond({
            [":status"] = "400",
        }, "{\"code\":\"5002\",\"text\":\"Time-to-live expired\"}")
        return 400
    end

    local expected_digest_value = payload:match(DIGEST_PATTERN)

    request:logDebug(string.format("jwt_digest_validator::digest from payload: %s", expected_digest_value))

    if expected_digest_value ~= nil then
        local body = request:body()
        if body:length() == 0 then return 400; end

        local actual_value = sha256.sha256(body:getBytes(0, body:length()))
        request:logDebug(string.format("jwt_digest_validator::digest from body: %s", actual_value))

        if expected_digest_value ~= actual_value then
            request:logInfo("jwt_digest_validator::digest value mismatch")
            request:respond({
                [":status"] = "401",
            }, "{\"code\":\"5001\",\"text\":\"Digital signature verification failure\"}")
            return 401
        end
    end

    request:logDebug("jwt_digest_validator::all checks passed")

    request:headers():replace(DIGEST_VALIDATED_HEADER, "true")
    return 200
end

return validator
