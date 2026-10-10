local API = "https://jarz-api.jarzzhub.workers.dev"

local HttpService = game:GetService("HttpService")
local request = (syn and syn.request) or (http and http.request) or http_request or request

if not request then
    return warn("[Jarz Hub] Executor kamu tidak mendukung request()")
end

local function post(path, body)
    local ok, res = pcall(request, {
        Url = API .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or not res then
        return nil
    end
    return res
end

local function fetch(kind)
    local hs = post("/v1/handshake", { placeId = game.PlaceId })
    if not hs then return nil, "handshake gagal" end
    if hs.StatusCode == 404 then return nil, "game tidak didukung" end
    if hs.StatusCode ~= 200 then return nil, "handshake error " .. tostring(hs.StatusCode) end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, hs.Body)
    if not okDecode or type(data) ~= "table" or not data.token then
        return nil, "respon handshake rusak"
    end

    local res = post("/v1/load", { token = data.token, kind = kind })
    if not res or res.StatusCode ~= 200 then
        return nil, "load error " .. tostring(res and res.StatusCode)
    end
    return res.Body
end

getgenv().JarzFetch = fetch

print("[Jarz Hub] Loading...")

local src, err = fetch("main")
if not src then
    return warn("[Jarz Hub] " .. tostring(err))
end

local fn, cerr = loadstring(src)
if not fn then
    return warn("[Jarz Hub] Compile error: " .. tostring(cerr))
end

fn()
