--[[
    Murder Mystery 2 — Full Script v2
    Library: provided (getgenv-based, Potassium compatible)
    Engine: Roblox / MM2
    Features: ESP, Aimbot, Movement, Autofarm, Misc, Desync,
              Anti-Fling, Anti-Kill, Anti-Exploit, Info HUD
]]

-- ════════════════════════════════════════════════════
--  SERVICES & ALIASES
-- ════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera
local Mouse             = LocalPlayer:GetMouse()

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
for _, F in {"MM2Hub","MM2Hub/Assets","MM2Hub/Configs"} do
    if not isfolder(F) then makefolder(F) end
end

-- ════════════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════════════
local State = {
    -- ESP
    ESPEnabled    = false,
    CoinESP       = false,
    GunESP        = false,
    -- Aimbot
    AimbotEnabled = false,
    SilentAim     = false,
    AimbotFOV     = 120,
    AimbotSmooth  = 0.15,
    AimbotPart    = "Head",
    -- Movement
    SpeedEnabled  = false,
    SpeedValue    = 30,
    FlyEnabled    = false,
    FlySpeed      = 50,
    NoclipEnabled = false,
    BunnyHop      = false,
    InfiniteStamina = false,
    -- Combat
    KillAura      = false,
    KillAuraRange = 15,
    -- Farm
    AutoCoin      = false,
    -- Misc
    DesyncEnabled   = false,
    DesyncStrength  = 5,
    FullBright      = false,
    GodMode         = false,
    ShowHUD         = true,
    -- Anti-Exploit
    AntiFling       = false,
    AntiKill        = false,
    AntiSpeedHack   = false,
    AntiTeleport    = false,
    AntiNoclip      = false,
    MaxTeleportDist = 50,
    -- Internal
    ESPDrawings   = {},
    CoinDrawings  = {},
    GunDrawings   = {},
    FlyBody       = nil,
}

-- ════════════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════════════
local function GetChar(p)  return p and p.Character end
local function GetRoot(p)  local c=GetChar(p) return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum(p)   local c=GetChar(p) return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive(p)  local h=GetHum(p) return h and h.Health>0 end
local function Dist(p)
    local r=GetRoot(p) local m=GetRoot(LocalPlayer)
    if not r or not m then return math.huge end
    return (r.Position-m.Position).Magnitude
end
local function WTV(pos)
    local v,on=Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X,v.Y),on,v.Z
end
local function GetRole(p)
    local ls=p:FindFirstChild("leaderstats")
    if ls then
        local r=ls:FindFirstChild("Role") or ls:FindFirstChild("role")
        if r then return r.Value end
    end
    return "Innocent"
end
local function RoleColor(p)
    local r=GetRole(p)
    if r=="Murderer" or r=="murderer" then return Color3.fromRGB(255,60,60)
    elseif r=="Sheriff" or r=="sheriff" then return Color3.fromRGB(80,140,255)
    else return Color3.fromRGB(100,255,100) end
end

-- ════════════════════════════════════════════════════
--  DRAWING POOL
-- ════════════════════════════════════════════════════
local function ND(t,p) local d=Drawing.new(t) for k,v in p do d[k]=v end return d end
local function RemDraw(tbl)
    for _,d in tbl do
        if type(d)=="table" then for _,v in d do pcall(function()v:Remove()end) end
        else pcall(function()d:Remove()end) end
    end table.clear(tbl)
end

-- ════════════════════════════════════════════════════
--  FOV CIRCLE
-- ════════════════════════════════════════════════════
local FOVCircle = ND("Circle",{Visible=false,Radius=120,Color=Color3.fromRGB(255,255,255),Thickness=1,Filled=false,Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)})

-- ════════════════════════════════════════════════════
--  INFO HUD
-- ════════════════════════════════════════════════════
local HUD = {
    BG   = ND("Square",{Visible=false,Color=Color3.fromRGB(12,12,15),Transparency=0.4,Filled=true,Size=Vector2.new(180,110),Position=Vector2.new(6,6)}),
    FPS  = ND("Text",{Visible=false,Color=Color3.fromRGB(100,220,255),Size=14,Font=2,Text="FPS: --"}),
    Ping = ND("Text",{Visible=false,Color=Color3.fromRGB(100,255,160),Size=14,Font=2,Text="Ping: --"}),
    Role = ND("Text",{Visible=false,Color=Color3.fromRGB(255,200,100),Size=14,Font=2,Text="Role: --"}),
    Alive= ND("Text",{Visible=false,Color=Color3.fromRGB(200,200,200),Size=14,Font=2,Text="Alive: --"}),
    Coins= ND("Text",{Visible=false,Color=Color3.fromRGB(255,230,60), Size=14,Font=2,Text="Coins: --"}),
    Prot = ND("Text",{Visible=false,Color=Color3.fromRGB(255,100,100),Size=14,Font=2,Text="Prot: OFF"}),
    Bar  = ND("Square",{Visible=false,Color=Color3.fromRGB(0,116,224),Filled=true,Size=Vector2.new(180,2),Position=Vector2.new(6,4)}),
}

local fpsDisplay = 0
local function UpdateHUD()
    local vis = State.ShowHUD
    for _,v in HUD do v.Visible=vis end
    if not vis then return end
    local ping=0
    pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    local alive=0
    for _,p in Players:GetPlayers() do if IsAlive(p) then alive+=1 end end
    local coins=0
    local ls=LocalPlayer:FindFirstChild("leaderstats")
    if ls then local c=ls:FindFirstChild("Coins") or ls:FindFirstChild("coins") if c then coins=c.Value end end
    local base=Vector2.new(14,10)
    HUD.FPS.Position   = base
    HUD.Ping.Position  = base+Vector2.new(0,18)
    HUD.Role.Position  = base+Vector2.new(0,36)
    HUD.Alive.Position = base+Vector2.new(0,54)
    HUD.Coins.Position = base+Vector2.new(0,72)
    HUD.Prot.Position  = base+Vector2.new(0,90)
    HUD.Ping.Text  = "Ping: "..ping.."ms"
    HUD.Role.Text  = "Role: "..GetRole(LocalPlayer)
    HUD.Role.Color = RoleColor(LocalPlayer)
    HUD.Alive.Text = "Alive: "..alive
    HUD.Coins.Text = "Coins: "..coins
    local protOn = State.AntiFling or State.AntiKill or State.AntiTeleport
    HUD.Prot.Text  = protOn and "Prot: ON" or "Prot: OFF"
    HUD.Prot.Color = protOn and Color3.fromRGB(100,255,160) or Color3.fromRGB(255,100,100)
end

-- ════════════════════════════════════════════════════
--  ██ ANTI-EXPLOIT SYSTEM
-- ════════════════════════════════════════════════════

-- Track last known good CFrame, velocity, health
local LastGoodCF       = CFrame.new(0,0,0)
local LastGoodHealth   = 100
local AntiExploitConns = {}
local BlockedPlayers   = {}

-- ── ANTI FLING ──────────────────────────────────────
-- Locks our HumanoidRootPart so exploiters can't touch/fling us
local function EnableAntiFling()
    local root = GetRoot(LocalPlayer)
    if not root then return end

    -- Make our parts massless so touch-based fling has no effect
    local char = GetChar(LocalPlayer)
    if char then
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(
                    0.01, 0, 0, 0, 0  -- density near-zero = massless
                )
            end
        end
    end

    -- BodyPosition anchor so velocity-based fling snaps us back
    local existing = root:FindFirstChild("AntiFlingBP")
    if not existing then
        local bp = Instance.new("BodyPosition")
        bp.Name         = "AntiFlingBP"
        bp.MaxForce     = Vector3.new(0, 0, 0)  -- off by default, activated on fling
        bp.Position     = root.Position
        bp.P            = 1e5
        bp.D            = 1e3
        bp.Parent       = root
    end

    -- Monitor velocity spikes — if suddenly > 200 studs/s someone flung us
    local lastPos = root.Position
    AntiExploitConns["fling"] = RunService.Heartbeat:Connect(function()
        if not State.AntiFling then return end
        local r = GetRoot(LocalPlayer)
        if not r then return end

        local vel = r.AssemblyLinearVelocity
        local speed = vel.Magnitude

        if speed > 200 then
            -- Snap back and zero velocity
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = LastGoodCF
            Library:Notification({
                Title="Anti-Fling",
                Description="Fling attempt blocked.",
                Duration=2,
                Icon="73789337996373"
            })
        else
            LastGoodCF = r.CFrame
        end
    end)
end

local function DisableAntiFling()
    if AntiExploitConns["fling"] then
        AntiExploitConns["fling"]:Disconnect()
        AntiExploitConns["fling"] = nil
    end
    -- Restore physics properties
    local char = GetChar(LocalPlayer)
    if char then
        for _, part in char:GetDescendants() do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(
                    0.7, 0.3, 0.3, 0.1, 0.1
                )
            end
        end
    end
    local root = GetRoot(LocalPlayer)
    if root then
        local bp = root:FindFirstChild("AntiFlingBP")
        if bp then bp:Destroy() end
    end
end

-- ── ANTI KILL ───────────────────────────────────────
-- Prevents exploiters from damaging/killing us directly
-- Uses a health lock and detects illegitimate damage sources
local AntiKillConn
local function EnableAntiKill()
    local hum = GetHum(LocalPlayer)
    if not hum then return end

    LastGoodHealth = hum.Health

    AntiKillConn = hum.HealthChanged:Connect(function(newHealth)
        if not State.AntiKill then return end
        local hm = GetHum(LocalPlayer)
        if not hm then return end

        -- If health dropped by more than 5 in one frame outside of legitimate game damage
        local drop = LastGoodHealth - newHealth
        if drop > 5 and newHealth > 0 then
            -- Restore health
            hm.Health = LastGoodHealth
            Library:Notification({
                Title="Anti-Kill",
                Description="Damage blocked ("..math.floor(drop).." dmg).",
                Duration=2,
                Icon="73789337996373"
            })
        else
            LastGoodHealth = newHealth
        end
    end)
end

local function DisableAntiKill()
    if AntiKillConn then
        AntiKillConn:Disconnect()
        AntiKillConn = nil
    end
end

-- ── ANTI TELEPORT ───────────────────────────────────
-- Prevents exploiters from teleporting us far away
local function EnableAntiTeleport()
    local lastPos = nil
    AntiExploitConns["teleport"] = RunService.Heartbeat:Connect(function()
        if not State.AntiTeleport then return end
        local root = GetRoot(LocalPlayer)
        if not root then lastPos=nil return end

        if lastPos then
            local jumped = (root.Position - lastPos).Magnitude
            -- If we moved more than MaxTeleportDist in one frame without flying/speed
            if jumped > State.MaxTeleportDist and not State.FlyEnabled then
                root.CFrame = CFrame.new(lastPos)
                Library:Notification({
                    Title="Anti-Teleport",
                    Description="Teleport attempt blocked.",
                    Duration=2,
                    Icon="73789337996373"
                })
            else
                lastPos = root.Position
            end
        else
            lastPos = root.Position
        end
    end)
end

local function DisableAntiTeleport()
    if AntiExploitConns["teleport"] then
        AntiExploitConns["teleport"]:Disconnect()
        AntiExploitConns["teleport"] = nil
    end
end

-- ── ANTI NOCLIP DETECTION ───────────────────────────
-- Detects if another player is noclipping into us to knife
local function EnableAntiNoclip()
    AntiExploitConns["noclip"] = RunService.Heartbeat:Connect(function()
        if not State.AntiNoclip then return end
        local myRoot = GetRoot(LocalPlayer)
        if not myRoot then return end

        for _, plr in Players:GetPlayers() do
            if plr == LocalPlayer then continue end
            local theirRoot = GetRoot(plr)
            if not theirRoot then continue end

            local d = (theirRoot.Position - myRoot.Position).Magnitude
            -- If another player is INSIDE our hitbox (< 2 studs) and moving fast
            if d < 2 then
                local vel = theirRoot.AssemblyLinearVelocity.Magnitude
                if vel > 5 or BlockedPlayers[plr] then
                    BlockedPlayers[plr] = true
                    -- Push them away from us
                    theirRoot.AssemblyLinearVelocity = (theirRoot.Position - myRoot.Position).Unit * 50
                end
            else
                BlockedPlayers[plr] = nil
            end
        end
    end)
end

local function DisableAntiNoclip()
    if AntiExploitConns["noclip"] then
        AntiExploitConns["noclip"]:Disconnect()
        AntiExploitConns["noclip"] = nil
    end
end

-- ── ANTI SPEED HACK ─────────────────────────────────
-- Detects insanely fast players moving toward you
local AntiSpeedNotifCooldown = {}
local function EnableAntiSpeedHack()
    AntiExploitConns["speed"] = RunService.Heartbeat:Connect(function()
        if not State.AntiSpeedHack then return end
        local myRoot = GetRoot(LocalPlayer)
        if not myRoot then return end

        for _, plr in Players:GetPlayers() do
            if plr == LocalPlayer then continue end
            local r = GetRoot(plr)
            if not r then continue end

            local vel = r.AssemblyLinearVelocity.Magnitude
            local dist = (r.Position - myRoot.Position).Magnitude

            -- Moving way faster than normal AND close to us
            if vel > 80 and dist < 30 then
                local now = tick()
                if not AntiSpeedNotifCooldown[plr] or now - AntiSpeedNotifCooldown[plr] > 5 then
                    AntiSpeedNotifCooldown[plr] = now
                    Library:Notification({
                        Title="Anti-Speed",
                        Description=plr.Name.." is speed hacking near you.",
                        Duration=3,
                        Icon="73789337996373"
                    })
                end
            end
        end
    end)
end

local function DisableAntiSpeedHack()
    if AntiExploitConns["speed"] then
        AntiExploitConns["speed"]:Disconnect()
        AntiExploitConns["speed"] = nil
    end
end

-- ── CHARACTER RESPAWN HOOKS ──────────────────────────
-- Re-apply protections on respawn
local function ApplyAntiExploitToChar()
    task.wait(0.5)
    if State.AntiFling    then EnableAntiFling()    end
    if State.AntiKill     then EnableAntiKill()     end
    if State.AntiTeleport then EnableAntiTeleport() end
    if State.AntiNoclip   then EnableAntiNoclip()   end
    if State.AntiSpeedHack then EnableAntiSpeedHack() end
end

LocalPlayer.CharacterAdded:Connect(ApplyAntiExploitToChar)

-- ════════════════════════════════════════════════════
--  ESP CORE
-- ════════════════════════════════════════════════════
local function ClearESP(plr)
    if State.ESPDrawings[plr] then
        for _,d in State.ESPDrawings[plr] do pcall(function()d:Remove()end) end
        State.ESPDrawings[plr]=nil
    end
end

local function BuildESP(plr)
    if plr==LocalPlayer then return end
    ClearESP(plr)
    State.ESPDrawings[plr]={
        Box     = ND("Square",{Visible=false,Thickness=1,Filled=false,Color=Color3.fromRGB(255,255,255)}),
        BoxFill = ND("Square",{Visible=false,Thickness=1,Filled=true, Color=Color3.fromRGB(0,0,0),Transparency=0.4}),
        Name    = ND("Text",  {Visible=false,Size=13,Font=2,Outline=true,Color=Color3.fromRGB(255,255,255)}),
        Dist    = ND("Text",  {Visible=false,Size=11,Font=2,Outline=true,Color=Color3.fromRGB(200,200,200)}),
        Tracer  = ND("Line",  {Visible=false,Thickness=1,Color=Color3.fromRGB(255,255,255)}),
        HpBar   = ND("Square",{Visible=false,Thickness=1,Filled=true, Color=Color3.fromRGB(0,255,0)}),
        HpBG    = ND("Square",{Visible=false,Thickness=1,Filled=true, Color=Color3.fromRGB(0,0,0),Transparency=0.5}),
    }
end

local function UpdateESP(plr)
    local d=State.ESPDrawings[plr]
    if not d then return end
    local char=GetChar(plr) local root=GetRoot(plr) local hum=GetHum(plr)
    if not State.ESPEnabled or not char or not root or not hum or hum.Health<=0 then
        for _,v in d do v.Visible=false end return
    end
    local head=char:FindFirstChild("Head")
    local lfoot=char:FindFirstChild("LeftFoot") or root
    local tp,_=WTV(head and head.Position or root.Position+Vector3.new(0,3,0))
    local bp,_=WTV(lfoot and lfoot.Position or root.Position-Vector3.new(0,3,0))
    local rp,ron,_=WTV(root.Position)
    if not ron then for _,v in d do v.Visible=false end return end
    local h=math.abs(bp.Y-tp.Y) local w=h*0.4
    local x=rp.X-w/2 local y=tp.Y
    local col=RoleColor(plr)
    local dist=(root.Position-GetRoot(LocalPlayer).Position).Magnitude
    local hp=hum.Health local mhp=hum.MaxHealth
    d.BoxFill.Position=Vector2.new(x,y) d.BoxFill.Size=Vector2.new(w,h) d.BoxFill.Visible=Library.Flags["ESPBoxFill"]==true
    d.Box.Color=col d.Box.Position=Vector2.new(x,y) d.Box.Size=Vector2.new(w,h) d.Box.Visible=true
    d.Name.Text=plr.Name d.Name.Color=col d.Name.Position=Vector2.new(rp.X,y-16) d.Name.Visible=Library.Flags["ESPNames"]~=false
    d.Dist.Text=math.floor(dist).."m" d.Dist.Position=Vector2.new(rp.X,y+h+2) d.Dist.Visible=Library.Flags["ESPDistance"]~=false
    d.Tracer.From=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) d.Tracer.To=Vector2.new(rp.X,rp.Y) d.Tracer.Color=col d.Tracer.Visible=Library.Flags["ESPTracers"]==true
    local hpPct=math.clamp(hp/mhp,0,1) local hbH=h*hpPct
    local hbCol=Color3.fromRGB(255-(hpPct*255),hpPct*255,0)
    d.HpBG.Position=Vector2.new(x-5,y) d.HpBG.Size=Vector2.new(3,h) d.HpBG.Visible=true
    d.HpBar.Position=Vector2.new(x-5,y+h-hbH) d.HpBar.Size=Vector2.new(3,hbH) d.HpBar.Color=hbCol d.HpBar.Visible=true
end

-- ════════════════════════════════════════════════════
--  WORLD ESP
-- ════════════════════════════════════════════════════
local function UpdateWorldESP()
    RemDraw(State.CoinDrawings)
    if State.CoinESP then
        local map=Workspace:FindFirstChild("Map") or Workspace
        for _,obj in map:GetDescendants() do
            if obj.Name=="Coin" or obj.Name=="coin" or (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
                local pos,on=WTV(obj.Position)
                if on then table.insert(State.CoinDrawings,ND("Text",{Text="Coin",Position=pos,Color=Color3.fromRGB(255,220,30),Size=13,Font=2,Outline=true,Visible=true})) end
            end
        end
    end
    RemDraw(State.GunDrawings)
    if State.GunESP then
        local map=Workspace:FindFirstChild("Map") or Workspace
        for _,obj in map:GetDescendants() do
            if obj.Name=="GunDrop" or obj.Name=="Gun" or (obj:IsA("Model") and obj:FindFirstChild("Handle")) then
                local part=obj:FindFirstChild("Handle") or (obj:IsA("BasePart") and obj)
                if part then
                    local pos,on=WTV(part.Position)
                    if on then table.insert(State.GunDrawings,ND("Text",{Text=obj.Name,Position=pos,Color=Color3.fromRGB(80,200,255),Size=13,Font=2,Outline=true,Visible=true})) end
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════
--  AIMBOT
-- ════════════════════════════════════════════════════
local function GetTarget()
    local best,bestD=nil,State.AimbotFOV
    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,plr in Players:GetPlayers() do
        if plr==LocalPlayer then continue end
        if not IsAlive(plr) then continue end
        if Library.Flags["AimbotMurdererOnly"] then
            local r=GetRole(plr)
            if r~="Murderer" and r~="murderer" then continue end
        end
        local char=GetChar(plr) if not char then continue end
        local part=char:FindFirstChild(State.AimbotPart) or GetRoot(plr)
        if not part then continue end
        local p2,on=WTV(part.Position)
        if not on then continue end
        local d=(center-p2).Magnitude
        if d<bestD then bestD=d best=part end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if State.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then
        local t=GetTarget()
        if t then
            local cf=CFrame.new(Camera.CFrame.Position,t.Position)
            Camera.CFrame=Camera.CFrame:Lerp(cf,State.AimbotSmooth)
        end
    end
end)

-- Silent Aim
local SilentConn
local function ApplySilentAim()
    if SilentConn then SilentConn:Disconnect() SilentConn=nil end
    if not State.SilentAim then return end
    SilentConn=RunService.RenderStepped:Connect(function()
        local t=GetTarget()
        if t then pcall(function() Mouse.Hit=CFrame.new(t.Position) end) end
    end)
end

-- ════════════════════════════════════════════════════
--  MOVEMENT
-- ════════════════════════════════════════════════════
local function SetSpeed(v) local h=GetHum(LocalPlayer) if h then h.WalkSpeed=v end end

local function StartFly()
    local root=GetRoot(LocalPlayer) if not root then return end
    if State.FlyBody then
        pcall(function() State.FlyBody.BV:Destroy() State.FlyBody.BG:Destroy() end)
        State.FlyBody=nil
    end
    local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(1e9,1e9,1e9) bv.Velocity=Vector3.zero bv.Parent=root
    local bg=Instance.new("BodyGyro") bg.MaxTorque=Vector3.new(1e9,1e9,1e9) bg.CFrame=root.CFrame bg.Parent=root
    State.FlyBody={BV=bv,BG=bg}
end

local function StopFly()
    if State.FlyBody then
        pcall(function() State.FlyBody.BV:Destroy() State.FlyBody.BG:Destroy() end)
        State.FlyBody=nil
    end
    local h=GetHum(LocalPlayer) if h then h.PlatformStand=false end
end

RunService.RenderStepped:Connect(function()
    if State.FlyEnabled and State.FlyBody then
        local root=GetRoot(LocalPlayer) if not root then return end
        local h=GetHum(LocalPlayer) if h then h.PlatformStand=true end
        local dir=Vector3.zero local cf=Camera.CFrame
        local fwd=-cf.LookVector local rgt=cf.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=rgt end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=rgt end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
        State.FlyBody.BV.Velocity=dir.Magnitude>0 and dir.Unit*State.FlySpeed or Vector3.zero
        State.FlyBody.BG.CFrame=cf
    end
    if State.SpeedEnabled then SetSpeed(State.SpeedValue) end
    if State.BunnyHop then
        local h=GetHum(LocalPlayer)
        if h and h.FloorMaterial~=Enum.Material.Air then h.Jump=true end
    end
    if State.NoclipEnabled then
        local char=GetChar(LocalPlayer)
        if char then for _,p in char:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end end
    end
    if State.InfiniteStamina then
        local char=GetChar(LocalPlayer)
        if char then
            local s=char:FindFirstChild("Stamina") or char:FindFirstChild("stamina")
            if s and s:IsA("NumberValue") then s.Value=100 end
        end
    end
    if State.GodMode then
        local h=GetHum(LocalPlayer) if h then h.Health=h.MaxHealth end
    end
end)

-- ════════════════════════════════════════════════════
--  DESYNC
-- ════════════════════════════════════════════════════
local DesyncConn
local function ApplyDesync()
    if DesyncConn then DesyncConn:Disconnect() DesyncConn=nil end
    if not State.DesyncEnabled then return end
    DesyncConn=RunService.Heartbeat:Connect(function()
        local root=GetRoot(LocalPlayer) if not root then return end
        local orig=root.CFrame
        local off=Vector3.new(math.random(-State.DesyncStrength,State.DesyncStrength),0,math.random(-State.DesyncStrength,State.DesyncStrength))
        root.CFrame=orig*CFrame.new(off)
        task.wait()
        pcall(function() root.CFrame=orig end)
    end)
end

-- ════════════════════════════════════════════════════
--  KILL AURA
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.1)
        if not State.KillAura then continue end
        local role=GetRole(LocalPlayer)
        if role~="Murderer" and role~="murderer" then continue end
        for _,plr in Players:GetPlayers() do
            if plr==LocalPlayer then continue end
            if not IsAlive(plr) then continue end
            if Dist(plr)<=State.KillAuraRange then
                local remote=ReplicatedStorage:FindFirstChild("KillPlayer") or ReplicatedStorage:FindFirstChildOfClass("RemoteEvent")
                if remote then pcall(function() remote:FireServer(plr) end) end
                local char=GetChar(plr) local root=GetRoot(LocalPlayer)
                if char and root then
                    local knife=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
                    if knife then
                        local handle=knife:FindFirstChild("Handle")
                        if handle then handle.CFrame=char:GetPivot() end
                    end
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════
--  AUTO COIN FARM
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.05)
        if not State.AutoCoin then continue end
        local root=GetRoot(LocalPlayer) if not root then continue end
        local map=Workspace:FindFirstChild("Map") or Workspace
        local closest,closestD=nil,math.huge
        for _,obj in map:GetDescendants() do
            if obj.Name=="Coin" or obj.Name=="coin" or (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
                local d=(obj.Position-root.Position).Magnitude
                if d<closestD then closestD=d closest=obj end
            end
        end
        if closest then root.CFrame=CFrame.new(closest.Position) end
    end
end)

-- ════════════════════════════════════════════════════
--  FULLBRIGHT
-- ════════════════════════════════════════════════════
local OrigBrightness
local function SetFullbright(on)
    local L=game:GetService("Lighting")
    if on then OrigBrightness=L.Brightness L.Brightness=10 L.FogEnd=1e6 L.GlobalShadows=false
    else L.Brightness=OrigBrightness or 1 L.GlobalShadows=true end
end

-- ════════════════════════════════════════════════════
--  PLAYER HOOKS
-- ════════════════════════════════════════════════════
for _,p in Players:GetPlayers() do BuildESP(p) end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1) BuildESP(p) end)
    BuildESP(p)
end)
Players.PlayerRemoving:Connect(ClearESP)

-- ════════════════════════════════════════════════════
--  MAIN RENDER LOOP
-- ════════════════════════════════════════════════════
local fpsCount=0 local fpsClock=tick()
RunService.RenderStepped:Connect(function()
    fpsCount+=1
    local now=tick()
    if now-fpsClock>=1 then
        fpsDisplay=fpsCount fpsCount=0 fpsClock=now
        HUD.FPS.Text="FPS: "..fpsDisplay
    end
    for _,p in Players:GetPlayers() do UpdateESP(p) end
    UpdateWorldESP()
    UpdateHUD()
    FOVCircle.Visible=State.AimbotEnabled
    FOVCircle.Radius=State.AimbotFOV
    FOVCircle.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
end)

-- ════════════════════════════════════════════════════
--  KEYBIND LIST
-- ════════════════════════════════════════════════════
local KeybindList=Library:KeybindList("MM2 Hub Keybinds")

-- ════════════════════════════════════════════════════
--  ██ PAGE: VISUALS
-- ════════════════════════════════════════════════════
local VisualsPage=Window:Page({Name="Visuals",Icon="100050851789190"})

local ESPSec=VisualsPage:Section({Name="Player ESP",Side=1,Icon="117786983271442"})
ESPSec:Toggle({Name="Enable ESP",Flag="ESPEnabled",Default=false,Callback=function(v) State.ESPEnabled=v end})
ESPSec:Toggle({Name="Show Names",Flag="ESPNames",Default=true,Callback=function()end})
ESPSec:Toggle({Name="Show Distance",Flag="ESPDistance",Default=true,Callback=function()end})
ESPSec:Toggle({Name="Tracers",Flag="ESPTracers",Default=false,Callback=function()end})
ESPSec:Toggle({Name="Box Fill",Flag="ESPBoxFill",Default=false,Callback=function()end})

local WorldSec=VisualsPage:Section({Name="World ESP",Side=2,Icon="122669828593160"})
WorldSec:Toggle({Name="Coin ESP",Flag="CoinESP",Default=false,Callback=function(v) State.CoinESP=v end})
WorldSec:Toggle({Name="Gun ESP",Flag="GunESP",Default=false,Callback=function(v) State.GunESP=v end})

local HUDSec=VisualsPage:Section({Name="HUD",Side=2,Icon="73789337996373"})
HUDSec:Toggle({Name="Show Info HUD",Flag="ShowHUD",Default=true,Callback=function(v) State.ShowHUD=v end})
HUDSec:Toggle({Name="Fullbright",Flag="FullBright",Default=false,Callback=function(v) SetFullbright(v) end})

-- ════════════════════════════════════════════════════
--  ██ PAGE: COMBAT
-- ════════════════════════════════════════════════════
local CombatPage=Window:Page({Name="Combat",Icon="121760666525660"})

local AimbotSec=CombatPage:Section({Name="Aimbot",Side=1,Icon="117786983271442"})
AimbotSec:Toggle({Name="Enable Aimbot",Flag="AimbotEnabled",Default=false,Callback=function(v) State.AimbotEnabled=v FOVCircle.Visible=v end})
AimbotSec:Toggle({Name="Silent Aim",Flag="SilentAim",Default=false,Callback=function(v) State.SilentAim=v ApplySilentAim() end})
AimbotSec:Toggle({Name="Murderer Only",Flag="AimbotMurdererOnly",Default=true,Callback=function()end})
AimbotSec:Dropdown({Name="Target Part",Flag="AimbotPart",Default="Head",Items={"Head","HumanoidRootPart","UpperTorso","Neck"},Callback=function(v) State.AimbotPart=v end})
AimbotSec:Slider({Name="FOV Radius",Flag="AimbotFOV",Default=120,Min=10,Max=500,Decimals=1,Callback=function(v) State.AimbotFOV=v end})
AimbotSec:Slider({Name="Smoothness",Flag="AimbotSmooth",Default=0.15,Min=0.01,Max=1,Decimals=0.01,Suffix="x",Callback=function(v) State.AimbotSmooth=v end})

local KillSec=CombatPage:Section({Name="Kill Aura",Side=2,Icon="100050851789190"})
KillSec:Toggle({Name="Kill Aura",Flag="KillAura",Default=false,Callback=function(v) State.KillAura=v end}):SubKeybind({Flag="KillAuraKey",Default=Enum.KeyCode.F})
KillSec:Slider({Name="Kill Range",Flag="KillAuraRange",Default=15,Min=1,Max=60,Decimals=1,Suffix="st",Callback=function(v) State.KillAuraRange=v end})

-- ════════════════════════════════════════════════════
--  ██ PAGE: MOVEMENT
-- ════════════════════════════════════════════════════
local MovPage=Window:Page({Name="Movement",Icon="92464809279921"})

local SpeedSec=MovPage:Section({Name="Speed",Side=1,Icon="122669828593160"})
SpeedSec:Toggle({Name="Speed Hack",Flag="SpeedEnabled",Default=false,Callback=function(v) State.SpeedEnabled=v if not v then SetSpeed(16) end end}):SubKeybind({Flag="SpeedKey",Default=Enum.KeyCode.X})
SpeedSec:Slider({Name="Speed Value",Flag="SpeedValue",Default=30,Min=16,Max=120,Decimals=1,Suffix=" ws",Callback=function(v) State.SpeedValue=v end})
SpeedSec:Toggle({Name="Bunny Hop",Flag="BunnyHop",Default=false,Callback=function(v) State.BunnyHop=v end}):SubKeybind({Flag="BhopKey",Default=Enum.KeyCode.V})

local FlySec=MovPage:Section({Name="Fly",Side=1,Icon="117786983271442"})
FlySec:Toggle({Name="Fly",Flag="FlyEnabled",Default=false,Callback=function(v) State.FlyEnabled=v if v then StartFly() else StopFly() end end}):SubKeybind({Flag="FlyKey",Default=Enum.KeyCode.G})
FlySec:Slider({Name="Fly Speed",Flag="FlySpeed",Default=50,Min=5,Max=300,Decimals=1,Suffix=" sp",Callback=function(v) State.FlySpeed=v end})

local MiscMovSec=MovPage:Section({Name="Misc Movement",Side=2,Icon="73789337996373"})
MiscMovSec:Toggle({Name="Noclip",Flag="NoclipEnabled",Default=false,Callback=function(v) State.NoclipEnabled=v end}):SubKeybind({Flag="NoclipKey",Default=Enum.KeyCode.N})
MiscMovSec:Toggle({Name="Infinite Stamina",Flag="InfiniteStamina",Default=false,Callback=function(v) State.InfiniteStamina=v end})

-- ════════════════════════════════════════════════════
--  ██ PAGE: ANTI-EXPLOIT
-- ════════════════════════════════════════════════════
local AntiPage=Window:Page({Name="Anti-Exploit",Icon="73789337996373"})

local AntiFlingSection=AntiPage:Section({Name="Anti-Fling",Side=1,Icon="117786983271442"})
AntiFlingSection:Toggle({
    Name="Anti-Fling",Flag="AntiFling",Default=false,
    Callback=function(v)
        State.AntiFling=v
        if v then EnableAntiFling() else DisableAntiFling() end
    end
})
AntiFlingSection:Label("Blocks velocity-based fling attacks")
AntiFlingSection:Label("Makes your mass near-zero to exploiters")

local AntiKillSection=AntiPage:Section({Name="Anti-Kill",Side=1,Icon="121760666525660"})
AntiKillSection:Toggle({
    Name="Anti-Kill",Flag="AntiKill",Default=false,
    Callback=function(v)
        State.AntiKill=v
        if v then EnableAntiKill() else DisableAntiKill() end
    end
})
AntiKillSection:Toggle({
    Name="God Mode",Flag="GodMode",Default=false,
    Callback=function(v) State.GodMode=v end
})
AntiKillSection:Label("Locks health against illegitimate damage")

local AntiTpSection=AntiPage:Section({Name="Anti-Teleport",Side=2,Icon="100050851789190"})
AntiTpSection:Toggle({
    Name="Anti-Teleport",Flag="AntiTeleport",Default=false,
    Callback=function(v)
        State.AntiTeleport=v
        if v then EnableAntiTeleport() else DisableAntiTeleport() end
    end
})
AntiTpSection:Slider({
    Name="Max Move Distance",Flag="MaxTeleportDist",Default=50,
    Min=10,Max=200,Decimals=1,Suffix=" st",
    Callback=function(v) State.MaxTeleportDist=v end
})
AntiTpSection:Label("Snaps you back if moved too far in one frame")

local AntiNcSection=AntiPage:Section({Name="Anti-Noclip",Side=2,Icon="122669828593160"})
AntiNcSection:Toggle({
    Name="Anti-Noclip Detection",Flag="AntiNoclip",Default=false,
    Callback=function(v)
        State.AntiNoclip=v
        if v then EnableAntiNoclip() else DisableAntiNoclip() end
    end
})
AntiNcSection:Toggle({
    Name="Anti-Speed Detection",Flag="AntiSpeedHack",Default=false,
    Callback=function(v)
        State.AntiSpeedHack=v
        if v then EnableAntiSpeedHack() else DisableAntiSpeedHack() end
    end
})
AntiNcSection:Label("Notifies when exploiters speedhack near you")

-- ════════════════════════════════════════════════════
--  ██ PAGE: FARM
-- ════════════════════════════════════════════════════
local FarmPage=Window:Page({Name="Farm",Icon="81598136527047"})
local CoinSec=FarmPage:Section({Name="Coin Farm",Side=1,Icon="73789337996373"})
CoinSec:Toggle({Name="Auto Coin Farm",Flag="AutoCoin",Default=false,Callback=function(v) State.AutoCoin=v end}):SubKeybind({Flag="AutoCoinKey",Default=Enum.KeyCode.C})
CoinSec:Label("Teleports to nearest coin automatically")

-- ════════════════════════════════════════════════════
--  ██ PAGE: MISC
-- ════════════════════════════════════════════════════
local MiscPage=Window:Page({Name="Misc",Icon="122669828593160"})

local DesyncSec=MiscPage:Section({Name="Desync",Side=1,Icon="100050851789190"})
DesyncSec:Toggle({Name="Enable Desync",Flag="DesyncEnabled",Default=false,Callback=function(v) State.DesyncEnabled=v ApplyDesync() end}):SubKeybind({Flag="DesyncKey",Default=Enum.KeyCode.Z})
DesyncSec:Slider({Name="Desync Strength",Flag="DesyncStrength",Default=5,Min=1,Max=25,Decimals=1,Suffix=" st",Callback=function(v) State.DesyncStrength=v if State.DesyncEnabled then ApplyDesync() end end})

local InfoSec=MiscPage:Section({Name="Info",Side=2,Icon="73789337996373"})
local PlrLabel=InfoSec:Label("Players: --")
local AliveLabel=InfoSec:Label("Alive: --")
local RoleLabel=InfoSec:Label("Role: --")
task.spawn(function()
    while true do
        task.wait(1)
        local alive=0
        for _,p in Players:GetPlayers() do if IsAlive(p) then alive+=1 end end
        PlrLabel:SetText("Players: "..#Players:GetPlayers())
        AliveLabel:SetText("Alive: "..alive)
        RoleLabel:SetText("Role: "..GetRole(LocalPlayer))
    end
end)

local ServerSec=MiscPage:Section({Name="Server",Side=1,Icon="117786983271442"})
ServerSec:Button({Name="Server Hop",Callback=function()
    local TS=game:GetService("TeleportService")
    local HS=game:GetService("HttpService")
    task.spawn(function()
        Library:Notification({Title="Server Hop",Description="Searching...",Duration=1,Icon="73789337996373"})
        local ok,servers=pcall(function() return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=Asc&limit=100")) end)
        if ok and servers and servers.data then
            for _,s in servers.data do
                if s.id~=game.JobId and s.playing and s.playing<s.maxPlayers then
                    pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,s.id) end)
                    return
                end
            end
        end
        Library:Notification({Title="Server Hop",Description="No servers found.",Duration=2,Icon="73789337996373"})
    end)
end})
ServerSec:Button({Name="Rejoin",Callback=function()
    pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId) end)
end})

-- ════════════════════════════════════════════════════
--  ██ SETTINGS PAGE
-- ════════════════════════════════════════════════════
Library:CreateSettingsPage(Window,KeybindList)

-- ════════════════════════════════════════════════════
--  WATERMARK
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(1)
        local ping=0
        pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        Library:Watermark({"MM2 Hub"," | ","FPS: "..fpsDisplay," | ","Ping: "..ping.."ms"," | ",GetRole(LocalPlayer)})
    end
end)
Library.WatermarkFrame.Instance.Visible=true

-- ════════════════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════════════════
Window:Init()

Library:Notification({
    Title="MM2 Hub v2",
    Description="Loaded. Anti-exploit features in Anti-Exploit tab.",
    Duration=4,
    Icon="73789337996373"
})
