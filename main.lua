-- ═════════════════════════════════════════════════════════════
-- ║             HAMA UNIVERSAL HUB V2.5                       ║
-- ║   Server Killer Edition | Hook Amp + 4-Phase + SimHack    ║
-- ═════════════════════════════════════════════════════════════

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    UserInputService = game:GetService("UserInputService"),
    TeleportService = game:GetService("TeleportService"),
    TweenService = game:GetService("TweenService"),
}

local Player = Services.Players.LocalPlayer
local RunService = Services.RunService
local UIS = Services.UserInputService
local TweenService = Services.TweenService

local State = {
    OwnerName = "dpnvhr",
    IsWhitelisted = true,
    PianoSpamming = false, SelectedRemote = nil, SelectedPiano = nil, FoundPianos = {},
    Level = 10, Threads = 10, KeyMult = 1, Mode = "nuke", FireCount = 0, RemoteFormat = "positional",
    FlyEnabled = false, FlySpeed = 50, FlyKeybind = Enum.KeyCode.F,
    NoclipEnabled = false, InvisibleEnabled = false, SpeedEnabled = false, WalkSpeed = 16,
    TargetPlayer = nil, TrollMode = "NONE", TrollActive = false, TrollConn = nil,
    SpectateStop = nil, PhysicStop = nil, HijackStop = nil, WalkFlingStop = nil, ShieldStop = nil,
    HookAmplifier = 20,
    SimHack = true,
    PhaseDriver = true,
}

-- ==========================================================
-- HOOK AMPLIFIER (Metamethod)
-- ==========================================================
local _HM_INSTALLED = false
local _HM_RESTORE_NC = nil
local _HM_ACTIVE_REMOTES = {}

local function _HM_SetRW(mt, writable)
    if typeof(setreadonly) == "function" then
        pcall(setreadonly, mt, not writable)
    elseif typeof(make_writeable) == "function" and writable then
        pcall(make_writeable, mt)
    end
end

local function _HM_Install()
    if _HM_INSTALLED then return end
    if typeof(hookmetamethod) ~= "function" or typeof(getrawmetatable) ~= "function" then
        warn("[HAMA] Hookmetamethod not supported on this executor!")
        return
    end
    
    local mt = getrawmetatable(game)
    _HM_RESTORE_NC = mt.__namecall
    local origNC = _HM_RESTORE_NC
    _HM_SetRW(mt, true)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method ~= "FireServer" and method ~= "InvokeServer" then
            return origNC(self, ...)
        end
        
        -- Cek apakah remote ini piano aktif
        if _HM_ACTIVE_REMOTES[self] then
            local args = {...}
            local amp = State.HookAmplifier
            
            -- Fire Server: synchronous loop
            if method == "FireServer" then
                for _ = 1, amp do
                    origNC(self, table.unpack(args))
                end
            else
                -- Invoke: spawn paralel
                for _ = 1, amp do
                    task.spawn(origNC, self, table.unpack(args))
                end
            end
        end
        
        return origNC(self, ...)
    end)
    
    _HM_SetRW(mt, false)
    _HM_INSTALLED = true
    print("[HAMA] Hook Amplifier INSTALLED (x" .. State.HookAmplifier .. ")")
end

local function _HM_Uninstall()
    if not _HM_INSTALLED then return end
    if typeof(getrawmetatable) ~= "function" then return end
    
    local mt = getrawmetatable(game)
    _HM_SetRW(mt, true)
    if _HM_RESTORE_NC then
        mt.__namecall = _HM_RESTORE_NC
        _HM_RESTORE_NC = nil
    end
    _HM_SetRW(mt, false)
    _HM_INSTALLED = false
    print("[HAMA] Hook Amplifier UNINSTALLED")
end

local function _HM_SetActiveRemotes(remotes)
    _HM_ACTIVE_REMOTES = {}
    for _, r in ipairs(remotes) do
        if r and r.Parent then _HM_ACTIVE_REMOTES[r] = true end
    end
end

-- ==========================================================
-- SIMULATION RADIUS HACK
-- ==========================================================
local function ExpandSimulation()
    if not State.SimHack then return end
    pcall(function()
        sethiddenproperty(Player, "SimulationRadius", 1e15)
        sethiddenproperty(Player, "MaxSimulationRadius", 1e15)
        settings().Physics.AllowSleep = false
        settings().Physics.ThrottleAdjustTime = 0
    end)
end

local function RestoreSimulation()
    pcall(function()
        sethiddenproperty(Player, "SimulationRadius", 1024)
        sethiddenproperty(Player, "MaxSimulationRadius", 1024)
        settings().Physics.AllowSleep = true
    end)
end

-- ==========================================================
-- PIANO LOGIC
-- ==========================================================
local PIANO_KEYWORDS = {"piano", "keyboard", "keys", "organ", "synthesizer", "grand", "upright", "key", "music", "sound", "instrument", "note", "play"}

local function ContainsPianoKeyword(str)
    if not str then return false end
    local lower = str:lower()
    for _, kw in ipairs(PIANO_KEYWORDS) do
        if lower:find(kw) then return true end
    end
    return false
end

local function ScanPianos()
    local found, seen = {}, {}
    for _, obj in ipairs(Services.Workspace:GetDescendants()) do
        if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and not seen[obj] then
            local nameMatch = ContainsPianoKeyword(obj.Name)
            local parentMatch = obj.Parent and ContainsPianoKeyword(obj.Parent.Name)
            local grandParentMatch = obj.Parent and obj.Parent.Parent and ContainsPianoKeyword(obj.Parent.Parent.Name)
            local hasPrompt = false
            if obj.Parent and obj.Parent:IsA("BasePart") then
                for _, child in ipairs(obj.Parent:GetChildren()) do
                    if child:IsA("ProximityPrompt") and (ContainsPianoKeyword(child.ActionText) or ContainsPianoKeyword(child.ObjectText)) then
                        hasPrompt = true
                    end
                end
            end
            if nameMatch or parentMatch or grandParentMatch or hasPrompt then
                seen[obj] = true
                local pianoName = obj.Name
                local pianoModel = obj.Parent
                for _ = 1, 3 do
                    if pianoModel and pianoModel ~= Services.Workspace and pianoModel:IsA("Model") then
                        pianoName = pianoModel.Name
                        break
                    end
                    if pianoModel then pianoModel = pianoModel.Parent end
                end
                table.insert(found, {
                    seat = obj, pos = obj.Position, name = pianoName,
                    label = string.format("[%d] %s [%d, %d, %d]", #found + 1, pianoName,
                        math.floor(obj.Position.X), math.floor(obj.Position.Y), math.floor(obj.Position.Z))
                })
            end
        end
    end
    return found
end

local function FindAllPianoRemotes()
    local remotes = {}
    for _, obj in ipairs(Services.ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            local n = obj.Name:lower()
            if n:find("piano") or n:find("note") or n:find("play") or n:find("music") or n:find("sound") then
                table.insert(remotes, obj)
            end
        end
    end
    if #remotes == 0 then
        local gpc = Services.Workspace:FindFirstChild("GlobalPianoConnector")
        if gpc and (gpc:IsA("RemoteEvent") or gpc:IsA("RemoteFunction")) then
            table.insert(remotes, gpc)
        end
    end
    return remotes
end

-- ==========================================================
-- PLAYER LOGIC
-- ==========================================================
local flyBV, flyBG, flyConn
local UI_UpdateFlyBtn = nil

local function ToggleFly(state)
    State.FlyEnabled = state
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if state and hrp and hum then
        hum.PlatformStand = true
        flyBV = Instance.new("BodyVelocity", hrp)
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.zero
        flyBG = Instance.new("BodyGyro", hrp)
        flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBG.P = 1000
        flyConn = RunService.RenderStepped:Connect(function()
            if not State.FlyEnabled then return end
            local cam = Services.Workspace.CurrentCamera
            local move = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end
            flyBV.Velocity = move.Magnitude > 0 and move.Unit * State.FlySpeed or Vector3.zero
            flyBG.CFrame = cam.CFrame
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum then hum.PlatformStand = false end
    end
    if UI_UpdateFlyBtn then UI_UpdateFlyBtn(state) end
end

local function ApplySpeed()
    local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.SpeedEnabled and State.WalkSpeed or 16 end
end

local noclipConn
local function ToggleNoclip(state)
    State.NoclipEnabled = state
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if not State.NoclipEnabled then return end
            local char = Player.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
end

local savedTrans = {}
local function ToggleInvisible(state)
    State.InvisibleEnabled = state
    local char = Player.Character
    if not char then return end
    if state then
        savedTrans = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                savedTrans[p] = p.Transparency
                p.Transparency = 1
            end
        end
    else
        for p, t in pairs(savedTrans) do if p and p.Parent then p.Transparency = t end end
        savedTrans = {}
    end
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == State.FlyKeybind then ToggleFly(not State.FlyEnabled) end
end)

-- ==========================================================
-- TROLL LOGIC
-- ==========================================================
local function StopTroll()
    State.TrollActive = false
    if State.TrollConn then State.TrollConn:Disconnect() State.TrollConn = nil end
    local myChar = Player.Character
    if myChar then
        for _, c in ipairs(myChar:GetDescendants()) do
            if c.Name == "BianTrollWeld" or c.Name == "BianTrollBV" or c.Name == "BianTrollBAV" then
                c:Destroy()
            end
        end
    end
    if State.TargetPlayer and State.TargetPlayer.Character then
        for _, c in ipairs(State.TargetPlayer.Character:GetDescendants()) do
            if c.Name == "BianTrollWeld" or c.Name == "BianTrollBV" or c.Name == "BianTrollBAV" then
                c:Destroy()
            end
        end
    end
    if State.TargetPlayer and State.TargetPlayer.Character then
        local tHRP = State.TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then pcall(function() tHRP:SetNetworkOwner(nil) end) end
    end
    local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if myHRP then pcall(function() myHRP:SetNetworkOwner(nil) end) end
end

local function StartTroll(mode)
    StopTroll()
    local target = State.TargetPlayer
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local tHead = target.Character:FindFirstChild("Head")
    if not tHRP or not tHead then return end
    local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local myHum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not myHRP or not myHum then return end
    State.TrollMode = mode
    State.TrollActive = true
    pcall(function()
        tHRP:SetNetworkOwner(Player)
        myHRP:SetNetworkOwner(Player)
    end)
    if mode == "FLING" then
        local bAV = Instance.new("BodyAngularVelocity", tHRP)
        bAV.Name = "BianTrollBAV"
        bAV.AngularVelocity = Vector3.new(0, 99999, 0)
        bAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        local bV = Instance.new("BodyVelocity", tHRP)
        bV.Name = "BianTrollBV"
        bV.Velocity = Vector3.new(0, 500, 0)
        bV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        task.wait(1.5)
        StopTroll()
    elseif mode == "DRAG" then
        local weld = Instance.new("Weld", tHRP)
        weld.Name = "BianTrollWeld"
        weld.Part0 = tHRP
        weld.Part1 = myHRP
        weld.C0 = CFrame.new(0, 0, 3)
        State.TrollConn = RunService.Heartbeat:Connect(function()
            if not State.TrollActive then return end
            weld.C0 = CFrame.new(0, 0, 3)
        end)
    elseif mode == "HEADSIT" then
        local weld = Instance.new("Weld", tHead)
        weld.Name = "BianTrollWeld"
        weld.Part0 = tHead
        weld.Part1 = myHRP
        weld.C0 = CFrame.new(0, 1.5, 0)
        State.TrollConn = RunService.Heartbeat:Connect(function()
            if not State.TrollActive then return end
            weld.C0 = CFrame.new(0, 1.5, 0)
        end)
    elseif mode == "BACKPACK" then
        local weld = Instance.new("Weld", tHRP)
        weld.Name = "BianTrollWeld"
        weld.Part0 = tHRP
        weld.Part1 = myHRP
        weld.C0 = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.pi, 0)
        State.TrollConn = RunService.Heartbeat:Connect(function()
            if not State.TrollActive then return end
            weld.C0 = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.pi, 0)
        end)
    end
end

-- ==========================================================
-- UI SETUP
-- ==========================================================
local function CreateUI()
    local pg = Player:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("HamaUniversalV25")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "HamaUniversalV25"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Enabled = true
    gui.Parent = pg
    _G.HamaGUI = gui

    local main = Instance.new("Frame", gui)
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(0, 540, 0, 360)
    main.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    main.BorderSizePixel = 0
    main.Active = true
    main.ClipsDescendants = true
    main.ZIndex = 5
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local sizeConstraint = Instance.new("UISizeConstraint", main)
    sizeConstraint.MaxSize = Vector2.new(620, 440)
    sizeConstraint.MinSize = Vector2.new(400, 260)

    local glow = Instance.new("UIStroke", main)
    glow.Thickness = 2
    glow.Color = Color3.fromRGB(0, 255, 100)
    glow.Transparency = 0.3
    glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local shadow = Instance.new("Frame", gui)
    shadow.Size = UDim2.new(0, 540, 0, 360)
    shadow.Position = UDim2.new(0.5, -265, 0.5, -175)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 4
    Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 10)
    task.spawn(function()
        while gui.Parent do
            shadow.Position = main.Position + UDim2.new(0, 6, 0, 6)
            task.wait(0.01)
        end
    end)

    local uiState = {
        Expanded = true,
        ExpandedSize = UDim2.new(0, 540, 0, 360),
        ExpandedPos = UDim2.new(0.5, 0, 0.5, 0),
        MinimizedSize = UDim2.new(0, 50, 0, 50),
    }
    local function applyResponsiveSize()
        if not uiState.Expanded then return end
        local cam = Services.Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        if vp.X < 100 or vp.Y < 100 then return end
        local w = math.clamp(vp.X * 0.90, 440, 620)
        local h = math.clamp(vp.Y * 0.80, 280, 440)
        uiState.ExpandedSize = UDim2.new(0, w, 0, h)
        main.Size = uiState.ExpandedSize
        shadow.Size = uiState.ExpandedSize
    end
    applyResponsiveSize()

    local viewportConn = nil
    local function bindViewport()
        if viewportConn then viewportConn:Disconnect() viewportConn = nil end
        local cam = Services.Workspace.CurrentCamera
        if cam then
            viewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveSize)
        end
        applyResponsiveSize()
    end
    Services.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
    bindViewport()

    local function Apply3DButton(btn)
        local sh = Instance.new("Frame", btn)
        sh.Name = "Shadow3D"
        sh.Size = UDim2.new(1, 0, 1, 0)
        sh.Position = UDim2.new(0, 3, 0, 3)
        sh.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        sh.BackgroundTransparency = 0.4
        sh.BorderSizePixel = 0
        sh.ZIndex = btn.ZIndex - 1
        Instance.new("UICorner", sh).CornerRadius = UDim.new(0, 4)
        local hl = Instance.new("Frame", btn)
        hl.Name = "Highlight3D"
        hl.Size = UDim2.new(1, -4, 0, 3)
        hl.Position = UDim2.new(0, 2, 0, 1)
        hl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hl.BackgroundTransparency = 0.7
        hl.BorderSizePixel = 0
        hl.ZIndex = btn.ZIndex + 1
        Instance.new("UICorner", hl).CornerRadius = UDim.new(0, 2)
        local origSize = btn.Size
        local origPos = btn.Position
        btn.MouseButton1Down:Connect(function()
            btn.Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 2, origSize.Y.Scale, origSize.Y.Offset - 2)
            btn.Position = origPos + UDim2.new(0, 1, 0, 1)
        end)
        btn.MouseButton1Up:Connect(function()
            btn.Size = origSize
            btn.Position = origPos
        end)
        btn.MouseLeave:Connect(function()
            btn.Size = origSize
            btn.Position = origPos
        end)
    end

    local function RichText(text)
        return tostring(text):gsub("(%d+)", '<font color="#00ff64">%1</font>')
    end

    local function MakeBtn(parent, text, pos, size, color)
        local b = Instance.new("TextButton", parent)
        b.Size = size or UDim2.new(1, 0, 0, 32)
        b.Position = pos
        b.BackgroundColor3 = color or Color3.fromRGB(25, 25, 30)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.Code
        b.TextSize = 11
        b.ZIndex = 7
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(60, 60, 70)
        s.Thickness = 1
        Apply3DButton(b)
        return b
    end

    local function MakeLabel(parent, text, pos, size, color)
        local lbl = Instance.new("TextLabel", parent)
        lbl.Size = size or UDim2.new(1, 0, 0, 18)
        lbl.Position = pos
        lbl.BackgroundTransparency = 1
        lbl.RichText = true
        lbl.Text = RichText(text)
        lbl.TextColor3 = color or Color3.fromRGB(220, 220, 220)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        return lbl
    end

    local function UpdateHackerLabel(lbl, text)
        lbl.Text = RichText(text)
    end

    local function MakeSlider(parent, label, pos, min, max, default, callback)
        local lbl = Instance.new("TextLabel", parent)
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Position = pos
        lbl.BackgroundTransparency = 1
        lbl.RichText = true
        lbl.Text = RichText(label .. ": " .. default)
        lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        local bar = Instance.new("Frame", parent)
        bar.Size = UDim2.new(1, 0, 0, 14)
        bar.Position = pos + UDim2.new(0, 0, 0, 18)
        bar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        bar.ZIndex = 6
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
        local border = Instance.new("UIStroke", bar)
        border.Color = Color3.fromRGB(0, 200, 80)
        border.Thickness = 1
        border.Transparency = 0.5
        local fill = Instance.new("Frame", bar)
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        fill.BorderSizePixel = 0
        fill.ZIndex = 7
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
        local sldDragging = false
        local function update(input)
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + rel * (max - min))
            fill.Size = UDim2.new(rel, 0, 1, 0)
            UpdateHackerLabel(lbl, label .. ": " .. v)
            callback(v)
        end
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sldDragging = true; update(i)
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if sldDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                update(i)
            end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sldDragging = false
            end
        end)
    end

    local function MakeScrollPage(parent, name, visible)
        local sf = Instance.new("ScrollingFrame", parent)
        sf.Name = name
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.ScrollBarThickness = 4
        sf.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 100)
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.ScrollingDirection = Enum.ScrollingDirection.Y
        sf.Visible = visible or false
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.ZIndex = 7
        return sf
    end

    -- HEADER
    local header = Instance.new("Frame", main)
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 6
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔥 HAMA UNIVERSAL V2.5"
    title.TextColor3 = Color3.fromRGB(0, 255, 100)
    title.Font = Enum.Font.Code
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 7
    local titleStroke = Instance.new("UIStroke", title)
    titleStroke.Color = Color3.fromRGB(0, 255, 100)
    titleStroke.Thickness = 1
    titleStroke.Transparency = 0.5

    local minBtn = Instance.new("TextButton", header)
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -64, 0, 6)
    minBtn.BackgroundColor3 = Color3.fromRGB(200, 180, 40)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    minBtn.Font = Enum.Font.Code
    minBtn.TextSize = 16
    minBtn.ZIndex = 7
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)
    Apply3DButton(minBtn)

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.Code
    closeBtn.TextSize = 14
    closeBtn.ZIndex = 7
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    Apply3DButton(closeBtn)

    local dragging = false
    local dragStart, startPos
    local function beginDrag(input)
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if input.Position.X > header.AbsolutePosition.X + header.AbsoluteSize.X - 70 then return end
            beginDrag(input)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- SIDEBAR
    local sidebar = Instance.new("Frame", main)
    sidebar.Size = UDim2.new(0, 100, 1, -55)
    sidebar.Position = UDim2.new(0, 8, 0, 48)
    sidebar.BackgroundTransparency = 1
    sidebar.ZIndex = 6
    local sidebarLayout = Instance.new("UIListLayout", sidebar)
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local content = Instance.new("Frame", main)
    content.Size = UDim2.new(1, -120, 1, -55)
    content.Position = UDim2.new(0, 112, 0, 48)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.ZIndex = 6

    local tabs = {"PIANO", "PLAYER", "TROLL", "PHYSIC", "HIJACK", "SERVER", "SHIELD", "ABOUT"}
    local tabBtns = {}
    local pages = {}

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", sidebar)
        btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Code
        btn.TextSize = 10
        btn.LayoutOrder = i
        btn.ZIndex = 7
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        local s = Instance.new("UIStroke", btn)
        s.Color = Color3.fromRGB(50, 50, 60)
        s.Thickness = 1
        Apply3DButton(btn)
        tabBtns[name] = btn
    end

    local function switchTab(tabName)
        for n, b in pairs(tabBtns) do
            b.BackgroundColor3 = n == tabName and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(20, 20, 25)
            b.TextColor3 = n == tabName and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(220, 220, 220)
        end
        for n, p in pairs(pages) do p.Visible = (n == tabName) end
    end
    for _, name in ipairs(tabs) do
        tabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
    end

    -- MINIMIZE
    local minimizedBtn
    local minimizeAnim = false
    local function setContentVisible(v)
        for _, child in ipairs(main:GetChildren()) do
            if child:IsA("GuiObject") and child ~= header and child.Name ~= "MinimizedBtn" then
                child.Visible = v
            end
        end
        title.Visible = v
        minBtn.Visible = v
        closeBtn.Visible = v
    end
    local function ensureMinimizedBtn()
        if minimizedBtn then return end
        minimizedBtn = Instance.new("TextButton", main)
        minimizedBtn.Name = "MinimizedBtn"
        minimizedBtn.Size = UDim2.new(1, 0, 1, 0)
        minimizedBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        minimizedBtn.Text = "H"
        minimizedBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
        minimizedBtn.Font = Enum.Font.Code
        minimizedBtn.TextSize = 20
        minimizedBtn.ZIndex = 10
        minimizedBtn.Visible = false
        Instance.new("UICorner", minimizedBtn).CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", minimizedBtn)
        s.Color = Color3.fromRGB(0, 255, 100)
        s.Thickness = 1
        local lastClick = 0
        minimizedBtn.MouseButton1Click:Connect(function()
            local now = tick()
            if now - lastClick < 0.4 then
                if not minimizeAnim then toggleMinimize() end
            end
            lastClick = now
        end)
        minimizedBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local origStart = input.Position
                local moved = false
                beginDrag(input)
                local conn
                conn = UIS.InputChanged:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                        if (i.Position - origStart).Magnitude > 4 then
                            moved = true
                            if conn then conn:Disconnect() conn = nil end
                        end
                    end
                end)
                local endConn
                endConn = UIS.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        if conn then conn:Disconnect() conn = nil end
                        if endConn then endConn:Disconnect() end
                        if moved then dragging = false end
                    end
                end)
            end
        end)
    end
    function toggleMinimize()
        if minimizeAnim then return end
        minimizeAnim = true
        if uiState.Expanded then
            uiState.ExpandedPos = main.Position
            uiState.ExpandedSize = main.Size
            setContentVisible(false)
            header.Visible = false
            shadow.Visible = false
            sizeConstraint.MinSize = Vector2.new(0, 0)
            local tween = TweenService:Create(main, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = uiState.MinimizedSize })
            tween:Play()
            tween.Completed:Connect(function()
                ensureMinimizedBtn()
                minimizedBtn.Visible = true
                minimizeAnim = false
            end)
            uiState.Expanded = false
        else
            if minimizedBtn then minimizedBtn.Visible = false end
            shadow.Visible = true
            main.Position = UDim2.new(0.5, 0, 0.5, 0)
            sizeConstraint.MinSize = Vector2.new(400, 250)
            local tween = TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = uiState.ExpandedSize })
            tween:Play()
            tween.Completed:Connect(function()
                header.Visible = true
                setContentVisible(true)
                minimizeAnim = false
            end)
            uiState.Expanded = true
        end
    end
    minBtn.MouseButton1Click:Connect(toggleMinimize)
    closeBtn.MouseButton1Click:Connect(function()
        StopTroll()
        if State.SpectateStop then State.SpectateStop() end
        if State.PhysicStop then State.PhysicStop() end
        if State.HijackStop then State.HijackStop() end
        if State.WalkFlingStop then State.WalkFlingStop() end
        if State.ShieldStop then State.ShieldStop() end
        gui:Destroy()
    end)

    -- TAB PIANO
    local pagePiano = MakeScrollPage(content, "PIANO", true)
    pages["PIANO"] = pagePiano
    local scanBtn = MakeBtn(pagePiano, "SCAN PIANO", UDim2.new(0, 0, 0, 0), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(40, 40, 70))
    local tpBtn = MakeBtn(pagePiano, "TELEPORT", UDim2.new(0.52, 2, 0, 0), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(70, 60, 30))
    local pianoList = Instance.new("ScrollingFrame", pagePiano)
    pianoList.Size = UDim2.new(1, 0, 0, 60)
    pianoList.Position = UDim2.new(0, 0, 0, 38)
    pianoList.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    pianoList.BorderSizePixel = 0
    pianoList.ScrollBarThickness = 2
    pianoList.ZIndex = 7
    Instance.new("UICorner", pianoList).CornerRadius = UDim.new(0, 5)
    Instance.new("UIListLayout", pianoList).Padding = UDim.new(0, 2)
    MakeSlider(pagePiano, "Level", UDim2.new(0, 0, 0, 108), 1, 100, 10, function(v) State.Level = v end)
    MakeSlider(pagePiano, "Threads", UDim2.new(0, 0, 0, 148), 1, 8000, 10, function(v) State.Threads = v end)
    MakeSlider(pagePiano, "Key Mult", UDim2.new(0, 0, 0, 188), 1, 100, 1, function(v) State.KeyMult = v end)
    MakeSlider(pagePiano, "Hook Amp (1-50x)", UDim2.new(0, 0, 0, 228), 1, 50, 20, function(v) State.HookAmplifier = v end)
    local modeBtn = MakeBtn(pagePiano, "Mode: NUKE", UDim2.new(0, 0, 0, 268), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(30, 30, 50))
    local modeList = {"nuke", "chaos", "chromatic", "all", "whiteflood", "blackflood", "thunderclap"}
    local modeNames = {"NUKE", "Chaos", "Chromatic", "All Keys", "White Flood", "Black Flood", "Thunderclap"}
    local modeIdx = 1
    modeBtn.MouseButton1Click:Connect(function()
        modeIdx = modeIdx % #modeList + 1
        State.Mode = modeList[modeIdx]
        modeBtn.Text = "Mode: " .. modeNames[modeIdx]
    end)
    local counterLbl = MakeLabel(pagePiano, "Fires: 0", UDim2.new(0.52, 2, 0, 268), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(200, 200, 200))
    counterLbl.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    counterLbl.BackgroundTransparency = 0
    counterLbl.TextXAlignment = Enum.TextXAlignment.Center
    Instance.new("UICorner", counterLbl).CornerRadius = UDim.new(0, 5)
    local startBtn = MakeBtn(pagePiano, "START SPAM", UDim2.new(0, 0, 0, 310), UDim2.new(0.48, -2, 0, 34), Color3.fromRGB(20, 80, 40))
    local stopBtn = MakeBtn(pagePiano, "STOP", UDim2.new(0.52, 2, 0, 310), UDim2.new(0.48, -2, 0, 34), Color3.fromRGB(80, 20, 20))
    local fmtBtn = MakeBtn(pagePiano, "Remote: Positional", UDim2.new(0, 0, 0, 352), UDim2.new(1, 0, 0, 30), Color3.fromRGB(30, 50, 80))
    local fmtList = {
        { id = "positional", label = 'Remote: Positional ("play", key)' },
        { id = "table", label = "Remote: Table {play, key}" },
    }
    local fmtIdx = 1
    State.RemoteFormat = fmtList[fmtIdx].id
    fmtBtn.Text = fmtList[fmtIdx].label
    fmtBtn.MouseButton1Click:Connect(function()
        fmtIdx = fmtIdx % #fmtList + 1
        State.RemoteFormat = fmtList[fmtIdx].id
        fmtBtn.Text = fmtList[fmtIdx].label
    end)

    -- TAB PLAYER
    local pagePlayer = MakeScrollPage(content, "PLAYER", false)
    pages["PLAYER"] = pagePlayer
    local speedBtn = MakeBtn(pagePlayer, "SPEED: OFF", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 32))
    local speedTog = false
    speedBtn.MouseButton1Click:Connect(function()
        speedTog = not speedTog
        State.SpeedEnabled = speedTog
        speedBtn.Text = "SPEED: " .. (speedTog and "ON" or "OFF")
        speedBtn.BackgroundColor3 = speedTog and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(25, 25, 30)
        ApplySpeed()
    end)
    MakeSlider(pagePlayer, "WalkSpeed", UDim2.new(0, 0, 0, 44), 16, 500, 16, function(v)
        State.WalkSpeed = v
        if State.SpeedEnabled then ApplySpeed() end
    end)
    local flyBtn = MakeBtn(pagePlayer, "FLY: OFF", UDim2.new(0, 0, 0, 84), UDim2.new(0.48, -2, 0, 32))
    local function updateFlyBtnUI(state)
        flyBtn.Text = "FLY: " .. (state and "ON" or "OFF")
        flyBtn.BackgroundColor3 = state and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(25, 25, 30)
    end
    UI_UpdateFlyBtn = updateFlyBtnUI
    flyBtn.MouseButton1Click:Connect(function() ToggleFly(not State.FlyEnabled) end)
    local keybindBtn = MakeBtn(pagePlayer, "Keybind: F", UDim2.new(0.52, 2, 0, 84), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(40, 40, 60))
    keybindBtn.MouseButton1Click:Connect(function()
        keybindBtn.Text = "Press key..."
        local conn
        conn = UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                State.FlyKeybind = input.KeyCode
                keybindBtn.Text = "Keybind: " .. input.KeyCode.Name
                conn:Disconnect()
            end
        end)
    end)
    MakeSlider(pagePlayer, "Fly Speed", UDim2.new(0, 0, 0, 124), 10, 200, 50, function(v) State.FlySpeed = v end)
    local noclipBtn = MakeBtn(pagePlayer, "NOCLIP: OFF", UDim2.new(0, 0, 0, 164), UDim2.new(0.48, -2, 0, 32))
    noclipBtn.MouseButton1Click:Connect(function()
        ToggleNoclip(not State.NoclipEnabled)
        noclipBtn.Text = "NOCLIP: " .. (State.NoclipEnabled and "ON" or "OFF")
        noclipBtn.BackgroundColor3 = State.NoclipEnabled and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(25, 25, 30)
    end)
    local invisBtn = MakeBtn(pagePlayer, "INVISIBLE: OFF", UDim2.new(0.52, 2, 0, 164), UDim2.new(0.48, -2, 0, 32))
    invisBtn.MouseButton1Click:Connect(function()
        ToggleInvisible(not State.InvisibleEnabled)
        invisBtn.Text = "INVISIBLE: " .. (State.InvisibleEnabled and "ON" or "OFF")
        invisBtn.BackgroundColor3 = State.InvisibleEnabled and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(25, 25, 30)
    end)

    -- TAB TROLL
    local pageTroll = MakeScrollPage(content, "TROLL", false)
    pages["TROLL"] = pageTroll
    local targetLabel = MakeLabel(pageTroll, "Target: Belum dipilih", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 20), Color3.fromRGB(0, 255, 100))
    targetLabel.ZIndex = 8
    local searchBox = Instance.new("TextBox", pageTroll)
    searchBox.Size = UDim2.new(1, 0, 0, 28)
    searchBox.Position = UDim2.new(0, 0, 0, 24)
    searchBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    searchBox.BorderSizePixel = 0
    searchBox.PlaceholderText = "Cari player..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(0, 255, 100)
    searchBox.Font = Enum.Font.Code
    searchBox.TextSize = 11
    searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ZIndex = 8
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)
    local searchBorder = Instance.new("UIStroke", searchBox)
    searchBorder.Color = Color3.fromRGB(0, 200, 80)
    searchBorder.Thickness = 1
    local searchPad = Instance.new("UIPadding", searchBox)
    searchPad.PaddingLeft = UDim.new(0, 8)
    local playerList = Instance.new("ScrollingFrame", pageTroll)
    playerList.Size = UDim2.new(1, 0, 0, 85)
    playerList.Position = UDim2.new(0, 0, 0, 58)
    playerList.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    playerList.BorderSizePixel = 0
    playerList.ScrollBarThickness = 2
    playerList.ZIndex = 6
    Instance.new("UICorner", playerList).CornerRadius = UDim.new(0, 5)
    local function RefreshPlayerList()
        local filter = (searchBox.Text or ""):lower()
        for _, c in ipairs(playerList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local idx = 0
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= Player then
                local match = (filter == "") or p.Name:lower():find(filter, 1, true)
                if match then
                    local b = Instance.new("TextButton", playerList)
                    b.Size = UDim2.new(1, -4, 0, 24)
                    b.Position = UDim2.new(0, 2, 0, idx * 26)
                    b.BackgroundColor3 = (p == State.TargetPlayer) and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(20, 20, 25)
                    b.Text = "  " .. p.Name
                    b.TextColor3 = Color3.fromRGB(220, 220, 220)
                    b.Font = Enum.Font.Code
                    b.TextSize = 10
                    b.TextXAlignment = Enum.TextXAlignment.Left
                    b.ZIndex = 7
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                    b.MouseButton1Click:Connect(function()
                        State.TargetPlayer = p
                        UpdateHackerLabel(targetLabel, "Target: " .. p.Name)
                        for _, c in ipairs(playerList:GetChildren()) do
                            if c:IsA("TextButton") then c.BackgroundColor3 = Color3.fromRGB(20, 20, 25) end
                        end
                        b.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
                    end)
                    idx += 1
                end
            end
        end
        playerList.CanvasSize = UDim2.new(0, 0, 0, idx * 26 + 4)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(RefreshPlayerList)
    RefreshPlayerList()
    Services.Players.PlayerAdded:Connect(function() task.wait(1); RefreshPlayerList() end)
    Services.Players.PlayerRemoving:Connect(function() task.wait(1); RefreshPlayerList() end)
    local tpPlayerBtn = MakeBtn(pageTroll, "TP TO TARGET", UDim2.new(0, 0, 0, 148), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(20, 80, 40))
    tpPlayerBtn.MouseButton1Click:Connect(function()
        local t = State.TargetPlayer
        if not t or not t.Character then return end
        local tHRP = t.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if tHRP and myHRP then myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3) end
    end)
    local Spectate = { Active = false, Conn = nil, SavedCamType = nil, SavedCamSubject = nil, Target = nil, Distance = 8, AngleYaw = 0, AnglePitch = 20 }
    local spectateBtn = MakeBtn(pageTroll, "SPECTATE (ORBIT)", UDim2.new(0.52, 2, 0, 148), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(30, 50, 80))
    local function StopSpectate()
        if Spectate.Conn then Spectate.Conn:Disconnect() Spectate.Conn = nil end
        local cam = Services.Workspace.CurrentCamera
        if cam then
            cam.CameraType = Spectate.SavedCamType or Enum.CameraType.Custom
            local myHum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            cam.CameraSubject = Spectate.SavedCamSubject or myHum
        end
        Spectate.Active = false
        Spectate.Target = nil
        spectateBtn.Text = "SPECTATE (ORBIT)"
        spectateBtn.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
    end
    local function StartSpectate()
        local t = State.TargetPlayer
        if not t or not t.Character then warn("[HAMA] Pilih target dulu."); return end
        local tHRP = t.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end
        local cam = Services.Workspace.CurrentCamera
        Spectate.SavedCamType = cam.CameraType
        Spectate.SavedCamSubject = cam.CameraSubject
        cam.CameraSubject = nil
        cam.CameraType = Enum.CameraType.Scriptable
        Spectate.Target = t
        Spectate.Active = true
        Spectate.Distance = 8
        Spectate.AngleYaw = 0
        Spectate.AnglePitch = 20
        Spectate.Conn = RunService.RenderStepped:Connect(function()
            if not Spectate.Active then return end
            local tgt = Spectate.Target
            if not tgt or not tgt.Character then StopSpectate(); return end
            local tHead = tgt.Character:FindFirstChild("Head")
            local tHRP = tgt.Character:FindFirstChild("HumanoidRootPart")
            if not tHRP then StopSpectate(); return end
            local base = (tHead and tHead.Position) or tHRP.Position
            local mouseDelta = UIS:GetMouseDelta()
            Spectate.AngleYaw = Spectate.AngleYaw - mouseDelta.X * 0.2
            Spectate.AnglePitch = math.clamp(Spectate.AnglePitch - mouseDelta.Y * 0.2, -80, 80)
            local scroll = UIS:GetMouseDelta().Z * 0.5
            Spectate.Distance = math.clamp(Spectate.Distance + scroll, 3, 30)
            if UIS:IsKeyDown(Enum.KeyCode.A) then Spectate.AngleYaw -= 2 end
            if UIS:IsKeyDown(Enum.KeyCode.D) then Spectate.AngleYaw += 2 end
            if UIS:IsKeyDown(Enum.KeyCode.W) then Spectate.AnglePitch += 2 end
            if UIS:IsKeyDown(Enum.KeyCode.S) then Spectate.AnglePitch -= 2 end
            Spectate.AnglePitch = math.clamp(Spectate.AnglePitch, -80, 80)
            local radYaw = math.rad(Spectate.AngleYaw)
            local radPitch = math.rad(Spectate.AnglePitch)
            local offset = Vector3.new(
                math.sin(radYaw) * math.cos(radPitch) * Spectate.Distance,
                math.sin(radPitch) * Spectate.Distance,
                math.cos(radYaw) * math.cos(radPitch) * Spectate.Distance
            )
            local targetPos = base + offset
            local desiredCF = CFrame.new(targetPos, base)
            cam.CFrame = cam.CFrame:Lerp(desiredCF, 0.3)
        end)
        spectateBtn.Text = "STOP ORBIT"
        spectateBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
    State.SpectateStop = StopSpectate
    spectateBtn.MouseButton1Click:Connect(function()
        if Spectate.Active then StopSpectate() else StartSpectate() end
    end)
    Services.Players.PlayerRemoving:Connect(function(plr)
        if Spectate.Active and Spectate.Target == plr then StopSpectate() end
    end)
    local backpackBtn = MakeBtn(pageTroll, "BACKPACK", UDim2.new(0, 0, 0, 185), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(60, 30, 60))
    backpackBtn.MouseButton1Click:Connect(function()
        if State.TargetPlayer then
            if State.TrollActive and State.TrollMode == "BACKPACK" then StopTroll() else StartTroll("BACKPACK") end
            backpackBtn.BackgroundColor3 = State.TrollActive and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 30, 60)
            backpackBtn.Text = State.TrollActive and "STOP" or "BACKPACK"
        end
    end)
    local headsitBtn = MakeBtn(pageTroll, "HEADSIT", UDim2.new(0.52, 2, 0, 185), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(30, 60, 60))
    headsitBtn.MouseButton1Click:Connect(function()
        if State.TargetPlayer then
            if State.TrollActive and State.TrollMode == "HEADSIT" then StopTroll() else StartTroll("HEADSIT") end
            headsitBtn.BackgroundColor3 = State.TrollActive and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(30, 60, 60)
            headsitBtn.Text = State.TrollActive and "STOP" or "HEADSIT"
        end
    end)
    local dragBtn = MakeBtn(pageTroll, "DRAG", UDim2.new(0, 0, 0, 222), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(60, 60, 30))
    dragBtn.MouseButton1Click:Connect(function()
        if State.TargetPlayer then
            if State.TrollActive and State.TrollMode == "DRAG" then StopTroll() else StartTroll("DRAG") end
            dragBtn.BackgroundColor3 = State.TrollActive and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(60, 60, 30)
            dragBtn.Text = State.TrollActive and "STOP" or "DRAG"
        end
    end)
    local flingBtn = MakeBtn(pageTroll, "FLING", UDim2.new(0.52, 2, 0, 222), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(70, 30, 70))
    flingBtn.MouseButton1Click:Connect(function()
        if State.TargetPlayer then
            if State.TrollActive and State.TrollMode == "FLING" then StopTroll() else StartTroll("FLING") end
            flingBtn.BackgroundColor3 = State.TrollActive and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(70, 30, 70)
            flingBtn.Text = State.TrollActive and "STOP" or "FLING"
        end
    end)

    -- TAB PHYSIC
    local pagePhysic = MakeScrollPage(content, "PHYSIC", false)
    pages["PHYSIC"] = pagePhysic
    local phyTitle = MakeLabel(pagePhysic, "PHYSIC MANIPULATOR", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 20), Color3.fromRGB(0, 255, 100))
    phyTitle.TextSize = 14
    local phyStatus = MakeLabel(pagePhysic, "Status: Idle | Target: 0", UDim2.new(0, 0, 0, 22), UDim2.new(1, 0, 0, 18), Color3.fromRGB(150, 150, 150))
    local phyModeList = {"STACK", "ORBIT", "BLACKHOLE", "TORNADO", "VORTEX", "WAVE", "CAGE", "SPIRAL", "SATURN"}
    local phyMode = "STACK"
    local phyModeBtn = MakeBtn(pagePhysic, "Mode: " .. phyMode, UDim2.new(0, 0, 0, 45), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(50, 30, 70))
    phyModeBtn.MouseButton1Click:Connect(function()
        local idx = 1
        for i, v in ipairs(phyModeList) do if v == phyMode then idx = i break end end
        idx = idx % #phyModeList + 1
        phyMode = phyModeList[idx]
        phyModeBtn.Text = "Mode: " .. phyMode
    end)
    local phyRadius = 2500
    local phyRadiusBtn = MakeBtn(pagePhysic, "Radius: " .. phyRadius, UDim2.new(0.52, 2, 0, 45), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(30, 50, 70))
    phyRadiusBtn.MouseButton1Click:Connect(function()
        phyRadius = phyRadius + 500
        if phyRadius > 5000 then phyRadius = 500 end
        phyRadiusBtn.Text = "Radius: " .. phyRadius
    end)
    local phyActive = false
    local phyConn = nil
    local managedParts = {}
    local phyTime = 0
    local phyToggleBtn = MakeBtn(pagePhysic, "START PHYSIC", UDim2.new(0, 0, 0, 87), UDim2.new(1, 0, 0, 36), Color3.fromRGB(20, 80, 40))
    local function IsValidPart(part)
        if not part:IsA("BasePart") or part.Anchored then return false end
        if Player.Character and part:IsDescendantOf(Player.Character) then return false end
        if part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then return false end
        if part.Name == "Baseplate" or part.Name == "Terrain" then return false end
        return true
    end
    local function SetupAlignOnly(part)
        if managedParts[part] then return end
        pcall(function()
            local head = Player.Character and Player.Character:FindFirstChild("Head")
            if not head then return end
            local hrpAtt = head:FindFirstChild("An9xTargetAtt")
            if not hrpAtt then
                hrpAtt = Instance.new("Attachment")
                hrpAtt.Name = "An9xTargetAtt"
                hrpAtt.Parent = head
                hrpAtt.Position = Vector3.new(0, 3, 0)
            end
            local partAtt = Instance.new("Attachment")
            partAtt.Name = "An9xPartAtt"
            partAtt.Parent = part
            local align = Instance.new("AlignPosition")
            align.Name = "An9xAlign"
            align.Attachment0 = partAtt
            align.Attachment1 = hrpAtt
            align.MaxForce = 9e18
            align.Responsiveness = 200
            align.RigidityEnabled = true
            align.ApplyAtCenterOfMass = true
            align.Parent = part
            part.CanCollide = false
            part.Velocity = Vector3.new(0, 5, 0)
            managedParts[part] = {
                Attachment = partAtt,
                AlignPosition = align,
                Seed = math.random() * math.pi * 2,
                HeightOffset = math.random(-8, 8),
                RadiusJitter = 0.7 + math.random() * 0.6,
            }
        end)
    end
    local function CleanupPart(part)
        local c = managedParts[part]
        if c then
            pcall(function()
                if c.Attachment then c.Attachment:Destroy() end
                if c.AlignPosition then c.AlignPosition:Destroy() end
            end)
            managedParts[part] = nil
        end
    end
    local function GetTargetPos(mode, hrpPos, data, i, n, t)
        local seed = data.Seed
        local h = data.HeightOffset
        if mode == "STACK" then
            return hrpPos + Vector3.new(0, 10, 0)
        elseif mode == "ORBIT" then
            local a = t * 1.5 + seed + (n > 0 and (i / n) * math.pi * 2 or 0)
            local r = 30 * data.RadiusJitter
            return hrpPos + Vector3.new(math.cos(a) * r, 10 + h, math.sin(a) * r)
        elseif mode == "BLACKHOLE" then
            local a = t * 3 + seed
            local r = 6 * (0.3 + 0.7 * math.abs(math.sin(t * 0.5 + seed)))
            return hrpPos + Vector3.new(math.cos(a) * r, 10 + h * 0.5, math.sin(a) * r)
        elseif mode == "TORNADO" then
            local spin = t * 2.25
            local a = spin + seed
            local wave = (math.sin(t * 0.8 + seed) + 1) / 2
            local r = 25 * (1 - wave * 0.5) * data.RadiusJitter
            return hrpPos + Vector3.new(math.cos(a) * r, wave * 60, math.sin(a) * r)
        elseif mode == "VORTEX" then
            local cycle = (math.sin(t * 1.2 + seed) + 1) / 2
            local r = 5 + cycle * 60 * data.RadiusJitter
            local a = t * 3 + seed
            return hrpPos + Vector3.new(math.cos(a) * r, 10 + (cycle - 0.5) * 30, math.sin(a) * r)
        elseif mode == "WAVE" then
            local a = t * 0.75 + seed
            local r = 40 * data.RadiusJitter
            local hh = 10 + math.sin(t * 2 + seed) * 20
            return hrpPos + Vector3.new(math.cos(a) * r, hh, math.sin(a) * r)
        elseif mode == "CAGE" then
            local phi = math.acos(1 - 2 * (i + 0.5) / math.max(n, 1))
            local theta = math.pi * (1 + 5 ^ 0.5) * i
            local r = 15 * data.RadiusJitter
            return hrpPos + Vector3.new(
                math.cos(theta) * math.sin(phi) * r,
                math.cos(phi) * r + 10,
                math.sin(theta) * math.sin(phi) * r
            )
        elseif mode == "SPIRAL" then
            local phase = (i / math.max(n, 1)) + t * 0.3
            local a = phase * math.pi * 2 * 3 + seed
            local hh = (phase % 1) * 80
            local r = 30 * data.RadiusJitter * (0.6 + 0.4 * math.sin(phase * math.pi))
            return hrpPos + Vector3.new(math.cos(a) * r, hh, math.sin(a) * r)
        elseif mode == "SATURN" then
            local a = t * 1.5 + seed + (n > 0 and (i / n) * math.pi * 2 or 0)
            local r = 45 * data.RadiusJitter
            local tilt = math.rad(25)
            local x = math.cos(a) * r
            local z = math.sin(a) * r
            local y = h * 0.3
            local y2 = y * math.cos(tilt) - z * math.sin(tilt)
            local z2 = y * math.sin(tilt) + z * math.cos(tilt)
            return hrpPos + Vector3.new(x, y2 + 10, z2)
        end
        return hrpPos + Vector3.new(0, 10, 0)
    end
    local function StopPhysic()
        phyActive = false
        if phyConn then phyConn:Disconnect() phyConn = nil end
        for p, _ in pairs(managedParts) do CleanupPart(p) end
        managedParts = {}
        UpdateHackerLabel(phyStatus, "Status: Idle | Target: 0")
        phyToggleBtn.Text = "START PHYSIC"
        phyToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 40)
    end
    local function StartPhysic()
        phyActive = true
        managedParts = {}
        phyTime = 0
        phyToggleBtn.Text = "STOP PHYSIC"
        phyToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        phyConn = RunService.Heartbeat:Connect(function(dt)
            if not phyActive then return end
            ExpandSimulation()
            phyTime = phyTime + dt
            local myChar = Player.Character
            local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local head = myChar and myChar:FindFirstChild("Head")
            if not hrp or not head then StopPhysic(); return end
            local hrpPos = head.Position + Vector3.new(0, 3, 0)
            for _, part in pairs(Services.Workspace:GetDescendants()) do
                if IsValidPart(part) then
                    local dist = (part.Position - hrpPos).Magnitude
                    if dist < phyRadius then SetupAlignOnly(part) end
                end
            end
            local totalParts = 0
            for _ in pairs(managedParts) do totalParts = totalParts + 1 end            local activeCount = 0
            local idx = 0
            for part, data in pairs(managedParts) do
                if part.Parent and IsValidPart(part) then
                    idx = idx + 1
                    activeCount = activeCount + 1
                    local targetPos = GetTargetPos(phyMode, hrpPos, data, idx, totalParts, phyTime)
                    if phyMode == "STACK" then
                        data.Attachment.WorldPosition = targetPos
                        part.Velocity = Vector3.new(0, 0.5, 0)
                    else
                        data.Attachment.WorldPosition = targetPos
                        part.Velocity = Vector3.zero
                        part.RotVelocity = Vector3.new(math.random() * 5, math.random() * 5, math.random() * 5)
                    end
                else
                    CleanupPart(part)
                end
            end
            UpdateHackerLabel(phyStatus, "Status: Active | Target: " .. activeCount)
        end)
    end
    phyToggleBtn.MouseButton1Click:Connect(function()
        if phyActive then StopPhysic() else StartPhysic() end
    end)
    State.PhysicStop = StopPhysic

        -- =============================================
    -- TAB HIJACK (FIX: Ignore non-cart seats)
    -- =============================================
    local pageHijack = MakeScrollPage(content, "HIJACK", false)
    pages["HIJACK"] = pageHijack

    local hjTitle = MakeLabel(pageHijack, "🧲 WHEELBARROW AUTO-PILOT", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 20), Color3.fromRGB(0, 255, 100))
    hjTitle.TextSize = 14

    local hjStatus = MakeLabel(pageHijack, "Status: Idle", UDim2.new(0, 0, 0, 22), UDim2.new(1, 0, 0, 18), Color3.fromRGB(150, 150, 150))
    local massInfo = MakeLabel(pageHijack, "My Mass: 0 | Target Mass: 0", UDim2.new(0, 0, 0, 45), UDim2.new(1, 0, 0, 18), Color3.fromRGB(200, 200, 200))

    local hjAutoSit = true
    local hjAutoSitBtn = MakeBtn(pageHijack, "AUTO SIT: ON", UDim2.new(0, 0, 0, 75), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(20, 80, 40))
    hjAutoSitBtn.MouseButton1Click:Connect(function()
        hjAutoSit = not hjAutoSit
        hjAutoSitBtn.Text = "AUTO SIT: " .. (hjAutoSit and "ON" or "OFF")
        hjAutoSitBtn.BackgroundColor3 = hjAutoSit and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(60, 30, 30)
    end)

    local hjAutoExit = true
    local hjAutoExitBtn = MakeBtn(pageHijack, "AUTO EXIT: ON", UDim2.new(0.52, 2, 0, 75), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(20, 80, 40))
    hjAutoExitBtn.MouseButton1Click:Connect(function()
        hjAutoExit = not hjAutoExit
        hjAutoExitBtn.Text = "AUTO EXIT: " .. (hjAutoExit and "ON" or "OFF")
        hjAutoExitBtn.BackgroundColor3 = hjAutoExit and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(60, 30, 30)
    end)

    local wfActive = true
    local wfStatus = MakeLabel(pageHijack, "WalkFling: ON (Detect Unequip)", UDim2.new(0, 0, 0, 118), UDim2.new(1, 0, 0, 18), Color3.fromRGB(0, 255, 100))
    local wfToggleBtn = MakeBtn(pageHijack, "WALKFLING: ON", UDim2.new(0, 0, 0, 140), UDim2.new(1, 0, 0, 36), Color3.fromRGB(20, 80, 40))
    wfToggleBtn.MouseButton1Click:Connect(function()
        wfActive = not wfActive
        wfToggleBtn.Text = "WALKFLING: " .. (wfActive and "ON" or "OFF")
        wfToggleBtn.BackgroundColor3 = wfActive and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(60, 30, 30)
        if wfActive then
            UpdateHackerLabel(wfStatus, "WalkFling: ON (Detect Unequip)")
        else
            UpdateHackerLabel(wfStatus, "WalkFling: OFF")
        end
    end)

    local hjConn = nil
    local hijackedSeat = nil
    local lastTargetOwner = nil
    local cooldownUntil = 0
    local unequipMonitor = nil

    local function GetCharacterMass(character)
        if not character then return 0 end
        local totalMass = 0
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then totalMass = totalMass + part.AssemblyMass end
        end
        return totalMass
    end

    local function FlingTarget(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        local tHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end
        pcall(function() tHRP:SetNetworkOwner(Player) end)
        for _, c in ipairs(tHRP:GetChildren()) do
            if c.Name == "WF_Vel" or c.Name == "WF_Ang" then c:Destroy() end
        end
        local bv = Instance.new("BodyVelocity", tHRP)
        bv.Name = "WF_Vel"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 9999, 0)
        local bav = Instance.new("BodyAngularVelocity", tHRP)
        bav.Name = "WF_Ang"
        bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bav.AngularVelocity = Vector3.new(math.random(-999, 999), math.random(-999, 999), math.random(-999, 999))
        task.delay(3, function()
            if bv and bv.Parent then bv:Destroy() end
            if bav and bav.Parent then bav:Destroy() end
            pcall(function() tHRP:SetNetworkOwner(nil) end)
        end)
    end

    local function ForceUnseat(myHum)
        local myChar = Player.Character
        if myChar then
            for _, obj in ipairs(myChar:GetDescendants()) do
                if obj:IsA("Weld") or obj:IsA("Motor6D") then
                    if obj.Name == "SeatWeld" or obj.Name == "Weld" or obj.Part1 == nil or (obj.Part1 and obj.Part1:IsA("Seat")) then
                        obj:Destroy()
                    end
                end
            end
        end
        if myHum then
            myHum.Sit = false
            myHum.Jump = true
        end
    end

    local function StartUnequipMonitor(targetPlayer)
        if unequipMonitor then unequipMonitor:Disconnect() unequipMonitor = nil end
        if not targetPlayer or not targetPlayer.Character then return end
        local targetChar = targetPlayer.Character

        unequipMonitor = RunService.Heartbeat:Connect(function()
            if not targetPlayer.Character or targetPlayer.Character ~= targetChar then
                if unequipMonitor then unequipMonitor:Disconnect() unequipMonitor = nil end
                return
            end
            local tool = targetChar:FindFirstChildOfClass("Tool")
            local hasCart = false
            if tool then
                local tn = tool.Name:lower()
                if tn:find("wheel") or tn:find("cart") or tn:find("barrow") then hasCart = true end
            end
            if not hasCart and wfActive then
                UpdateHackerLabel(wfStatus, "🚀 UNEQUIP! Flinging " .. targetPlayer.Name)
                FlingTarget(targetPlayer)
                if unequipMonitor then unequipMonitor:Disconnect() unequipMonitor = nil end
            end
        end)
    end

    -- Cek apakah kursi yang lagi diduduki = gerobak
    local function IsCartSeat(seat)
        if not seat then return false end
        local parentModel = seat:FindFirstAncestorOfClass("Model")
        if parentModel then
            local pn = parentModel.Name:lower()
            if pn:find("wheel") or pn:find("cart") or pn:find("barrow") then
                return true
            end
        end
        -- Cek juga parent part
        local part = seat.Parent
        if part then
            local pn2 = part.Name:lower()
            if pn2:find("wheel") or pn2:find("cart") or pn2:find("barrow") then
                return true
            end
        end
        return false
    end

    -- AUTO-PILOT LOOP
    hjConn = RunService.Heartbeat:Connect(function()
        local myChar = Player.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not myHRP or not myHum then return end

        if tick() < cooldownUntil then
            UpdateHackerLabel(hjStatus, "Cooldown: " .. math.ceil(cooldownUntil - tick()) .. "s")
            return
        end

        -- 🛡️ GUARD: Kalau duduk di kursi BUKAN gerobak (piano, ayunan, dll) → SKIP TOTAL
        if myHum.Sit then
            local currentSeat = myHum.SeatPart
            if currentSeat and not IsCartSeat(currentSeat) then
                UpdateHackerLabel(hjStatus, "Sitting on non-cart (piano?) — skipping")
                return
            end
        end

        -- Kalau lagi duduk di gerobak & auto exit ON
        if myHum.Sit then
            if hjAutoExit and hijackedSeat then
                UpdateHackerLabel(hjStatus, "Auto Exiting (1s)...")
                task.delay(1, function()
                    ForceUnseat(myHum)
                    hijackedSeat = nil
                    cooldownUntil = tick() + 3
                end)
                hijackedSeat = nil
                return
            end
            if not hijackedSeat or not hijackedSeat.Parent then
                ForceUnseat(myHum)
                hijackedSeat = nil
            else
                local cartModel = hijackedSeat:FindFirstAncestorOfClass("Model")
                local ownerName = cartModel and cartModel.Parent and cartModel.Parent.Name or "Player"
                UpdateHackerLabel(hjStatus, "Riding " .. ownerName)
                return
            end
        end

        if not hjAutoSit then
            UpdateHackerLabel(hjStatus, "Auto Sit: OFF")
            return
        end

        -- Scan gerobak
        local myMass = GetCharacterMass(myChar)
        local bestSeat = nil
        local bestTargetPlayer = nil
        local bestCartModel = nil
        local bestDist = 99999
        local targetOwnerMass = 0

        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= Player and p.Character then
                local cart = p.Character:FindFirstChild("WheelBarrow") or p.Character:FindFirstChild("Wheelbarrow")
                if cart and cart:IsA("Model") then
                    local seat = cart:FindFirstChildWhichIsA("Seat") or cart:FindFirstChildWhichIsA("VehicleSeat")
                    if seat and seat.Occupant == nil then
                        local dist = (seat.Position - myHRP.Position).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestSeat = seat
                            bestTargetPlayer = p
                            bestCartModel = cart
                            targetOwnerMass = GetCharacterMass(p.Character)
                        end
                    end
                end
            end
        end

        UpdateHackerLabel(massInfo, "My Mass: " .. math.floor(myMass) .. " | Target: " .. math.floor(targetOwnerMass))

        if bestSeat and bestTargetPlayer then
            lastTargetOwner = bestTargetPlayer
            if wfActive then StartUnequipMonitor(bestTargetPlayer) end
            pcall(function()
                bestSeat:SetNetworkOwner(Player)
                if bestCartModel then bestCartModel:SetNetworkOwner(Player) end
            end)

            if myMass > targetOwnerMass then
                UpdateHackerLabel(hjStatus, "You're heavier! Pulling cart...")
                local frontPos = myHRP.CFrame * CFrame.new(0, 0, -3)
                local desiredSeatCF = CFrame.new(frontPos.Position) * myHRP.CFrame.Rotation
                pcall(function()
                    if bestCartModel then
                        bestCartModel:PivotTo(desiredSeatCF)
                    else
                        bestSeat.CFrame = desiredSeatCF
                    end
                end)
                task.wait(0.15)
                pcall(function() bestSeat:Sit(myHum) end)
                hijackedSeat = bestSeat
            else
                UpdateHackerLabel(hjStatus, bestTargetPlayer.Name .. " heavier! Pulling you...")
                myHRP.CFrame = bestSeat.CFrame * CFrame.new(0, 3, 3)
                task.wait(0.15)
                pcall(function() bestSeat:Sit(myHum) end)
                hijackedSeat = bestSeat
            end
        else
            UpdateHackerLabel(hjStatus, "Scanning... (No Wheelbarrow)")
        end
    end)

    State.HijackStop = function()
        if hjConn then hjConn:Disconnect() hjConn = nil end
        if unequipMonitor then unequipMonitor:Disconnect() unequipMonitor = nil end
        local myHum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if myHum then myHum.Sit = false end
    end

    -- TAB SHIELD
    local pageShield = MakeScrollPage(content, "SHIELD", false)
    pages["SHIELD"] = pageShield
    local shTitle = MakeLabel(pageShield, "🛡️ ANTI-SPAM PIANO", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 20), Color3.fromRGB(0, 255, 100))
    shTitle.TextSize = 14
    local shStatus = MakeLabel(pageShield, "Status: Idle | Blocked: 0", UDim2.new(0, 0, 0, 22), UDim2.new(1, 0, 0, 18), Color3.fromRGB(150, 150, 150))
    local shThreshold = 300
    MakeSlider(pageShield, "Threshold (/sec)", UDim2.new(0, 0, 0, 45), 100, 5000, 300, function(v) shThreshold = v end)
    local shMuteAudio = true
    local shMuteBtn = MakeBtn(pageShield, "MUTE AUDIO: ON", UDim2.new(0, 0, 0, 85), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(20, 80, 40))
    shMuteBtn.MouseButton1Click:Connect(function()
        shMuteAudio = not shMuteAudio
        shMuteBtn.Text = "MUTE AUDIO: " .. (shMuteAudio and "ON" or "OFF")
        shMuteBtn.BackgroundColor3 = shMuteAudio and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(60, 30, 30)
    end)
    local shClearFX = true
    local shClearBtn = MakeBtn(pageShield, "CLEAR FX: ON", UDim2.new(0.52, 2, 0, 85), UDim2.new(0.48, -2, 0, 32), Color3.fromRGB(20, 80, 40))
    shClearBtn.MouseButton1Click:Connect(function()
        shClearFX = not shClearFX
        shClearBtn.Text = "CLEAR FX: " .. (shClearFX and "ON" or "OFF")
        shClearBtn.BackgroundColor3 = shClearFX and Color3.fromRGB(20, 80, 40) or Color3.fromRGB(60, 30, 30)
    end)
    local shPanicBtn = MakeBtn(pageShield, "🚨 PANIC REJOIN", UDim2.new(0, 0, 0, 122), UDim2.new(1, 0, 0, 36), Color3.fromRGB(150, 30, 30))
    shPanicBtn.MouseButton1Click:Connect(function()
        UpdateHackerLabel(shStatus, "Status: PANIC REJOIN!")
        task.wait(0.5)
        pcall(function() Services.TeleportService:Teleport(game.PlaceId, Player) end)
    end)
    local shTracker = Instance.new("TextLabel", pageShield)
    shTracker.Size = UDim2.new(1, 0, 0, 18)
    shTracker.Position = UDim2.new(0, 0, 0, 168)
    shTracker.BackgroundTransparency = 1
    shTracker.RichText = true
    shTracker.Text = "SPAM TRACKER:"
    shTracker.TextColor3 = Color3.fromRGB(0, 255, 100)
    shTracker.Font = Enum.Font.Code
    shTracker.TextSize = 10
    shTracker.TextXAlignment = Enum.TextXAlignment.Left
    shTracker.ZIndex = 7
    local shLog = Instance.new("ScrollingFrame", pageShield)
    shLog.Size = UDim2.new(1, 0, 0, 100)
    shLog.Position = UDim2.new(0, 0, 0, 190)
    shLog.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    shLog.BorderSizePixel = 0
    shLog.ScrollBarThickness = 2
    shLog.ZIndex = 6
    Instance.new("UICorner", shLog).CornerRadius = UDim.new(0, 4)
    local shLogLayout = Instance.new("UIListLayout", shLog)
    shLogLayout.Padding = UDim.new(0, 2)
    shLogLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local shActive = false
    local shConn = nil
    local shBlockedCount = 0
    local shRemoteData = {}
    local shBlockedRemotes = {}
    local shConnections = {}
    local function IsMyRemote(remote)
        local rn = remote.Name:lower()
        local myName = Player.Name:lower()
        if rn:find(myName) then return true end
        return false
    end
    local function BlockRemote(remote, rate)
        if shBlockedRemotes[remote] then return end
        shBlockedRemotes[remote] = true
        shBlockedCount = shBlockedCount + 1
        local logLbl = Instance.new("TextLabel", shLog)
        logLbl.Size = UDim2.new(1, -4, 0, 20)
        logLbl.Position = UDim2.new(0, 2, 0, (shBlockedCount - 1) * 22)
        logLbl.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
        logLbl.BorderSizePixel = 0
        logLbl.RichText = true
        logLbl.Text = "  🚫 " .. remote.Name .. " | " .. math.floor(rate) .. "/s"
        logLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
        logLbl.Font = Enum.Font.Code
        logLbl.TextSize = 10
        logLbl.TextXAlignment = Enum.TextXAlignment.Left
        logLbl.ZIndex = 7
        Instance.new("UICorner", logLbl).CornerRadius = UDim.new(0, 4)
        if shMuteAudio then
            task.spawn(function()
                for _, obj in ipairs(Services.Workspace:GetDescendants()) do
                    if obj:IsA("Sound") and obj.IsPlaying then
                        pcall(function() obj.Volume = 0 end)
                    end
                end
            end)
        end
        if shClearFX then
            task.spawn(function()
                for _, obj in ipairs(Services.Workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") then
                        pcall(function() obj.Enabled = false end)
                    end
                end
            end)
        end
        UpdateHackerLabel(shStatus, "Status: Active | Blocked: " .. shBlockedCount)
    end
    local function StopShield()
        shActive = false
        if shConn then shConn:Disconnect() shConn = nil end
        for _, conn in ipairs(shConnections) do pcall(function() conn:Disconnect() end) end
        shConnections = {}
        UpdateHackerLabel(shStatus, "Status: Idle | Blocked: " .. shBlockedCount)
    end
    local function StartShield()
        shActive = true
        shBlockedCount = 0
        shRemoteData = {}
        shBlockedRemotes = {}
        shConnections = {}
        for _, c in ipairs(shLog:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        UpdateHackerLabel(shStatus, "Status: Active | Blocked: 0")
        local pianoRemotes = {}
        for _, obj in ipairs(Services.ReplicatedStorage:GetDescendants()) do
            if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                local n = obj.Name:lower()
                if n:find("piano") or n:find("note") or n:find("play") or n:find("music") or n:find("sound") or n:find("key") then
                    table.insert(pianoRemotes, obj)
                end
            end
        end
        if #pianoRemotes == 0 then
            UpdateHackerLabel(shStatus, "Status: No piano remote found")
            shActive = false
            return
        end
        for _, remote in ipairs(pianoRemotes) do
            if not IsMyRemote(remote) then
                shRemoteData[remote] = { count = 0, lastReset = tick() }
                local remoteRef = remote
                local conn = remote.OnClientEvent:Connect(function()
                    if not shActive then return end
                    if shBlockedRemotes[remoteRef] then return end
                    local data = shRemoteData[remoteRef]
                    if not data then return end
                    data.count = data.count + 1
                    local elapsed = tick() - data.lastReset
                    if elapsed >= 1 then
                        local rate = data.count / elapsed
                        if rate > shThreshold then
                            BlockRemote(remoteRef, rate)
                        end
                        data.count = 0
                        data.lastReset = tick()
                    end
                end)
                table.insert(shConnections, conn)
            end
        end
        shConn = RunService.Heartbeat:Connect(function()
            if not shActive then return end
            for remote, data in pairs(shRemoteData) do
                if type(data) == "table" then
                    local elapsed = tick() - data.lastReset
                    if elapsed >= 1 then
                        data.count = 0
                        data.lastReset = tick()
                    end
                end
            end
        end)
    end
    local shToggleBtn = MakeBtn(pageShield, "START SHIELD", UDim2.new(0, 0, 0, 302), UDim2.new(1, 0, 0, 36), Color3.fromRGB(20, 80, 40))
    shToggleBtn.MouseButton1Click:Connect(function()
        if shActive then
            StopShield()
            shToggleBtn.Text = "START SHIELD"
            shToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 40)
        else
            StartShield()
            shToggleBtn.Text = "STOP SHIELD"
            shToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        end
    end)
    State.ShieldStop = StopShield

    -- TAB ABOUT
    local pageAbout = MakeScrollPage(content, "ABOUT", false)
    pages["ABOUT"] = pageAbout
    local aboutTitle = MakeLabel(pageAbout, "HAMA UNIVERSAL HUB", UDim2.new(0, 0, 0, 10), UDim2.new(1, 0, 0, 30), Color3.fromRGB(0, 255, 100))
    aboutTitle.TextSize = 18
    aboutTitle.TextXAlignment = Enum.TextXAlignment.Center
    local aboutVersion = MakeLabel(pageAbout, "Version 2.5 | Server Killer", UDim2.new(0, 0, 0, 40), UDim2.new(1, 0, 0, 20), Color3.fromRGB(150, 150, 150))
    aboutVersion.TextXAlignment = Enum.TextXAlignment.Center
    local devLabel = MakeLabel(pageAbout, "— DEVELOPED BY —", UDim2.new(0, 0, 0, 80), UDim2.new(1, 0, 0, 20), Color3.fromRGB(200, 200, 200))
    devLabel.TextXAlignment = Enum.TextXAlignment.Center
    local devNames = MakeLabel(pageAbout, "@dpnvhr\n@fire6uns", UDim2.new(0, 0, 0, 105), UDim2.new(1, 0, 0, 50), Color3.fromRGB(0, 255, 100))
    devNames.TextSize = 14
    devNames.TextXAlignment = Enum.TextXAlignment.Center
    devNames.TextYAlignment = Enum.TextYAlignment.Top
    local thanksLabel = MakeLabel(pageAbout, "Server Killer Edition - Hook Amp x20 + 4-Phase + SimHack", UDim2.new(0, 0, 0, 180), UDim2.new(1, 0, 0, 40), Color3.fromRGB(180, 180, 180))
    thanksLabel.TextXAlignment = Enum.TextXAlignment.Center
    thanksLabel.TextWrapped = true
    local copyrightLabel = MakeLabel(pageAbout, "© 2026 HAMA Universal Hub.", UDim2.new(0, 0, 0, 240), UDim2.new(1, 0, 0, 20), Color3.fromRGB(100, 100, 100))
    copyrightLabel.TextXAlignment = Enum.TextXAlignment.Center

    -- PIANO BINDINGS
    scanBtn.MouseButton1Click:Connect(function()
        pcall(function()
            State.FoundPianos = ScanPianos()
            for _, c in ipairs(pianoList:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for i, p in ipairs(State.FoundPianos) do
                local b = Instance.new("TextButton", pianoList)
                b.Size = UDim2.new(1, -4, 0, 26)
                b.Position = UDim2.new(0, 2, 0, (i - 1) * 28)
                b.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                b.Text = "  " .. p.label
                b.TextColor3 = Color3.fromRGB(220, 220, 220)
                b.Font = Enum.Font.Code
                b.TextSize = 9
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.ZIndex = 8
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                b.MouseButton1Click:Connect(function()
                    State.SelectedPiano = p
                    for _, c in ipairs(pianoList:GetChildren()) do
                        if c:IsA("TextButton") then c.BackgroundColor3 = Color3.fromRGB(20, 20, 25) end
                    end
                    b.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
                end)
            end
            pianoList.CanvasSize = UDim2.new(0, 0, 0, #State.FoundPianos * 28 + 4)
        end)
    end)
    tpBtn.MouseButton1Click:Connect(function()
        if not State.SelectedPiano then return end
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(State.SelectedPiano.pos + Vector3.new(0, 5, 0)) end
    end)

    -- SPAM ENGINE (SERVER KILLER V2.5)
    local Spam = {
        Running = false, Gen = 0, FireCount = 0, Connections = {},
        BurstSize = 1, Remotes = {}, KeyPool = {}, Format = "positional",
    }
    local function BuildKeyPool()
        local pool = {}
        local mult = math.max(1, math.floor(State.KeyMult))
        for i = 1, 61 do
            for _ = 1, mult do table.insert(pool, i) end
        end
        return pool
    end
    local function FireOne(remote, fmt, key)
        if fmt == "positional" then
            return pcall(remote.FireServer, remote, "play", key)
        elseif fmt == "table" then
            return pcall(remote.FireServer, remote, { play = true, action = "play", key = key, note = key, index = key, value = key })
        end
        return false
    end
    local function FireBurst(remotes, pool, calls, burstSize, gen, fmt)
        local poolLen = #pool
        if poolLen == 0 or #remotes == 0 then return end
        local idx = 1
        for _ = 1, calls do
            if not Spam.Running or Spam.Gen ~= gen then return end
            for _ = 1, burstSize do
                local key = pool[idx]; idx += 1
                if idx > poolLen then idx = 1 end
                for _, remote in ipairs(remotes) do
                    if FireOne(remote, fmt, key) then Spam.FireCount += 1 end
                end
            end
        end
    end
    local function StopSpam()
        Spam.Running = false
        Spam.Gen = Spam.Gen + 1
        for _, conn in ipairs(Spam.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        Spam.Connections = {}
        _HM_Uninstall()
        RestoreSimulation()
        if counterLbl then UpdateHackerLabel(counterLbl, "Fires: " .. Spam.FireCount) end
        print("[HAMA] Spam STOPPED, Hook uninstalled")
    end
    local function StartSpam()
        if not State.IsWhitelisted and Player.Name ~= State.OwnerName then
            warn("[HAMA Hub] Unauthorized.")
            startBtn.Text = "UNAUTHORIZED"
            task.wait(1.5)
            pcall(function() Services.TeleportService:Teleport(game.PlaceId, Player) end)
            return
        end
        local allRemotes = FindAllPianoRemotes()
        if #allRemotes == 0 then
            warn("[HAMA] Remote piano tidak ditemukan!")
            return
        end
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if not hum.Sit then
            warn("[HAMA] Duduk dulu di piano!")
            return
        end
        StopSpam()
        -- INSTALL SERVER KILLER
        _HM_SetActiveRemotes(allRemotes)
        _HM_Install()
        ExpandSimulation()
        Spam.Running = true
        Spam.FireCount = 0
        Spam.Gen = Spam.Gen + 1
        local myGen = Spam.Gen
        Spam.Remotes = allRemotes
        Spam.KeyPool = BuildKeyPool()
        Spam.Format = State.RemoteFormat
        -- 4-PHASE DRIVER
        local phases = {
            RunService.Heartbeat,
            RunService.Stepped,
            RunService.PreSimulation,
            RunService.PostSimulation
        }
        local function firePhase()
            if not Spam.Running or Spam.Gen ~= myGen then return end
            FireBurst(Spam.Remotes, Spam.KeyPool, 500, 1, myGen, Spam.Format)
        end
        for _, sig in ipairs(phases) do
            local ok, conn = pcall(function() return sig:Connect(firePhase) end)
            if ok and conn then table.insert(Spam.Connections, conn) end
        end
        print("[HAMA] 🔥 SERVER KILLER ACTIVE — Hook x" .. State.HookAmplifier .. " | 4-Phase | SimHack")
        task.spawn(function()
            while Spam.Running and Spam.Gen == myGen do
                UpdateHackerLabel(counterLbl, "Fires: " .. Spam.FireCount)
                task.wait(0.15)
            end
            UpdateHackerLabel(counterLbl, "Fires: " .. Spam.FireCount)
        end)
    end
    startBtn.MouseButton1Click:Connect(StartSpam)
    stopBtn.MouseButton1Click:Connect(StopSpam)

    gui.Destroying:Connect(function()
        StopSpam()
        StopTroll()
        if State.SpectateStop then State.SpectateStop() end
        if State.PhysicStop then State.PhysicStop() end
        if State.HijackStop then State.HijackStop() end
        if State.WalkFlingStop then State.WalkFlingStop() end
        if State.ShieldStop then State.ShieldStop() end
        _HM_Uninstall()
        RestoreSimulation()
        if viewportConn then viewportConn:Disconnect() end
        _G.HamaGUI = nil
    end)

    switchTab("PIANO")
end

local ok, err = pcall(CreateUI)
if not ok then
    warn("[HAMA] CreateUI ERROR:", err)
end

print("[HAMA] Universal V2.5 loaded — SERVER KILLER EDITION")
