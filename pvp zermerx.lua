






local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Stats             = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService        = game:GetService("GuiService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local VirtualInput = Instance.new("VirtualInputManager")

if _G.Formega_Script_Purge then
    pcall(function() _G.Formega_Script_Purge() end)
    task.wait(0.2)
end

local ActiveConnections = {}
local thisScriptStopped = false

local MultiZones = {
	{Shape = 'Line', Center = Vector3.new(-345.35, -6.55, 39.19), Size = 5, Rotation = 0},
	{Shape = 'Line', Center = Vector3.new(-350.53, -6.55, 38.67), Size = 20, Rotation = 0},
	{Shape = 'Line', Center = Vector3.new(-364.01, -6.55, 38.94), Size = 20, Rotation = 0},
	{Shape = 'Line', Center = Vector3.new(-337.34, -6.55, 39.18), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-365.29, -6.95, -10.40), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-337.5, -7.3, 38.8), Size = 20, Rotation = 0}, -- ROT: -11.54, -67.80, 0.00
	{Shape = 'Square', Center = Vector3.new(-343.15, -6.53, -13.20), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-344.93, -6.95, 25.73), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-343.76, -6.95, -10.27), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-354.42, -6.95, 6.51), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-340.48, -5.32, 28.10), Size = 20, Rotation = 0},
	{Shape = 'Square', Center = Vector3.new(-361.10, -6.95, 29.42), Size = 20, Rotation = 0},
	{Shape = 'Line', Center = Vector3.new(-354.83, 27.19, 31.22), Size = 20, Rotation = 0},
}

-- ==========================================
-- AUTO BALLOON LOGIC
-- ==========================================
local balloonActive = {}
local balloonedThisSession = {}
local autoBallon = false

local function hasBrainrot(targetPlayer)
	if not targetPlayer.Character then return false end
	local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local playerNames = {}
	for _, p in pairs(Players:GetPlayers()) do
		playerNames[p.Name] = true
	end
	for _, v in pairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and not playerNames[v.Name] and not v:IsDescendantOf(targetPlayer.Character) then
			local rp = v:FindFirstChild("RootPart") or v:FindFirstChild("FakeRootPart")
			if rp then
				if (rp.Position - root.Position).Magnitude < 8 then
					return true
				end
			end
		end
	end
	return false
end

local function isInAnyZone(position)
	for _, zone in ipairs(MultiZones) do
		local half = zone.Size / 2
		local dx = math.abs(position.X - zone.Center.X)
		local dz = math.abs(position.Z - zone.Center.Z)
		if zone.Shape == 'Line' then
			if dx <= half and dz <= 1.5 then return true end
		elseif zone.Shape == 'Square' then
			if dx <= half and dz <= half then return true end
		end
	end
	return false
end

local function findAdminPanel()
	return PlayerGui:FindFirstChild("AdminPanel")
end

local function findPlayerButton(targetPlayer)
	local adminPanel = findAdminPanel()
	if not adminPanel then return nil end
	for _, desc in pairs(adminPanel:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			local t = ""
			if desc:IsA("TextButton") then
				t = desc.Text
			else
				local lbl = desc:FindFirstChildWhichIsA("TextLabel", true)
				if lbl then t = lbl.Text end
			end
			if t == targetPlayer.DisplayName or string.find(t, targetPlayer.DisplayName) or t == targetPlayer.Name or string.find(t, targetPlayer.Name) then
				return desc
			end
		end
	end
	return nil
end

local function getCommandButtons()
	local btns = {}
	local adminPanel = findAdminPanel()
	if not adminPanel then return btns end
	for _, desc in pairs(adminPanel:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			local t = ""
			if desc:IsA("TextButton") then
				t = desc.Text
			else
				local lbl = desc:FindFirstChildWhichIsA("TextLabel", true)
				if lbl then t = lbl.Text end
			end
			if t and t ~= "" and (t:match("^:") or t:match("^;")) then
				table.insert(btns, {button = desc, name = t})
			end
		end
	end
	return btns
end

local function clickButton(button)
	pcall(function() button.MouseButton1Click:Fire() end)
	pcall(function() button.Activated:Fire() end)
	pcall(function()
		if getconnections then
			for _, cx in pairs(getconnections(button.MouseButton1Click)) do cx:Fire() end
			for _, cx in pairs(getconnections(button.Activated)) do cx:Fire() end
		end
	end)
end

local function isExactCommand(buttonName, expectedCmdName)
	local bName = string.lower(string.match(buttonName, "^%s*(.-)%s*$") or buttonName)
	local cmdName = string.lower(expectedCmdName)
	if bName == cmdName or bName == ":"..cmdName or bName == ";"..cmdName then return true end
	if string.match(bName, "^[:;]?"..cmdName.."$") or string.match(bName, "^[:;]?"..cmdName.."%s") then return true end
	return false
end

local function triggerBalloonOnTarget(targetPlayer)
	if not targetPlayer or not targetPlayer.Parent then return end
	if not findAdminPanel() then return end
	for _, cBtn in ipairs(getCommandButtons()) do
		if isExactCommand(cBtn.name, "balloon") then
			clickButton(cBtn.button)
			task.wait(0.02)
			local pBtn = findPlayerButton(targetPlayer)
			if pBtn then clickButton(pBtn) end
			break
		end
	end
end

local AntiRagdollConns = {}
local lastRagdollClean = 0
local antiRagdollEnabled = false

local AdminRemote = nil
local RAGDOLL_UUID = "f888ee6e-c86d-46e1-93d7-0639d6635d42"

local function findAdminRemote()
	task.spawn(function()
		if AdminRemote then return end
		local repsto = game:GetService("ReplicatedStorage")
		local net = repsto:WaitForChild("Packages"):WaitForChild("Net")
		local children = net:GetChildren()
		local byIdx = {}
		local byName = {}
		
		for i, obj in ipairs(children) do
			byIdx[i] = obj
			byName[obj.Name] = i
		end
		
		local anchorIdx = byName["RF/a0e78691-cb9b-4efc-ac08-9c06fea70059"]
		if anchorIdx then
			local actual = byIdx[anchorIdx + 1]
			if actual then
				AdminRemote = actual
			end
		end
	end)
end

local function ragdollPlayerWithRemote()
	if not AdminRemote then return false end
	pcall(function()
		AdminRemote:InvokeServer(RAGDOLL_UUID, LocalPlayer, "ragdoll")
	end)
	return true
end

findAdminRemote()

local AutoResetTinyEnabled = false
local _artConns        = {}
local _artBoundRemotes = {}
local _artAddConn      = nil
local _artLastFire     = 0

local function _arbStringMatchesTiny(s)
	if type(s) ~= "string" then return false end
	local ls = s:lower()
	return ls:find("tiny for 30", 1, true) ~= nil
end

local function _artHandleArgs(...)
	if not AutoResetTinyEnabled then return end
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if _arbStringMatchesTiny(arg) then
			local now = tick()
			if now - _artLastFire < 3 then return end
			_artLastFire = now
			local Net = ReplicatedStorage:WaitForChild("Packages", 2)
				and ReplicatedStorage.Packages:WaitForChild("Net", 2)
			if not Net then
				local char = LocalPlayer and LocalPlayer.Character
				local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
				if hum then hum.Health = 0 end
				return
			end
			local remote = nil
			local childs = Net:GetChildren()
			for i2 = 1, #childs - 1 do
				if childs[i2] and childs[i2+1] and string.find(childs[i2].Name, "Tools/Cooldown") then
					remote = childs[i2+1]; break
				end
			end
			if not remote then
				local char = LocalPlayer and LocalPlayer.Character
				local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
				if hum then hum.Health = 0 end
				return
			end
			local savedTools = {}
			local char = LocalPlayer.Character
			local bp   = LocalPlayer:FindFirstChild("Backpack")
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:UnequipTools() end) end
				for _, t in ipairs(char:GetChildren()) do
					if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
				end
			end
			if bp then
				for _, t in ipairs(bp:GetChildren()) do
					if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
				end
			end
			LocalPlayer.Character = nil
			local sending = true
			local loopConn
			local fire = remote.FireServer
			local throttle = 0
			loopConn = RunService.Heartbeat:Connect(function(dt)
				if not sending then
					if loopConn then loopConn:Disconnect(); loopConn = nil end
					return
				end
				throttle = throttle + dt
				if throttle >= 0.016 then
					throttle = 0
					pcall(fire, remote, "f888ee6e-c86d-46e1-93d7-0639d6635d42", LocalPlayer, "balloon")
				end
				if sending and LocalPlayer.Character then LocalPlayer.Character = nil end
			end)
			local conn2
			conn2 = LocalPlayer.CharacterAdded:Connect(function()
				sending = false
				if loopConn then loopConn:Disconnect(); loopConn = nil end
				if conn2 then conn2:Disconnect() end
				task.spawn(function()
					local newBp = LocalPlayer:WaitForChild("Backpack", 3)
					if newBp then
						for _, t in ipairs(savedTools) do if t then t.Parent = newBp end end
					end
					savedTools = {}
				end)
			end)
			task.delay(4, function()
				sending = false
				if loopConn then loopConn:Disconnect(); loopConn = nil end
				local curBp = LocalPlayer:FindFirstChild("Backpack")
				if curBp and #savedTools > 0 then
					for _, t in ipairs(savedTools) do if t then t.Parent = curBp end end
					savedTools = {}
				end
			end)
			return
		end
	end
end

local function _artBindRemote(obj)
	if not obj:IsA("RemoteEvent") then return end
	if _artBoundRemotes[obj] then return end
	local ok, conn = pcall(function()
		return obj.OnClientEvent:Connect(_artHandleArgs)
	end)
	if ok and conn then
		table.insert(_artConns, conn)
		_artBoundRemotes[obj] = true
	end
end

local function startAutoResetTiny()
	for _, conn in ipairs(_artConns) do pcall(function() conn:Disconnect() end) end
	_artConns = {}
	_artBoundRemotes = {}
	if _artAddConn then pcall(function() _artAddConn:Disconnect() end); _artAddConn = nil end
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do _artBindRemote(obj) end
	_artAddConn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
		if AutoResetTinyEnabled then _artBindRemote(obj) end
	end)
end

local function stopAutoResetTiny()
	for _, conn in ipairs(_artConns) do pcall(function() conn:Disconnect() end) end
	_artConns = {}
	_artBoundRemotes = {}
	if _artAddConn then pcall(function() _artAddConn:Disconnect() end); _artAddConn = nil end
end

local AutoResetJailEnabled = false
local _arjConns        = {}
local _arjBoundRemotes = {}
local _arjAddConn      = nil
local _arjLastFire     = 0

local function _arbStringMatchesJail(s)
	if type(s) ~= "string" then return false end
	local ls = s:lower()
	return ls:find("trapped for", 1, true) ~= nil
end

local function _arjHandleArgs(...)
	if not AutoResetJailEnabled then return end
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if _arbStringMatchesJail(arg) then
			local now = tick()
			if now - _arjLastFire < 3 then return end
			_arjLastFire = now
			local Net = ReplicatedStorage:WaitForChild("Packages", 2)
				and ReplicatedStorage.Packages:WaitForChild("Net", 2)
			if not Net then
				local char = LocalPlayer and LocalPlayer.Character
				local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
				if hum then hum.Health = 0 end
				return
			end
			local remote = nil
			local childs = Net:GetChildren()
			for i2 = 1, #childs - 1 do
				if childs[i2] and childs[i2+1] and string.find(childs[i2].Name, "Tools/Cooldown") then
					remote = childs[i2+1]; break
				end
			end
			if not remote then
				local char = LocalPlayer and LocalPlayer.Character
				local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
				if hum then hum.Health = 0 end
				return
			end
			local savedTools = {}
			local char = LocalPlayer.Character
			local bp   = LocalPlayer:FindFirstChild("Backpack")
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then pcall(function() hum:UnequipTools() end) end
				for _, t in ipairs(char:GetChildren()) do
					if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
				end
			end
			if bp then
				for _, t in ipairs(bp:GetChildren()) do
					if t:IsA("Tool") then table.insert(savedTools, t); t.Parent = nil end
				end
			end
			LocalPlayer.Character = nil
			local sending = true
			local loopConn
			local fire = remote.FireServer
			local throttle = 0
			loopConn = RunService.Heartbeat:Connect(function(dt)
				if not sending then
					if loopConn then loopConn:Disconnect(); loopConn = nil end
					return
				end
				throttle = throttle + dt
				if throttle >= 0.016 then
					throttle = 0
					pcall(fire, remote, "f888ee6e-c86d-46e1-93d7-0639d6635d42", LocalPlayer, "balloon")
				end
				if sending and LocalPlayer.Character then LocalPlayer.Character = nil end
			end)
			local conn2
			conn2 = LocalPlayer.CharacterAdded:Connect(function()
				sending = false
				if loopConn then loopConn:Disconnect(); loopConn = nil end
				if conn2 then conn2:Disconnect() end
				task.spawn(function()
					local newBp = LocalPlayer:WaitForChild("Backpack", 3)
					if newBp then
						for _, t in ipairs(savedTools) do if t then t.Parent = newBp end end
					end
					savedTools = {}
				end)
			end)
			task.delay(4, function()
				sending = false
				if loopConn then loopConn:Disconnect(); loopConn = nil end
				local curBp = LocalPlayer:FindFirstChild("Backpack")
				if curBp and #savedTools > 0 then
					for _, t in ipairs(savedTools) do if t then t.Parent = curBp end end
					savedTools = {}
				end
			end)
			return
		end
	end
end

local function _arjBindRemote(obj)
	if not obj:IsA("RemoteEvent") then return end
	if _arjBoundRemotes[obj] then return end
	local ok, conn = pcall(function()
		return obj.OnClientEvent:Connect(_arjHandleArgs)
	end)
	if ok and conn then
		table.insert(_arjConns, conn)
		_arjBoundRemotes[obj] = true
	end
end

local function startAutoResetJail()
	for _, conn in ipairs(_arjConns) do pcall(function() conn:Disconnect() end) end
	_arjConns = {}
	_arjBoundRemotes = {}
	if _arjAddConn then pcall(function() _arjAddConn:Disconnect() end); _arjAddConn = nil end
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do _arjBindRemote(obj) end
	_arjAddConn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
		if AutoResetJailEnabled then _arjBindRemote(obj) end
	end)
end

local function stopAutoResetJail()
	for _, conn in ipairs(_arjConns) do pcall(function() conn:Disconnect() end) end
	_arjConns = {}
	_arjBoundRemotes = {}
	if _arjAddConn then pcall(function() _arjAddConn:Disconnect() end); _arjAddConn = nil end
end

local function forceBackpackVisible()
	if not antiRagdollEnabled then return end
	pcall(function()
		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		if not gui then return end
		local backpackGui = gui:FindFirstChild("BackpackGui")
		if not backpackGui then return end
		local backpack = backpackGui:FindFirstChild("Backpack")
		if not backpack then return end
		backpack.Visible = true
		if not backpack:FindFirstChild("ForceConnection") then
			local tag = Instance.new("BoolValue")
			tag.Name   = "ForceConnection"
			tag.Parent = backpack
			backpack:GetPropertyChangedSignal("Visible"):Connect(function()
				if not antiRagdollEnabled then return end
				if not backpack.Visible then backpack.Visible = true end
			end)
		end
	end)
end

local function removeRagdollConstraints(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BallSocketConstraint") or d:IsA("HingeConstraint")
			or d:IsA("NoCollisionConstraint")
			or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
			pcall(function() d:Destroy() end)
		end
	end
end

local function advancedCharacterReset(char)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then return end

	task.spawn(function()
		rootPart.Anchored = false
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("Motor6D") then
				obj.Enabled = true
			end
		end
		
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		
		humanoid.PlatformStand = false
		humanoid.Sit = false
		
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		
		workspace.CurrentCamera.CameraSubject = humanoid
	end)
end

local SETTINGS_FILE = "rares_script_settings.json"

local function loadSettings()
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(SETTINGS_FILE))
    end)
    if ok and type(data) == "table" then return data end
    return {}
end

local function saveSettings()
    pcall(function()
        writefile(SETTINGS_FILE, game:GetService("HttpService"):JSONEncode({
            AutoResetOnBalloon = _G.AutoResetOnBalloon,
            AutoFlashTP        = _G.AutoFlashTP,
            RagdollBypass      = _G.RagdollBypass,
            AutoGiant          = _G.AutoGiant,
            AutoBlock          = _G.AutoBlock,
            AntiRagdoll        = antiRagdollEnabled,
            AutoBalloon        = _G.AutoBalloon,
            AutoSelectBest     = _G.AutoSelectBest,
        }))
    end)
end

local savedSettings = loadSettings()

if savedSettings.AutoResetOnBalloon ~= nil then _G.AutoResetOnBalloon = savedSettings.AutoResetOnBalloon
elseif _G.AutoResetOnBalloon == nil then _G.AutoResetOnBalloon = true end

if savedSettings.AutoFlashTP ~= nil then _G.AutoFlashTP = savedSettings.AutoFlashTP
elseif _G.AutoFlashTP == nil then _G.AutoFlashTP = false end

if savedSettings.RagdollBypass ~= nil then _G.RagdollBypass = savedSettings.RagdollBypass
elseif _G.RagdollBypass == nil then _G.RagdollBypass = true end

if savedSettings.AutoGiant ~= nil then _G.AutoGiant = savedSettings.AutoGiant
elseif _G.AutoGiant == nil then _G.AutoGiant = false end

if savedSettings.AutoBlock ~= nil then _G.AutoBlock = savedSettings.AutoBlock
elseif _G.AutoBlock == nil then _G.AutoBlock = false end

if savedSettings.AntiRagdoll ~= nil then antiRagdollEnabled = savedSettings.AntiRagdoll
else antiRagdollEnabled = false end

if savedSettings.AutoBalloon ~= nil then _G.AutoBalloon = savedSettings.AutoBalloon
elseif _G.AutoBalloon == nil then _G.AutoBalloon = false end

if savedSettings.AutoSelectBest ~= nil then _G.AutoSelectBest = savedSettings.AutoSelectBest
elseif _G.AutoSelectBest == nil then _G.AutoSelectBest = false end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid  = Character:WaitForChild("Humanoid")
local Root      = Character:WaitForChild("HumanoidRootPart")
local Camera    = Workspace.CurrentCamera

local autoStealEnabled  = false
local stealDelay        = 1.30
local isStealing        = false
local currentMovement   = nil
local selectedPrompt    = nil
local selectedSlotNumber= nil

local player = LocalPlayer
local maxVelocity  = 40
local clampVelocity= 25
local maxClamp     = 15

local function connectAntiRagdollToChar(c)
    local humanoid = c:WaitForChild("Humanoid")
    local root     = c:WaitForChild("HumanoidRootPart")
    local animator = humanoid:WaitForChild("Animator")
    local lastVelocity = Vector3.new(0,0,0)
    local isRag = false

    local function IsRagdollState()
        local state = humanoid:GetState()
        return state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.GettingUp
    end

    local function CleanRagdollEffects()
        local now = tick()
        if now - lastRagdollClean < 0.15 then return end
        lastRagdollClean = now
        
        for _, obj in pairs(c:GetDescendants()) do
            if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint")
                or (obj:IsA("Attachment") and (obj.Name == "A" or obj.Name == "B")) then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("Motor6D") then
                obj.Enabled = true
            end
        end
        
        removeRagdollConstraints(c)
        
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            local animName = track.Animation and track.Animation.Name:lower() or ""
            if animName:find("rag") or animName:find("fall") or animName:find("hurt") or animName:find("down") then
                pcall(function() track:Stop(0) end)
            end
        end
    end

    local function ReEnableControls()
        pcall(function()
            require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls():Enable()
        end)
    end

    table.insert(AntiRagdollConns, humanoid.StateChanged:Connect(function(_, newState)
        if not antiRagdollEnabled then return end
        if IsRagdollState() then
            isRag = true
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
            CleanRagdollEffects()
            workspace.CurrentCamera.CameraSubject = humanoid
            ReEnableControls()
        else
            isRag = false
        end
    end))

    table.insert(AntiRagdollConns, humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if not antiRagdollEnabled then return end
        if humanoid.PlatformStand then
            task.defer(function()
                if not antiRagdollEnabled then return end
                advancedCharacterReset(c)
                removeRagdollConstraints(c)
            end)
        end
    end))

    table.insert(AntiRagdollConns, RunService.Heartbeat:Connect(function()
        if not antiRagdollEnabled then return end
        
        local endTime = player:GetAttribute("RagdollEndTime")
        if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then
            isRag = true
        end
        
        if isRag then
            CleanRagdollEffects()
            
            local maxVelocity  = 40
            local clampVelocity= 25
            local maxClamp     = 15
            local vel = root.AssemblyLinearVelocity
            if (vel - lastVelocity).Magnitude > maxVelocity and vel.Magnitude > clampVelocity then
                root.AssemblyLinearVelocity = vel.Unit * math.min(vel.Magnitude, maxClamp)
            end
            lastVelocity = vel
            
            if humanoid.PlatformStand then
                advancedCharacterReset(c)
            end
        end
    end))

    table.insert(AntiRagdollConns, c.DescendantAdded:Connect(function(obj)
        if antiRagdollEnabled then
            if isRag then CleanRagdollEffects() end
            
            if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint")
                or obj:IsA("NoCollisionConstraint")
                or (obj:IsA("Attachment") and obj.Name:find("RagdollAttachment")) then
                task.defer(function()
                    if not antiRagdollEnabled then return end
                    if obj.Parent then pcall(function() obj:Destroy() end) end
                end)
            end
        end
    end))

    ReEnableControls()
    CleanRagdollEffects()
    forceBackpackVisible()
end

local function startAntiRagdoll()
    for _, conn in pairs(AntiRagdollConns) do pcall(function() conn:Disconnect() end) end
    AntiRagdollConns = {}
    local c = player.Character or player.CharacterAdded:Wait()
    
    forceBackpackVisible()
    
    task.spawn(function()
        while antiRagdollEnabled do
            task.wait(0.5)
            forceBackpackVisible()
        end
    end)
    
    connectAntiRagdollToChar(c)
end

local function stopAntiRagdoll()
    for _, conn in pairs(AntiRagdollConns) do pcall(function() conn:Disconnect() end) end
    AntiRagdollConns = {}
    
    pcall(function()
        local c = player.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     true)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics,     true)
        end
    end)
end

local arCharConn = player.CharacterAdded:Connect(function(newChar)
    if not antiRagdollEnabled then return end
    for _, conn in pairs(AntiRagdollConns) do pcall(function() conn:Disconnect() end) end
    AntiRagdollConns = {}
    task.spawn(function()
        connectAntiRagdollToChar(newChar)
    end)
end)
table.insert(ActiveConnections, arCharConn)

if antiRagdollEnabled then task.spawn(startAntiRagdoll) end

local function FastConfirm()
    local res = GuiService:GetScreenResolution()
    local x = res.X * 0.5
    local y = res.Y * 0.58
    for i = 1, 10 do
        if thisScriptStopped then break end
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        task.wait(0.01)
    end
end

local function getNearestPlayer()
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            if d < dist then dist = d closest = plr end
        end
    end
    return closest
end

local blockDelay = 0.05

local function PromptClick()
    task.wait(blockDelay)
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = (viewportSize.Y / 2) + 30
    
    for _ = 1, 4 do
        VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
        VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
        task.wait(0.001)
    end
end

local function blockPlayer(plr)
    if not plr or plr == LocalPlayer then return end
    pcall(function()
        StarterGui:SetCore("PromptBlockPlayer", plr)
        PromptClick()
    end)
end

local function blockAllPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            blockPlayer(p)
            task.wait(1)
        end
    end
end

local function waitForStealPrompt()
    for _, v in ipairs(CoreGui:GetDescendants()) do
        if v:IsA("TextLabel") and v.Text and string.find(v.Text, "Steal") then return true end
    end
    local found = false
    local connection
    connection = CoreGui.DescendantAdded:Connect(function(v)
        if v:IsA("TextLabel") and v.Text and string.find(v.Text, "Steal") then found = true end
    end)

    table.insert(ActiveConnections, connection)
    while not found and not thisScriptStopped do task.wait(0.05) end
    if connection then pcall(function() connection:Disconnect() end) end
    return true
end

local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    if currentMovement then pcall(function() currentMovement:Disconnect() end) currentMovement = nil end
    Character = newChar
    Humanoid  = newChar:WaitForChild("Humanoid")
    Root      = newChar:WaitForChild("HumanoidRootPart")
    Camera    = Workspace.CurrentCamera
    autoStealEnabled = false isStealing = false
    task.wait()
    if Root then
        local oldVelocity = Root:FindFirstChild("LinearVelocity")
        if oldVelocity then oldVelocity:Destroy() end
        local oldAttachment = Root:FindFirstChild("Attachment")
        if oldAttachment then oldAttachment:Destroy() end
    end
    
    if _G.AutoFlashTP and _G.AutoResetOnBalloon and selectedPrompt and selectedSlotNumber then
        task.delay(0.5, function()
            if not thisScriptStopped and selectedPrompt and selectedSlotNumber then
                startTripToPetSlot(selectedPrompt, selectedSlotNumber)
            end
        end)
    end
end)
table.insert(ActiveConnections, charAddedConn)

local SlotsConfig = {
    [1]  = { Positions = { Vector3.new(-345.4766,-6.0291,1.5014) }, CamOffset = Vector3.new(-354.1492,4.0350,9.3823)-Vector3.new(-345.4766,-6.0291,1.5014), CamAngles = {-0.827500,-0.640100,-0.576243} },
    [2]  = { Positions = { Vector3.new(-349.9259,-6.2791,-1.5767) }, CamOffset = Vector3.new(-363.2081,2.9403,3.3074)-Vector3.new(-349.9259,-6.2791,-1.5767), CamAngles = {-1.007271,-0.967909,-0.916433} },
    [3]  = { Positions = { Vector3.new(-349.9259,-6.2791,-1.5758) }, CamOffset = Vector3.new(-367.7556,4.3232,3.4983)-Vector3.new(-349.9259,-6.2791,-1.5758), CamAngles = {-1.062718,-1.041500,-0.997864} },
    [4]  = { Positions = { Vector3.new(-343.4199,-5.9197,10.5505) }, CamOffset = Vector3.new(-359.0885,4.0544,21.0001)-Vector3.new(-343.4199,-5.9197,10.5505), CamAngles = {-0.681953,-0.861073,-0.551998} },
    [5]  = { Positions = { Vector3.new(-343.7608,-6.3272,-9.7994) }, CamOffset = Vector3.new(-363.9226,-0.3924,-9.1459)-Vector3.new(-343.7608,-6.3272,-9.7994), CamAngles = {-1.424811,-1.351549,-1.421283} },
    [6] = { Positions = { Vector3.new(-353.820709,-7.3017997,56.7122993), Vector3.new(-300.422119,-7.30179977,34.2573051) }, CamOffset = Vector3.new(-298.584991,3.38974237,49.2246361)-Vector3.new(-300.422119,-7.30179977,34.2573051), CamAngles = {0,0.06,0} },
    [7]  = { Positions = { Vector3.new(-344.4383,-6.4281,41.8672) }, CamOffset = Vector3.new(-362.8094,-3.2299,51.1552)-Vector3.new(-344.4383,-6.4281,41.8672), CamAngles = {-0.181885,-1.095968,-0.162135} },
    [8]  = { Positions = { Vector3.new(-348.5228,-6.4281,48.1022) }, CamOffset = Vector3.new(-369.4075,-0.1123,63.3763)-Vector3.new(-348.5228,-6.4281,48.1022), CamAngles = {-0.306020,-0.916511,-0.245634} },
    [9]  = { Positions = { Vector3.new(-339.6349,-6.4281,60.4164) }, CamOffset = Vector3.new(-349.9293,-1.6218,84.4119)-Vector3.new(-339.6349,-6.4281,60.4164), CamAngles = {-0.137335,-0.401849,-0.054002} },
    [10] = { Positions = { Vector3.new(-355.3322,-6.4281,25.3526) }, CamOffset = Vector3.new(-377.7117,8.9106,25.7208)-Vector3.new(-355.3322,-6.4281,25.3526), CamAngles = {-1.544218,-1.016502,-1.539540} },
    [11] = { Positions = { Vector3.new(-354.9932,-6.4281,-47.3879), Vector3.new(-331.5262,-6.4281,-47.3607) }, CamOffset = Vector3.new(-333.2372,-9.9613,-64.2099)-Vector3.new(-331.5262,-6.4281,-47.3607), CamAngles = {2.851853,-0.097011,3.112724} },
    [12] = { Positions = { Vector3.new(-354.9584,-6.4208,-42.6520), Vector3.new(-338.7290,-6.4281,-43.4713) }, CamOffset = Vector3.new(-346.9807,-9.9578,-60.5865)-Vector3.new(-338.7290,-6.4281,-43.4713), CamAngles = {2.856299,-0.433315,3.019061} },
    [13] = { Positions = { Vector3.new(-354.8862,-6.2793,-37.9787), Vector3.new(-334.5183,-6.4281,-41.6819) }, CamOffset = Vector3.new(-343.9747,-9.9590,-57.3332)-Vector3.new(-334.5183,-6.4281,-41.6819), CamAngles = {2.831168,-0.522070,2.982964} },
    [14] = { Positions = { Vector3.new(-351.8463,-6.5022,-37.0529), Vector3.new(-319.8298,-6.4281,-45.1476) }, CamOffset = Vector3.new(-325.1408,-9.9618,-60.9837)-Vector3.new(-319.8298,-6.4281,-45.1476), CamAngles = {2.834406,-0.309406,3.045298} },
    [15] = { Positions = { Vector3.new(-351.0894,-6.2833,-32.7751), Vector3.new(-317.9170,-6.4281,-41.9999) }, CamOffset = Vector3.new(-327.9996,-9.9581,-57.8876)-Vector3.new(-317.9170,-6.4281,-41.9999), CamAngles = {2.835549,-0.544183,2.979445} },
    [16] = { Positions = { Vector3.new(-338.2857,-6.4281,57.2060) }, CamOffset = Vector3.new(-341.5551,-9.9642,72.3530)-Vector3.new(-338.2857,-6.4281,57.2060), CamAngles = {0.320392,-0.202067,0.066497} },
    [17] = { Positions = { Vector3.new(-337.9285,-6.4281,55.1757) }, CamOffset = Vector3.new(-344.4950,-9.9637,69.4787)-Vector3.new(-337.9285,-6.4281,55.1757), CamAngles = {0.337895,-0.408747,0.138758} },
    [18] = { Positions = { Vector3.new(-332.1088,-6.4281,53.1675) }, CamOffset = Vector3.new(-338.8290,-9.9674,65.6692)-Vector3.new(-332.1088,-6.4281,53.1675), CamAngles = {0.382481,-0.462609,0.177644} },
    [19] = { Positions = { Vector3.new(-347.9923,-6.2933,-34.0232), Vector3.new(-328.5790,-6.4281,-35.0857) }, CamOffset = Vector3.new(-328.6130,-10.0174,-40.4923)-Vector3.new(-328.5790,-6.4281,-35.0857), CamAngles = {2.387391,-0.004579,3.137291} },
    [20] = { Positions = { Vector3.new(-355.0801,-6.4404,-33.2302), Vector3.new(-321.5783,-6.4281,-33.5778) }, CamOffset = Vector3.new(-321.6123,-10.0174,-38.9844)-Vector3.new(-321.5783,-6.4281,-33.5778), CamAngles = {2.387391,-0.004579,3.137291} },
    [21] = { Positions = { Vector3.new(-351.5396,-7.5033,-41.797), Vector3.new(-314.088,-7.5033,-32.1806) }, CamOffset = Vector3.new(-314.1147,-10.0174,-36.4214)-Vector3.new(-314.088,-7.5033,-32.1806), CamAngles = {2.387391,-0.004579,3.137291}, NeedJump = true },
    [22] = { Positions = { Vector3.new(-351.5396,-7.5033,-41.797), Vector3.new(-306.8919,-7.5033,-33.9124) }, CamOffset = Vector3.new(-306.923,-10.008,-38.86)-Vector3.new(-306.8919,-7.5033,-33.9124), CamAngles = {2.4648,-0.004898,3.137657}, NeedJump = true },
    [23] = { Positions = { Vector3.new(-351.5396,-7.5033,-41.797), Vector3.new(-300.2759,-7.5033,-32.7047) }, CamOffset = Vector3.new(-300.4669,-10.016,-37.044)-Vector3.new(-300.2759,-7.5033,-32.7047), CamAngles = {2.399014,-0.032413,3.111857}, NeedJump = true },
    [24] = { Positions = { Vector3.new(-348.2407,-7.5033,74.3719), Vector3.new(-330.0484,-7.5033,48.183) }, CamOffset = Vector3.new(-330.1124,-10.0063,53.2779)-Vector3.new(-330.0484,-7.5033,48.183), CamAngles = {0.662308,-0.00991,0.007727}, NeedJump = true },
    [25] = { Positions = { Vector3.new(-348.2407,-7.5033,74.3719), Vector3.new(-325.4576,-7.5033,46.8182) }, CamOffset = Vector3.new(-326.0541,-10.0104,51.5397)-Vector3.new(-325.4576,-7.5033,46.8182), CamAngles = {0.700033,-0.09632,0.080833}, NeedJump = true },
    [26] = { Positions = { Vector3.new(-348.2407,-7.5033,74.3719), Vector3.new(-324.6721,-7.5033,47.2033) }, CamOffset = Vector3.new(-326.6859,-10.0057,51.9385)-Vector3.new(-324.6721,-7.5033,47.2033), CamAngles = {0.698024,-0.314979,0.254268}, NeedJump = true },
    [27] = { Positions = { Vector3.new(-348.2407,-7.5033,74.3719), Vector3.new(-320.4196,-7.5033,44.1) }, CamOffset = Vector3.new(-322.9213,-10.0122,49.5157)-Vector3.new(-320.4196,-7.5033,44.1), CamAngles = {0.876985,-0.422603,0.397417} },
}

Players.PlayerRemoving:Connect(function(p)
	balloonActive[p.UserId] = nil
end)

local _resetWasByBalloon = false
local balloonConnection
balloonConnection = LocalPlayer:GetAttributeChangedSignal("Balloon"):Connect(function()
    if thisScriptStopped then pcall(function() balloonConnection:Disconnect() end) return end
    if _G.AutoResetOnBalloon == true and LocalPlayer:GetAttribute("Balloon") == true then
        _resetWasByBalloon = true
        task.spawn(function() doReset() end)
    end
end)
table.insert(ActiveConnections, balloonConnection)

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") then
        local conn = obj.OnClientEvent:Connect(function(...)
            if not _G.AutoResetOnBalloon then return end
            for _, arg in ipairs({...}) do
                if type(arg) == "string" and arg:lower():find("jump higher") then
                    task.spawn(function() doReset() end)
                end
            end
        end)
        table.insert(ActiveConnections, conn)
    end
end

local function applyGiantPotion(humanoid, root)
	if not humanoid or not root then return end
	
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	task.wait(0.1)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	
	task.wait(0.08)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function startTripToPetSlot(prompt, slotNumber)
    local config          = SlotsConfig[slotNumber] or SlotsConfig[1]
    local targetPositions = config.Positions or { config.Position }
    local needJump        = config.NeedJump == true
    if slotNumber >= 19 and slotNumber <= 27 then needJump = true end

    if currentMovement then pcall(function() currentMovement:Disconnect() end) currentMovement = nil end
    if not Root or not Humanoid then return end

    autoStealEnabled = true
    local Speed            = 200
    local grabStartDistance= 60
    local grabStarted      = false

    local carpet = findTool("flying carpet")
    if carpet then Humanoid:UnequipTools() task.wait(0.03) Humanoid:EquipTool(carpet) end

    if Root:FindFirstChild("LinearVelocity") then Root.LinearVelocity:Destroy() end
    if Root:FindFirstChild("Attachment")     then Root.Attachment:Destroy() end

    local Attachment = Instance.new("Attachment")
    Attachment.Parent = Root

    local Velocity = Instance.new("LinearVelocity")
    Velocity.Attachment0     = Attachment
    Velocity.RelativeTo      = Enum.ActuatorRelativeTo.World
    Velocity.MaxForce        = math.huge
    Velocity.Parent          = Root

    local currentPosIndex       = 1
    local intermediatePauseActive = false

    currentMovement = RunService.Heartbeat:Connect(function()
        if thisScriptStopped then
            if currentMovement then pcall(function() currentMovement:Disconnect() end) currentMovement = nil end
            return
        end
        if not Root or not Humanoid or not Root.Parent or Humanoid.Health <= 0 then
            if currentMovement then pcall(function() currentMovement:Disconnect() end) currentMovement = nil end
            return
        end
        if intermediatePauseActive then Velocity.VectorVelocity = Vector3.zero return end

        local TargetPosition = targetPositions[currentPosIndex]
        if not TargetPosition then return end

        local rootPos = Root.Position
        local dir     = Vector3.new(TargetPosition.X - rootPos.X, 0, TargetPosition.Z - rootPos.Z)
        local dist    = dir.Magnitude

        if currentPosIndex == 1 and dist <= grabStartDistance and not grabStarted then
            grabStarted = true
            task.spawn(function() executeSteal(prompt) end)
        end

        local speedMult = 1
        if dist < SLOW_DIST then speedMult = math.max(0.15, dist / SLOW_DIST) end

        if dist <= STOP_DIST then
            if currentPosIndex < #targetPositions then
                intermediatePauseActive = true
                Velocity.VectorVelocity = Vector3.zero
                Root.AssemblyLinearVelocity = Vector3.zero
                task.spawn(function()
                    currentPosIndex = currentPosIndex + 1
                    intermediatePauseActive = false
                end)
                return
            end

            Velocity.VectorVelocity = Vector3.zero
            Root.AssemblyLinearVelocity = Vector3.zero
            Velocity:Destroy()
            Attachment:Destroy()
            Root.CFrame = CFrame.new(TargetPosition)
            if currentMovement then pcall(function() currentMovement:Disconnect() end) currentMovement = nil end

            task.wait(0.12)
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = CFrame.new(Root.Position + config.CamOffset) * CFrame.Angles(unpack(config.CamAngles))
            Humanoid:UnequipTools()
            task.wait(0.06)

            if needJump then
                Root.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
                task.wait(0.08)
            end

            local flash = findTool("flash")
            if flash then
                Humanoid:EquipTool(flash)
                task.wait(0.08)
                flash:Activate()
            end

            task.wait(0.1)

            if _G.AutoGiant then
                local giant = findTool("giant potion")
                if giant then
                    Humanoid:EquipTool(giant) 
                    task.wait(0.08) 
                    giant:Activate()
                    
                    task.spawn(function()
                        task.wait(0.15)
                        
                        if _G.RagdollBypass then
                            local success = ragdollPlayerWithRemote()
                            
                            if not success then
                                local char = LocalPlayer.Character
                                if char then
                                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                                    local root = char:FindFirstChild("HumanoidRootPart")
                                    if humanoid and root then
										applyGiantPotion(humanoid, root)
                                    end
                                end
                            end
                        end
                    end)
                    
                    task.wait(0.05) 
                    Humanoid:UnequipTools()
                end
            end

            Camera.CameraType = Enum.CameraType.Custom

            if _G.AutoBlock then
                task.spawn(function()
                    task.wait(0.13)
                    local target = getNearestPlayer()
                    if target then
                        blockPlayer(target)
                    end
                end)
            end

            task.spawn(function() task.wait(1.0) autoStealEnabled = false end)
            return
        end

        Velocity.VectorVelocity = Vector3.new(dir.Unit.X * Speed * speedMult, 0, dir.Unit.Z * Speed * speedMult)
    end)
    table.insert(ActiveConnections, currentMovement)
end

local function findTool(name)
    if not Character then return nil end
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then return tool end
    end
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then return tool end
    end
    return nil
end

local function isMyPlot(plot)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled then return true end
    end
    return false
end

local function isValidStealPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end
    local state      = prompt:GetAttribute("State")
    local actionText = prompt.ActionText
    if state == "Steal" or state == "Grab" or actionText == "Steal" or actionText == "Grab" then return true end
    return false
end

local function firePromptConnections(prompt, signalName)
    if not getconnections then return end
    local connections = getconnections(prompt[signalName])
    for _, conn in ipairs(connections) do
        if conn.Function then task.spawn(conn.Function) end
    end
end

local function executeSteal(prompt)
    if isStealing or not prompt or not prompt.Parent then return end
    isStealing = true
    firePromptConnections(prompt, "PromptButtonHoldBegan")
    task.wait(stealDelay)
    if prompt and prompt.Parent and prompt.Enabled and not thisScriptStopped then
        firePromptConnections(prompt, "Triggered")
    end
    isStealing = false
end

local STOP_DIST = 5
local SLOW_DIST = 20

local resetRemote = nil
local instaResetCooldown = false
local RESET_GUID = "f888ee6e-c86d-46e1-93d7-0639d6635d42"

local o
o = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
    if not resetRemote and self.Name:sub(1, 3) == "RE/" then
        resetRemote = self
    end
    return o(self, ...)
end))

local function resetCharacter(char)
    if instaResetCooldown then return end
    if not resetRemote then return end
    
    instaResetCooldown = true
    local oldChar = LocalPlayer.Character
    
    task.spawn(function()
        while LocalPlayer.Character == oldChar do
            pcall(function() resetRemote:FireServer(RESET_GUID, LocalPlayer, "balloon") end)
            task.wait()
        end
        instaResetCooldown = false
    end)
end

local function doReset()
    if Character then
        resetCharacter(Character)
    end
end

-- ==========================================
-- AUTO BALLOON HEARTBEAT
-- ==========================================
local lastBalloonCheck = 0
RunService.Heartbeat:Connect(function()
	if not _G.AutoBalloon then return end
	local now = tick()
	if now - lastBalloonCheck < 0.1 then return end
	lastBalloonCheck = now

	for _, p in pairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		local character = p.Character
		if not character then continue end
		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
		if not rootPart then continue end

		local targetKey = p.UserId
		local inZone = isInAnyZone(rootPart.Position)
		local withBrainrot = hasBrainrot(p)

		if inZone and withBrainrot and not balloonActive[targetKey] and not balloonedThisSession[targetKey] then
			balloonActive[targetKey] = true
			balloonedThisSession[targetKey] = true
			triggerBalloonOnTarget(p)
		elseif (not inZone or not withBrainrot) and balloonActive[targetKey] then
			balloonActive[targetKey] = nil
		end
	end
end)

local function findTool(name)
    if not Character then return nil end
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then return tool end
    end
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find(name:lower()) then return tool end
    end
    return nil
end

local function isMyPlot(plot)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled then return true end
    end
    return false
end

local function isValidStealPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end
    local state      = prompt:GetAttribute("State")
    local actionText = prompt.ActionText
    if state == "Steal" or state == "Grab" or actionText == "Steal" or actionText == "Grab" then return true end
    return false
end

local function firePromptConnections(prompt, signalName)
    if not getconnections then return end
    local connections = getconnections(prompt[signalName])
    for _, conn in ipairs(connections) do
        if conn.Function then task.spawn(conn.Function) end
    end
end

local function executeSteal(prompt)
    if isStealing or not prompt or not prompt.Parent then return end
    isStealing = true
    firePromptConnections(prompt, "PromptButtonHoldBegan")
    task.wait(stealDelay)
    if prompt and prompt.Parent and prompt.Enabled and not thisScriptStopped then
        firePromptConnections(prompt, "Triggered")
    end
    isStealing = false
end

local STOP_DIST = 5
local SLOW_DIST = 20

local resetRemote = nil
local instaResetCooldown = false
local RESET_GUID = "f888ee6e-c86d-46e1-93d7-0639d6635d42"

local o
o = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
    if not resetRemote and self.Name:sub(1, 3) == "RE/" then
        resetRemote = self
    end
    return o(self, ...)
end))

local function resetCharacter(char)
    if instaResetCooldown then return end
    if not resetRemote then return end
    
    instaResetCooldown = true
    local oldChar = LocalPlayer.Character
    
    task.spawn(function()
        while LocalPlayer.Character == oldChar do
            pcall(function() resetRemote:FireServer(RESET_GUID, LocalPlayer, "balloon") end)
            task.wait()
        end
        instaResetCooldown = false
    end)
end

local function doReset()
    if Character then
        resetCharacter(Character)
    end
end

-- ==========================================
-- AUTO BALLOON HEARTBEAT
-- ==========================================
local lastBalloonCheck = 0
RunService.Heartbeat:Connect(function()
	if not _G.AutoBalloon then return end
	local now = tick()
	if now - lastBalloonCheck < 0.1 then return end
	lastBalloonCheck = now

	for _, p in pairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		local character = p.Character
		if not character then continue end
		local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
		if not rootPart then continue end

		local targetKey = p.UserId
		local inZone = isInAnyZone(rootPart.Position)
		local withBrainrot = hasBrainrot(p)

		if inZone and withBrainrot and not balloonActive[targetKey] and not balloonedThisSession[targetKey] then
			balloonActive[targetKey] = true
			balloonedThisSession[targetKey] = true
			triggerBalloonOnTarget(p)
		elseif (not inZone or not withBrainrot) and balloonActive[targetKey] then
			balloonActive[targetKey] = nil
		end
	end
end)

-- ==========================================
-- THEME: NOIR PUR / PURE BLACK THEME
-- ==========================================
local C = {
    accent     = Color3.fromRGB(50, 50, 50),     -- Gris très foncé
    accentHi   = Color3.fromRGB(80, 80, 80),     -- Gris foncé
    deepPurple = Color3.fromRGB(10, 10, 10),     -- Noir pur
    body       = Color3.fromRGB(5, 5, 5),        -- Noir presque pur
    panel      = Color3.fromRGB(10, 10, 10),     -- Noir foncé
    tabBar     = Color3.fromRGB(5, 5, 5),        -- Noir
    card       = Color3.fromRGB(15, 15, 15),     -- Noir avec léger gris
    iconBg     = Color3.fromRGB(20, 20, 20),     -- Noir très foncé
    stroke     = Color3.fromRGB(40, 40, 40),     -- Gris très foncé
    strokeDim  = Color3.fromRGB(25, 25, 25),     -- Gris foncé
    textBright = Color3.fromRGB(255, 255, 255),  -- Blanc pur (texte principal)
    textMauve  = Color3.fromRGB(180, 180, 180),  -- Gris clair (texte secondaire)
    textMute   = Color3.fromRGB(140, 140, 140),  -- Gris moyen (texte muet)
    textDim    = Color3.fromRGB(100, 100, 100),  -- Gris (texte atténué)
    knobOn     = Color3.fromRGB(180, 180, 180),  -- Blanc/gris clair (switch ON)
    knobOff    = Color3.fromRGB(40, 40, 40),     -- Gris foncé (switch OFF)
    trackOff   = Color3.fromRGB(15, 15, 15),     -- Noir très foncé (pistes inactives)
}

local borderGradientSeq = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    C.accentHi),
    ColorSequenceKeypoint.new(0.25, C.deepPurple),
    ColorSequenceKeypoint.new(0.5,  C.accent),
    ColorSequenceKeypoint.new(0.75, C.deepPurple),
    ColorSequenceKeypoint.new(1,    C.accentHi),
})

local function getDevice()
    local screen = workspace.CurrentCamera.ViewportSize
    local w, h = screen.X, screen.Y
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    if isMobile then
        if w >= 900 or h >= 900 then return "ipad" end
        return "mobile"
    end
    return "pc"
end

local DEVICE = getDevice()

local LAYOUT = {
    pc = {
        winW = 310, winH = 400,
        posX = UDim2.new(0.5, 0, 0.5, 0),
        bannerW = 302, bannerH = 82,
        bannerPos = UDim2.new(0.5, -151, 0, 60),
        btnSize = 94, btnH = 40,
        tabH = 32, headerH = 47,
        actionXs = {8, 108, 208},
        textSize = { header = 11, btn = 12, tab = 12 },
    },
    ipad = {
        winW = 280, winH = 370,
        posX = UDim2.new(0.5, 0, 0.5, 0),
        bannerW = 260, bannerH = 76,
        bannerPos = UDim2.new(0.5, -130, 0, 50),
        btnSize = 83, btnH = 38,
        tabH = 30, headerH = 45,
        actionXs = {7, 96, 185},
        textSize = { header = 11, btn = 11, tab = 11 },
    },
    mobile = {
        winW = 240, winH = 310,
        posX = UDim2.new(0.5, 0, 0.5, 0),
        bannerW = 220, bannerH = 70,
        bannerPos = UDim2.new(0.5, -110, 0, 40),
        btnSize = 70, btnH = 36,
        tabH = 28, headerH = 42,
        actionXs = {6, 82, 158},
        textSize = { header = 10, btn = 10, tab = 10 },
    },
}

local L = LAYOUT[DEVICE]

local ZERMRX_SCRIPT_GUI = Instance.new("ScreenGui")
ZERMRX_SCRIPT_GUI.Name           = "ZERMRX SCRIPT"
ZERMRX_SCRIPT_GUI.SelectionGroup = false
ZERMRX_SCRIPT_GUI.ResetOnSpawn   = false
ZERMRX_SCRIPT_GUI.DisplayOrder   = 999
ZERMRX_SCRIPT_GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ZERMRX_SCRIPT_GUI.IgnoreGuiInset = false
ZERMRX_SCRIPT_GUI.Parent         = PlayerGui

local BorderFrame = Instance.new("Frame")
BorderFrame.Name             = "BorderFrame"
BorderFrame.SelectionGroup   = false
BorderFrame.Size             = UDim2.new(0, L.winW+4, 0, L.winH+4)
BorderFrame.Position         = L.posX
BorderFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
BorderFrame.BackgroundColor3 = C.accent
BorderFrame.BorderSizePixel  = 0
BorderFrame.ClipsDescendants = false
BorderFrame.Active           = false
BorderFrame.Selectable       = false
BorderFrame.Parent           = ZERMRX_SCRIPT_GUI

local BorderCorner = Instance.new("UICorner")
BorderCorner.CornerRadius = UDim.new(0, 16)
BorderCorner.Parent = BorderFrame

local UIGradient = Instance.new("UIGradient")
UIGradient.Color    = borderGradientSeq
UIGradient.Rotation = 308.077
UIGradient.Parent   = BorderFrame

local Win = Instance.new("Frame")
Win.Name             = "Win"
Win.SelectionGroup   = false
Win.Size             = UDim2.new(0, L.winW, 0, L.winH)
Win.Position         = L.posX
Win.AnchorPoint      = Vector2.new(0.5, 0.5)
Win.BackgroundTransparency = 1
Win.BorderSizePixel  = 0
Win.ZIndex           = 2
Win.ClipsDescendants = false
Win.Active           = false
Win.Selectable       = false
Win.Parent           = ZERMRX_SCRIPT_GUI

local Frame = Instance.new("Frame")
Frame.Name             = "Frame"
Frame.SelectionGroup   = false
Frame.Size             = UDim2.new(1, 0, 1, 0)
Frame.BackgroundColor3 = C.body
Frame.BorderSizePixel  = 0
Frame.ClipsDescendants = true
Frame.Active           = false
Frame.Selectable       = false
Frame.Parent           = Win
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)

local Frame2 = Instance.new("Frame")
Frame2.Name             = "Frame"
Frame2.Size             = UDim2.new(1, 0, 1, -94)
Frame2.Position         = UDim2.new(0, 0, 0, 90)
Frame2.BackgroundColor3 = C.panel
Frame2.BorderSizePixel  = 0
Frame2.ClipsDescendants = true
Frame2.Parent           = Frame
Instance.new("UICorner", Frame2).CornerRadius = UDim.new(0, 16)

local Frame3 = Instance.new("Frame")
Frame3.Name             = "Frame"
Frame3.Size             = UDim2.new(1, 0, 0, L.headerH)
Frame3.Position         = UDim2.new(0, 0, 0, -8)
Frame3.BackgroundTransparency = 1
Frame3.BorderSizePixel  = 0
Frame3.ZIndex           = 3
Frame3.ClipsDescendants = false
Frame3.Active           = false
Frame3.Selectable       = false
Frame3.Parent           = Frame

local Frame4 = Instance.new("Frame")
Frame4.Size             = UDim2.new(1, 0, 0, 1)
Frame4.Position         = UDim2.new(0, 0, 1, -1)
Frame4.BackgroundColor3 = C.stroke
Frame4.BorderSizePixel  = 0
Frame4.ZIndex           = 4
Frame4.Parent           = Frame3

local Frame5 = Instance.new("Frame")
Frame5.Size             = UDim2.new(0, 6, 0, 6)
Frame5.Position         = UDim2.new(0, 10, 0.5, -3)
Frame5.BackgroundColor3 = C.accent
Frame5.BorderSizePixel  = 0
Frame5.ZIndex           = 5
Frame5.Parent           = Frame3
Instance.new("UICorner", Frame5).CornerRadius = UDim.new(0, 4)

local Frame6 = Instance.new("Frame")
Frame6.Size                 = UDim2.new(0, 12, 0, 12)
Frame6.Position             = UDim2.new(0, 7, 0.5, -6)
Frame6.BackgroundColor3     = C.accent
Frame6.BackgroundTransparency = 0.75
Frame6.BorderSizePixel      = 0
Frame6.ZIndex               = 4
Frame6.Parent               = Frame3
Instance.new("UICorner", Frame6).CornerRadius = UDim.new(0, 7)

local TextLabel = Instance.new("TextLabel")
TextLabel.Size               = UDim2.new(0, 180, 1, 0)
TextLabel.Position           = UDim2.new(0, 24, 0, 0)
TextLabel.BackgroundTransparency = 1
TextLabel.ZIndex             = 5
TextLabel.Text               = 'ZERMRX <font color="rgb(255,50,50)">HUB</font>'
TextLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize           = 15
TextLabel.Font               = Enum.Font.GothamBold
TextLabel.TextXAlignment     = Enum.TextXAlignment.Left
TextLabel.RichText           = true
TextLabel.Parent             = Frame3

local Frame21 = Instance.new("Frame")
Frame21.Name             = "Frame"
Frame21.Size             = UDim2.new(1, 0, 1, 0)
Frame21.Position         = UDim2.new(1, 0, 0, 0)
Frame21.BackgroundTransparency = 1
Frame21.BorderSizePixel  = 0
Frame21.Visible          = false
Frame21.ZIndex           = 3
Frame21.Parent           = Frame16

local ScrollingFrame2 = Instance.new("ScrollingFrame")
ScrollingFrame2.Size                  = UDim2.new(1, 0, 1, 0)
ScrollingFrame2.BackgroundTransparency= 1
ScrollingFrame2.BorderSizePixel       = 0
ScrollingFrame2.CanvasSize            = UDim2.new(0, 0, 0, 0)
ScrollingFrame2.ScrollBarThickness    = 3
ScrollingFrame2.ScrollBarImageColor3  = C.accent
ScrollingFrame2.ScrollingDirection    = Enum.ScrollingDirection.Y
ScrollingFrame2.AutomaticCanvasSize   = Enum.AutomaticSize.Y
ScrollingFrame2.Parent                = Frame21

local UIListLayout3 = Instance.new("UIListLayout")
UIListLayout3.SortOrder           = Enum.SortOrder.LayoutOrder
UIListLayout3.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout3.Padding             = UDim.new(0, 4)
UIListLayout3.Parent              = ScrollingFrame2

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingTop    = UDim.new(0, 10)
UIPadding.PaddingBottom = UDim.new(0, 10)
UIPadding.PaddingLeft   = UDim.new(0, 8)
UIPadding.PaddingRight  = UDim.new(0, 8)
UIPadding.Parent        = ScrollingFrame2

local sectionOrder = 0
local toggleRefs   = {}

local function sectionHeader(text)
    sectionOrder += 1
    local wrap = Instance.new("Frame")
    wrap.Size             = UDim2.new(1, 0, 0, 24)
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel  = 0
    wrap.ZIndex           = 4
    wrap.LayoutOrder      = sectionOrder
    wrap.Parent           = ScrollingFrame2
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1, 0, 0, 1)
    line.Position         = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = C.stroke
    line.BorderSizePixel  = 0
    line.ZIndex           = 5
    line.Parent           = wrap
    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 0, 1, 0)
    pill.Position         = UDim2.new(0.5, 0, 0, 0)
    pill.AnchorPoint      = Vector2.new(0.5, 0)
    pill.BackgroundColor3 = C.panel
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 6
    pill.AutomaticSize    = Enum.AutomaticSize.X
    pill.Parent           = wrap
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.ZIndex             = 7
    lbl.Text               = text
    lbl.TextColor3         = C.textMute
    lbl.TextSize           = 10
    lbl.Font               = Enum.Font.GothamBold
    lbl.Parent             = pill
    return wrap
end

local function toggleRow(title, desc, defaultOn, onToggle)
    sectionOrder += 1
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.LayoutOrder      = sectionOrder
    row.Parent           = ScrollingFrame2
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
    local s = Instance.new("UIStroke"); s.Color = C.stroke; s.Parent = row

    local accentBar = Instance.new("Frame")
    accentBar.Size             = UDim2.new(0, 3, 1, -10)
    accentBar.Position         = UDim2.new(0, 0, 0, 5)
    accentBar.BackgroundColor3 = C.accent
    accentBar.BorderSizePixel  = 0
    accentBar.ZIndex           = 5
    accentBar.Parent           = row
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 3)

    local t1 = Instance.new("TextLabel")
    t1.Size               = UDim2.new(1, -52, 0, 24)
    t1.Position           = UDim2.new(0, 12, 0, 0)
    t1.BackgroundTransparency = 1
    t1.ZIndex             = 5
    t1.Text               = title
    t1.TextColor3         = C.textBright
    t1.TextSize           = 13
    t1.Font               = Enum.Font.GothamMedium
    t1.TextXAlignment     = Enum.TextXAlignment.Left
    t1.Parent             = row

    local t2 = Instance.new("TextLabel")
    t2.Size               = UDim2.new(1, -52, 0, 20)
    t2.Position           = UDim2.new(0, 12, 0, 22)
    t2.BackgroundTransparency = 1
    t2.ZIndex             = 5
    t2.Text               = desc
    t2.TextColor3         = C.textMute
    t2.TextSize           = 11
    t2.Font               = Enum.Font.Gotham
    t2.TextWrapped        = true
    t2.TextXAlignment     = Enum.TextXAlignment.Left
    t2.Parent             = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, 36, 0, 20)
    track.Position         = UDim2.new(1, -42, 0.5, -10)
    track.BackgroundColor3 = C.accent
    track.BorderSizePixel  = 0
    track.ZIndex           = 6
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 10)
    local ts = Instance.new("UIStroke"); ts.Color = C.accent; ts.Parent = track

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = UDim2.new(0, 19, 0.5, -7)
    knob.BackgroundColor3 = C.knobOn
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 7
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 7)

    local hit = Instance.new("TextButton")
    hit.Size               = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.ZIndex             = 8
    hit.Text               = ""
    hit.Parent             = row

    local ref = { on = defaultOn ~= false, track = track, stroke = ts, knob = knob }
    local function render(animate)
        local info = TweenInfo.new(animate and 0.16 or 0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if ref.on then
            TweenService:Create(track, info, { BackgroundColor3 = C.accent }):Play()
            TweenService:Create(ts,    info, { Color = C.accent }):Play()
            TweenService:Create(knob,  info, { Position = UDim2.new(0, 19, 0.5, -7), BackgroundColor3 = C.knobOn }):Play()
        else
            TweenService:Create(track, info, { BackgroundColor3 = C.trackOff }):Play()
            TweenService:Create(ts,    info, { Color = C.stroke }):Play()
            TweenService:Create(knob,  info, { Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = C.knobOff }):Play()
        end
    end
    render(false)
    if onToggle then task.defer(function() pcall(onToggle, ref.on) end) end
    hit.MouseButton1Click:Connect(function()
        ref.on = not ref.on
        render(true)
        if onToggle then pcall(onToggle, ref.on) end
        saveSettings()
    end)
    table.insert(toggleRefs, ref)
    return row, ref
end

sectionHeader("  AUTO RESET  ")
toggleRow("Reset On Balloon", "Reset quand tu es ballonné", _G.AutoResetOnBalloon, function(v)
    _G.AutoResetOnBalloon = v
end)
toggleRow("Reset On Tiny", "Auto reset si tu deviens tiny", AutoResetTinyEnabled, function(v)
    AutoResetTinyEnabled = v
    if v then startAutoResetTiny() else stopAutoResetTiny() end
end)
toggleRow("Reset On Jail", "Auto reset si tu es emprisonné", AutoResetJailEnabled, function(v)
    AutoResetJailEnabled = v
    if v then startAutoResetJail() else stopAutoResetJail() end
end)

sectionHeader("  FLASH TP  ")
toggleRow("Auto Flash TP",  "Auto flash tp quand reset (necessite Reset On Balloon)", _G.AutoFlashTP, function(v)
    _G.AutoFlashTP = v
end)
toggleRow("Ragdoll Bypass", "Ragdoll instantanément quand la potion s'active", _G.RagdollBypass, function(v)
    _G.RagdollBypass = v
end)
toggleRow("Auto Block",     "Block auto le joueur le plus proche après un grab", _G.AutoBlock, function(v)
    _G.AutoBlock = v
end)
toggleRow("Auto Giant",     "Active la giant potion après le flash", _G.AutoGiant, function(v)
    _G.AutoGiant = v
end)

sectionHeader("  BRAINROT SELECTION  ")
toggleRow("Auto Select Best Brainrot", "Sélectionne auto le meilleur brainrot disponible", _G.AutoSelectBest, function(v)
    _G.AutoSelectBest = v
end)

sectionHeader("  MISC  ")
toggleRow("Auto Balloon",  "Balloon auto celui qui te vole + Détection Brainrot + Zones", _G.AutoBalloon, function(v)
    _G.AutoBalloon = v
    autoBallon = v
    if not v then 
        balloonActive = {} 
    end
end)
toggleRow("AP ESP",        "Tag les joueurs avec Admin Commands gamepass", false)

task.spawn(function()
    local base1, base2 = UIGradient.Rotation, UIGradient.Rotation
    while UIGradient.Parent do
        local t = os.clock()
        UIGradient.Rotation  = (base1 + t * 60) % 360
        RunService.RenderStepped:Wait()
    end
end)

local function syncBorder()
    BorderFrame.Position = Win.Position
end

do
    local dragging, dragStart, startPos
    local function begin(input)
        dragging = true
        dragStart = input.Position
        startPos  = Win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
    Frame3.Active = true
    Frame3.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then begin(input) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            syncBorder()
        end
    end)
end

local activeTab = "brainrots"
local function setTab(tab)
    if tab == activeTab then return end
    activeTab = tab
    local info = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if tab == "settings" then
        Frame21.Visible = true
        Frame21.Position = UDim2.new(1, 0, 0, 0)
        TweenService:Create(Frame17, info, { Position = UDim2.new(-1, 0, 0, 0) }):Play()
        TweenService:Create(Frame21, info, { Position = UDim2.new(0, 0, 0, 0) }):Play()
        TextLabel7.TextColor3 = C.textDim
        TextLabel8.TextColor3 = C.textMauve
        TweenService:Create(Frame13, info, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(Frame14, info, { BackgroundTransparency = 0 }):Play()
    else
        Frame17.Visible = true
        Frame17.Position = UDim2.new(-1, 0, 0, 0)
        TweenService:Create(Frame17, info, { Position = UDim2.new(0, 0, 0, 0) }):Play()
        TweenService:Create(Frame21, info, { Position = UDim2.new(1, 0, 0, 0) }):Play()
        TextLabel7.TextColor3 = C.textMauve
        TextLabel8.TextColor3 = C.textDim
        TweenService:Create(Frame13, info, { BackgroundTransparency = 0 }):Play()
        TweenService:Create(Frame14, info, { BackgroundTransparency = 1 }):Play()
        task.delay(0.22, function() if activeTab == "brainrots" then Frame21.Visible = false end end)
    end
end
Frame17.Position = UDim2.new(0, 0, 0, 0)
TextButton4.MouseButton1Click:Connect(function() setTab("brainrots") end)
TextButton5.MouseButton1Click:Connect(function() setTab("settings") end)

local locked = false
LockBtn.MouseButton1Click:Connect(function()
    locked = true
    LockBtn.Text      = "🔒"
    Frame3.Active     = false
    LockBtn.TextColor3= C.accent
end)

local minimised   = false
local fullSize    = Win.Size
local fullBorder  = BorderFrame.Size
local MIN_WIN_H   = L.headerH + 41
local MIN_BORDER_H= MIN_WIN_H + 4
MinBtn.MouseButton1Click:Connect(function()
    minimised = not minimised
    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if minimised then
        TweenService:Create(Win,         info, { Size = UDim2.new(0, L.winW, 0, MIN_WIN_H) }):Play()
        TweenService:Create(BorderFrame, info, { Size = UDim2.new(0, L.winW+4, 0, MIN_BORDER_H) }):Play()
    else
        TweenService:Create(Win,         info, { Size = fullSize }):Play()
        TweenService:Create(BorderFrame, info, { Size = fullBorder }):Play()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local t1 = TweenService:Create(Win,         info, { Size = UDim2.new(0,0,0,0) })
    local t2 = TweenService:Create(BorderFrame, info, { Size = UDim2.new(0,0,0,0) })
    t1:Play(); t2:Play()
    t1.Completed:Connect(function() ZERMRX_SCRIPT_GUI:Destroy() end)
end)

local function hookButton(btn, normal, hover)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = normal }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.06), { BackgroundColor3 = C.deepPurple }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = hover }):Play()
    end)
end
hookButton(FLASHTP, C.card, C.iconBg)
hookButton(BLOCK,   C.card, C.iconBg)
hookButton(RESET,   C.card, C.iconBg)
for _, b in ipairs({ LockBtn, MinBtn, CloseBtn }) do hookButton(b, C.card, C.iconBg) end

local function flashBar(bar)
    bar.BackgroundColor3 = C.accentHi
    TweenService:Create(bar, TweenInfo.new(0.4), { BackgroundColor3 = C.stroke }):Play()
end

local flashBlinkActive = false
local BLINK_HI  = Color3.fromRGB(255, 50, 50)
local BLINK_LO  = Color3.fromRGB(180, 20, 20)
local BLINK_T   = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function startFlashBlink()
    if flashBlinkActive then return end
    flashBlinkActive = true
    task.spawn(function()
        while flashBlinkActive and not thisScriptStopped do
            TweenService:Create(FLASHTP,     BLINK_T, { BackgroundColor3 = BLINK_HI }):Play()
            TweenService:Create(flashAccent, BLINK_T, { BackgroundColor3 = BLINK_HI }):Play()
            TweenService:Create(Frame13,     BLINK_T, { BackgroundColor3 = BLINK_HI, BackgroundTransparency = 0 }):Play()
            task.wait(0.3)
            if not flashBlinkActive then break end
            TweenService:Create(FLASHTP,     BLINK_T, { BackgroundColor3 = BLINK_LO }):Play()
            TweenService:Create(flashAccent, BLINK_T, { BackgroundColor3 = BLINK_LO }):Play()
            TweenService:Create(Frame13,     BLINK_T, { BackgroundColor3 = BLINK_LO }):Play()
            task.wait(0.3)
        end
    end)
end

local function stopFlashBlink()
    if not flashBlinkActive then return end
    flashBlinkActive = false
    TweenService:Create(FLASHTP,     TweenInfo.new(0.2), { BackgroundColor3 = C.card }):Play()
    TweenService:Create(flashAccent, TweenInfo.new(0.2), { BackgroundColor3 = C.stroke }):Play()
    TweenService:Create(Frame13,     TweenInfo.new(0.2), { BackgroundColor3 = C.accent, BackgroundTransparency = 0 }):Play()
end

startFlashBlink()

FLASHTP.MouseButton1Click:Connect(function()
    if selectedPrompt and selectedSlotNumber then
        if not isStealing and not autoStealEnabled then
            flashBar(flashAccent)
            startTripToPetSlot(selectedPrompt, selectedSlotNumber)
        end
    end
end)

BLOCK.MouseButton1Click:Connect(function()
    flashBar(blockAccent)
    local target = getNearestPlayer()
    if target then
        blockPlayer(target)
    end
end)

RESET.MouseButton1Click:Connect(function()
    flashBar(resetAccent)
    doReset()
end)

task.spawn(function()
    while task.wait(1.5) do
        if thisScriptStopped then break end
        updatePetList()
        if selectedPrompt and selectedSlotNumber then
            stopFlashBlink()
        else
            startFlashBlink()
        end
    end
end)
updatePetList()

task.spawn(function()
    local target = L.posX
    Win.Position         = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset - 40)
    BorderFrame.Position = Win.Position
    Win.Visible = true
    TweenService:Create(Win, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = target }):Play()
    local bt = TweenService:Create(BorderFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = target })
    bt:Play()
    bt.Completed:Wait()
    RunService.RenderStepped:Connect(syncBorder)
end)

_G.Formega_Script_Purge = function()
    thisScriptStopped = true
    stopAntiRagdoll()
    for _, conn in ipairs(ActiveConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    _G.Formega_Script_Purge = nil
end

local charAddedConnForReset = LocalPlayer.CharacterAdded:Connect(function(newChar)
    if _resetWasByBalloon and _G.AutoFlashTP and selectedPrompt and selectedSlotNumber then
        _resetWasByBalloon = false
        task.delay(0.2, function()
            if not isStealing and not autoStealEnabled then
                startTripToPetSlot(selectedPrompt, selectedSlotNumber)
            end
        end)
    else
        _resetWasByBalloon = false
    end
end)
table.insert(ActiveConnections, charAddedConnForReset)

local keybinds = {
    flash = Enum.KeyCode.F,
    block = Enum.KeyCode.B,
    reset = Enum.KeyCode.R,
}

local kbConn = UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if inp.KeyCode == keybinds.flash then
        if selectedPrompt and selectedSlotNumber and not isStealing and not autoStealEnabled then
            startTripToPetSlot(selectedPrompt, selectedSlotNumber)
        end
    elseif inp.KeyCode == keybinds.block then
        local target = getNearestPlayer()
        if target then blockPlayer(target) end
    elseif inp.KeyCode == keybinds.reset then
        doReset()
    end
end)
table.insert(ActiveConnections, kbConn)
