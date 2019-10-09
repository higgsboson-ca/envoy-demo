local router = {}

local HEADER_PARTICIPANT_ID = "x-et-participant-id"
local HEADER_LONG_RUNNIG_TRANSACTION = "etint-complex-read-transaction"
local longRunningServices = {GetIncomingTransfers=0, GetInterruptedTransfers=0, GetOutgoingTransfers=0, GetRecievedTransfers=0, GetTransferStatusHistory=0, AddContactRequest=0}

-- Parse the body of a SOAP request for a participant ID.
router.process = function(request)
    request:logInfo("hey its jason - soap_router::process")
    if request:headers():get("content-type"):find("application/json") then
        return 200
    end
    request:logInfo("hey its jason - soap_router::proces - content type is not json")

    local body = request:body()
    if body:length() == 0 then
        return 400
    end

    local data = tostring(body:getBytes(0, body:length()))
    local match = data:match("participantId>%s-(%w-)%s-</.-:?participantId>")
    
    if match then
        request:logInfo("hey its jason - soap_router::proces - match is " .. match)
        request:headers():add(HEADER_PARTICIPANT_ID, match)
    end

    --  sed -n 's/.*Body><ns2:\(.*\)><requestHeader.*/\1/p'
    local matchTransactionName = data:match("Body>%s-<ns%d-:(%w-)>%s-<requestHeader")
    if matchTransactionName and longRunningServices[matchTransactionName] ~= nil then                   
        request:logInfo("hey its jason - soap_router::proces - matchTransactionName found in longRunningServices")
        request:headers():add(HEADER_LONG_RUNNIG_TRANSACTION, matchTransactionName)
    else
        request:logInfo("hey its jason - soap_router::proces - matchTransactionName NOT found in longRunningServices")
    end

    return 200
end

return router
