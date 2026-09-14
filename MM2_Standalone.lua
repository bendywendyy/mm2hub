if getgenv().MM2HubScriptLoaded then return end
getgenv().MM2HubScriptLoaded = true

-- ══════════════════════════════════════════════
--  MM2 Hub v3 — Full Rewrite
--  Fixed: ESP tracking, FOV slider, kill aura,
--         movement, anti-exploit, cleaner UI
-- ══════════════════════════════════════════════

local Library = getgenv().Library
if not Library then
    local waited = 0
    repeat task.wait(0.1) waited += 0.1 Library = getgenv().Library until Library or waited >= 10
    if not Library then error("[MM2 Hub] Library not loaded.") return end
end

-- ── Services ─────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

-- ── Folders ──────────────────────────────────
Library.Folders = { Main="MM2Hub", Assets="MM2Hub/Assets", Configs="MM2Hub/Configs" }
for _,f in ipairs({"MM2Hub","MM2Hub/Assets","MM2Hub/Configs"}) do
    if not isfolder(f) then makefolder(f) end
end

-- ── Window ───────────────────────────────────
local Window = Library:Window({
    Name    = "MM2 Hub",
    SubName = "v3 — clean & fixed",
    Logo    = "1l20959262762131",
})

-- ── State ────────────────────────────────────
local S = {
    -- ESP
    ESP=false, CoinESP=false, GunESP=false, PlayerESP_Chams=false,
    ESPColor_Innocent=Color3.fromRGB(100,255,100),
    ESPColor_Murderer=Color3.fromRGB(255,60,60),
    ESPColor_Sheriff=Color3.fromRGB(80,140,255),
    -- Aimbot
    Aim=false, SilentAim=false, AimFOV=150, AimSmooth=0.15, AimPart="Head", AimMurdOnly=true,
    -- Movement
    Speed=false, SpeedVal=30,
    Fly=false, FlySpeed=50, FlyBody=nil,
    Noclip=false, Bhop=false, InfStam=false,
    -- Combat
    KillAura=false, KillRange=15,
    -- Anti
    AntiFling=false, AntiKill=false, AntiTp=false, AntiNoclip=false, AntiSpd=false,
    MaxTpDist=50, LastGoodCF=CFrame.new(0,0,0), LastGoodHP=100,
    -- Misc
    Desync=false, DesyncStr=5,
    GodMode=false, FullBright=false, ShowHUD=true,
    AutoCoin=false,
    -- Drawings
    ESPDrawings={}, CoinDraw={}, GunDraw={},
    AEConns={},
}

-- ── Helpers ──────────────────────────────────
local function Char(p)  return p and p.Character end
local function Root(p)  local c=Char(p) return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p)   local c=Char(p) return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p) local h=Hum(p) return h and h.Health>0 end
local function Dist(p)
    local r=Root(p) local m=Root(LocalPlayer)
    if not r or not m then return 9e9 end
    return (r.Position-m.Position).Magnitude
end
local function WTV(v3)
    local vp,on = Camera:WorldToViewportPoint(v3)
    return Vector2.new(vp.X,vp.Y), on, vp.Z
end
local function Role(p)
    local ls=p:FindFirstChild("leaderstats")
    if ls then
        local r=ls:FindFirstChild("Role") or ls:FindFirstChild("role")
        if r then return tostring(r.Value) end
    end
    -- fallback: check team
    if p.Team then return tostring(p.Team.Name) end
    return "Innocent"
end
local function RoleCol(p)
    local r=Role(p):lower()
    if r:find("murder") then return S.ESPColor_Murderer
    elseif r:find("sheriff") then return S.ESPColor_Sheriff
    else return S.ESPColor_Innocent end
end

-- ── Drawing helpers ──────────────────────────
local function ND(t,props)
    local d=Drawing.new(t)
    for k,v in pairs(props) do d[k]=v end
    return d
end
local function ClearDraw(tbl)
    for _,v in pairs(tbl) do
        if type(v)=="table" then for _,d in pairs(v) do pcall(function()d:Remove()end) end
        else pcall(function()v:Remove()end) end
    end table.clear(tbl)
end

-- ── FOV Circle ───────────────────────────────
local FOVCircle = ND("Circle",{
    Visible=false, Radius=150, Thickness=1.5, Filled=false,
    Color=Color3.fromRGB(255,255,255),
    Position=Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
})

-- ── HUD drawings ─────────────────────────────
local HUD = {
    BG   = ND("Square",{Visible=false,Color=Color3.fromRGB(10,10,13),Transparency=0.35,Filled=true,Size=Vector2.new(190,120),Position=Vector2.new(6,6)}),
    FPS  = ND("Text",{Visible=false,Color=Color3.fromRGB(100,220,255),Size=14,Font=2,Text="FPS: --",Outline=true}),
    Ping = ND("Text",{Visible=false,Color=Color3.fromRGB(100,255,160),Size=14,Font=2,Text="Ping: --",Outline=true}),
    Role = ND("Text",{Visible=false,Color=Color3.fromRGB(255,200,100),Size=14,Font=2,Text="Role: --",Outline=true}),
    Alive= ND("Text",{Visible=false,Color=Color3.fromRGB(200,200,200),Size=14,Font=2,Text="Alive: --",Outline=true}),
    Coins= ND("Text",{Visible=false,Color=Color3.fromRGB(255,230,60), Size=14,Font=2,Text="Coins: --",Outline=true}),
    Prot = ND("Text",{Visible=false,Color=Color3.fromRGB(255,100,100),Size=14,Font=2,Text="Prot: OFF",Outline=true}),
    Bar  = ND("Square",{Visible=false,Color=Color3.fromRGB(0,116,224),Filled=true,Size=Vector2.new(190,2),Position=Vector2.new(6,4)}),
}
local fpsDisp=0

local function UpdateHUD()
    for _,v in pairs(HUD) do v.Visible=S.ShowHUD end
    if not S.ShowHUD then return end
    local ping=0 pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    local alive=0 for _,p in ipairs(Players:GetPlayers()) do if Alive(p) then alive+=1 end end
    local coins=0 local ls=LocalPlayer:FindFirstChild("leaderstats")
    if ls then local c=ls:FindFirstChild("Coins") or ls:FindFirstChild("coins") if c then coins=c.Value end end
    local b=Vector2.new(14,10)
    HUD.FPS.Position=b; HUD.Ping.Position=b+Vector2.new(0,18); HUD.Role.Position=b+Vector2.new(0,36)
    HUD.Alive.Position=b+Vector2.new(0,54); HUD.Coins.Position=b+Vector2.new(0,72); HUD.Prot.Position=b+Vector2.new(0,90)
    HUD.Ping.Text="Ping: "..ping.."ms"
    HUD.Role.Text="Role: "..Role(LocalPlayer); HUD.Role.Color=RoleCol(LocalPlayer)
    HUD.Alive.Text="Alive: "..alive; HUD.Coins.Text="Coins: "..coins
    local protOn=S.AntiFling or S.AntiKill or S.AntiTp
    HUD.Prot.Text=protOn and "Prot: ON" or "Prot: OFF"
    HUD.Prot.Color=protOn and Color3.fromRGB(100,255,160) or Color3.fromRGB(255,100,100)
end

-- ══════════════════════════════════════════════
--  PLAYER ESP — Fixed WorldToViewport approach
-- ══════════════════════════════════════════════
local function ClearESP(p)
    if S.ESPDrawings[p] then
        for _,d in pairs(S.ESPDrawings[p]) do pcall(function()d:Remove()end) end
        S.ESPDrawings[p]=nil
    end
end

local function BuildESP(p)
    if p==LocalPlayer then return end
    ClearESP(p)
    S.ESPDrawings[p] = {
        -- Outer box
        Box     = ND("Square",{Visible=false,Thickness=1,Filled=false,Color=Color3.fromRGB(255,255,255)}),
        BoxFill = ND("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(0,0,0),Transparency=0.5}),
        -- Health bar background
        HpBG    = ND("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(30,30,30)}),
        -- Health bar fill
        HpFill  = ND("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(0,255,80)}),
        -- Name above box
        Name    = ND("Text",{Visible=false,Size=13,Font=2,Outline=true,Color=Color3.fromRGB(255,255,255),Center=true}),
        -- Role tag
        RoleTag = ND("Text",{Visible=false,Size=11,Font=2,Outline=true,Color=Color3.fromRGB(200,200,200),Center=true}),
        -- Distance below box
        Dist    = ND("Text",{Visible=false,Size=11,Font=2,Outline=true,Color=Color3.fromRGB(180,180,180),Center=true}),
        -- Tracer from bottom of screen
        Tracer  = ND("Line",{Visible=false,Thickness=1,Color=Color3.fromRGB(255,255,255)}),
    }
end

local function UpdateESP(p)
    local d=S.ESPDrawings[p]
    if not d then return end
    local char=Char(p); local root=Root(p); local hum=Hum(p)
    if not S.ESP or not char or not root or not hum or hum.Health<=0 then
        for _,v in pairs(d) do v.Visible=false end return
    end

    -- Get screen positions of head and feet
    local head = char:FindFirstChild("Head")
    local leftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg")

    local headPos = head and head.Position or (root.Position + Vector3.new(0,2.5,0))
    local feetPos = leftFoot and leftFoot.Position or (root.Position - Vector3.new(0,3,0))
    local rootPos = root.Position

    local screenHead, headVisible = WTV(headPos)
    local screenFeet, feetVisible = WTV(feetPos)
    local screenRoot, rootVisible, rootDepth = WTV(rootPos)

    -- Only draw if any part is on screen and in front of camera
    if not rootVisible or rootDepth <= 0 then
        for _,v in pairs(d) do v.Visible=false end return
    end

    local col = RoleCol(p)
    local hp  = hum.Health
    local mhp = math.max(hum.MaxHealth, 1)
    local dist= math.floor(Dist(p))

    -- Box dimensions from head to feet
    local boxH = math.abs(screenFeet.Y - screenHead.Y)
    if boxH < 10 then boxH = 10 end -- minimum box height
    local boxW = boxH * 0.5
    local boxX = screenRoot.X - boxW/2
    local boxY = screenHead.Y

    -- Box
    d.Box.Position = Vector2.new(boxX, boxY)
    d.Box.Size     = Vector2.new(boxW, boxH)
    d.Box.Color    = col
    d.Box.Visible  = true

    -- Box fill
    d.BoxFill.Position = Vector2.new(boxX, boxY)
    d.BoxFill.Size     = Vector2.new(boxW, boxH)
    d.BoxFill.Visible  = Library.Flags["ESPBoxFill"]==true

    -- Health bar (3px wide, left of box)
    local hpH    = math.floor(boxH * math.clamp(hp/mhp, 0, 1))
    local hpCol  = Color3.fromRGB(
        math.floor(255*(1-(hp/mhp))),
        math.floor(255*(hp/mhp)),
        0
    )
    d.HpBG.Position = Vector2.new(boxX-5, boxY)
    d.HpBG.Size     = Vector2.new(3, boxH)
    d.HpBG.Visible  = true

    d.HpFill.Position = Vector2.new(boxX-5, boxY+boxH-hpH)
    d.HpFill.Size     = Vector2.new(3, hpH)
    d.HpFill.Color    = hpCol
    d.HpFill.Visible  = true

    -- Name (above box)
    d.Name.Text     = p.Name
    d.Name.Color    = col
    d.Name.Position = Vector2.new(screenRoot.X, boxY - 16)
    d.Name.Visible  = Library.Flags["ESPNames"]~=false

    -- Role tag
    d.RoleTag.Text     = "["..Role(p).."]"
    d.RoleTag.Color    = col
    d.RoleTag.Position = Vector2.new(screenRoot.X, boxY - 29)
    d.RoleTag.Visible  = Library.Flags["ESPRoleTags"]==true

    -- Distance (below box)
    d.Dist.Text     = dist.."m"
    d.Dist.Position = Vector2.new(screenRoot.X, boxY+boxH+3)
    d.Dist.Visible  = Library.Flags["ESPDistance"]~=false

    -- Tracer from center-bottom of screen to player
    d.Tracer.From  = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
    d.Tracer.To    = Vector2.new(screenRoot.X, screenRoot.Y)
    d.Tracer.Color = col
    d.Tracer.Visible = Library.Flags["ESPTracers"]==true
end

-- ── World ESP ────────────────────────────────
local coinESPClock = 0
local function UpdateWorldESP()
    -- Throttle to every 0.5s to save performance
    if tick() - coinESPClock < 0.5 then return end
    coinESPClock = tick()

    ClearDraw(S.CoinDraw)
    ClearDraw(S.GunDraw)

    local map = Workspace:FindFirstChild("Map") or Workspace
    for _,obj in ipairs(map:GetDescendants()) do
        -- Coins
        if S.CoinESP and obj:IsA("BasePart") and obj.Name:lower():find("coin") then
            local pos,on = WTV(obj.Position)
            if on then
                table.insert(S.CoinDraw, ND("Text",{
                    Text="● Coin", Position=pos-Vector2.new(0,8),
                    Color=Color3.fromRGB(255,220,30), Size=13, Font=2, Outline=true, Visible=true, Center=true
                }))
            end
        end
        -- Guns / dropped weapons
        if S.GunESP then
            local handle = obj:FindFirstChild("Handle")
            if handle and (obj.Name:lower():find("gun") or obj.Name:lower():find("knife") or obj.Name:lower():find("sheriff")) then
                local pos,on = WTV(handle.Position)
                if on then
                    table.insert(S.GunDraw, ND("Text",{
                        Text="⚔ "..obj.Name, Position=pos-Vector2.new(0,8),
                        Color=Color3.fromRGB(80,200,255), Size=13, Font=2, Outline=true, Visible=true, Center=true
                    }))
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  AIMBOT — fixed FOV check
-- ══════════════════════════════════════════════
local function GetTarget()
    local best, bestDist = nil, S.AimFOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer or not Alive(p) then continue end
        if S.AimMurdOnly then
            local r=Role(p):lower()
            if not r:find("murder") then continue end
        end
        local c=Char(p); if not c then continue end
        local part=c:FindFirstChild(S.AimPart) or Root(p)
        if not part then continue end
        local p2,on,depth = WTV(part.Position)
        if not on or depth<=0 then continue end
        local screenDist=(center-p2).Magnitude
        if screenDist < bestDist then
            bestDist=screenDist; best=part
        end
    end
    return best
end

-- Silent aim override
local SilentConn
local function ApplySilentAim()
    if SilentConn then SilentConn:Disconnect() SilentConn=nil end
    if not S.SilentAim then return end
    SilentConn = RunService.RenderStepped:Connect(function()
        local t=GetTarget()
        if t then pcall(function() LocalPlayer:GetMouse().Hit=CFrame.new(t.Position) end) end
    end)
end

-- ══════════════════════════════════════════════
--  ANTI-EXPLOIT — rewritten
-- ══════════════════════════════════════════════
local flingNotifCD = 0
local function EnableAntiFling()
    if S.AEConns.fling then S.AEConns.fling:Disconnect() end
    -- Make character massless so velocity flings do nothing
    local char=Char(LocalPlayer)
    if char then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.CustomPhysicalProperties=PhysicalProperties.new(0.01,0,0,0,0)
                end)
            end
        end
    end
    S.AEConns.fling = RunService.Heartbeat:Connect(function()
        if not S.AntiFling then return end
        local r=Root(LocalPlayer); if not r then return end
        local vel=r.AssemblyLinearVelocity
        if vel.Magnitude > 250 then
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            r.CFrame = S.LastGoodCF
            if tick()-flingNotifCD > 3 then
                flingNotifCD=tick()
                Library:Notification({Title="Anti-Fling",Description="Fling attempt blocked!",Duration=2})
            end
        else
            S.LastGoodCF = r.CFrame
        end
    end)
end

local AntiKillConn
local function EnableAntiKill()
    if AntiKillConn then AntiKillConn:Disconnect() end
    local hum=Hum(LocalPlayer); if not hum then return end
    S.LastGoodHP = hum.Health
    AntiKillConn = hum.HealthChanged:Connect(function(hp)
        if not S.AntiKill then S.LastGoodHP=hp return end
        local hm=Hum(LocalPlayer); if not hm then return end
        local drop = S.LastGoodHP - hp
        if drop > 8 and hp > 0 then
            hm.Health = S.LastGoodHP
            Library:Notification({Title="Anti-Kill",Description="Blocked "..math.floor(drop).." damage",Duration=2})
        else
            S.LastGoodHP = hp
        end
    end)
end

local tpLastPos
local tpNotifCD = 0
local function EnableAntiTp()
    if S.AEConns.tp then S.AEConns.tp:Disconnect() end
    tpLastPos = nil
    S.AEConns.tp = RunService.Heartbeat:Connect(function()
        if not S.AntiTp then tpLastPos=nil return end
        local r=Root(LocalPlayer); if not r then tpLastPos=nil return end
        if tpLastPos then
            local moved=(r.Position-tpLastPos).Magnitude
            if moved > S.MaxTpDist and not S.Fly then
                r.CFrame = CFrame.new(tpLastPos)
                if tick()-tpNotifCD > 3 then
                    tpNotifCD=tick()
                    Library:Notification({Title="Anti-Teleport",Description="Teleport blocked",Duration=2})
                end
            else tpLastPos=r.Position end
        else tpLastPos=r.Position end
    end)
end

local spdNotifCD = {}
local function EnableAntiSpeed()
    if S.AEConns.spd then S.AEConns.spd:Disconnect() end
    S.AEConns.spd = RunService.Heartbeat:Connect(function()
        if not S.AntiSpd then return end
        local myR=Root(LocalPlayer); if not myR then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer then continue end
            local r=Root(p); if not r then continue end
            local vel=r.AssemblyLinearVelocity.Magnitude
            local d=(r.Position-myR.Position).Magnitude
            if vel>90 and d<35 then
                local now=tick()
                if not spdNotifCD[p] or now-spdNotifCD[p]>5 then
                    spdNotifCD[p]=now
                    Library:Notification({Title="⚡ Speedhack",Description=p.Name.." is speed hacking near you",Duration=3})
                end
            end
        end
    end)
end

local function ReapplyAntiExploit()
    task.wait(1)
    if S.AntiFling  then EnableAntiFling()  end
    if S.AntiKill   then EnableAntiKill()   end
    if S.AntiTp     then EnableAntiTp()     end
    if S.AntiSpd    then EnableAntiSpeed()  end
end
LocalPlayer.CharacterAdded:Connect(ReapplyAntiExploit)

-- ══════════════════════════════════════════════
--  MOVEMENT
-- ══════════════════════════════════════════════
local function SetSpeed(v) local h=Hum(LocalPlayer) if h then h.WalkSpeed=v end end

local function StartFly()
    local r=Root(LocalPlayer); if not r then return end
    if S.FlyBody then pcall(function() S.FlyBody.BV:Destroy() S.FlyBody.BG:Destroy() end) S.FlyBody=nil end
    local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(1e9,1e9,1e9); bv.Velocity=Vector3.zero; bv.Parent=r
    local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(1e9,1e9,1e9); bg.CFrame=r.CFrame; bg.Parent=r
    S.FlyBody={BV=bv,BG=bg}
end
local function StopFly()
    if S.FlyBody then pcall(function() S.FlyBody.BV:Destroy() S.FlyBody.BG:Destroy() end) S.FlyBody=nil end
    local h=Hum(LocalPlayer); if h then h.PlatformStand=false end
end

-- ══════════════════════════════════════════════
--  KILL AURA — MM2 specific
-- ══════════════════════════════════════════════
-- MM2 uses a touch-based knife mechanic.
-- We move our knife handle to the target's position.
local function DoKillAura()
    task.spawn(function()
        while true do
            task.wait(0.08)
            if not S.KillAura then continue end
            local roleStr=Role(LocalPlayer):lower()
            if not roleStr:find("murder") then continue end

            local myChar=Char(LocalPlayer); if not myChar then continue end

            -- Find knife in character
            local knife = myChar:FindFirstChild("Knife")
                       or myChar:FindFirstChild("MM2Knife")
                       or myChar:FindFirstChildWhichIsA("Tool")

            local handle = knife and (knife:FindFirstChild("Handle") or (knife:IsA("BasePart") and knife))

            for _,p in ipairs(Players:GetPlayers()) do
                if p==LocalPlayer or not Alive(p) then continue end
                if Dist(p) <= S.KillRange then
                    local targetRoot = Root(p)
                    if targetRoot then
                        -- Method 1: teleport knife handle
                        if handle then
                            pcall(function() handle.CFrame=targetRoot.CFrame end)
                        end
                        -- Method 2: fire kill remote if it exists
                        local remote = ReplicatedStorage:FindFirstChild("KillPlayer")
                                    or ReplicatedStorage:FindFirstChild("RemoteFunction")
                        if remote and remote:IsA("RemoteEvent") then
                            pcall(function() remote:FireServer(p) end)
                        end
                        -- Method 3: teleport us on top of them briefly
                        local myRoot = Root(LocalPlayer)
                        if myRoot and not handle then
                            myRoot.CFrame = targetRoot.CFrame
                        end
                    end
                end
            end
        end
    end)
end
DoKillAura()

-- ══════════════════════════════════════════════
--  AUTO COIN FARM
-- ══════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.05)
        if not S.AutoCoin then continue end
        local r=Root(LocalPlayer); if not r then continue end
        local map=Workspace:FindFirstChild("Map") or Workspace
        local closest,closestD=nil,math.huge
        for _,obj in ipairs(map:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("coin") then
                local d=(obj.Position-r.Position).Magnitude
                if d<closestD then closestD=d closest=obj end
            end
        end
        if closest then r.CFrame=CFrame.new(closest.Position) end
    end
end)

-- ══════════════════════════════════════════════
--  DESYNC
-- ══════════════════════════════════════════════
local DesyncConn
local function ApplyDesync()
    if DesyncConn then DesyncConn:Disconnect() DesyncConn=nil end
    if not S.Desync then return end
    DesyncConn=RunService.Heartbeat:Connect(function()
        local r=Root(LocalPlayer); if not r then return end
        local orig=r.CFrame
        local off=Vector3.new(math.random(-S.DesyncStr,S.DesyncStr),0,math.random(-S.DesyncStr,S.DesyncStr))
        r.CFrame=orig*CFrame.new(off)
        task.wait()
        pcall(function() r.CFrame=orig end)
    end)
end

-- ── Fullbright ───────────────────────────────
local origBright
local function SetFullbright(on)
    local L=game:GetService("Lighting")
    if on then origBright=L.Brightness; L.Brightness=10; L.FogEnd=1e6; L.GlobalShadows=false
    else L.Brightness=origBright or 2; L.GlobalShadows=true end
end

-- ══════════════════════════════════════════════
--  MAIN RENDER LOOP
-- ══════════════════════════════════════════════
local fpsCount=0; local fpsClock=tick()

RunService.RenderStepped:Connect(function()
    -- FPS
    fpsCount+=1
    if tick()-fpsClock>=1 then
        fpsDisp=fpsCount; fpsCount=0; fpsClock=tick()
        HUD.FPS.Text="FPS: "..fpsDisp
    end

    -- Aimbot
    if S.Aim and UserInputService:IsMouseButtonPressed(Enum.UserInputButton.MouseButton2) then
        local t=GetTarget()
        if t then
            local cf=CFrame.new(Camera.CFrame.Position, t.Position)
            Camera.CFrame=Camera.CFrame:Lerp(cf, S.AimSmooth)
        end
    end

    -- FOV circle — always update position and radius
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Radius   = S.AimFOV
    FOVCircle.Visible  = S.Aim

    -- Fly
    if S.Fly and S.FlyBody then
        local r=Root(LocalPlayer)
        if r then
            local h=Hum(LocalPlayer); if h then h.PlatformStand=true end
            local dir=Vector3.zero; local cf=Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=-cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=-cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir+=-cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.new(0,1,0) end
            S.FlyBody.BV.Velocity=dir.Magnitude>0 and dir.Unit*S.FlySpeed or Vector3.zero
            S.FlyBody.BG.CFrame=cf
        end
    end

    -- Speed
    if S.Speed then SetSpeed(S.SpeedVal) end

    -- Bhop
    if S.Bhop then
        local h=Hum(LocalPlayer)
        if h and h.FloorMaterial~=Enum.Material.Air then h.Jump=true end
    end

    -- Noclip
    if S.Noclip then
        local c=Char(LocalPlayer)
        if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end

    -- Inf Stamina
    if S.InfStam then
        local c=Char(LocalPlayer)
        if c then
            local stam=c:FindFirstChild("Stamina") or c:FindFirstChild("stamina")
            if stam and stam:IsA("NumberValue") then stam.Value=100 end
        end
    end

    -- God Mode
    if S.GodMode then
        local h=Hum(LocalPlayer); if h then h.Health=h.MaxHealth end
    end

    -- ESP updates
    for _,p in ipairs(Players:GetPlayers()) do UpdateESP(p) end
    UpdateWorldESP()
    UpdateHUD()
end)

-- ══════════════════════════════════════════════
--  PLAYER HOOKS
-- ══════════════════════════════════════════════
for _,p in ipairs(Players:GetPlayers()) do BuildESP(p) end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1) BuildESP(p) end)
    BuildESP(p)
end)
Players.PlayerRemoving:Connect(function(p) ClearESP(p) end)

-- ══════════════════════════════════════════════
--  KEYBIND LIST
-- ══════════════════════════════════════════════
local KeybindList = Library:KeybindList("MM2 Hub Binds")

-- ══════════════════════════════════════════════
--  ██ PAGE: VISUALS
-- ══════════════════════════════════════════════
local VisualsPage=Window:Page({Name="Visuals",Icon="100050851789190"})
Window:Category("ESP")

local ESPSec=VisualsPage:Section({Name="Player ESP",Side=1,Icon="117786983271442",Description="See players through walls"})
ESPSec:Toggle({Name="Enable ESP",Flag="ESP",Default=false,Callback=function(v) S.ESP=v end})
ESPSec:Toggle({Name="Show Names",Flag="ESPNames",Default=true,Callback=function()end})
ESPSec:Toggle({Name="Show Role Tag",Flag="ESPRoleTags",Default=true,Callback=function()end})
ESPSec:Toggle({Name="Show Distance",Flag="ESPDistance",Default=true,Callback=function()end})
ESPSec:Toggle({Name="Tracers",Flag="ESPTracers",Default=false,Callback=function()end})
ESPSec:Toggle({Name="Box Fill",Flag="ESPBoxFill",Default=false,Callback=function()end})

local WorldSec=VisualsPage:Section({Name="World ESP",Side=1,Icon="122669828593160"})
WorldSec:Toggle({Name="Coin ESP",Flag="CoinESP",Default=false,Callback=function(v) S.CoinESP=v end})
WorldSec:Toggle({Name="Gun / Drop ESP",Flag="GunESP",Default=false,Callback=function(v) S.GunESP=v end})

local HUDSec=VisualsPage:Section({Name="HUD & Visual",Side=2,Icon="73789337996373"})
HUDSec:Toggle({Name="Show Info HUD",Flag="ShowHUD",Default=true,Callback=function(v) S.ShowHUD=v end})
HUDSec:Toggle({Name="Fullbright",Flag="FullBright",Default=false,Callback=function(v) SetFullbright(v) end})

-- ESP Color pickers per role
local ColorSec=VisualsPage:Section({Name="ESP Colors",Side=2,Icon="100050851789190",Description="Per-role box color"})
ColorSec:Label("Innocent Color"):Colorpicker({
    Flag="ESPColorInnocent",Default=Color3.fromRGB(100,255,100),
    Callback=function(c) S.ESPColor_Innocent=c end
})
ColorSec:Label("Murderer Color"):Colorpicker({
    Flag="ESPColorMurderer",Default=Color3.fromRGB(255,60,60),
    Callback=function(c) S.ESPColor_Murderer=c end
})
ColorSec:Label("Sheriff Color"):Colorpicker({
    Flag="ESPColorSheriff",Default=Color3.fromRGB(80,140,255),
    Callback=function(c) S.ESPColor_Sheriff=c end
})

-- ══════════════════════════════════════════════
--  ██ PAGE: COMBAT
-- ══════════════════════════════════════════════
local CombatPage=Window:Page({Name="Combat",Icon="121760666525660"})

local AimSec=CombatPage:Section({Name="Aimbot",Side=1,Icon="117786983271442",Description="Hold RMB to lock on"})
AimSec:Toggle({Name="Enable Aimbot",Flag="Aim",Default=false,Callback=function(v) S.Aim=v FOVCircle.Visible=v end})
AimSec:Toggle({Name="Silent Aim",Flag="SilentAim",Default=false,Callback=function(v) S.SilentAim=v ApplySilentAim() end})
AimSec:Toggle({Name="Murderer Only",Flag="AimMurdOnly",Default=true,Callback=function(v) S.AimMurdOnly=v end})
AimSec:Dropdown({Name="Target Part",Flag="AimPart",Default="Head",Items={"Head","HumanoidRootPart","UpperTorso","Neck"},Callback=function(v) S.AimPart=v end})
AimSec:Slider({Name="FOV Radius",Flag="AimFOV",Default=150,Min=10,Max=600,Decimals=1,Suffix=" px",
    Callback=function(v) S.AimFOV=v FOVCircle.Radius=v end})
AimSec:Slider({Name="Smoothness",Flag="AimSmooth",Default=0.15,Min=0.01,Max=1,Decimals=0.01,Suffix="x",
    Callback=function(v) S.AimSmooth=v end})

local KillSec=CombatPage:Section({Name="Kill Aura",Side=2,Icon="100050851789190",Description="Auto knife nearby players"})
KillSec:Toggle({Name="Kill Aura",Flag="KillAura",Default=false,Callback=function(v) S.KillAura=v end}):SubKeybind({Flag="KillAuraKey",Default=Enum.KeyCode.F})
KillSec:Slider({Name="Kill Range",Flag="KillRange",Default=15,Min=1,Max=80,Decimals=1,Suffix=" st",Callback=function(v) S.KillRange=v end})
KillSec:Label("Only works when you are Murderer")

-- ══════════════════════════════════════════════
--  ██ PAGE: MOVEMENT
-- ══════════════════════════════════════════════
local MovPage=Window:Page({Name="Movement",Icon="92464809279921"})

local SpeedSec=MovPage:Section({Name="Speed",Side=1,Icon="122669828593160"})
SpeedSec:Toggle({Name="Speed Hack",Flag="Speed",Default=false,
    Callback=function(v) S.Speed=v if not v then SetSpeed(16) end end}):SubKeybind({Flag="SpeedKey",Default=Enum.KeyCode.X})
SpeedSec:Slider({Name="Walk Speed",Flag="SpeedVal",Default=30,Min=16,Max=200,Decimals=1,Suffix=" ws",Callback=function(v) S.SpeedVal=v end})

local FlySec=MovPage:Section({Name="Fly",Side=1,Icon="117786983271442",Description="WASD + Space/Ctrl"})
FlySec:Toggle({Name="Fly",Flag="Fly",Default=false,
    Callback=function(v) S.Fly=v if v then StartFly() else StopFly() end end}):SubKeybind({Flag="FlyKey",Default=Enum.KeyCode.G})
FlySec:Slider({Name="Fly Speed",Flag="FlySpeed",Default=50,Min=5,Max=400,Decimals=1,Suffix=" sp",Callback=function(v) S.FlySpeed=v end})

local MiscMovSec=MovPage:Section({Name="Misc Movement",Side=2,Icon="73789337996373"})
MiscMovSec:Toggle({Name="Noclip",Flag="Noclip",Default=false,Callback=function(v) S.Noclip=v end}):SubKeybind({Flag="NoclipKey",Default=Enum.KeyCode.N})
MiscMovSec:Toggle({Name="Bunny Hop",Flag="Bhop",Default=false,Callback=function(v) S.Bhop=v end}):SubKeybind({Flag="BhopKey",Default=Enum.KeyCode.V})
MiscMovSec:Toggle({Name="Infinite Stamina",Flag="InfStam",Default=false,Callback=function(v) S.InfStam=v end})
MiscMovSec:Toggle({Name="God Mode",Flag="GodMode",Default=false,Callback=function(v) S.GodMode=v end})

-- ══════════════════════════════════════════════
--  ██ PAGE: ANTI-EXPLOIT
-- ══════════════════════════════════════════════
local AntiPage=Window:Page({Name="Anti-Exploit",Icon="73789337996373"})

local AFSec=AntiPage:Section({Name="Anti-Fling",Side=1,Icon="117786983271442",Description="Blocks velocity fling attacks"})
AFSec:Toggle({Name="Anti-Fling",Flag="AntiFling",Default=false,
    Callback=function(v) S.AntiFling=v if v then EnableAntiFling() end end})

local AKSec=AntiPage:Section({Name="Anti-Kill",Side=1,Icon="121760666525660",Description="Blocks illegitimate damage"})
AKSec:Toggle({Name="Anti-Kill",Flag="AntiKill",Default=false,
    Callback=function(v) S.AntiKill=v if v then EnableAntiKill() end end})

local ATSec=AntiPage:Section({Name="Anti-Teleport",Side=2,Icon="100050851789190"})
ATSec:Toggle({Name="Anti-Teleport",Flag="AntiTp",Default=false,
    Callback=function(v) S.AntiTp=v if v then EnableAntiTp() end end})
ATSec:Slider({Name="Max Move Dist",Flag="MaxTpDist",Default=50,Min=10,Max=250,Decimals=1,Suffix=" st",
    Callback=function(v) S.MaxTpDist=v end})

local ADSec=AntiPage:Section({Name="Detection",Side=2,Icon="122669828593160"})
ADSec:Toggle({Name="Anti-Speed Detection",Flag="AntiSpd",Default=false,
    Callback=function(v) S.AntiSpd=v if v then EnableAntiSpeed() end end})

-- ══════════════════════════════════════════════
--  ██ PAGE: FARM
-- ══════════════════════════════════════════════
local FarmPage=Window:Page({Name="Farm",Icon="81598136527047"})
local CoinSec=FarmPage:Section({Name="Coin Farm",Side=1,Icon="73789337996373",Description="Teleports to nearest coin"})
CoinSec:Toggle({Name="Auto Coin Farm",Flag="AutoCoin",Default=false,Callback=function(v) S.AutoCoin=v end}):SubKeybind({Flag="CoinKey",Default=Enum.KeyCode.C})

-- ══════════════════════════════════════════════
--  ██ PAGE: MISC
-- ══════════════════════════════════════════════
local MiscPage=Window:Page({Name="Misc",Icon="122669828593160"})

local DesyncSec=MiscPage:Section({Name="Desync",Side=1,Icon="100050851789190",Description="Server-side position flicker"})
DesyncSec:Toggle({Name="Enable Desync",Flag="Desync",Default=false,
    Callback=function(v) S.Desync=v ApplyDesync() end}):SubKeybind({Flag="DesyncKey",Default=Enum.KeyCode.Z})
DesyncSec:Slider({Name="Strength",Flag="DesyncStr",Default=5,Min=1,Max=30,Decimals=1,Suffix=" st",
    Callback=function(v) S.DesyncStr=v if S.Desync then ApplyDesync() end end})

local InfoSec=MiscPage:Section({Name="Server Info",Side=2,Icon="73789337996373"})
local PlrLbl=InfoSec:Label("Players: --")
local AliveLbl=InfoSec:Label("Alive: --")
local RoleLbl=InfoSec:Label("Role: --")
task.spawn(function()
    while true do task.wait(1)
        local alive=0 for _,p in ipairs(Players:GetPlayers()) do if Alive(p) then alive+=1 end end
        PlrLbl:SetText("Players: "..#Players:GetPlayers())
        AliveLbl:SetText("Alive: "..alive)
        RoleLbl:SetText("Role: "..Role(LocalPlayer))
    end
end)

local SrvSec=MiscPage:Section({Name="Server",Side=1,Icon="117786983271442"})
SrvSec:Button({Name="Server Hop",Callback=function()
    task.spawn(function()
        Library:Notification({Title="Server Hop",Description="Searching...",Duration=1})
        local HS=game:GetService("HttpService"); local TS=game:GetService("TeleportService")
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
SrvSec:Button({Name="Low Pop Server",Callback=function()
    task.spawn(function()
        Library:Notification({Title="Low Pop Hop",Description="Searching...",Duration=1})
        local HS=game:GetService("HttpService"); local TS=game:GetService("TeleportService")
        local ok,s=pcall(function() return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=Asc&limit=100")) end)
        if ok and s and s.data then
            local best,lowest=nil,999
            for _,srv in ipairs(s.data) do
                if srv.id~=game.JobId and srv.playing and srv.playing<srv.maxPlayers and srv.playing<lowest then
                    lowest=srv.playing; best=srv
                end
            end
            if best then pcall(function() TS:TeleportToPlaceInstance(game.PlaceId,best.id) end) return end
        end
        Library:Notification({Title="Low Pop Hop",Description="No servers found.",Duration=2})
    end)
end})
SrvSec:Button({Name="Rejoin",Callback=function()
    pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId) end)
end})

-- ══════════════════════════════════════════════
--  SETTINGS PAGE + WATERMARK + INIT
-- ══════════════════════════════════════════════
Library:CreateSettingsPage(Window, KeybindList)

-- Watermark update loop
task.spawn(function()
    while true do task.wait(1)
        local ping=0 pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        Library:Watermark({"MM2 Hub v3"," | ","FPS: "..fpsDisp," | ","Ping: "..ping.."ms"," | ",Role(LocalPlayer)})
    end
end)
Library.WatermarkFrame.Instance.Visible = true

Window:Init()

Library:Notification({
    Title="MM2 Hub v3",
    Description="Loaded! RightAlt = menu. ESP & FOV fixed.",
    Duration=4,
    Icon="73789337996373"
})
