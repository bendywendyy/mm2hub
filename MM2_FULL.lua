if getgenv().MM2HubLoaded then return end
getgenv().MM2HubLoaded = true

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/bendywendyy/mm2hub/main/library.lua"))()
getgenv().Library = lib
task.wait(1)
loadstring(game:HttpGet("https://raw.githubusercontent.com/bendywendyy/mm2hub/main/MM2_Standalone.lua"))()
