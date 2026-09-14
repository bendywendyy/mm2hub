--[[
    MM2 Hub - Single Link Loader
    Upload THIS file to GitHub as MM2_FULL.lua
    Then just run:
    loadstring(game:HttpGet("RAW_URL_OF_THIS_FILE"))()
]]

-- Load library
local libUrl = "https://raw.githubusercontent.com/bendywendyy/mm2hub/main/library.lua"
local scriptUrl = "https://raw.githubusercontent.com/bendywendyy/mm2hub/main/MM2_Standalone.lua"

-- Execute library and catch its return value
local ok1, lib = pcall(function()
    return loadstring(game:HttpGet(libUrl .. "?t=" .. math.floor(tick())))()
end)

if not ok1 or not lib then
    -- try without cache bust
    local ok2, lib2 = pcall(function()
        return loadstring(game:HttpGet(libUrl))()
    end)
    if ok2 and lib2 then
        lib = lib2
    else
        error("[MM2 Hub] Failed to load library: " .. tostring(lib))
        return
    end
end

-- Set into getgenv so the MM2 script can find it
getgenv().Library = lib

-- Small wait to let Library settle
task.wait(0.5)

-- Verify
if not getgenv().Library then
    error("[MM2 Hub] Library did not register into getgenv. Check your library.lua file.")
    return
end

-- Load MM2 script
local ok3, err3 = pcall(function()
    loadstring(game:HttpGet(scriptUrl .. "?t=" .. math.floor(tick())))()
end)

if not ok3 then
    -- try without cache bust
    pcall(function()
        loadstring(game:HttpGet(scriptUrl))()
    end)
end
