-- This filter is used to temporary bypass the jwt validation requirements on a per FI basis

local PARTICIPANT_ID_HEADER = "x-et-participant-id"
local TIMESTAMP_HEADER = "x-et-transaction-time"
local SIGNATURE_HEADER = "x-et-api-signature"
local SIGNATURE_TYPE_HEADER = "x-et-api-signature-type"
local SIGNATURE_TYPE_DUMMY_VALUE = "PAYLOAD_DIGEST_SHA256"
local SIGNATURE_DUMMY_VALUE = "placeholder-for-bypass"
local TIMESTAMP_DUMMY_VALUE = "2019-05-01T23:59:59.123Z"

local global_flag = "false" -- String for consistency because of values read from env
local fi_id_set = {}

local bypasser = {}

function Set (list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
  end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function loadBypassIds(request)
    local config = os.getenv("jwt_bypass_ids")
    if config ~= nil then
        request:logDebug(string.format("jwt_bypass::env_var %s", config))
        local fi_ids = split(config, " ")
        fi_id_set = Set(fi_ids)
    end
end

function loadBypassFlag(request)
    local global_flag_config = os.getenv("jwt_global_bypass_enabled")
    if global_flag_config ~= nil then
        request:logDebug(string.format("jwt_bypass::global bypass flag from env %s", global_flag_config))
        global_flag = global_flag_config
    end
end

bypasser.preprocess = function(request)
    local signature = request:headers():get(SIGNATURE_HEADER)
    if signature ~= "" then
        return 200
    end

    local participant_id = request:headers():get(PARTICIPANT_ID_HEADER)
    request:logDebug(string.format("jwt_bypass::participant_id %s", participant_id))
    if participant_id == nil then
        return 400
    end

    loadBypassIds(request)
    loadBypassFlag(request)

    if (global_flag == "true" or fi_id_set[participant_id]) then
        request:headers():remove(SIGNATURE_TYPE_HEADER)
        request:headers():remove(SIGNATURE_HEADER)
        request:headers():remove(TIMESTAMP_HEADER)
        request:logInfo("jwt_bypass::Preprocessing removed required headers")
    end
    return 200
end

bypasser.process = function(request)
    local content_type = request:headers():get("content-type")
    if content_type ~= nil and content_type:find("text/xml") then
        return 200
    end

    local signature_type = request:headers():get(SIGNATURE_TYPE_HEADER)
    if signature_type ~= nil then
        return 200
    end

    local participant_id = request:headers():get(PARTICIPANT_ID_HEADER)
    request:logDebug(string.format("jwt_bypass::participant_id %s", participant_id))
    if participant_id == nil then
        return 400
    end

    loadBypassIds(request)
    loadBypassFlag(request)

    if (global_flag == "true") or fi_id_set[participant_id] then
        request:headers():add(SIGNATURE_TYPE_HEADER, SIGNATURE_TYPE_DUMMY_VALUE)
        request:headers():add(SIGNATURE_HEADER, SIGNATURE_DUMMY_VALUE)
        request:headers():add(TIMESTAMP_HEADER, TIMESTAMP_DUMMY_VALUE)
        request:logInfo(string.format("jwt_bypass::verification bypassed for ID %s", participant_id))
    else
        request:logDebug(string.format("jwt_bypass::verification not bypassed with global flag %s", global_flag))
    end
    return 200
end

return bypasser