local router = {}

local HEADER_PARTICIPANT_ID = "x-et-participant-id"
local HEADER_LONG_RUNNING_TRANSACTION = "etint-complex-read-transaction"
local longRunningServices = {GetInterruptedTransfers=0, GetOutgoingTransfers=0, GetReceivedTransfers=0}

local HEADER_INGRESS_ROUTER = "etint-ingress-router"
local VALUE_ROUTED_BY_ENVOY = "ROUTED_BY_ENVOY"
local VALUE_ROUTED_BY_CONTENT_ROUTER = "ROUTED_BY_ENVOY_VIA_CONTENT"

-- Parse the body of a SOAP request for a participant ID.
router.process = function(request)
    local content_type = request:headers():get("content-type")
    if content_type ~= nil and content_type:find("application/json") then
        request:headers():add(HEADER_INGRESS_ROUTER, VALUE_ROUTED_BY_ENVOY)
        return 200
    end

    local body = request:body()
    if body == nil or body:length() == 0 then
        return 400
    end

    local data = tostring(body:getBytes(0, body:length()))
    local match = data:match("participantId>%s-(%w-)%s-</.-:?participantId>")

    if match then
        request:headers():add(HEADER_PARTICIPANT_ID, match)
    end

    local matchTransactionName = data:match("Body>%s-<ns%d-:(%w-)Request>%s-<requestHeader")
    if matchTransactionName and longRunningServices[matchTransactionName] ~= nil then
        request:headers():add(HEADER_INGRESS_ROUTER, VALUE_ROUTED_BY_CONTENT_ROUTER)
        request:headers():add(HEADER_LONG_RUNNING_TRANSACTION, matchTransactionName)
    else
        request:headers():add(HEADER_INGRESS_ROUTER, VALUE_ROUTED_BY_ENVOY)
    end

    return 200
end

return router
