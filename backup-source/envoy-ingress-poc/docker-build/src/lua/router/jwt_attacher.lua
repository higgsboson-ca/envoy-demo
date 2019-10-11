local base64 = require "lockbox.util.base64"

local JWT_HEADER = "x-et-api-signature"

local jwt_attacher = {}

-- Create a full JWT for processing by the jwt_authn filter if the existing JWT is in detached mode.
jwt_attacher.process = function(request)
    local jwt = request:headers():get(JWT_HEADER)

    if request:headers():get("content-type"):find("application/json") and jwt and jwt:find("%.%.") then
        local body = request:body()
        if body:length() == 0 then
            return 400
        end

        local data = base64.fromString(tostring(body:getBytes(0, body:length())))
            :gsub("=", ""):gsub("%+", "-"):gsub("/", "_")
        local attached_jwt = jwt:gsub("%.%.", "."..data..".")
        request:headers():replace(JWT_HEADER, attached_jwt)
    else
        -- Processing workaround for jwt_authn not forwarding etint-ingress-jws-digest to route match
        request:headers():replace("foo", "bar")
    end
    
    return 200
end

return jwt_attacher
