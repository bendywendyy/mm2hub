--[[
    Murder Mystery 2 — Full Script
    Library: provided (getgenv-based, Potassium compatible)
    Engine: Roblox / MM2
    Features: ESP, Aimbot, Movement, Autofarm, Misc, Desync, Info HUD
    
    Usage:
        1. Load the library first (loadstring or require)
        2. Execute this script after Library is in getgenv()
        3. Menu opens/closes with RightAlt by default
]]

-- ════════════════════════════════════════════════════
--  SERVICES & ALIASES
-- ════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local Stats            = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera
local Mouse            = LocalPlayer:GetMouse()

-- ════════════════════════════════════════════════════
--  LIBRARY INIT
-- ════════════════════════════════════════════════════
local Library = getgenv().Library
assert(Library, "Library not loaded — run the library loader first")

Library.Folders = {
    Main    = "MM2Hub",
    Assets  = "MM2Hub/Assets",
    Configs = "MM2Hub/Configs"
}

for _, Folder in {"MM2Hub", "MM2Hub/Assets", "MM2Hub/Configs"} do
    if not isfolder(Folder) then makefolder(Folder) end
end

-- ════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════
local Window = Library:Window({
    Name    = "MM2 Hub",
    SubName = "by xxangelxx",
    Logo    = "1l20959262762131",
})

-- ════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════
local State = {
    ESPDrawings      = {},
    CoinDrawings     = {},
    GunDrawings      = {},
    ESPEnabled       = false,
    CoinESP          = false,
    GunESP           = false,
    AimbotEnabled    = false,
    SilentAim        = false,
    AimbotFOV        = 120,
    AimbotSmooth     = 0.15,
    AimbotPart       = "Head",
    SpeedEnabled     = false,
    SpeedValue       = 16,
    FlyEnabled       = false,
    FlySpeed         = 50,
    NoclipEnabled    = false,
    KillAura         = false,
    KillAuraRange    = 15,
    AutoCoin         = false,
    DesyncEnabled    = false,
    DesyncStrength   = 5,
    ShowHUD          = true,
    InfiniteStamina  = false,
    NoFallDamage     = false,
    GodMode          = false,
    BunnyHop         = false,
    AlwaysMurderer   = false,
    FullBright       = false,
    FakeLag          = false,
    FakeLagAmount    = 0,
}

-- ════════════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════════════
local function GetCharacter(plr)
    return plr and plr.Character
end

local function GetRoot(plr)
    local c = GetCharacter(plr)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(plr)
    local c = GetCharacter(plr)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(plr)
    local h = GetHumanoid(plr)
    return h and h.Health > 0
end

local function WorldToViewport(pos)
    local vp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X, vp.Y), onScreen, vp.Z
end

local function GetTeam(plr)
    -- MM2 stores roles in leaderstats or module
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local role = ls:FindFirstChild("Role") or ls:FindFirstChild("role")
        if role then return role.Value end
    end
    return "Unknown"
end

local function GetRoleColor(plr)
    local role = GetTeam(plr)
    if role == "Murderer" or role == "murderer" then return Color3.fromRGB(255, 60, 60)
    elseif role == "Sheriff" or role == "sheriff" then return Color3.fromRGB(80, 140, 255)
    else return Color3.fromRGB(100, 255, 100) end
end

local function Distance(plr)
    local root = GetRoot(plr)
    local myRoot = GetRoot(LocalPlayer)
    if not root or not myRoot then return math.huge end
    return (root.Position - myRoot.Position).Magnitude
end

-- ════════════════════════════════════════════════════
--  DRAWING POOL
-- ════════════════════════════════════════════════════
local function NewDrawing(type, props)
    local d = Drawing.new(type)
    for k,v in props do d[k] = v end
    return d
end

local function RemoveDrawings(tbl)
    for _, d in tbl do
        if type(d) == "table" then
            for _, v in d do pcall(function() v:Remove() end) end
        else
            pcall(function() d:Remove() end)
        end
    end
    table.clear(tbl)
end

-- ════════════════════════════════════════════════════
--  FOV CIRCLE
-- ════════════════════════════════════════════════════
local FOVCircle = NewDrawing("Circle", {
    Visible   = false,
    Radius    = 120,
    Color     = Color3.fromRGB(255, 255, 255),
    Thickness = 1,
    Filled    = false,
    Position  = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
})

-- ════════════════════════════════════════════════════
--  INFO HUD
-- ════════════════════════════════════════════════════
local HUD = {
    BG      = NewDrawing("Square", {Visible=false, Color=Color3.fromRGB(15,15,18), Transparency=0.45, Filled=true, Size=Vector2.new(175,90), Position=Vector2.new(6,6)}),
    FPS     = NewDrawing("Text",   {Visible=false, Color=Color3.fromRGB(100,220,255), Size=15, Font=2, Text="FPS: --"}),
    Ping    = NewDrawing("Text",   {Visible=false, Color=Color3.fromRGB(100,255,160), Size=15, Font=2, Text="Ping: --"}),
    Role    = NewDrawing("Text",   {Visible=false, Color=Color3.fromRGB(255,200,100), Size=15, Font=2, Text="Role: --"}),
    Alive   = NewDrawing("Text",   {Visible=false, Color=Color3.fromRGB(200,200,200),Size=15, Font=2, Text="Alive: --"}),
    Coins   = NewDrawing("Text",   {Visible=false, Color=Color3.fromRGB(255,230,60), Size=15, Font=2, Text="Coins: --"}),
    Bar     = NewDrawing("Square", {Visible=false, Color=Color3.fromRGB(0,116,224), Filled=true, Size=Vector2.new(175,2), Position=Vector2.new(6,4)}),
}

local function UpdateHUD()
    local vis = State.ShowHUD
    HUD.BG.Visible  = vis
    HUD.FPS.Visible = vis
    HUD.Ping.Visible= vis
    HUD.Role.Visible= vis
    HUD.Alive.Visible=vis
    HUD.Coins.Visible=vis
    HUD.Bar.Visible  =vis

    if not vis then return end

    local fps   = math.floor(1 / RunService.RenderStepped:Wait() * 0 + 0) -- updated in loop
    local ping  = Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"] and
                  math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) or 0

    local role  = GetTeam(LocalPlayer)
    local alive = 0
    for _, p in Players:GetPlayers() do
        if IsAlive(p) then alive += 1 end
    end

    local coins = 0
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local c = ls:FindFirstChild("Coins") or ls:FindFirstChild("coins")
        if c then coins = c.Value end
    end

    local base = Vector2.new(14, 10)
    HUD.FPS.Position   = base
    HUD.Ping.Position  = base + Vector2.new(0, 18)
    HUD.Role.Position  = base + Vector2.new(0, 36)
    HUD.Alive.Position = base + Vector2.new(0, 54)
    HUD.Coins.Position = base + Vector2.new(0, 72)

    HUD.Ping.Text  = "Ping: " .. ping .. "ms"
    HUD.Role.Text  = "Role: " .. role
    HUD.Alive.Text = "Alive: " .. alive
    HUD.Coins.Text = "Coins: " .. coins

    -- role color
    local rc = GetRoleColor(LocalPlayer)
    HUD.Role.Color = rc
end

-- ════════════════════════════════════════════════════
--  ESP CORE
-- ════════════════════════════════════════════════════
local function ClearPlayerESP(plr)
    if State.ESPDrawings[plr] then
        for _, d in State.ESPDrawings[plr] do pcall(function() d:Remove() end) end
        State.ESPDrawings[plr] = nil
    end
end

local function BuildPlayerESP(plr)
    if plr == LocalPlayer then return end
    ClearPlayerESP(plr)
    State.ESPDrawings[plr] = {
        Box      = NewDrawing("Square",  {Visible=false, Thickness=1, Filled=false, Color=Color3.fromRGB(255,255,255)}),
        BoxFill  = NewDrawing("Square",  {Visible=false, Thickness=1, Filled=true,  Color=Color3.fromRGB(0,0,0), Transparency=0.4}),
        Name     = NewDrawing("Text",    {Visible=false, Size=13, Font=2, Outline=true, Color=Color3.fromRGB(255,255,255)}),
        Distance = NewDrawing("Text",    {Visible=false, Size=11, Font=2, Outline=true, Color=Color3.fromRGB(200,200,200)}),
        Tracer   = NewDrawing("Line",    {Visible=false, Thickness=1, Color=Color3.fromRGB(255,255,255)}),
        HealthBar= NewDrawing("Square",  {Visible=false, Thickness=1, Filled=true,  Color=Color3.fromRGB(0,255,0)}),
        HealthBG = NewDrawing("Square",  {Visible=false, Thickness=1, Filled=true,  Color=Color3.fromRGB(0,0,0), Transparency=0.5}),
    }
end

local function UpdatePlayerESP(plr)
    local d = State.ESPDrawings[plr]
    if not d then return end

    local enabled = State.ESPEnabled
    local char    = GetCharacter(plr)
    local root    = GetRoot(plr)
    local hum     = GetHumanoid(plr)

    if not enabled or not char or not root or not hum or hum.Health <= 0 then
        for _, v in d do v.Visible = false end
        return
    end

    -- Get head + foot for bounding box
    local head  = char:FindFirstChild("Head")
    local lfoot = char:FindFirstChild("LeftFoot") or root

    local topPos,    topOn    = WorldToViewport(head  and head.Position  or root.Position + Vector3.new(0, 3, 0))
    local botPos,    botOn    = WorldToViewport(lfoot and lfoot.Position or root.Position - Vector3.new(0, 3, 0))
    local rootPos,   rootOn,  rootZ = WorldToViewport(root.Position)

    if not topOn and not rootOn then
        for _, v in d do v.Visible = false end
        return
    end

    local h = math.abs(botPos.Y - topPos.Y)
    local w = h * 0.4
    local x = rootPos.X - w / 2
    local y = topPos.Y

    local col = GetRoleColor(plr)
    local dist = Distance(plr)
    local hp   = hum.Health
    local maxhp= hum.MaxHealth

    -- Box fill
    d.BoxFill.Position = Vector2.new(x, y)
    d.BoxFill.Size     = Vector2.new(w, h)
    d.BoxFill.Visible  = Library.Flags["ESPBoxFill"] == true

    -- Box outline
    d.Box.Color    = col
    d.Box.Position = Vector2.new(x, y)
    d.Box.Size     = Vector2.new(w, h)
    d.Box.Visible  = true

    -- Name
    d.Name.Text     = plr.Name
    d.Name.Color    = col
    d.Name.Position = Vector2.new(rootPos.X, y - 16)
    d.Name.Visible  = Library.Flags["ESPNames"] ~= false

    -- Distance
    d.Distance.Text     = math.floor(dist) .. "m"
    d.Distance.Position = Vector2.new(rootPos.X, y + h + 2)
    d.Distance.Visible  = Library.Flags["ESPDistance"] ~= false

    -- Tracer
    d.Tracer.From    = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    d.Tracer.To      = Vector2.new(rootPos.X, rootPos.Y)
    d.Tracer.Color   = col
    d.Tracer.Visible = Library.Flags["ESPTracers"] == true

    -- Health bar (left side)
    local hpPct  = math.clamp(hp / maxhp, 0, 1)
    local hbH    = h * hpPct
    local hbCol  = Color3.fromRGB(255 - (hpPct * 255), hpPct * 255, 0)
    d.HealthBG.Position = Vector2.new(x - 5, y)
    d.HealthBG.Size     = Vector2.new(3, h)
    d.HealthBG.Visible  = true
    d.HealthBar.Position= Vector2.new(x - 5, y + h - hbH)
    d.HealthBar.Size    = Vector2.new(3, hbH)
    d.HealthBar.Color   = hbCol
    d.HealthBar.Visible = true
end

-- ════════════════════════════════════════════════════
--  COIN & GUN ESP
-- ════════════════════════════════════════════════════
local function UpdateWorldESP()
    -- Coins
    RemoveDrawings(State.CoinDrawings)
    if State.CoinESP then
        local map = Workspace:FindFirstChild("Map") or Workspace
        for _, obj in map:GetDescendants() do
            if obj.Name == "Coin" or obj.Name == "coin" or
               (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
                local pos, onScreen = WorldToViewport(obj.Position)
                if onScreen then
                    local lbl = NewDrawing("Text", {
                        Text     = "Coin",
                        Position = pos,
                        Color    = Color3.fromRGB(255, 220, 30),
                        Size     = 13,
                        Font     = 2,
                        Outline  = true,
                        Visible  = true
                    })
                    table.insert(State.CoinDrawings, lbl)
                end
            end
        end
    end

    -- Guns / dropped weapons
    RemoveDrawings(State.GunDrawings)
    if State.GunESP then
        local map = Workspace:FindFirstChild("Map") or Workspace
        for _, obj in map:GetDescendants() do
            if obj.Name == "GunDrop" or obj.Name == "Gun" or
               (obj:IsA("Model") and obj:FindFirstChild("Handle")) then
                local part = obj:FindFirstChild("Handle") or obj:IsA("BasePart") and obj
                if part then
                    local pos, onScreen = WorldToViewport(part.Position)
                    if onScreen then
                        local lbl = NewDrawing("Text", {
                            Text     = obj.Name,
                            Position = pos,
                            Color    = Color3.fromRGB(80, 200, 255),
                            Size     = 13,
                            Font     = 2,
                            Outline  = true,
                            Visible  = true
                        })
                        table.insert(State.GunDrawings, lbl)
                    end
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════
--  AIMBOT
-- ════════════════════════════════════════════════════
local function GetAimbotTarget()
    local best, bestDist = nil, State.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in Players:GetPlayers() do
        if plr == LocalPlayer then continue end
        if not IsAlive(plr) then continue end

        -- optional: only target murderer
        if Library.Flags["AimbotMurdererOnly"] then
            local role = GetTeam(plr)
            if role ~= "Murderer" and role ~= "murderer" then continue end
        end

        local char = GetCharacter(plr)
        if not char then continue end
        local part = char:FindFirstChild(State.AimbotPart) or GetRoot(plr)
        if not part then continue end

        local pos2d, onScreen = WorldToViewport(part.Position)
        if not onScreen then continue end

        local dist = (center - pos2d).Magnitude
        if dist < bestDist then
            bestDist = dist
            best = part
        end
    end

    return best
end

local AimbotConn
local function StartAimbot()
    if AimbotConn then AimbotConn:Disconnect() end
    AimbotConn = RunService.RenderStepped:Connect(function()
        if not State.AimbotEnabled then return end
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then return end

        local target = GetAimbotTarget()
        if not target then return end

        local cf = CFrame.new(Camera.CFrame.Position, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(cf, State.AimbotSmooth)
    end)
end
StartAimbot()

-- Silent Aim: redirect bullet via ray / mouse override
local SilentHook
local function ApplySilentAim()
    if SilentHook then
        SilentHook:Disconnect()
        SilentHook = nil
    end
    if not State.SilentAim then return end

    SilentHook = RunService.RenderStepped:Connect(function()
        local target = GetAimbotTarget()
        if not target then return end
        -- Override Mouse.Hit so tools use our target
        local cf = CFrame.new(target.Position)
        -- Attempt property spoof via reflection (executor-side)
        pcall(function()
            Mouse.Hit = cf
        end)
    end)
end

-- ════════════════════════════════════════════════════
--  MOVEMENT
-- ════════════════════════════════════════════════════
local OriginalSpeed   = 16
local FlyBody

local function SetSpeed(val)
    local hum = GetHumanoid(LocalPlayer)
    if hum then hum.WalkSpeed = val end
end

local function StartFly()
    local char = GetCharacter(LocalPlayer)
    local root = GetRoot(LocalPlayer)
    if not char or not root then return end

    -- Remove existing
    if FlyBody then
        pcall(function()
            FlyBody.BodyVelocity:Destroy()
            FlyBody.BodyGyro:Destroy()
        end)
        FlyBody = nil
    end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent   = root

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.CFrame    = root.CFrame
    bg.Parent    = root

    FlyBody = {BodyVelocity = bv, BodyGyro = bg}
end

local function StopFly()
    if FlyBody then
        pcall(function()
            FlyBody.BodyVelocity:Destroy()
            FlyBody.BodyGyro:Destroy()
        end)
        FlyBody = nil
    end
    local hum = GetHumanoid(LocalPlayer)
    if hum then hum.PlatformStand = false end
end

local FlyKeys = {
    [Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
    [Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0),
}

RunService.RenderStepped:Connect(function()
    -- FLY
    if State.FlyEnabled and FlyBody then
        local root = GetRoot(LocalPlayer)
        if root then
            local hum = GetHumanoid(LocalPlayer)
            if hum then hum.PlatformStand = true end

            local dir  = Vector3.zero
            local cf   = Camera.CFrame
            local fwd  = -cf.LookVector
            local rgt  =  cf.RightVector

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= rgt end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += rgt end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)  then dir -= Vector3.new(0, 1, 0) end

            FlyBody.BodyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * State.FlySpeed or Vector3.zero
            FlyBody.BodyGyro.CFrame = cf
        end
    end

    -- SPEED
    if State.SpeedEnabled then
        SetSpeed(State.SpeedValue)
    end

    -- BUNNY HOP
    if State.BunnyHop then
        local hum = GetHumanoid(LocalPlayer)
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum.Jump = true
        end
    end

    -- NOCLIP
    if State.NoclipEnabled then
        local char = GetCharacter(LocalPlayer)
        if char then
            for _, part in char:GetDescendants() do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end

    -- INFINITE STAMINA (MM2 dash)
    if State.InfiniteStamina then
        local char = GetCharacter(LocalPlayer)
        if char then
            local stam = char:FindFirstChild("Stamina") or char:FindFirstChild("stamina")
            if stam and stam:IsA("NumberValue") then
                stam.Value = 100
            end
        end
    end
end)

-- ════════════════════════════════════════════════════
--  DESYNC / FAKE LAG
-- ════════════════════════════════════════════════════
local DesyncConn
local function ApplyDesync()
    if DesyncConn then DesyncConn:Disconnect() DesyncConn = nil end
    if not State.DesyncEnabled then return end

    DesyncConn = RunService.Heartbeat:Connect(function()
        local root = GetRoot(LocalPlayer)
        if not root then return end
        -- Rapidly flicker CFrame to desync server-side position
        local orig = root.CFrame
        local offset = Vector3.new(
            math.random(-State.DesyncStrength, State.DesyncStrength),
            0,
            math.random(-State.DesyncStrength, State.DesyncStrength)
        )
        root.CFrame = orig * CFrame.new(offset)
        task.wait()
        pcall(function() root.CFrame = orig end)
    end)
end

-- ════════════════════════════════════════════════════
--  KILL AURA
-- ════════════════════════════════════════════════════
local function KillAuraLoop()
    task.spawn(function()
        while true do
            task.wait(0.1)
            if not State.KillAura then continue end
            local role = GetTeam(LocalPlayer)
            if role ~= "Murderer" and role ~= "murderer" then continue end

            for _, plr in Players:GetPlayers() do
                if plr == LocalPlayer then continue end
                if not IsAlive(plr) then continue end
                local d = Distance(plr)
                if d <= State.KillAuraRange then
                    -- Fire the kill remote if available
                    local remote = ReplicatedStorage:FindFirstChild("KillPlayer")
                             or ReplicatedStorage:FindFirstChildOfClass("RemoteEvent")
                    if remote then
                        pcall(function() remote:FireServer(plr) end)
                    end
                    -- Fallback: touch-based
                    local char  = GetCharacter(plr)
                    local root  = GetRoot(LocalPlayer)
                    if char and root then
                        local knife = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
                        if knife then
                            local handle = knife:FindFirstChild("Handle")
                            if handle then
                                handle.CFrame = char:GetPivot()
                            end
                        end
                    end
                end
            end
        end
    end)
end
KillAuraLoop()

-- ════════════════════════════════════════════════════
--  AUTO COIN FARM
-- ════════════════════════════════════════════════════
local function AutoCoinLoop()
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not State.AutoCoin then continue end
            local root = GetRoot(LocalPlayer)
            if not root then continue end

            local map = Workspace:FindFirstChild("Map") or Workspace
            local closest, closestDist = nil, math.huge

            for _, obj in map:GetDescendants() do
                if obj.Name == "Coin" or obj.Name == "coin" or
                   (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
                    local d = (obj.Position - root.Position).Magnitude
                    if d < closestDist then
                        closestDist = d
                        closest = obj
                    end
                end
            end

            if closest then
                root.CFrame = CFrame.new(closest.Position)
            end
        end
    end)
end
AutoCoinLoop()

-- ════════════════════════════════════════════════════
--  GOD MODE
-- ════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if State.GodMode then
        local hum = GetHumanoid(LocalPlayer)
        if hum then
            hum.Health = hum.MaxHealth
        end
    end
end)

-- ════════════════════════════════════════════════════
--  FULLBRIGHT
-- ════════════════════════════════════════════════════
local OriginalBrightness
local function SetFullbright(enabled)
    local lighting = game:GetService("Lighting")
    if enabled then
        OriginalBrightness = lighting.Brightness
        lighting.Brightness = 10
        lighting.FogEnd = 1e6
        lighting.GlobalShadows = false
    else
        lighting.Brightness = OriginalBrightness or 1
        lighting.GlobalShadows = true
    end
end

-- ════════════════════════════════════════════════════
--  PLAYER ESP SETUP HOOKS
-- ════════════════════════════════════════════════════
for _, plr in Players:GetPlayers() do
    BuildPlayerESP(plr)
end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() BuildPlayerESP(plr) end)
    BuildPlayerESP(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
    ClearPlayerESP(plr)
end)

-- ════════════════════════════════════════════════════
--  MAIN RENDER LOOP
-- ════════════════════════════════════════════════════
local fpsCount = 0
local fpsClock = tick()
local fpsDisplay = 0

RunService.RenderStepped:Connect(function()
    -- FPS counter
    fpsCount += 1
    local now = tick()
    if now - fpsClock >= 1 then
        fpsDisplay = fpsCount
        fpsCount   = 0
        fpsClock   = now
        HUD.FPS.Text = "FPS: " .. fpsDisplay
    end

    -- Player ESP
    for _, plr in Players:GetPlayers() do
        UpdatePlayerESP(plr)
    end

    -- World ESP (throttled)
    UpdateWorldESP()

    -- HUD
    UpdateHUD()

    -- FOV circle visibility
    FOVCircle.Visible  = State.AimbotEnabled
    FOVCircle.Radius   = State.AimbotFOV
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)

-- ════════════════════════════════════════════════════
--  KEYBIND LIST
-- ════════════════════════════════════════════════════
local KeybindList = Library:KeybindList("MM2 Hub Keybinds")

-- ════════════════════════════════════════════════════
--  ██ PAGE: VISUALS
-- ════════════════════════════════════════════════════
local VisualsPage = Window:Page({Name = "Visuals", Icon = "100050851789190"})

local ESPSection = VisualsPage:Section({Name = "Player ESP", Side = 1, Icon = "117786983271442"})
ESPSection:Toggle({
    Name = "Enable ESP", Flag = "ESPEnabled", Default = false,
    Callback = function(v) State.ESPEnabled = v end
})
ESPSection:Toggle({
    Name = "Show Names", Flag = "ESPNames", Default = true,
    Callback = function() end
})
ESPSection:Toggle({
    Name = "Show Distance", Flag = "ESPDistance", Default = true,
    Callback = function() end
})
ESPSection:Toggle({
    Name = "Tracers", Flag = "ESPTracers", Default = false,
    Callback = function() end
})
ESPSection:Toggle({
    Name = "Box Fill", Flag = "ESPBoxFill", Default = false,
    Callback = function() end
})

local WorldESPSection = VisualsPage:Section({Name = "World ESP", Side = 2, Icon = "122669828593160"})
WorldESPSection:Toggle({
    Name = "Coin ESP", Flag = "CoinESP", Default = false,
    Callback = function(v) State.CoinESP = v end
})
WorldESPSection:Toggle({
    Name = "Gun ESP", Flag = "GunESP", Default = false,
    Callback = function(v) State.GunESP = v end
})

local HUDSection = VisualsPage:Section({Name = "HUD", Side = 2, Icon = "73789337996373"})
HUDSection:Toggle({
    Name = "Show Info HUD", Flag = "ShowHUD", Default = true,
    Callback = function(v) State.ShowHUD = v end
})
HUDSection:Toggle({
    Name = "Fullbright", Flag = "FullBright", Default = false,
    Callback = function(v)
        State.FullBright = v
        SetFullbright(v)
    end
})

-- ════════════════════════════════════════════════════
--  ██ PAGE: COMBAT
-- ════════════════════════════════════════════════════
local CombatPage = Window:Page({Name = "Combat", Icon = "121760666525660"})

local AimbotSection = CombatPage:Section({Name = "Aimbot", Side = 1, Icon = "117786983271442"})
AimbotSection:Toggle({
    Name = "Enable Aimbot", Flag = "AimbotEnabled", Default = false,
    Callback = function(v)
        State.AimbotEnabled = v
        FOVCircle.Visible = v
    end
})
AimbotSection:Toggle({
    Name = "Silent Aim", Flag = "SilentAim", Default = false,
    Callback = function(v)
        State.SilentAim = v
        ApplySilentAim()
    end
})
AimbotSection:Toggle({
    Name = "Murderer Only", Flag = "AimbotMurdererOnly", Default = true,
    Callback = function() end
})
AimbotSection:Dropdown({
    Name = "Target Part", Flag = "AimbotPart", Default = "Head",
    Items = {"Head", "HumanoidRootPart", "UpperTorso", "Neck"},
    Callback = function(v) State.AimbotPart = v end
})
AimbotSection:Slider({
    Name = "FOV Radius", Flag = "AimbotFOV", Default = 120,
    Min = 10, Max = 500, Decimals = 1,
    Callback = function(v) State.AimbotFOV = v end
})
AimbotSection:Slider({
    Name = "Smoothness", Flag = "AimbotSmooth", Default = 0.15,
    Min = 0.01, Max = 1, Decimals = 0.01,
    Suffix = "x",
    Callback = function(v) State.AimbotSmooth = v end
})

local KillSection = CombatPage:Section({Name = "Kill Aura", Side = 2, Icon = "100050851789190"})
KillSection:Toggle({
    Name = "Kill Aura", Flag = "KillAura", Default = false,
    Callback = function(v) State.KillAura = v end
}):SubKeybind({Flag = "KillAuraKey", Default = Enum.KeyCode.F})
KillSection:Slider({
    Name = "Kill Range", Flag = "KillAuraRange", Default = 15,
    Min = 1, Max = 60, Decimals = 1, Suffix = "st",
    Callback = function(v) State.KillAuraRange = v end
})

-- ════════════════════════════════════════════════════
--  ██ PAGE: MOVEMENT
-- ════════════════════════════════════════════════════
local MovementPage = Window:Page({Name = "Movement", Icon = "92464809279921"})

local SpeedSection = MovementPage:Section({Name = "Speed", Side = 1, Icon = "122669828593160"})
SpeedSection:Toggle({
    Name = "Speed Hack", Flag = "SpeedEnabled", Default = false,
    Callback = function(v)
        State.SpeedEnabled = v
        if not v then SetSpeed(16) end
    end
}):SubKeybind({Flag = "SpeedKey", Default = Enum.KeyCode.X})
SpeedSection:Slider({
    Name = "Speed Value", Flag = "SpeedValue", Default = 30,
    Min = 16, Max = 120, Decimals = 1, Suffix = " ws",
    Callback = function(v) State.SpeedValue = v end
})
SpeedSection:Toggle({
    Name = "Bunny Hop", Flag = "BunnyHop", Default = false,
    Callback = function(v) State.BunnyHop = v end
}):SubKeybind({Flag = "BhopKey", Default = Enum.KeyCode.V})

local FlySection = MovementPage:Section({Name = "Fly", Side = 1, Icon = "117786983271442"})
FlySection:Toggle({
    Name = "Fly", Flag = "FlyEnabled", Default = false,
    Callback = function(v)
        State.FlyEnabled = v
        if v then StartFly() else StopFly() end
    end
}):SubKeybind({Flag = "FlyKey", Default = Enum.KeyCode.G})
FlySection:Slider({
    Name = "Fly Speed", Flag = "FlySpeed", Default = 50,
    Min = 5, Max = 300, Decimals = 1, Suffix = " sp",
    Callback = function(v) State.FlySpeed = v end
})

local MiscMovSection = MovementPage:Section({Name = "Misc Movement", Side = 2, Icon = "73789337996373"})
MiscMovSection:Toggle({
    Name = "Noclip", Flag = "NoclipEnabled", Default = false,
    Callback = function(v) State.NoclipEnabled = v end
}):SubKeybind({Flag = "NoclipKey", Default = Enum.KeyCode.N})
MiscMovSection:Toggle({
    Name = "Infinite Stamina", Flag = "InfiniteStamina", Default = false,
    Callback = function(v) State.InfiniteStamina = v end
})
MiscMovSection:Toggle({
    Name = "No Fall Damage", Flag = "NoFallDamage", Default = false,
    Callback = function(v)
        State.NoFallDamage = v
        local hum = GetHumanoid(LocalPlayer)
        if hum then hum.AutoJumpEnabled = not v end
    end
})

-- ════════════════════════════════════════════════════
--  ██ PAGE: FARM
-- ════════════════════════════════════════════════════
local FarmPage = Window:Page({Name = "Farm", Icon = "81598136527047"})

local CoinSection = FarmPage:Section({Name = "Coin Farm", Side = 1, Icon = "73789337996373"})
CoinSection:Toggle({
    Name = "Auto Coin Farm", Flag = "AutoCoin", Default = false,
    Callback = function(v) State.AutoCoin = v end
}):SubKeybind({Flag = "AutoCoinKey", Default = Enum.KeyCode.C})
CoinSection:Label("Teleports to nearest coin automatically")

local GodSection = FarmPage:Section({Name = "Survival", Side = 2, Icon = "121760666525660"})
GodSection:Toggle({
    Name = "God Mode", Flag = "GodMode", Default = false,
    Callback = function(v) State.GodMode = v end
})

-- ════════════════════════════════════════════════════
--  ██ PAGE: MISC
-- ════════════════════════════════════════════════════
local MiscPage = Window:Page({Name = "Misc", Icon = "122669828593160"})

local DesyncSection = MiscPage:Section({Name = "Desync", Side = 1, Icon = "100050851789190"})
DesyncSection:Toggle({
    Name = "Enable Desync", Flag = "DesyncEnabled", Default = false,
    Callback = function(v)
        State.DesyncEnabled = v
        ApplyDesync()
    end
}):SubKeybind({Flag = "DesyncKey", Default = Enum.KeyCode.Z})
DesyncSection:Slider({
    Name = "Desync Strength", Flag = "DesyncStrength", Default = 5,
    Min = 1, Max = 25, Decimals = 1, Suffix = " st",
    Callback = function(v)
        State.DesyncStrength = v
        if State.DesyncEnabled then ApplyDesync() end
    end
})
DesyncSection:Label("Makes your position appear inconsistent to the server")

local RoleSection = MiscPage:Section({Name = "Role Tricks", Side = 2, Icon = "117786983271442"})
RoleSection:Button({
    Name = "Claim Sheriff Drop",
    Callback = function()
        -- attempt to auto-pick up sheriff gun if dropped
        local root = GetRoot(LocalPlayer)
        if not root then return end
        local map = Workspace:FindFirstChild("Map") or Workspace
        for _, obj in map:GetDescendants() do
            if obj.Name == "GunDrop" or obj.Name == "SheriffGun" then
                local part = obj:FindFirstChild("Handle") or (obj:IsA("BasePart") and obj)
                if part then
                    root.CFrame = CFrame.new(part.Position)
                    Library:Notification({Title="Misc", Description="Teleported to gun drop.", Duration=1.5})
                    break
                end
            end
        end
    end
})
RoleSection:Button({
    Name = "Fake Report Spam",
    Callback = function()
        -- Spam a notification (visual troll on local only — no server call)
        for i = 1, 3 do
            task.delay(i * 0.4, function()
                Library:Notification({
                    Title = "Report",
                    Description = "Player reported successfully.",
                    Duration = 2,
                    Icon = "73789337996373"
                })
            end)
        end
    end
})

local InfoSection = MiscPage:Section({Name = "Info", Side = 2, Icon = "73789337996373"})
local PlrCountLabel = InfoSection:Label("Players: --")
local AliveLabel    = InfoSection:Label("Alive: --")
local RoleLabel     = InfoSection:Label("Role: --")

task.spawn(function()
    while true do
        task.wait(1)
        local alive = 0
        for _, p in Players:GetPlayers() do
            if IsAlive(p) then alive += 1 end
        end
        PlrCountLabel:SetText("Players: " .. #Players:GetPlayers())
        AliveLabel:SetText("Alive: " .. alive)
        RoleLabel:SetText("Role: " .. GetTeam(LocalPlayer))
    end
end)

-- ════════════════════════════════════════════════════
--  ██ SETTINGS PAGE
-- ════════════════════════════════════════════════════
Library:CreateSettingsPage(Window, KeybindList)

-- ════════════════════════════════════════════════════
--  WATERMARK
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(1)
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        Library:Watermark({
            "MM2 Hub",
            " | ",
            "FPS: " .. fpsDisplay,
            " | ",
            "Ping: " .. ping .. "ms",
            " | ",
            GetTeam(LocalPlayer)
        })
    end
end)
Library.WatermarkFrame.Instance.Visible = true

-- ════════════════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════════════════
Window:Init()

Library:Notification({
    Title       = "MM2 Hub",
    Description = "Loaded successfully. RightAlt to toggle menu.",
    Duration    = 3,
    Icon        = "73789337996373"
})
