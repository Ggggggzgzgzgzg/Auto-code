-- LEAK BY PRINCE THE OWNER GIVE IT TO ME

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local lp = Players.LocalPlayer

local STEAL_RADIUS = 60
local STEAL_DURATION = 1.4
local isStealing = false
local StealData = {}
local progressBarBg = nil
local progressFill = nil
local percentLabel = nil
local bannerFrame = nil
local infoLabel = nil

local function updateTopBar()
    if not infoLabel then return end
    local fps = 60
    local ping = 0
    local framesCount = 0
    local last = tick()
    RunService.RenderStepped:Connect(function()
        framesCount = framesCount + 1
        if tick() - last >= 1 then
            fps = framesCount
            framesCount = 0
            last = tick()
        end
        local network = Stats:FindFirstChild("Network")
        if network and network:FindFirstChild("ServerStatsItem") then
            local dataPing = network.ServerStatsItem:FindFirstChild("Data Ping")
            if dataPing then ping = math.floor(dataPing:GetValue()) end
        end
        infoLabel.Text = "Zermerx hub | Ping: " .. ping .. "ms | FPS: " .. fps
    end)
end

local function setupUI()
    local sg = lp.PlayerGui:FindFirstChild("J hub ")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "J hub "
        sg.ResetOnSpawn = false
        sg.Parent = lp.PlayerGui
    end

    if not progressBarBg then
        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 260, 0, 70)
        container.Position = UDim2.new(0.5, -130, 0, 35)
        container.BackgroundTransparency = 1
        container.Parent = sg

        bannerFrame = Instance.new("Frame")
        bannerFrame.Size = UDim2.new(1, 0, 0, 30)
        bannerFrame.Position = UDim2.new(0, 0, 0, 0)
        bannerFrame.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        bannerFrame.BackgroundTransparency = 0.85
        bannerFrame.BorderSizePixel = 0
        bannerFrame.Parent = container
        Instance.new("UICorner", bannerFrame).CornerRadius = UDim.new(0, 8)

        local bannerStroke = Instance.new("UIStroke", bannerFrame)
        bannerStroke.Color = Color3.fromRGB(0, 170, 0)
        bannerStroke.Thickness = 1.5

        infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, 0, 1, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextSize = 14
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.Text = "Irish Hub | Ping: 0ms | FPS: 0"
        infoLabel.TextXAlignment = Enum.TextXAlignment.Center
        infoLabel.Parent = bannerFrame

        progressBarBg = Instance.new("Frame")
        progressBarBg.Size = UDim2.new(1, 0, 0, 14)
        progressBarBg.Position = UDim2.new(0, 0, 0, 34)
        progressBarBg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        progressBarBg.BackgroundTransparency = 0.25
        progressBarBg.Visible = true
        progressBarBg.Parent = container
        Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0, 10)

        progressFill = Instance.new("Frame")
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        progressFill.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        progressFill.Parent = progressBarBg
        Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 10)

        percentLabel = Instance.new("TextLabel")
        percentLabel.Size = UDim2.new(1, 0, 1, 0)
        percentLabel.BackgroundTransparency = 1
        percentLabel.Font = Enum.Font.GothamBold
        percentLabel.TextSize = 11
        percentLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        percentLabel.Text = "0%"
        percentLabel.Parent = progressBarBg

        updateTopBar()
    end
end

local function getHRP()
    local c = lp.Character
    if c then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
    return nil
end

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function findNearestPrompt()
    local hrp = getHRP()
    if not hrp then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local nearest, dist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            local base = pod:FindFirstChild("Base")
            if not base then continue end
            local spawn = base:FindFirstChild("Spawn")
            if not spawn then continue end
            local d = (spawn.Position - hrp.Position).Magnitude
            if d <= STEAL_RADIUS and d < dist then
                local att = spawn:FindFirstChild("PromptAttachment")
                if att then
                    for _, p in ipairs(att:GetChildren()) do
                        if p:IsA("ProximityPrompt") and p.ActionText and p.ActionText:find("Steal") then
                            nearest, dist = p, d
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function updateProgressBar(p)
    if progressFill then
        progressFill.Size = UDim2.new(p, 0, 1, 0)
    end
    if percentLabel then
        percentLabel.Text = math.floor(p * 100) .. "%"
    end
end

local function executeSteal(prompt)
    if isStealing then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        if getconnections then
            for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                if c.Function then table.insert(StealData[prompt].hold, c.Function) end
            end
            for _, c in ipairs(getconnections(prompt.Triggered)) do
                if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
            end
        end
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    local startTime = tick()
    task.spawn(function()
        for _, f in ipairs(data.hold) do pcall(f) end
        while tick() - startTime < STEAL_DURATION do
            local elapsed = tick() - startTime
            local p = math.clamp(elapsed / STEAL_DURATION, 0, 1)
            updateProgressBar(p)
            task.wait()
        end
        updateProgressBar(1)
        for _, f in ipairs(data.trigger) do pcall(f) end
        task.wait(0.05)
        updateProgressBar(0)
        data.ready = true
        isStealing = false
    end)
end

local heartbeatConn
local function startAutoSteal()
    setupUI()
    if heartbeatConn then return end
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if isStealing then return end
        local success, prompt = pcall(findNearestPrompt)
        if success and prompt then pcall(executeSteal, prompt) end
    end)
end

local function stopAutoSteal()
    if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
    isStealing = false
    updateProgressBar(0)
end

startAutoSteal()
