--[[
    MM2 Hub - Single Link Loader
    loadstring(game:HttpGet("RAW_URL_OF_THIS_FILE"))()
]]

-- Prevent double execution
if getgenv().MM2HubLoaded then
    warn("[MM2 Hub] Already loaded, skipping.")
    return
end
getgenv().MM2HubLoaded = true

local libUrl    = "https://raw.githubusercontent.com/bendywendyy/mm2hub/main/library.lua"
local scriptUrl = "https://raw.githubusercontent.com/bendywendyy/mm2hub/main/MM2_Standalone.lua"

-- Load library
local lib
local ok1, res1 = pcall(function()
    lib = loadstring(game:HttpGet(libUrl))()
end)

if not ok1 or not lib then
    getgenv().MM2HubLoaded = false
    error("[MM2 Hub] Library failed to load: " .. tostring(res1))
    return
end

getgenv().Library = lib
task.wait(0.5)

-- Load MM2 script
local ok2, res2 = pcall(function()
    loadstring(game:HttpGet(scriptUrl))()
end)

if not ok2 then
    getgenv().MM2HubLoaded = false
    error("[MM2 Hub] MM2 script failed to load: " .. tostring(res2))
end
