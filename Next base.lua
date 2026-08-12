-- Next Empty Base (discord.gg/rmyzCM7Wy
)
    task.spawn(function()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local parent
    if gethui then
        pcall(function() parent = gethui() end)
    end
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent and player then
        parent = player:WaitForChild("PlayerGui")
    end
    if not parent then return end

    local old = parent:FindFirstChild("TPSweetBanner")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "TPSweetBanner"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999
    gui.Parent = parent

    local backing = Instance.new("Frame")
    backing.AnchorPoint = Vector2.new(0.5,0)
    backing.Position = UDim2.new(0.5,0,0,8)
    backing.Size = UDim2.fromOffset(420,56)
    backing.BackgroundColor3 = Color3.fromRGB(2,8,30)
    backing.BackgroundTransparency = 0.35
    backing.BorderSizePixel = 0
    backing.Parent = gui

    local corner = Instance.new("UICorner", backing)
    corner.CornerRadius = UDim.new(1,0)

    local stroke = Instance.new("UIStroke", backing)
    stroke.Color = Color3.fromRGB(120,200,255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5,0.5)
    label.Position = UDim2.new(0.5,0,0.5,0)
    label.Size = UDim2.new(1,-20,1,-12)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.Text = "discord.gg/rmyzCM7Wy
"
    label.TextColor3 = Color3.new(1,1,1)
    label.TextStrokeColor3 = Color3.fromRGB(5,15,40)
    label.TextStrokeTransparency = 0
    label.Parent = backing

    local constraint = Instance.new("UITextSizeConstraint", label)
    constraint.MaxTextSize = 30
    constraint.MinTextSize = 18

    local grad = Instance.new("UIGradient", label)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(150,220,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0,140,255))
    }
end)

if _G.__NextBaseCleanup then pcall(_G.__NextBaseCleanup) end
local Plots = workspace:WaitForChild("Plots")
local BASE_POSITIONS = {
	Vector3.new(-342.439, 10.399, 113.107),
	Vector3.new(-342.439, 10.465,   6.107),
	Vector3.new(-476.752, 10.465, 114.107),
	Vector3.new(-476.752, 10.465,   7.107),
	Vector3.new(-342.440, 10.464, 220.107),
	Vector3.new(-476.752, 10.465, 221.107),
	Vector3.new(-342.439, 10.465,-100.893),
	Vector3.new(-476.752, 10.465, -99.893),
}
local MATCH_TOL = 6
local EMPTY_TEXT = "Empty Base"
local ARROW = utf8.char(0x2B07)
local function baseIndexFor(model)
	local ok, cf = pcall(function() return (model:GetBoundingBox()) end)
	if not ok then return nil end
	local p, bestI, bestD = cf.Position
	for i, bp in ipairs(BASE_POSITIONS) do
		local dx, dz = p.X - bp.X, p.Z - bp.Z
		local d = math.sqrt(dx * dx + dz * dz)
		if not bestD or d < bestD then bestI, bestD = i, d end
	end
	return (bestD and bestD <= MATCH_TOL) and bestI or nil
end
local bases = {}
local connected = {}
local conns = {}
local anchor = Instance.new("Part")
anchor.Name = "__NextBaseAnchor"
anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
anchor.Transparency = 1
anchor.Size = Vector3.new(1, 1, 1)
anchor.Parent = workspace
local bb = Instance.new("BillboardGui")
bb.Name = "NextBaseBillboard"
bb.Adornee = anchor
bb.Size = UDim2.fromScale(32, 13)
bb.StudsOffset = Vector3.new(0, 10, 0)
bb.MaxDistance = math.huge
bb.AlwaysOnTop = true
bb.LightInfluence = 0
bb.Enabled = false
bb.Parent = anchor
local top = Instance.new("TextLabel", bb)
top.BackgroundTransparency = 1
top.AnchorPoint = Vector2.new(0.5, 0.5)
top.Position = UDim2.fromScale(0.5, 0.30)
top.Size = UDim2.fromScale(0.95, 0.50)
top.Font = Enum.Font.GothamBlack
top.Text = ARROW .. "  NEXT  " .. ARROW
top.TextScaled = true
top.TextColor3 = Color3.fromRGB(46, 230, 92)
top.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
top.TextStrokeTransparency = 0
local bottom = Instance.new("TextLabel", bb)
bottom.BackgroundTransparency = 1
bottom.AnchorPoint = Vector2.new(0.5, 0.5)
bottom.Position = UDim2.fromScale(0.5, 0.72)
bottom.Size = UDim2.fromScale(0.95, 0.42)
bottom.Font = Enum.Font.GothamBlack
bottom.Text = "EMPTY BASE"
bottom.TextScaled = true
bottom.TextColor3 = Color3.fromRGB(255, 255, 255)
bottom.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
bottom.TextStrokeTransparency = 0
local function isEmpty(label)
	return (label.Text:gsub("^%s+", ""):gsub("%s+$", "")) == EMPTY_TEXT
end
local function recompute()
	local targetIdx
	for i = 1, #BASE_POSITIONS do
		local b = bases[i]
		if b and b.label and isEmpty(b.label) then targetIdx = i break end
	end
	if targetIdx then
		anchor.CFrame = bases[targetIdx].cf
		bb.Enabled = true
	else
		bb.Enabled = false
	end
end
local function connectLabel(label)
	if connected[label] then return end
	connected[label] = true
	table.insert(conns, label:GetPropertyChangedSignal("Text"):Connect(recompute))
end
local function scan()
	for _, plot in ipairs(Plots:GetChildren()) do
		local sign  = plot:FindFirstChild("PlotSign")
		local model = sign and sign:FindFirstChild("Model")
		local gui   = sign and sign:FindFirstChild("SurfaceGui")
		local fr    = gui and gui:FindFirstChild("Frame")
		local label = fr and fr:FindFirstChild("TextLabel")
		if model and label then
			local idx = baseIndexFor(model)
			if idx then
				bases[idx] = { label = label, cf = (select(1, model:GetBoundingBox())) }
				connectLabel(label)
			end
		end
	end
	recompute()
end
scan()
table.insert(conns, Plots.DescendantAdded:Connect(function(d)
	if d:IsA("TextLabel") then task.defer(scan) end
end))
table.insert(conns, Plots.ChildAdded:Connect(function() task.defer(scan) end))
_G.__NextBaseCleanup = function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if anchor then anchor:Destroy() end
	_G.__NextBaseCleanup = nil
end
