if getgenv().MM2HubScriptLoaded then return end
getgenv().MM2HubScriptLoaded = true
-- ══════════════════════════════════════════
-- WAIT FOR LIBRARY (already loaded separately)
-- ══════════════════════════════════════════
local Library
local waited = 0
repeat
    Library = getgenv().Library
    if not Library then task.wait(0.1) waited += 0.1 end
until Library or waited >= 10

if not Library then
    error("Library not loaded after 10 seconds. Load library.lua first.")
    return
end

-- ══════════════════════════════════════════
-- FOLDERS
-- ══════════════════════════════════════════
Library.Folders = {
    Main    = "MM2Hub",
    Assets  = "MM2Hub/Assets",
    Configs = "MM2Hub/Configs"
}
for _, F in ipairs({"MM2Hub","MM2Hub/Assets","MM2Hub/Configs"}) do
    if not isfolder(F) then makefolder(F) end
end

-- ══════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera
local Mouse             = LocalPlayer:GetMouse()

-- ══════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════
local Window = Library:Window({
    Name    = "MM2 Hub",
    SubName = "by xxangelxx",
    Logo    = "1l20959262762131",
})

assert(Window, "Window creation failed — library may be corrupted")

-- ══════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════
local State = {
    ESPEnabled=false, CoinESP=false, GunESP=false,
    AimbotEnabled=false, SilentAim=false, AimbotFOV=120, AimbotSmooth=0.15, AimbotPart="Head",
    SpeedEnabled=false, SpeedValue=30, FlyEnabled=false, FlySpeed=50,
    NoclipEnabled=false, BunnyHop=false, InfiniteStamina=false,
    KillAura=false, KillAuraRange=15,
    AutoCoin=false,
    DesyncEnabled=false, DesyncStrength=5,
    FullBright=false, GodMode=false, ShowHUD=true,
    AntiFling=false, AntiKill=false, AntiTeleport=false, AntiNoclip=false, AntiSpeedHack=false,
    MaxTeleportDist=50,
    ESPDrawings={}, CoinDrawings={}, GunDrawings={},
    FlyBody=nil,
}

-- ══════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════
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

-- ══════════════════════════════════════════
-- DRAWING HELPERS
-- ══════════════════════════════════════════
local function ND(t,p) local d=Drawing.new(t) for k,v in pairs(p) do d[k]=v end return d end
local function RemDraw(tbl)
    for _,d in pairs(tbl) do
        if type(d)=="table" then for _,v in pairs(d) do pcall(function()v:Remove()end) end
        else pcall(function()d:Remove()end) end
    end
    table.clear(tbl)
end

-- ══════════════════════════════════════════
-- FOV CIRCLE
-- ══════════════════════════════════════════
local FOVCircle = ND("Circle",{
    Visible=false, Radius=120, Thickness=1, Filled=false,
    Color=Color3.fromRGB(255,255,255),
    Position=Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
})

-- ══════════════════════════════════════════
-- HUD
-- ══════════════════════════════════════════
local HUD = {
    BG   = ND("Square",{Visible=false,Color=Color3.fromRGB(12,12,15),Transparency=0.4,Filled=true,Size=Vector2.new(185,115),Position=Vector2.new(6,6)}),
    FPS  = ND("Text",  {Visible=false,Color=Color3.fromRGB(100,220,255),Size=14,Font=2,Text="FPS: --"}),
    Ping = ND("Text",  {Visible=false,Color=Color3.fromRGB(100,255,160),Size=14,Font=2,Text="Ping: --"}),
    Role = ND("Text",  {Visible=false,Color=Color3.fromRGB(255,200,100),Size=14,Font=2,Text="Role: --"}),
    Alive= ND("Text",  {Visible=false,Color=Color3.fromRGB(200,200,200),Size=14,Font=2,Text="Alive: --"}),
    Coins= ND("Text",  {Visible=false,Color=Color3.fromRGB(255,230,60), Size=14,Font=2,Text="Coins: --"}),
    Prot = ND("Text",  {Visible=false,Color=Color3.fromRGB(255,100,100),Size=14,Font=2,Text="Prot: OFF"}),
    Bar  = ND("Square",{Visible=false,Color=Color3.fromRGB(0,116,224),Filled=true,Size=Vector2.new(185,2),Position=Vector2.new(6,4)}),
}
local fpsDisplay=0
local function UpdateHUD()
    local vis=State.ShowHUD
    for _,v in pairs(HUD) do v.Visible=vis end
    if not vis then return end
    local ping=0
    pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    local alive=0
    for _,p in ipairs(Players:GetPlayers()) do if IsAlive(p) then alive+=1 end end
    local coins=0
    local ls=LocalPlayer:FindFirstChild("leaderstats")
    if ls then local c=ls:FindFirstChild("Coins") or ls:FindFirstChild("coins") if c then coins=c.Value end end
    local b=Vector2.new(14,10)
    HUD.FPS.Position=b HUD.Ping.Position=b+Vector2.new(0,18) HUD.Role.Position=b+Vector2.new(0,36)
    HUD.Alive.Position=b+Vector2.new(0,54) HUD.Coins.Position=b+Vector2.new(0,72) HUD.Prot.Position=b+Vector2.new(0,90)
    HUD.Ping.Text="Ping: "..ping.."ms"
    HUD.Role.Text="Role: "..GetRole(LocalPlayer) HUD.Role.Color=RoleColor(LocalPlayer)
    HUD.Alive.Text="Alive: "..alive HUD.Coins.Text="Coins: "..coins
    local protOn=State.AntiFling or State.AntiKill or State.AntiTeleport
    HUD.Prot.Text=protOn and "Prot: ON" or "Prot: OFF"
    HUD.Prot.Color=protOn and Color3.fromRGB(100,255,160) or Color3.fromRGB(255,100,100)
end

-- ══════════════════════════════════════════
-- ANTI-EXPLOIT
-- ══════════════════════════════════════════
local LastGoodCF=CFrame.new(0,0,0)
local LastGoodHP=100
local AEConns={}
local BlockedPlrs={}

local function EnableAntiFling()
    local char=GetChar(LocalPlayer)
    if char then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CustomPhysicalProperties=PhysicalProperties.new(0.01,0,0,0,0) end)
            end
        end
    end
    if AEConns.fling then AEConns.fling:Disconnect() end
    AEConns.fling=RunService.Heartbeat:Connect(function()
        if not State.AntiFling then return end
        local r=GetRoot(LocalPlayer) if not r then return end
        if r.AssemblyLinearVelocity.Magnitude>200 then
            r.AssemblyLinearVelocity=Vector3.zero
            r.AssemblyAngularVelocity=Vector3.zero
            r.CFrame=LastGoodCF
            Library:Notification({Title="Anti-Fling",Description="Fling blocked.",Duration=2})
        else LastGoodCF=r.CFrame end
    end)
end
local function DisableAntiFling()
    if AEConns.fling then AEConns.fling:Disconnect() AEConns.fling=nil end
end

local AntiKillConn
local function EnableAntiKill()
    local hum=GetHum(LocalPlayer) if not hum then return end
    LastGoodHP=hum.Health
    if AntiKillConn then AntiKillConn:Disconnect() end
    AntiKillConn=hum.HealthChanged:Connect(function(hp)
        if not State.AntiKill then return end
        local h=GetHum(LocalPlayer) if not h then return end
        local drop=LastGoodHP-hp
        if drop>5 and hp>0 then h.Health=LastGoodHP
            Library:Notification({Title="Anti-Kill",Description="Damage blocked ("..math.floor(drop).."hp).",Duration=2})
        else LastGoodHP=hp end
    end)
end
local function DisableAntiKill()
    if AntiKillConn then AntiKillConn:Disconnect() AntiKillConn=nil end
end

local function EnableAntiTeleport()
    local lastPos=nil
    if AEConns.tp then AEConns.tp:Disconnect() end
    AEConns.tp=RunService.Heartbeat:Connect(function()
        if not State.AntiTeleport then return end
        local r=GetRoot(LocalPlayer) if not r then lastPos=nil return end
        if lastPos then
            if (r.Position-lastPos).Magnitude>State.MaxTeleportDist and not State.FlyEnabled then
                r.CFrame=CFrame.new(lastPos)
                Library:Notification({Title="Anti-TP",Description="Teleport blocked.",Duration=2})
            else lastPos=r.Position end
        else lastPos=r.Position end
    end)
end
local function DisableAntiTeleport()
    if AEConns.tp then AEConns.tp:Disconnect() AEConns.tp=nil end
end

local function EnableAntiNoclip()
    if AEConns.nc then AEConns.nc:Disconnect() end
    AEConns.nc=RunService.Heartbeat:Connect(function()
        if not State.AntiNoclip then return end
        local myR=GetRoot(LocalPlayer) if not myR then return end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr==LocalPlayer then continue end
            local r=GetRoot(plr) if not r then continue end
            if (r.Position-myR.Position).Magnitude<2 then
                pcall(function() r.AssemblyLinearVelocity=(r.Position-myR.Position).Unit*50 end)
            end
        end
    end)
end
local function DisableAntiNoclip()
    if AEConns.nc then AEConns.nc:Disconnect() AEConns.nc=nil end
end

local SpeedNotifCD={}
local function EnableAntiSpeed()
    if AEConns.spd then AEConns.spd:Disconnect() end
    AEConns.spd=RunService.Heartbeat:Connect(function()
        if not State.AntiSpeedHack then return end
        local myR=GetRoot(LocalPlayer) if not myR then return end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr==LocalPlayer then continue end
            local r=GetRoot(plr) if not r then continue end
            local vel=r.AssemblyLinearVelocity.Magnitude
            local dist=(r.Position-myR.Position).Magnitude
            if vel>80 and dist<30 then
                local now=tick()
                if not SpeedNotifCD[plr] or now-SpeedNotifCD[plr]>5 then
                    SpeedNotifCD[plr]=now
                    Library:Notification({Title="Anti-Speed",Description=plr.Name.." speedhacking nearby.",Duration=3})
                end
            end
        end
    end)
end
local function DisableAntiSpeed()
    if AEConns.spd then AEConns.spd:Disconnect() AEConns.spd=nil end
end

local function ReapplyAntiExploit()
    task.wait(0.5)
    if State.AntiFling then EnableAntiFling() end
    if State.AntiKill then EnableAntiKill() end
    if State.AntiTeleport then EnableAntiTeleport() end
    if State.AntiNoclip then EnableAntiNoclip() end
    if State.AntiSpeedHack then EnableAntiSpeed() end
end
LocalPlayer.CharacterAdded:Connect(ReapplyAntiExploit)

-- ══════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════
local function ClearESP(plr)
    if State.ESPDrawings[plr] then
        for _,d in pairs(State.ESPDrawings[plr]) do pcall(function()d:Remove()end) end
        State.ESPDrawings[plr]=nil
    end
end
local function BuildESP(plr)
    if plr==LocalPlayer then return end
    ClearESP(plr)
    State.ESPDrawings[plr]={
        Box    =ND("Square",{Visible=false,Thickness=1,Filled=false,Color=Color3.fromRGB(255,255,255)}),
        BoxFill=ND("Square",{Visible=false,Thickness=1,Filled=true,Color=Color3.fromRGB(0,0,0),Transparency=0.4}),
        Name   =ND("Text",  {Visible=false,Size=13,Font=2,Outline=true,Color=Color3.fromRGB(255,255,255)}),
        Dist   =ND("Text",  {Visible=false,Size=11,Font=2,Outline=true,Color=Color3.fromRGB(200,200,200)}),
        Tracer =ND("Line",  {Visible=false,Thickness=1,Color=Color3.fromRGB(255,255,255)}),
        HpBar  =ND("Square",{Visible=false,Thickness=1,Filled=true,Color=Color3.fromRGB(0,255,0)}),
        HpBG   =ND("Square",{Visible=false,Thickness=1,Filled=true,Color=Color3.fromRGB(0,0,0),Transparency=0.5}),
    }
end
local function UpdateESP(plr)
    local d=State.ESPDrawings[plr] if not d then return end
    local char=GetChar(plr) local root=GetRoot(plr) local hum=GetHum(plr)
    if not State.ESPEnabled or not char or not root or not hum or hum.Health<=0 then
        for _,v in pairs(d) do v.Visible=false end return
    end
    local head=char:FindFirstChild("Head")
    local lfoot=char:FindFirstChild("LeftFoot") or root
    local tp,_=WTV(head and head.Position or root.Position+Vector3.new(0,3,0))
    local bp,_=WTV(lfoot and lfoot.Position or root.Position-Vector3.new(0,3,0))
    local rp,ron=WTV(root.Position)
    if not ron then for _,v in pairs(d) do v.Visible=false end return end
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
    d.HpBG.Position=Vector2.new(x-5,y) d.HpBG.Size=Vector2.new(3,h) d.HpBG.Visible=true
    d.HpBar.Position=Vector2.new(x-5,y+h-hbH) d.HpBar.Size=Vector2.new(3,hbH)
    d.HpBar.Color=Color3.fromRGB(255-(hpPct*255),hpPct*255,0) d.HpBar.Visible=true
end

local function UpdateWorldESP()
    RemDraw(State.CoinDrawings)
    if State.CoinESP then
        local map=Workspace:FindFirstChild("Map") or Workspace
        for _,obj in ipairs(map:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("coin") then
                local pos,on=WTV(obj.Position)
                if on then table.insert(State.CoinDrawings,ND("Text",{Text="Coin",Position=pos,Color=Color3.fromRGB(255,220,30),Size=13,Font=2,Outline=true,Visible=true})) end
            end
        end
    end
    RemDraw(State.GunDrawings)
    if State.GunESP then
        local map=Workspace:FindFirstChild("Map") or Workspace
        for _,obj in ipairs(map:GetDescendants()) do
            local part=obj:FindFirstChild("Handle")
            if part and (obj.Name:lower():find("gun") or obj.Name:lower():find("knife")) then
                local pos,on=WTV(part.Position)
                if on then table.insert(State.GunDrawings,ND("Text",{Text=obj.Name,Position=pos,Color=Color3.fromRGB(80,200,255),Size=13,Font=2,Outline=true,Visible=true})) end
            end
        end
    end
end

-- ══════════════════════════════════════════
-- AIMBOT
-- ══════════════════════════════════════════
local function GetTarget()
    local best,bestD=nil,State.AimbotFOV
    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer or not IsAlive(plr) then continue end
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

local SilentConn
local function ApplySilentAim()
    if SilentConn then SilentConn:Disconnect() SilentConn=nil end
    if not State.SilentAim then return end
    SilentConn=RunService.RenderStepped:Connect(function()
        local t=GetTarget()
        if t then pcall(function() Mouse.Hit=CFrame.new(t.Position) end) end
    end)
end

-- ══════════════════════════════════════════
-- MOVEMENT
-- ══════════════════════════════════════════
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
    if State.FlyBody then pcall(function() State.FlyBody.BV:Destroy() State.FlyBody.BG:Destroy() end) State.FlyBody=nil end
    local h=GetHum(LocalPlayer) if h then h.PlatformStand=false end
end

-- ══════════════════════════════════════════
-- DESYNC
-- ══════════════════════════════════════════
local DesyncConn
local function ApplyDesync()
    if DesyncConn then DesyncConn:Disconnect() DesyncConn=nil end
    if not State.DesyncEnabled then return end
    DesyncConn=RunService.Heartbeat:Connect(function()
        local root=GetRoot(LocalPlayer) if not root then return end
        local orig=root.CFrame
        local off=Vector3.new(math.random(-State.DesyncStrength,State.DesyncStrength),0,math.random(-State.DesyncStrength,State.DesyncStrength))
        root.CFrame=orig*CFrame.new(off) task.wait() pcall(function() root.CFrame=orig end)
    end)
end

-- ══════════════════════════════════════════
-- KILL AURA
-- ══════════════════════════════════════════
task.spawn(function()
    while true do task.wait(0.1)
        if not State.KillAura then continue end
        local role=GetRole(LocalPlayer)
        if role~="Murderer" and role~="murderer" then continue end
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr==LocalPlayer or not IsAlive(plr) then continue end
            if Dist(plr)<=State.KillAuraRange then
                local remote=ReplicatedStorage:FindFirstChild("KillPlayer") or ReplicatedStorage:FindFirstChildOfClass("RemoteEvent")
                if remote then pcall(function() remote:FireServer(plr) end) end
                local char=GetChar(plr) local mychar=GetChar(LocalPlayer)
                if char and mychar then
                    local knife=mychar:FindFirstChild("Knife")
                    if knife then local h=knife:FindFirstChild("Handle") if h then h.CFrame=char:GetPivot() end end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════
-- AUTO COIN
-- ══════════════════════════════════════════
task.spawn(function()
    while true do task.wait(0.05)
        if not State.AutoCoin then continue end
        local root=GetRoot(LocalPlayer) if not root then continue end
        local map=Workspace:FindFirstChild("Map") or Workspace
        local closest,closestD=nil,math.huge
        for _,obj in ipairs(map:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("coin") then
                local d=(obj.Position-root.Position).Magnitude
                if d<closestD then closestD=d closest=obj end
            end
        end
        if closest then root.CFrame=CFrame.new(closest.Position) end
    end
end)

-- ══════════════════════════════════════════
-- FULLBRIGHT
-- ══════════════════════════════════════════
local OrigBright
local function SetFullbright(on)
    local L=game:GetService("Lighting")
    if on then OrigBright=L.Brightness L.Brightness=10 L.FogEnd=1e6 L.GlobalShadows=false
    else L.Brightness=OrigBright or 1 L.GlobalShadows=true end
end

-- ══════════════════════════════════════════
-- PLAYER HOOKS
-- ══════════════════════════════════════════
for _,p in ipairs(Players:GetPlayers()) do BuildESP(p) end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1) BuildESP(p) end)
    BuildESP(p)
end)
Players.PlayerRemoving:Connect(ClearESP)

-- ══════════════════════════════════════════
-- RENDER LOOP
-- ══════════════════════════════════════════
local fpsCount=0 local fpsClock=tick()
RunService.RenderStepped:Connect(function()
    fpsCount+=1
    if tick()-fpsClock>=1 then fpsDisplay=fpsCount fpsCount=0 fpsClock=tick() HUD.FPS.Text="FPS: "..fpsDisplay end
    if State.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then
        local t=GetTarget()
        if t then Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,t.Position),State.AimbotSmooth) end
    end
    if State.FlyEnabled and State.FlyBody then
        local root=GetRoot(LocalPlayer) if root then
            local h=GetHum(LocalPlayer) if h then h.PlatformStand=true end
            local dir=Vector3.zero local cf=Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=-cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=-cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir+=-cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
            State.FlyBody.BV.Velocity=dir.Magnitude>0 and dir.Unit*State.FlySpeed or Vector3.zero
            State.FlyBody.BG.CFrame=cf
        end
    end
    if State.SpeedEnabled then SetSpeed(State.SpeedValue) end
    if State.BunnyHop then local h=GetHum(LocalPlayer) if h and h.FloorMaterial~=Enum.Material.Air then h.Jump=true end end
    if State.NoclipEnabled then local char=GetChar(LocalPlayer) if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end
    if State.InfiniteStamina then local char=GetChar(LocalPlayer) if char then local s=char:FindFirstChild("Stamina") if s then s.Value=100 end end end
    if State.GodMode then local h=GetHum(LocalPlayer) if h then h.Health=h.MaxHealth end end
    for _,p in ipairs(Players:GetPlayers()) do UpdateESP(p) end
    UpdateWorldESP()
    UpdateHUD()
    FOVCircle.Visible=State.AimbotEnabled
    FOVCircle.Radius=State.AimbotFOV
    FOVCircle.Position=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
end)

-- ══════════════════════════════════════════
-- KEYBIND LIST
-- ══════════════════════════════════════════
local KeybindList=Library:KeybindList("MM2 Hub Keybinds")

-- ══════════════════════════════════════════
-- PAGES
-- ══════════════════════════════════════════
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

local MovPage=Window:Page({Name="Movement",Icon="92464809279921"})
local SpeedSec=MovPage:Section({Name="Speed",Side=1,Icon="122669828593160"})
SpeedSec:Toggle({Name="Speed Hack",Flag="SpeedEnabled",Default=false,Callback=function(v) State.SpeedEnabled=v if not v then SetSpeed(16) end end}):SubKeybind({Flag="SpeedKey",Default=Enum.KeyCode.X})
SpeedSec:Slider({Name="Speed Value",Flag="SpeedValue",Default=30,Min=16,Max=120,Decimals=1,Suffix=" ws",Callback=function(v) State.SpeedValue=v end})
SpeedSec:Toggle({Name="Bunny Hop",Flag="BunnyHop",Default=false,Callback=function(v) State.BunnyHop=v end}):SubKeybind({Flag="BhopKey",Default=Enum.KeyCode.V})
local FlySec=MovPage:Section({Name="Fly",Side=1,Icon="117786983271442"})
FlySec:Toggle({Name="Fly",Flag="FlyEnabled",Default=false,Callback=function(v) State.FlyEnabled=v if v then StartFly() else StopFly() end end}):SubKeybind({Flag="FlyKey",Default=Enum.KeyCode.G})
FlySec:Slider({Name="Fly Speed",Flag="FlySpeed",Default=50,Min=5,Max=300,Decimals=1,Suffix=" sp",Callback=function(v) State.FlySpeed=v end})
local MiscMovSec=MovPage:Section({Name="Misc",Side=2,Icon="73789337996373"})
MiscMovSec:Toggle({Name="Noclip",Flag="NoclipEnabled",Default=false,Callback=function(v) State.NoclipEnabled=v end}):SubKeybind({Flag="NoclipKey",Default=Enum.KeyCode.N})
MiscMovSec:Toggle({Name="Infinite Stamina",Flag="InfiniteStamina",Default=false,Callback=function(v) State.InfiniteStamina=v end})

local AntiPage=Window:Page({Name="Anti-Exploit",Icon="73789337996373"})
local AntiFSec=AntiPage:Section({Name="Anti-Fling",Side=1,Icon="117786983271442"})
AntiFSec:Toggle({Name="Anti-Fling",Flag="AntiFling",Default=false,Callback=function(v) State.AntiFling=v if v then EnableAntiFling() else DisableAntiFling() end end})
local AntiKSec=AntiPage:Section({Name="Anti-Kill",Side=1,Icon="121760666525660"})
AntiKSec:Toggle({Name="Anti-Kill",Flag="AntiKill",Default=false,Callback=function(v) State.AntiKill=v if v then EnableAntiKill() else DisableAntiKill() end end})
AntiKSec:Toggle({Name="God Mode",Flag="GodMode",Default=false,Callback=function(v) State.GodMode=v end})
local AntiTSec=AntiPage:Section({Name="Anti-Teleport",Side=2,Icon="100050851789190"})
AntiTSec:Toggle({Name="Anti-Teleport",Flag="AntiTeleport",Default=false,Callback=function(v) State.AntiTeleport=v if v then EnableAntiTeleport() else DisableAntiTeleport() end end})
AntiTSec:Slider({Name="Max Move Dist",Flag="MaxTeleportDist",Default=50,Min=10,Max=200,Decimals=1,Suffix=" st",Callback=function(v) State.MaxTeleportDist=v end})
local AntiNSec=AntiPage:Section({Name="Detection",Side=2,Icon="122669828593160"})
AntiNSec:Toggle({Name="Anti-Noclip",Flag="AntiNoclip",Default=false,Callback=function(v) State.AntiNoclip=v if v then EnableAntiNoclip() else DisableAntiNoclip() end end})
AntiNSec:Toggle({Name="Anti-Speed",Flag="AntiSpeedHack",Default=false,Callback=function(v) State.AntiSpeedHack=v if v then EnableAntiSpeed() else DisableAntiSpeed() end end})

local FarmPage=Window:Page({Name="Farm",Icon="81598136527047"})
local CoinSec=FarmPage:Section({Name="Coin Farm",Side=1,Icon="73789337996373"})
CoinSec:Toggle({Name="Auto Coin Farm",Flag="AutoCoin",Default=false,Callback=function(v) State.AutoCoin=v end}):SubKeybind({Flag="AutoCoinKey",Default=Enum.KeyCode.C})

local MiscPage=Window:Page({Name="Misc",Icon="122669828593160"})
local DesyncSec=MiscPage:Section({Name="Desync",Side=1,Icon="100050851789190"})
DesyncSec:Toggle({Name="Enable Desync",Flag="DesyncEnabled",Default=false,Callback=function(v) State.DesyncEnabled=v ApplyDesync() end}):SubKeybind({Flag="DesyncKey",Default=Enum.KeyCode.Z})
DesyncSec:Slider({Name="Strength",Flag="DesyncStrength",Default=5,Min=1,Max=25,Decimals=1,Suffix=" st",Callback=function(v) State.DesyncStrength=v if State.DesyncEnabled then ApplyDesync() end end})
local InfoSec=MiscPage:Section({Name="Info",Side=2,Icon="73789337996373"})
local PlrLabel=InfoSec:Label("Players: --")
local AliveLabel2=InfoSec:Label("Alive: --")
local RoleLabel2=InfoSec:Label("Role: --")
task.spawn(function()
    while true do task.wait(1)
        local alive=0 for _,p in ipairs(Players:GetPlayers()) do if IsAlive(p) then alive+=1 end end
        PlrLabel:SetText("Players: "..#Players:GetPlayers())
        AliveLabel2:SetText("Alive: "..alive)
        RoleLabel2:SetText("Role: "..GetRole(LocalPlayer))
    end
end)
local SrvSec=MiscPage:Section({Name="Server",Side=1,Icon="117786983271442"})
SrvSec:Button({Name="Server Hop",Callback=function()
    task.spawn(function()
        Library:Notification({Title="Server Hop",Description="Searching...",Duration=1})
        local HS=game:GetService("HttpService") local TS=game:GetService("TeleportService")
        local ok,s=pcall(function() return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=Asc&limit=100")) end)
        if ok and s and s.data then
            for _,srv in ipairs(s.data) do
                if srv.id~=game.JobId and srv.playing and srv.playing<srv.maxPlayers then
                    pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,srv.id) end) return
                end
            end
        end
        Library:Notification({Title="Server Hop",Description="No servers found.",Duration=2})
    end)
end})
SrvSec:Button({Name="Rejoin",Callback=function()
    pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId) end)
end})

-- ══════════════════════════════════════════
-- SETTINGS + WATERMARK + INIT
-- ══════════════════════════════════════════
Library:CreateSettingsPage(Window,KeybindList)

task.spawn(function()
    while true do task.wait(1)
        local ping=0 pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        Library:Watermark({"MM2 Hub"," | ","FPS: "..fpsDisplay," | ","Ping: "..ping.."ms"," | ",GetRole(LocalPlayer)})
    end
end)
Library.WatermarkFrame.Instance.Visible=true

Window:Init()

Library:Notification({Title="MM2 Hub",Description="Loaded! RightAlt to open menu.",Duration=4})
