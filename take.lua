-- ============================================================
-- AUTO GRAB GUI — beautiful "UNREADY / READY" floating pill
-- Extracted from Done.lua (StealProgressGui), enhanced visually.
-- The whole pill IS the progress bar; it fills while stealing
-- and flips UNREADY -> READY. Tapping it toggles Auto Steal.
-- Steal a Brainrot.
-- ============================================================
repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ============================================================
-- MINIMAL STEAL STATE (from Done.lua, needed by the bar)
-- ============================================================
local Steal = {
	AutoStealEnabled=true, StealRadius=55, StealDuration=0.2,
	Mode="half", -- locked to half autograb
	HalfFireRange=10, HalfHoldMin=1.3, HalfHoldMax=2.6, HalfEntryDelay=0.3,
	Data={}
}
local isStealing = false
local stealStartTime = nil
local autoConn = nil
local progressFill, progressPct

local function isMyPlotByName(plotName)
	local plots=workspace:FindFirstChild("Plots"); if not plots then return false end
	local plot=plots:FindFirstChild(plotName); if not plot then return false end
	local sign=plot:FindFirstChild("PlotSign")
	if sign then local yb=sign:FindFirstChild("YourBase"); if yb and yb:IsA("BillboardGui") then return yb.Enabled==true end end
	return false
end

local function findNearestPrompt()
	local char=LP.Character; if not char then return nil end
	local root=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not root then return nil end
	local plots=workspace:FindFirstChild("Plots"); if not plots then return nil end
	local nearest,dist=nil,math.huge
	for _,plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and not isMyPlotByName(plot.Name) then
			local pods=plot:FindFirstChild("AnimalPodiums")
			if pods then
				for _,pod in ipairs(pods:GetChildren()) do
					local base=pod:FindFirstChild("Base")
					local sp=base and base:FindFirstChild("Spawn")
					if sp then
						local d=(sp.Position-root.Position).Magnitude
						if d<=Steal.StealRadius and d<dist then
							local found=nil
							local att=sp:FindFirstChild("PromptAttachment")
							if att then for _,pr in ipairs(att:GetChildren()) do if pr:IsA("ProximityPrompt") and pr.ActionText and pr.ActionText:find("Steal") then found=pr end end end
							if not found then for _,pr in ipairs(sp:GetDescendants()) do if pr:IsA("ProximityPrompt") and pr.ActionText and pr.ActionText:find("Steal") then found=pr end end end
							if found then nearest,dist=found,d end
						end
					end
				end
			end
		end
	end
	return nearest
end

local function _promptDist(prompt)
	local char=LP.Character; if not char then return math.huge end
	local root=char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not root then return math.huge end
	local part=prompt.Parent
	if part and part:IsA("Attachment") then part=part.Parent end
	if part and part:IsA("BasePart") then return (part.Position-root.Position).Magnitude end
	local ok,cf=pcall(function() return prompt.Parent and prompt.Parent.WorldPosition end)
	if ok and cf then return (cf-root.Position).Magnitude end
	return math.huge
end

local function executeSteal(prompt)
	if isStealing then return end
	if not Steal.Data[prompt] then
		Steal.Data[prompt]={hold={},trigger={},ready=true}
		if getconnections then
			for _,c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do if c.Function then table.insert(Steal.Data[prompt].hold,c.Function) end end
			for _,c in ipairs(getconnections(prompt.Triggered)) do if c.Function then table.insert(Steal.Data[prompt].trigger,c.Function) end end
		end
	end
	local data=Steal.Data[prompt]; if not data.ready then return end
	data.ready=false; isStealing=true; stealStartTime=tick()
	if Steal.Mode=="half" then
		task.spawn(function()
			for _,fn in ipairs(data.hold) do task.spawn(fn) end
			task.wait(Steal.HalfHoldMin)
			local inRange=_promptDist(prompt)<=Steal.HalfFireRange
			while true do
				local el=tick()-stealStartTime
				if el>Steal.HalfHoldMax or not prompt.Parent then break end
				if _promptDist(prompt)<=Steal.HalfFireRange then
					if not inRange then task.wait(Steal.HalfEntryDelay) end
					for _,fn in ipairs(data.trigger) do task.spawn(fn) end; break
				end
				task.wait()
			end
			task.wait(0.05); data.ready=true; isStealing=false
		end)
	else
		task.spawn(function()
			for _,fn in ipairs(data.hold) do task.spawn(fn) end
			local el=0; while el<Steal.StealDuration do el=el+task.wait() end
			for _,fn in ipairs(data.trigger) do task.spawn(fn) end
			task.wait(0.05); data.ready=true; isStealing=false
		end)
	end
end

local function startAutoSteal()
	if autoConn then return end
	autoConn=RunService.Heartbeat:Connect(function()
		if not Steal.AutoStealEnabled or isStealing then return end
		local p=findNearestPrompt(); if p then executeSteal(p) end
	end)
end

local function stopAutoSteal()
	if autoConn then autoConn:Disconnect(); autoConn=nil end
	isStealing=false
end
_G.AutoSteal = Steal

-- ============================================================
-- BEAUTIFIED GUI with background image, gradient fill, shimmer, glow
-- Fill completes in 0.2 sec, but HalfHoldMin stays 1.3 sec
-- ============================================================
do
	local _oldSPG = LP.PlayerGui:FindFirstChild("StealProgressScreenGui")
	if _oldSPG then _oldSPG:Destroy() end
	local spScreenGui=Instance.new("ScreenGui")
	spScreenGui.Name="StealProgressScreenGui";spScreenGui.ResetOnSpawn=false
	spScreenGui.DisplayOrder=200;spScreenGui.IgnoreGuiInset=true
	spScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	spScreenGui.Parent=LP.PlayerGui

	-- Main frame – transparent to show background image
	local spFrame=Instance.new("Frame",spScreenGui)
	spFrame.Name="StealProgressGui"
	spFrame.Size=UDim2.new(0,320,0,36)
	spFrame.Position=UDim2.new(0.5,0,1,-90)
	spFrame.AnchorPoint=Vector2.new(0.5,1)
	spFrame.BackgroundTransparency=1
	spFrame.BorderSizePixel=0;spFrame.Active=true;spFrame.Visible=true
	spFrame.ZIndex=300;spFrame.ClipsDescendants=true
	Instance.new("UICorner",spFrame).CornerRadius=UDim.new(1,0)

	-- Shadow (glow) behind the pill
	local shadow=Instance.new("Frame",spScreenGui)
	shadow.Name="PillShadow"
	shadow.Size=UDim2.new(0,330,0,30)
	shadow.Position=UDim2.new(0.5,0,1,-87)
	shadow.AnchorPoint=Vector2.new(0.5,1)
	shadow.BackgroundColor3=Color3.fromRGB(255,255,255)
	shadow.BackgroundTransparency=0.8
	shadow.BorderSizePixel=0
	shadow.ZIndex=299
	local shadowCorner=Instance.new("UICorner",shadow)
	shadowCorner.CornerRadius=UDim.new(1,0)
	local shadowBlur=Instance.new("BlurEffect",shadow)
	shadowBlur.Size=8
	shadow.ClipsDescendants=true  -- keep blur inside

	-- Background image (the entire pill background)
	local bgImage=Instance.new("ImageLabel",spFrame)
	bgImage.Name="BgImage"
	bgImage.Size=UDim2.new(1,0,1,0)
	bgImage.Position=UDim2.new(0,0,0,0)
	bgImage.BackgroundTransparency=1
	bgImage.Image="rbxassetid://115292342024385"
	bgImage.ZIndex=300
	bgImage.ScaleType=Enum.ScaleType.Slice
	bgImage.SliceCenter=Rect.new(4,4,4,4)

	-- Outer border with glow effect
	local border=Instance.new("UIStroke",spFrame)
	border.Color=Color3.fromRGB(255,255,255)
	border.Thickness=2
	border.Transparency=0.3
	border.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

	-- Inner glassy overlay (shine effect – moving)
	local shine=Instance.new("Frame",spFrame)
	shine.Name="Shine"
	shine.Size=UDim2.new(0.5,0,1,0)
	shine.Position=UDim2.new(-0.5,0,0,0)
	shine.BackgroundColor3=Color3.fromRGB(255,255,255)
	shine.BackgroundTransparency=0.6
	shine.BorderSizePixel=0
	shine.ZIndex=302
	shine.ClipsDescendants=true
	local shineCorner=Instance.new("UICorner",shine)
	shineCorner.CornerRadius=UDim.new(1,0)
	-- Animate shine from left to right continuously
	task.spawn(function()
		while true do
			shine.Position=UDim2.new(-0.5,0,0,0)
			TS:Create(shine,TweenInfo.new(1.2,Enum.EasingStyle.Linear),{Position=UDim2.new(1.5,0,0,0)}):Play()
			task.wait(1.2)
		end
	end)

	-- Progress fill – blood red gradient
	local spFill=Instance.new("Frame",spFrame)
	spFill.Name="ProgressFill"
	spFill.Size=UDim2.new(0,0,1,-6)
	spFill.Position=UDim2.new(0,3,0,3)
	spFill.BackgroundColor3=Color3.fromRGB(200,0,0)
	spFill.BackgroundTransparency=0
	spFill.BorderSizePixel=0
	spFill.ZIndex=301
	spFill.ClipsDescendants=true
	local fillCorner=Instance.new("UICorner",spFill)
	fillCorner.CornerRadius=UDim.new(1,0)
	-- Gradient: dark red to bright red
	local gradient=Instance.new("UIGradient",spFill)
	gradient.Color=ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120,0,0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,0,0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255,60,60))
	}
	gradient.Rotation=90  -- horizontal

	-- Text label with shadow
	local spPct=Instance.new("TextLabel",spFrame)
	spPct.Size=UDim2.new(1,-28,0,22)
	spPct.Position=UDim2.new(0,14,0,0)
	spPct.BackgroundTransparency=1
	spPct.Text="UNREADY"
	spPct.TextColor3=Color3.fromRGB(255,255,255)
	spPct.Font=Enum.Font.GothamBold
	spPct.TextSize=14
	spPct.TextStrokeTransparency=0.5
	spPct.TextStrokeColor3=Color3.fromRGB(0,0,0)
	spPct.TextXAlignment=Enum.TextXAlignment.Center
	spPct.TextYAlignment=Enum.TextYAlignment.Center
	spPct.ZIndex=304

	-- Small Discord link displayed on the Auto Grab bar
	local discordLabel=Instance.new("TextLabel",spFrame)
	discordLabel.Name="DiscordLink"
	discordLabel.Size=UDim2.new(1,-28,0,11)
	discordLabel.Position=UDim2.new(0,14,0,23)
	discordLabel.BackgroundTransparency=1
	discordLabel.Text="discord.gg/wN95Sj2yj"
	discordLabel.TextColor3=Color3.fromRGB(255,255,255)
	discordLabel.Font=Enum.Font.Gotham
	discordLabel.TextSize=8
	discordLabel.TextTransparency=0.15
	discordLabel.TextStrokeTransparency=0.8
	discordLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
	discordLabel.TextXAlignment=Enum.TextXAlignment.Center
	discordLabel.TextYAlignment=Enum.TextYAlignment.Center
	discordLabel.ZIndex=304
	-- Add a subtle glow to text (duplicate behind)
	local textShadow=spPct:Clone()
	textShadow.Name="TextShadow"
	textShadow.Parent=spFrame
	textShadow.TextColor3=Color3.fromRGB(0,0,0)
	textShadow.TextStrokeTransparency=1
	textShadow.TextTransparency=0.8
	textShadow.ZIndex=303
	textShadow.Size=UDim2.new(1,-28,0,22)
	textShadow.Position=UDim2.new(0,14,0,1)  -- slight offset

	progressFill=spFill
	progressPct=spPct

	-- Toggle button (invisible, covers whole pill)
	local spToggleBtn=Instance.new("TextButton",spFrame)
	spToggleBtn.Name="ToggleGUIBtn"
	spToggleBtn.Size=UDim2.new(1,0,1,0)
	spToggleBtn.BackgroundTransparency=1
	spToggleBtn.Text=""
	spToggleBtn.AutoButtonColor=false
	spToggleBtn.ZIndex=310
	local _spWasDragged=false
	spToggleBtn.Activated:Connect(function()
		if _spWasDragged then return end
		local base=spFrame.Size
		TS:Create(spFrame,TweenInfo.new(0.08),{Size=UDim2.new(base.X.Scale,base.X.Offset*0.95,base.Y.Scale,base.Y.Offset*0.9)}):Play()
		task.delay(0.1,function() TS:Create(spFrame,TweenInfo.new(0.16,Enum.EasingStyle.Back),{Size=base}):Play() end)
	end)

	-- drive fill/label — always locked at 99%
	local FILL_DURATION = 0.2
	local _lastPct=0.99
	RunService.RenderStepped:Connect(function()
		if not spFrame.Visible then return end
		-- Force the bar to stay permanently at 99%
		local f = 0.99
		_lastPct = f
		spFill.Size=UDim2.new(f,-6*f,1,-6)
		-- Auto Grab is always armed: keep the bar visually READY.
		spPct.Text="READY"
		spPct.TextColor3=Color3.fromRGB(120,255,140)
		textShadow.TextColor3=Color3.fromRGB(0,0,0)
	end)

	-- drag handling with off-screen clamp
	local dragging,dragStart,startPos=false,nil,nil
	spToggleBtn.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
			dragging=true;_spWasDragged=false;dragStart=inp.Position;startPos=spFrame.Position
			inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if not dragging then return end
		if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
			local dx=inp.Position.X-dragStart.X
			local dy=inp.Position.Y-dragStart.Y
			if math.abs(dx)>5 or math.abs(dy)>5 then _spWasDragged=true end
			local cam=workspace.CurrentCamera
			local vp=cam and cam.ViewportSize or Vector2.new(1000,1000)
			local sz=spFrame.AbsoluteSize
			local newXScalePx=startPos.X.Scale*vp.X
			local newX=math.clamp(newXScalePx+startPos.X.Offset+dx,sz.X/2,vp.X-sz.X/2)
			local newY=math.clamp(startPos.Y.Scale*vp.Y+startPos.Y.Offset+dy,sz.Y,vp.Y)
			spFrame.Position=UDim2.new(startPos.X.Scale,newX-newXScalePx,startPos.Y.Scale,newY-startPos.Y.Scale*vp.Y)
			-- move shadow with it
			shadow.Position=UDim2.new(spFrame.Position.X.Scale,spFrame.Position.X.Offset,spFrame.Position.Y.Scale,spFrame.Position.Y.Offset+3)
		end
	end)
	-- Sync shadow position on any move
	local function updateShadow()
		shadow.Position=UDim2.new(spFrame.Position.X.Scale,spFrame.Position.X.Offset,spFrame.Position.Y.Scale,spFrame.Position.Y.Offset+3)
	end
	spFrame:GetPropertyChangedSignal("Position"):Connect(updateShadow)
	updateShadow()

	_G._CursedSetProgressBarVisible=function(v) spFrame.Visible=v; shadow.Visible=v end
end

-- auto grab always on
Steal.AutoStealEnabled=true
pcall(startAutoSteal)

-- ============================================================
-- ANTI‑DIE — ALWAYS ENABLED
-- Prevents death: instantly restores health if it hits 0,
-- and replaces the humanoid on death.
-- ============================================================
do
	local Workspace = game:GetService("Workspace")
	local connections = {}

	local function enableAntiDie()
		local char = LP.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		-- Health monitor: keep health at max if it drops to 0 or below
		local healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
			if hum.Health <= 0 then
				hum.Health = hum.MaxHealth
			end
		end)
		table.insert(connections, healthConn)

		-- Death handler: replace the dead humanoid with a fresh one
		local diedConn = hum.Died:Connect(function()
			task.wait()  -- wait a frame for death animation
			pcall(function()
				local newHum = Instance.new("Humanoid")
				newHum.Name = "Humanoid"
				newHum.Parent = char
				if Workspace.CurrentCamera then
					Workspace.CurrentCamera.CameraSubject = newHum
				end
				hum:Destroy()
			end)
		end)
		table.insert(connections, diedConn)
	end

	local function setup()
		for _, conn in pairs(connections) do
			pcall(conn.Disconnect, conn)
		end
		connections = {}
		enableAntiDie()
	end

	setup()
	LP.CharacterAdded:Connect(function()
		task.wait(0.1)
		setup()
	end)
end
