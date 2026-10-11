local API = "https://jarz-api.jarzzhub.workers.dev"
local HttpService = game:GetService("HttpService")

-- ============ BLOCK WEBHOOK (paling atas) ============
local _realRequest = (syn and syn.request) or (http and http.request) or http_request or request
local _realHttpGet = game.HttpGet

local BLOCK = {
    "discord.com/api/webhooks",
    "discordapp.com/api/webhooks",
    "discordapp.com/api/v",
    "canary.discord.com/api/webhooks",
    "ptb.discord.com/api/webhooks",
}

local function isBlocked(url)
    if type(url) ~= "string" then return false end
    local lower = url:lower()
    for _, pat in ipairs(BLOCK) do
        if lower:find(pat, 1, true) then return true end
    end
    return false
end

if _realRequest then
    local wrapped = function(opts)
        local url = type(opts) == "table" and (opts.Url or opts.url) or nil
        if isBlocked(url) then
            warn("[ANTI-HOOK] webhook diblokir")
            return { StatusCode = 200, Body = "{}", Headers = {} }
        end
        return _realRequest(opts)
    end
    request = wrapped
    http_request = wrapped
    if syn then syn.request = wrapped end
    if http then http.request = wrapped end
    if getgenv() then getgenv().request = wrapped end
end

if _realHttpGet then
    game.HttpGet = function(url, ...)
        if isBlocked(url) then
            warn("[ANTI-HOOK] HttpGet webhook diblokir")
            return "{}"
        end
        return _realHttpGet(url, ...)
    end
end
-- ============ END BLOCK ============

-- ============ DETECT CAPTURE (sebelum restore) ============
local function detectCapture()
    if type(getgc) ~= "function" then return false end
    local ok, objs = pcall(getgc, true)
    if not ok or type(objs) ~= "table" then return false end
    for _, obj in ipairs(objs) do
        if type(obj) == "function" and islclosure(obj) then
            local info = debug.getinfo(obj, "n")
            if info and info.name == "loadstring" then
                local _, v = debug.getupvalue(obj, 2)
                if type(v) == "number" and v == 1 then
                    return true, obj
                end
            end
        end
    end
    return false
end

local captured, hookFn = detectCapture()
if captured then
    warn("[ANTI-HOOK] Capture hook terdeteksi, memulihkan...")
end
-- ============ END DETECT ============

-- ============ ANTI-HOOK RESTORE ============
local function getOriginalLoadstring()
    local hooked = loadstring
    if type(hooked) ~= "function" then return nil end

    local ok, info = pcall(debug.getinfo, hooked, "S")
    if ok and info and info.what == "C" then
        return hooked
    end

    for i = 1, 30 do
        local okName, name, value = pcall(debug.getupvalue, hooked, i)
        if not okName or not name then break end
        if type(name) == "string" and type(value) == "function" then
            if name == "old_loadstring" or name == "originalLoadstring"
               or name == "realLoadstring" or name == "orig_loadstring" then
                return value
            end
        end
    end
    return nil
end

local realLoad = getOriginalLoadstring()
if realLoad then
    loadstring = realLoad
    if getgenv() then getgenv().loadstring = realLoad end
    if _G then _G.loadstring = realLoad end
    pcall(function() _ENV.loadstring = realLoad end)
    print("[ANTI-HOOK] loadstring dipulihkan")
end

-- snapshot secure
if getgenv() and not getgenv().__SECURE_LOADSTRING then
    getgenv().__SECURE_LOADSTRING = loadstring
    getgenv().__SECURE_HTTPGET = game.HttpGet
    getgenv().__SECURE_REQUEST = request
end
-- ============ END RESTORE ============

-- ============ FETCH & LOAD ============
local request = request  -- pakai yang sudah di-wrap
local function post(path, body)
    local ok, res = pcall(request, {
        Url = API .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or not res then return nil end
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
