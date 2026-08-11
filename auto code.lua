local Players    = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────
--  CONFIG  (persisted to file)
-- ─────────────────────────────────────────
local CFG_PATH = "notif_scanner_config.json"

-- defaults
local cfg = {
    scanEnabled  = true,
    autoCode     = true,
    captureCount = 4,
    keywords     = { "code is", "", "", "", "", "", "", "", "", "" },
    replaceRules = { {kw="admin war",rep="jandel"},{kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
                     {kw="",rep=""},{kw="",rep=""},{kw="",rep=""},{kw="",rep=""},
                     {kw="",rep=""},{kw="",rep=""} },
    posX         = -120,
    posY         = -120,
    minimized    = false,
    activeTab    = 1,   -- 1 = Main, 2 = Keyword Dropdown, 3 = Replace, 4 = Status
}

local function saveConfig()
    if not writefile then return end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(cfg))
end

local function loadConfig()
    if not (readfile and isfile and isfile(CFG_PATH)) then return end
    local ok, dec = pcall(function()
        return HttpService:JSONDecode(readfile(CFG_PATH))
    end)
    if ok and type(dec) == "table" then
        for k, v in pairs(dec) do cfg[k] = v end
    end
end

loadConfig()

-- ─────────────────────────────────────────
--  COLOUR / STYLE TOKENS
-- ─────────────────────────────────────────
local C = {
    bg0       = Color3.fromRGB(12, 12, 12),
    bg1       = Color3.fromRGB(18, 18, 18),
    bg2       = Color3.fromRGB(26, 26, 26),
    bg3       = Color3.fromRGB(20, 19, 15),
    accent    = Color3.fromRGB(220, 160, 60),
    accentDim = Color3.fromRGB(100, 72, 28),
    accentSec = Color3.fromRGB(255, 200, 90),
    activeTabText = Color3.fromRGB(255, 255, 225),
    toggleOff = Color3.fromRGB(38, 34, 26),
    toggleOn  = Color3.fromRGB(180, 120, 40),
    knob      = Color3.fromRGB(255, 220, 140),
    textPri   = Color3.fromRGB(235, 215, 170),
    textMuted = Color3.fromRGB(100, 85, 60),
    inputBg   = Color3.fromRGB(14, 13, 10),
    tweenFast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    tweenMed  = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    toggleW   = 40,
    toggleH   = 20,
    knobSz    = 16,
}

-- ─────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 8)
    c.Parent = p
end

local function stroke(p, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.accent
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
end

-- ─────────────────────────────────────────
--  SCANNER STATE  (initialised from cfg)
-- ─────────────────────────────────────────
local scanEnabled    = true  -- always enabled; toggle removed
local autoCode       = cfg.autoCode == true
local filterKeywords = {}   -- runtime table; synced to cfg.keywords on every write
local replaceRules   = {}   -- runtime table; synced to cfg.replaceRules on every write
local captureCount   = cfg.captureCount

-- collection state
local collecting      = false
local collectBuf      = {}
local collectRemain   = 0
local forceScanActive = false   -- set by Force Scan + Code button

local MAX_FILTERS = 10
local BOX_H       = 22
local BOX_GAP     = 4
local SCROLL_H    = 100

-- initialise filterKeywords from saved cfg
for i = 1, MAX_FILTERS do
    filterKeywords[i] = (type(cfg.keywords) == "table" and cfg.keywords[i]) or ""
end

-- initialise replaceRules from saved cfg
for i = 1, MAX_FILTERS do
    local saved = type(cfg.replaceRules) == "table" and cfg.replaceRules[i]
    replaceRules[i] = { kw = (saved and saved.kw) or "", rep = (saved and saved.rep) or "" }
end

-- ─────────────────────────────────────────
--  STATUS LOG
-- ─────────────────────────────────────────
local statusLog = {}
local statusScrollRef = nil   -- assigned after GUI creation

local function logStatus(msg)
    local t = os.date and os.date("%H:%M:%S") or "??"
    local entry = "[" .. t .. "] " .. msg
    table.insert(statusLog, entry)
    print("[STATUS] " .. entry)
    -- Update the scroll frame if it exists
    if statusScrollRef then
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -8, 0, 0)
        lbl.AutomaticSize          = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.Code
        lbl.TextSize               = 10
        lbl.TextColor3             = C.textPri
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.TextWrapped            = true
        lbl.RichText               = false
        lbl.Text                   = entry
        lbl.Parent                 = statusScrollRef
        -- Auto-scroll to bottom
        task.defer(function()
            statusScrollRef.CanvasPosition = Vector2.new(0, math.huge)
        end)
    end
end



local seen = {}

-- forward-declared; assigned after ScreenGui creation
local vonGui

local function isOwnedByUs(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur == vonGui then return true end
        cur = cur.Parent
    end
    return false
end

local function getText(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return obj.Text
    end
    return nil
end

local function matchesKeyword(text)
    if not text or text == "" then return false end
    local hasAny = false
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" then hasAny = true; break end
    end
    if not hasAny then return true end
    local lower = text:lower()
    for _, kw in ipairs(filterKeywords) do
        if kw ~= "" and lower:find(kw:lower(), 1, true) then return true end
    end
    return false
end

-- Attempts to redeem `notif` as a code via the in-game Codes UI.
-- Runs in a protected pcall so any missing UI never breaks the scanner.
local function redeemCode(notif)
    pcall(function()
        local Codes         = PlayerGui:WaitForChild("Codes", 3).Codes
        local textBox       = Codes.CodeRedeem.TextBox
        local confirmButton = Codes.Confirm
        textBox.Text        = notif
        local button = confirmButton:FindFirstChildWhichIsA("TextButton") or confirmButton
        if button then
            firesignal(button.MouseButton1Click)
            firesignal(button.Activated)
        end
    end)
end

-- Returns the replacement string if `text` matches any replace rule keyword,
-- otherwise returns nil (meaning: use original text).
local function applyReplace(text)
    if not text or text == "" then return nil end
    local lower = text:lower()
    for _, rule in ipairs(replaceRules) do
        if rule.kw ~= "" and lower:find(rule.kw:lower(), 1, true) then
            return rule.rep  -- could be "" meaning suppress entirely
        end
    end
    return nil
end

local function dispatch(text)
    if not scanEnabled then return end
    if not text or text == "" then return end

    -- Force Scan: collecting flag already armed; bypass keyword gate entirely
    if forceScanActive and collecting then
        logStatus("Notification received (Force Scan): " .. text)
        table.insert(collectBuf, text)
        collectRemain = collectRemain - 1
        logStatus("Code tracking update: [" .. table.concat(collectBuf) .. "] (" .. collectRemain .. " remaining)")
        if collectRemain <= 0 then
            local result = table.concat(collectBuf)
            print(result)
            logStatus("Submit Code triggered → entering: " .. result)
            redeemCode(result)   -- always redeem on a forced scan
            collecting      = false
            collectBuf      = {}
            collectRemain   = 0
            forceScanActive = false
            logStatus("Force Scan complete")
        end
        return
    end

    if captureCount > 0 then
        if collecting then
            logStatus("Notification received (collecting): " .. text)
            -- Apply per-notification replacement
            -- leave all others untouched, then concatenate.
            local replaced = applyReplace(text)
            if replaced ~= nil then
                table.insert(collectBuf, replaced)
                logStatus("Replace performed: [" .. text .. "] → [" .. replaced .. "]")
            else
                table.insert(collectBuf, text)
            end
            collectRemain = collectRemain - 1
            logStatus("Current tracked code: [" .. table.concat(collectBuf) .. "] (" .. collectRemain .. " remaining)")
            if collectRemain <= 0 then
                local result = table.concat(collectBuf)
                if result ~= "" then
                    print(result)
                    logStatus("Submit Code triggered → entering: " .. result)
                    if autoCode then redeemCode(result) end
                end
                collecting    = false
                collectBuf    = {}
                collectRemain = 0
            end
        else
            if matchesKeyword(text) then
                logStatus("Trigger keyword detected in: " .. text)
                collecting    = true
                collectBuf    = {}
                collectRemain = captureCount
                logStatus("Code tracking started, collecting " .. captureCount .. " notification(s)")
            else
                logStatus("Notification scanned (no match): " .. text)
            end
        end
        return
    end

    if matchesKeyword(text) then
        logStatus("Notification scanned – keyword match: " .. text)
        local replaced = applyReplace(text)
        local result   = replaced ~= nil and replaced or text
        if replaced ~= nil then
            logStatus("Replace performed: [" .. text .. "] → [" .. replaced .. "]")
        end
        if result ~= "" then
            print(result)
            logStatus("Text entered: " .. result)
            if autoCode then redeemCode(result) end
        end
    else
        logStatus("Notification scanned (no match): " .. text)
    end
end

-- ─────────────────────────────────────────
--  WATCHER
-- ─────────────────────────────────────────
local function watchObject(obj)
    if seen[obj] then return end
    if isOwnedByUs(obj) then return end
    seen[obj] = true

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not isOwnedByUs(obj) and obj.Text ~= "" then
                dispatch(obj.Text)
            end
        end)
    end

    for _, child in ipairs(obj:GetDescendants()) do
        watchObject(child)
    end

    obj.DescendantAdded:Connect(function(child)
        if isOwnedByUs(child) then return end
        local isNew = not seen[child]
        watchObject(child)
        if isNew then
            local t = getText(child)
            if t and t ~= "" then dispatch(t) end
        end
    end)
end

local function hookContainers()
    local names = { "TopNotification" }
    for _, name in ipairs(names) do
        local c = PlayerGui:FindFirstChild(name)
        if c then watchObject(c) end
    end
    PlayerGui.ChildAdded:Connect(function(child)
        for _, name in ipairs(names) do
            if child.Name == name then watchObject(child) end
        end
    end)
end
hookContainers()

-- ─────────────────────────────────────────
--  SPAWN WATCHER  (Notification folder)
-- ─────────────────────────────────────────
local WEBHOOK_URL = "https://discord.com/api/webhooks/1503607870649008208/ZjX8PnBgFMrWfSZbEpS2-5yOMFl94Wi9PPspx0CjBtWeaz4LAcCz44NLYLUMmK29GOng"

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

local function sendWebhook(spawnedName)
    if not httpRequest then return end
    local displayName = Players.LocalPlayer and Players.LocalPlayer.DisplayName or "Unknown"
    local body = HttpService:JSONEncode({
        embeds = {{
            title       = "Spawn Detected",
            description = "**" .. spawnedName .. "** spawned!\nPlayer: **" .. displayName .. "**",
            color       = 0x92FF67,
        }}
    })
    pcall(function()
        httpRequest({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)
end

local function checkSpawn(obj)
    if not obj:IsA("TextLabel") then return end
    local txt = obj.Text
    if type(txt) ~= "string" then return end
    -- strip rich-text tags, e.g. <font color="#92FF67">Apple spawned!</font>
    local plain = txt:gsub("<[^>]+>", "")
    local name = plain:match("^(.-)%s+spawned!%s*$")
    if name and name ~= "" then
        logStatus("Spawn detected: " .. name .. " spawned!")
        print("[SPAWN] " .. name .. " spawned!")
        sendWebhook(name)
    end
end

local function hookSpawnFolder()
    local ok, folder = pcall(function()
        return PlayerGui
            :WaitForChild("Notification", 10)
            :WaitForChild("Notification", 10)
    end)
    if not ok or not folder then
        logStatus("Spawn watcher: Notification folder not found")
        return
    end
    -- scan children already present
    for _, obj in ipairs(folder:GetChildren()) do
        checkSpawn(obj)
    end
    -- watch new children
    folder.ChildAdded:Connect(function(obj)
        task.wait()   -- let text populate
        checkSpawn(obj)
    end)
end

task.spawn(hookSpawnFolder)

-- title(TITLE_H) + tabBar(TABBAR_H) + page
-- page1 (Main)      = pad*2 + 4 rows * ROW_H + 3 gaps * ROW_GAP
-- page2 (Keywords)  = pad*2 + filterSection
-- filterSection     = header(34) + divider(1) + gap(4) + scroll(SCROLL_H) + bpad(8)
-- ─────────────────────────────────────────
local TITLE_H  = 36
local TABBAR_H = 37
local ROW_H    = 34
local ROW_GAP  = 6
local PAGE_PAD = 10

local FILTER_SECTION_H = 34 + 1 + 4 + SCROLL_H + 8

local PAGE1_H = (ROW_H * 4 + ROW_GAP * 3) + PAGE_PAD * 2
local PAGE2_H = FILTER_SECTION_H + PAGE_PAD * 2

local FULL_H_MAIN = TITLE_H + TABBAR_H + PAGE1_H
local FULL_H_KEY  = TITLE_H + TABBAR_H + PAGE2_H
local FULL_H_REP  = TITLE_H + TABBAR_H + PAGE2_H   -- same height as keyword page
local MIN_H       = TITLE_H

-- ─────────────────────────────────────────
--  ROOT GUI
-- ─────────────────────────────────────────
vonGui = Instance.new("ScreenGui")
vonGui.Name           = "vonNotifScanner"
vonGui.ResetOnSpawn   = false
vonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
vonGui.Parent         = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size                   = UDim2.new(0, 310, 0, FULL_H_MAIN)
mainFrame.Position               = UDim2.new(0.5, cfg.posX, 0.5, cfg.posY)
mainFrame.BackgroundColor3       = C.bg1
mainFrame.BackgroundTransparency = 0.04
mainFrame.Active                 = true
mainFrame.Parent                 = vonGui
corner(mainFrame, UDim.new(0, 10))
stroke(mainFrame, C.accent, 1.2)

-- ── Title bar ──────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
titleBar.BorderSizePixel  = 0
titleBar.Active           = true
titleBar.Selectable       = true
titleBar.Parent           = mainFrame
corner(titleBar, UDim.new(0, 10))

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -52, 1, 0)
titleLabel.Position               = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font                   = Enum.Font.GothamBlack
titleLabel.TextSize               = 14
titleLabel.TextColor3             = Color3.fromRGB(0, 0, 0)
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.Text                   = "ZERMERX AUTO CODE"
titleLabel.Parent                 = titleBar

local discordSubtitle = Instance.new("TextLabel")
discordSubtitle.Size                   = UDim2.new(1, -52, 0, 12)
discordSubtitle.Position               = UDim2.new(0, 14, 0, 20)
discordSubtitle.BackgroundTransparency = 1
discordSubtitle.Font                   = Enum.Font.Gotham
discordSubtitle.TextSize               = 9
discordSubtitle.TextColor3             = Color3.fromRGB(0, 0, 0)
discordSubtitle.TextXAlignment         = Enum.TextXAlignment.Left
discordSubtitle.Text                   = "discord.gg/8UeHYWayU"
discordSubtitle.Parent                 = titleBar

local titleGloss = Instance.new("Frame")
titleGloss.Name                   = "titleGloss"
titleGloss.Size                   = UDim2.new(1, 0, 0, 8)
titleGloss.Position               = UDim2.new(0, 0, 0, 0)
titleGloss.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
titleGloss.BackgroundTransparency = 0.75
titleGloss.BorderSizePixel        = 0
titleGloss.ZIndex                 = 2
titleGloss.Parent                 = titleBar


local accentLine = Instance.new("Frame")
accentLine.Size                   = UDim2.new(1, -20, 0, 1)
accentLine.Position               = UDim2.new(0, 10, 1, 0)
accentLine.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
accentLine.BackgroundTransparency = 0.5
accentLine.BorderSizePixel        = 0
accentLine.Parent                 = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size                   = UDim2.new(0, 28, 0, 20)
minBtn.AnchorPoint            = Vector2.new(1, 0.5)
minBtn.Position               = UDim2.new(1, -8, 0.5, 0)
minBtn.BackgroundColor3       = C.accentDim
minBtn.BorderSizePixel        = 0
minBtn.Font                   = Enum.Font.GothamBlack
minBtn.TextSize               = 14
minBtn.TextColor3             = C.accentSec
minBtn.Text                   = "–"
minBtn.Parent                 = titleBar
corner(minBtn, UDim.new(0, 5))

-- ── Tab bar ────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Position               = UDim2.new(0, 0, 0, TITLE_H)
tabBar.Size                   = UDim2.new(1, 0, 0, TABBAR_H)
tabBar.BackgroundTransparency = 1
tabBar.Parent                 = mainFrame

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft   = UDim.new(0, 10)
tabPadding.PaddingRight  = UDim.new(0, 10)
tabPadding.PaddingTop    = UDim.new(0, 11)
tabPadding.PaddingBottom = UDim.new(0, 2)
tabPadding.Parent        = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection       = Enum.FillDirection.Horizontal
tabLayout.Padding             = UDim.new(0, 6)
tabLayout.SortOrder           = Enum.SortOrder.LayoutOrder
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.Parent              = tabBar

local tabUnderline = Instance.new("Frame")
tabUnderline.Size                   = UDim2.new(1, -20, 0, 1)
tabUnderline.Position               = UDim2.new(0, 10, 1, 0)
tabUnderline.BackgroundColor3       = C.accentDim
tabUnderline.BackgroundTransparency = 0.3
tabUnderline.BorderSizePixel        = 0
tabUnderline.Parent                 = mainFrame

local function makeTabButton(text, order)
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(0.25, -3, 1, 0)
    btn.LayoutOrder            = order
    btn.BackgroundColor3       = C.bg2
    btn.BorderSizePixel        = 0
    btn.AutoButtonColor        = false
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 12
    btn.TextColor3             = C.textMuted
    btn.Text                   = text
    btn.Parent                 = tabBar
    corner(btn, UDim.new(0, 6))
    stroke(btn, C.accentDim, 1)

    local fit = Instance.new("UITextSizeConstraint")
    fit.MaxTextSize = 12
    fit.MinTextSize = 8
    fit.Parent      = btn
    btn.TextScaled  = true

    return btn
end

local tabMainBtn    = makeTabButton("Main", 1)
local tabKeyBtn     = makeTabButton("Triggers", 2)
local tabReplaceBtn = makeTabButton("Replace", 3)
local tabStatusBtn  = makeTabButton("Status", 4)

-- ── Content frame ──────────────────────────────────────────────────────────
local contentFrame = Instance.new("Frame")
contentFrame.Position               = UDim2.new(0, 0, 0, TITLE_H + TABBAR_H)
contentFrame.Size                   = UDim2.new(1, 0, 1, -(TITLE_H + TABBAR_H))
contentFrame.BackgroundTransparency = 1
contentFrame.Parent                 = mainFrame

-- Page 1: Main controls
local page1 = Instance.new("Frame")
page1.Size                   = UDim2.new(1, 0, 1, 0)
page1.BackgroundTransparency = 1
page1.Parent                 = contentFrame

local layout = Instance.new("UIListLayout")
layout.Padding             = UDim.new(0, 6)
layout.SortOrder           = Enum.SortOrder.LayoutOrder
layout.FillDirection       = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment   = Enum.VerticalAlignment.Top
layout.Parent              = page1

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 10)
padding.PaddingRight  = UDim.new(0, 10)
padding.PaddingTop    = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent        = page1

-- Page 2: Keyword Dropdown (triggers)
local page2 = Instance.new("Frame")
page2.Size                   = UDim2.new(1, 0, 1, 0)
page2.BackgroundTransparency = 1
page2.Visible                = false
page2.Parent                 = contentFrame

local page2Layout = Instance.new("UIListLayout")
page2Layout.Padding             = UDim.new(0, 6)
page2Layout.SortOrder           = Enum.SortOrder.LayoutOrder
page2Layout.FillDirection       = Enum.FillDirection.Vertical
page2Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
page2Layout.VerticalAlignment   = Enum.VerticalAlignment.Top
page2Layout.Parent              = page2

local page2Padding = Instance.new("UIPadding")
page2Padding.PaddingLeft   = UDim.new(0, 10)
page2Padding.PaddingRight  = UDim.new(0, 10)
page2Padding.PaddingTop    = UDim.new(0, 10)
page2Padding.PaddingBottom = UDim.new(0, 10)
page2Padding.Parent        = page2

-- Page 3: Replace tab
local page3 = Instance.new("Frame")
page3.Size                   = UDim2.new(1, 0, 1, 0)
page3.BackgroundTransparency = 1
page3.Visible                = false
page3.Parent                 = contentFrame

local page3Layout = Instance.new("UIListLayout")
page3Layout.Padding             = UDim.new(0, 6)
page3Layout.SortOrder           = Enum.SortOrder.LayoutOrder
page3Layout.FillDirection       = Enum.FillDirection.Vertical
page3Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
page3Layout.VerticalAlignment   = Enum.VerticalAlignment.Top
page3Layout.Parent              = page3

local page3Padding = Instance.new("UIPadding")
page3Padding.PaddingLeft   = UDim.new(0, 10)
page3Padding.PaddingRight  = UDim.new(0, 10)
page3Padding.PaddingTop    = UDim.new(0, 10)
page3Padding.PaddingBottom = UDim.new(0, 10)
page3Padding.Parent        = page3

-- Page 4: Status log
local page4 = Instance.new("Frame")
page4.Size                   = UDim2.new(1, 0, 1, 0)
page4.BackgroundTransparency = 1
page4.Visible                = false
page4.Parent                 = contentFrame

local page4Padding = Instance.new("UIPadding")
page4Padding.PaddingLeft   = UDim.new(0, 10)
page4Padding.PaddingRight  = UDim.new(0, 10)
page4Padding.PaddingTop    = UDim.new(0, 10)
page4Padding.PaddingBottom = UDim.new(0, 10)
page4Padding.Parent        = page4

-- Status scroll frame
local statusScroll = Instance.new("ScrollingFrame")
statusScroll.Size                   = UDim2.new(1, 0, 1, -34)
statusScroll.Position               = UDim2.new(0, 0, 0, 0)
statusScroll.BackgroundColor3       = C.bg3
statusScroll.BackgroundTransparency = 0.2
statusScroll.BorderSizePixel        = 0
statusScroll.ScrollBarThickness     = 3
statusScroll.ScrollBarImageColor3   = C.accentDim
statusScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
statusScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
statusScroll.ClipsDescendants       = true
statusScroll.Parent                 = page4
corner(statusScroll, UDim.new(0, 5))
stroke(statusScroll, C.accentDim, 1)

local statusScrollLayout = Instance.new("UIListLayout")
statusScrollLayout.Padding             = UDim.new(0, 2)
statusScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
statusScrollLayout.FillDirection       = Enum.FillDirection.Vertical
statusScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
statusScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
statusScrollLayout.Parent              = statusScroll

local statusScrollPad = Instance.new("UIPadding")
statusScrollPad.PaddingLeft   = UDim.new(0, 4)
statusScrollPad.PaddingRight  = UDim.new(0, 4)
statusScrollPad.PaddingTop    = UDim.new(0, 4)
statusScrollPad.PaddingBottom = UDim.new(0, 4)
statusScrollPad.Parent        = statusScroll

-- Clear log button
local clearLogRow = Instance.new("Frame")
clearLogRow.Size             = UDim2.new(1, 0, 0, 28)
clearLogRow.Position         = UDim2.new(0, 0, 1, -28)
clearLogRow.BackgroundColor3 = C.bg2
clearLogRow.Parent           = page4
corner(clearLogRow, UDim.new(0, 6))
stroke(clearLogRow, C.accentDim, 1)

local clearLogBtn = Instance.new("TextButton")
clearLogBtn.Size                   = UDim2.new(1, 0, 1, 0)
clearLogBtn.BackgroundTransparency = 1
clearLogBtn.Font                   = Enum.Font.Gotham
clearLogBtn.TextSize               = 11
clearLogBtn.TextColor3             = C.textMuted
clearLogBtn.Text                   = "Clear Log"
clearLogBtn.Parent                 = clearLogRow

clearLogBtn.MouseButton1Click:Connect(function()
    statusLog = {}
    for _, child in ipairs(statusScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    logStatus("Log cleared")
end)
clearLogBtn.MouseEnter:Connect(function()
    TweenService:Create(clearLogRow, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
end)
clearLogBtn.MouseLeave:Connect(function()
    TweenService:Create(clearLogRow, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
end)

-- Wire up the status scroll reference so logStatus can write to it
statusScrollRef = statusScroll

-- Replay any log entries that happened before the GUI was ready
for _, entry in ipairs(statusLog) do
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 0, 0)
    lbl.AutomaticSize          = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.Code
    lbl.TextSize               = 10
    lbl.TextColor3             = C.textPri
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.TextWrapped            = true
    lbl.RichText               = false
    lbl.Text                   = entry
    lbl.Parent                 = statusScroll
end


-- ─────────────────────────────────────────
local forceRow = Instance.new("Frame")
forceRow.Size             = UDim2.new(1, 0, 0, 34)
forceRow.BackgroundColor3 = C.bg2
forceRow.LayoutOrder      = 0
forceRow.Parent           = page1
corner(forceRow, UDim.new(0, 7))
stroke(forceRow, C.accentDim, 1)

local forceBtn = Instance.new("TextButton")
forceBtn.Size                   = UDim2.new(1, 0, 1, 0)
forceBtn.BackgroundTransparency = 1
forceBtn.Font                   = Enum.Font.Gotham
forceBtn.TextSize               = 13
forceBtn.TextColor3             = C.textPri
forceBtn.TextXAlignment         = Enum.TextXAlignment.Center
forceBtn.Text                   = "Force Scan + Code"
forceBtn.Parent                 = forceRow

forceBtn.MouseButton1Click:Connect(function()
    -- Use captureCount if set, otherwise capture exactly 1 notification
    local n = captureCount > 0 and captureCount or 1
    -- Immediately arm a forced collection that bypasses keyword filtering
    collecting    = true
    collectBuf    = {}
    collectRemain = n
    -- Override dispatch temporarily so the NEXT n notifications are captured
    -- regardless of keywords, then auto-coded.  We do this by monkey-patching
    -- the forceScan flag read inside dispatch.
    forceScanActive = true
    logStatus("Force Scan started – collecting " .. n .. " notification(s)")
end)

forceBtn.MouseEnter:Connect(function()
    TweenService:Create(forceRow, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    TweenService:Create(forceBtn, C.tweenFast, { TextColor3 = C.accent }):Play()
end)
forceBtn.MouseLeave:Connect(function()
    TweenService:Create(forceRow, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    TweenService:Create(forceBtn, C.tweenFast, { TextColor3 = C.accentSec }):Play()
end)

-- (Scan Notifications toggle removed – scanning is always active)

-- ─────────────────────────────────────────
--  ROW 2 – Auto Code toggle
-- ─────────────────────────────────────────
local autoRow = Instance.new("Frame")
autoRow.Size             = UDim2.new(1, 0, 0, 34)
autoRow.BackgroundColor3 = C.bg2
autoRow.LayoutOrder      = 2
autoRow.Parent           = page1
corner(autoRow, UDim.new(0, 7))
stroke(autoRow, C.accentDim, 1)

local autoLabel = Instance.new("TextLabel")
autoLabel.Size                   = UDim2.new(1, -60, 1, 0)
autoLabel.Position               = UDim2.new(0, 12, 0, 0)
autoLabel.BackgroundTransparency = 1
autoLabel.Font                   = Enum.Font.Gotham
autoLabel.TextSize               = 13
autoLabel.TextColor3             = C.textPri
autoLabel.TextXAlignment         = Enum.TextXAlignment.Left
autoLabel.Text                   = "Auto Enter Code"
autoLabel.Parent                 = autoRow

local autoTrack = Instance.new("Frame")
autoTrack.AnchorPoint      = Vector2.new(1, 0.5)
autoTrack.Position         = UDim2.new(1, -10, 0.5, 0)
autoTrack.Size             = UDim2.new(0, C.toggleW, 0, C.toggleH)
autoTrack.BackgroundColor3 = autoCode and C.toggleOn or C.toggleOff
autoTrack.Parent           = autoRow
corner(autoTrack, UDim.new(1, 0))

local autoKnob = Instance.new("Frame")
autoKnob.Size             = UDim2.new(0, C.knobSz, 0, C.knobSz)
autoKnob.Position         = autoCode
    and UDim2.new(0, C.toggleW - C.knobSz - 2, 0.5, -C.knobSz / 2)
    or  UDim2.new(0, 2, 0.5, -C.knobSz / 2)
autoKnob.BackgroundColor3 = C.knob
autoKnob.Parent           = autoTrack
corner(autoKnob, UDim.new(1, 0))

local autoBtn = Instance.new("TextButton")
autoBtn.Size                   = UDim2.new(1, 0, 1, 0)
autoBtn.BackgroundTransparency = 1
autoBtn.Text                   = ""
autoBtn.Parent                 = autoRow

local function setAutoCode(on)
    autoCode        = on
    cfg.autoCode    = on
    TweenService:Create(autoTrack, C.tweenFast, { BackgroundColor3 = on and C.toggleOn or C.toggleOff }):Play()
    TweenService:Create(autoKnob, C.tweenFast, {
        Position = on
            and UDim2.new(0, C.toggleW - C.knobSz - 2, 0.5, -C.knobSz / 2)
            or  UDim2.new(0, 2, 0.5, -C.knobSz / 2)
    }):Play()
    saveConfig()
end

autoBtn.MouseButton1Click:Connect(function() setAutoCode(not autoCode) end)
autoBtn.MouseEnter:Connect(function()
    TweenService:Create(autoRow, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
end)
autoBtn.MouseLeave:Connect(function()
    TweenService:Create(autoRow, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
end)

-- ─────────────────────────────────────────
--  ROW 3 – Capture count
-- ─────────────────────────────────────────
local captureRow = Instance.new("Frame")
captureRow.Size             = UDim2.new(1, 0, 0, 34)
captureRow.BackgroundColor3 = C.bg2
captureRow.LayoutOrder      = 3
captureRow.Parent           = page1
corner(captureRow, UDim.new(0, 7))
stroke(captureRow, C.accentDim, 1)

local captureLabel = Instance.new("TextLabel")
captureLabel.Size                   = UDim2.new(1, -60, 1, 0)
captureLabel.Position               = UDim2.new(0, 12, 0, 0)
captureLabel.BackgroundTransparency = 1
captureLabel.Font                   = Enum.Font.Gotham
captureLabel.TextSize               = 13
captureLabel.TextColor3             = C.textPri
captureLabel.TextXAlignment         = Enum.TextXAlignment.Left
captureLabel.Text                   = "Submit Code After"
captureLabel.Parent                 = captureRow

local captureBox = Instance.new("TextBox")
captureBox.AnchorPoint            = Vector2.new(1, 0.5)
captureBox.Position               = UDim2.new(1, -10, 0.5, 0)
captureBox.Size                   = UDim2.new(0, C.toggleW, 0, C.toggleH)
captureBox.BackgroundColor3       = C.inputBg
captureBox.BackgroundTransparency = 0
captureBox.BorderSizePixel        = 0
captureBox.Font                   = Enum.Font.GothamBold
captureBox.TextSize               = 12
captureBox.TextColor3             = C.accentSec
captureBox.PlaceholderText        = "0"
captureBox.PlaceholderColor3      = C.textMuted
captureBox.TextXAlignment         = Enum.TextXAlignment.Center
captureBox.ClearTextOnFocus       = false
captureBox.Text                   = captureCount > 0 and tostring(captureCount) or ""
captureBox.Parent                 = captureRow
corner(captureBox, UDim.new(0, 5))

local captureStroke = Instance.new("UIStroke")
captureStroke.Color     = C.accentDim
captureStroke.Thickness = 1
captureStroke.Parent    = captureBox

captureBox.Focused:Connect(function()
    TweenService:Create(captureStroke, C.tweenFast, { Color = C.accent }):Play()
end)
captureBox.FocusLost:Connect(function()
    TweenService:Create(captureStroke, C.tweenFast, { Color = C.accentDim }):Play()
    local raw = captureBox.Text:match("%d+")
    local n   = raw and tonumber(raw) or 0
    local old = captureCount
    captureCount        = n
    cfg.captureCount    = n
    captureBox.Text     = n > 0 and tostring(n) or ""
    collecting          = false
    collectBuf          = {}
    collectRemain       = 0
    saveConfig()
end)

captureRow.MouseEnter:Connect(function()
    TweenService:Create(captureRow, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
end)
captureRow.MouseLeave:Connect(function()
    TweenService:Create(captureRow, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
end)

-- ─────────────────────────────────────────
--  ROW 4 – Copy Discord button
-- ─────────────────────────────────────────
local discordRow = Instance.new("Frame")
discordRow.Size             = UDim2.new(1, 0, 0, 34)
discordRow.BackgroundColor3 = C.bg2
discordRow.LayoutOrder      = 4
discordRow.Parent           = page1
corner(discordRow, UDim.new(0, 7))
stroke(discordRow, C.accentDim, 1)

local discordBtn = Instance.new("TextButton")
discordBtn.Size                   = UDim2.new(1, 0, 1, 0)
discordBtn.BackgroundTransparency = 1
discordBtn.Font                   = Enum.Font.Gotham
discordBtn.TextSize               = 13
discordBtn.TextColor3             = C.textPri
discordBtn.TextXAlignment         = Enum.TextXAlignment.Center
discordBtn.Text                   = "Copy Discord"
discordBtn.Parent                 = discordRow

discordBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://discord.gg/rNvAU6cjVB")
    end
end)
discordBtn.MouseEnter:Connect(function()
    TweenService:Create(discordRow, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    TweenService:Create(discordBtn, C.tweenFast, { TextColor3 = C.accent }):Play()
end)
discordBtn.MouseLeave:Connect(function()
    TweenService:Create(discordRow, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    TweenService:Create(discordBtn, C.tweenFast, { TextColor3 = C.textPri }):Play()
end)
-- ─────────────────────────────────────────
local filterSection = Instance.new("Frame")
filterSection.Size             = UDim2.new(1, 0, 0, FILTER_SECTION_H)
filterSection.BackgroundColor3 = C.bg2
filterSection.LayoutOrder      = 0
filterSection.Parent           = page2
corner(filterSection, UDim.new(0, 7))
stroke(filterSection, C.accentDim, 1)

local filterHeaderRow = Instance.new("Frame")
filterHeaderRow.Size                   = UDim2.new(1, 0, 0, 34)
filterHeaderRow.Position               = UDim2.new(0, 0, 0, 0)
filterHeaderRow.BackgroundTransparency = 1
filterHeaderRow.Parent                 = filterSection

local filterLabel = Instance.new("TextLabel")
filterLabel.Size                   = UDim2.new(1, -20, 1, 0)
filterLabel.Position               = UDim2.new(0, 12, 0, 0)
filterLabel.BackgroundTransparency = 1
filterLabel.Font                   = Enum.Font.Gotham
filterLabel.TextSize               = 13
filterLabel.TextColor3             = C.textPri
filterLabel.TextXAlignment         = Enum.TextXAlignment.Left
filterLabel.Text                   = "Triggers  (blank = all)"
filterLabel.Parent                 = filterHeaderRow

local filterDivider = Instance.new("Frame")
filterDivider.Size             = UDim2.new(1, -16, 0, 1)
filterDivider.Position         = UDim2.new(0, 8, 0, 34)
filterDivider.BackgroundColor3 = C.accentDim
filterDivider.BorderSizePixel  = 0
filterDivider.Parent           = filterSection

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                   = UDim2.new(1, -8, 0, SCROLL_H)
scrollFrame.Position               = UDim2.new(0, 4, 0, 39)
scrollFrame.BackgroundColor3       = C.bg3
scrollFrame.BackgroundTransparency = 0.2
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 3
scrollFrame.ScrollBarImageColor3   = C.accentDim
scrollFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
scrollFrame.ClipsDescendants       = true
scrollFrame.Parent                 = filterSection
corner(scrollFrame, UDim.new(0, 5))

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding             = UDim.new(0, BOX_GAP)
scrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
scrollLayout.FillDirection       = Enum.FillDirection.Vertical
scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
scrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
scrollLayout.Parent              = scrollFrame

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingLeft   = UDim.new(0, 5)
scrollPad.PaddingRight  = UDim.new(0, 5)
scrollPad.PaddingTop    = UDim.new(0, 5)
scrollPad.PaddingBottom = UDim.new(0, 5)
scrollPad.Parent        = scrollFrame

-- helper: write filterKeywords into cfg.keywords and save
local function saveKeywords()
    cfg.keywords = {}
    for i = 1, MAX_FILTERS do
        cfg.keywords[i] = filterKeywords[i] or ""
    end
    saveConfig()
end

for i = 1, MAX_FILTERS do
    -- filterKeywords[i] already set from cfg above

    local slot = Instance.new("Frame")
    slot.Size                   = UDim2.new(1, 0, 0, BOX_H)
    slot.BackgroundColor3       = C.inputBg
    slot.BackgroundTransparency = 0.2
    slot.BorderSizePixel        = 0
    slot.LayoutOrder            = i
    slot.Parent                 = scrollFrame
    corner(slot, UDim.new(0, 4))

    local slotStroke = Instance.new("UIStroke")
    slotStroke.Color           = C.accentDim
    slotStroke.Thickness       = 1
    slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    slotStroke.Parent          = slot

    local badge = Instance.new("TextLabel")
    badge.Size                   = UDim2.new(0, 14, 1, 0)
    badge.Position               = UDim2.new(0, 4, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C.textMuted
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.Parent                 = slot

    local tb = Instance.new("TextBox")
    tb.Size                   = UDim2.new(1, -22, 1, -4)
    tb.Position               = UDim2.new(0, 20, 0, 2)
    tb.BackgroundTransparency = 1
    tb.BorderSizePixel        = 0
    tb.Font                   = Enum.Font.GothamBold
    tb.TextSize               = 11
    tb.TextColor3             = C.textPri
    tb.PlaceholderText        = "keyword " .. i
    tb.PlaceholderColor3      = C.textMuted
    tb.TextXAlignment         = Enum.TextXAlignment.Left
    tb.ClearTextOnFocus       = false
    tb.Text                   = filterKeywords[i]   -- restore saved value
    tb.Parent                 = slot

    tb.Focused:Connect(function()
        TweenService:Create(slotStroke, C.tweenFast, { Color = C.accent }):Play()
    end)
    tb.FocusLost:Connect(function()
        TweenService:Create(slotStroke, C.tweenFast, { Color = C.accentDim }):Play()
        local old = filterKeywords[i]
        filterKeywords[i] = tb.Text
        saveKeywords()
    end)
    tb:GetPropertyChangedSignal("Text"):Connect(function()
        filterKeywords[i] = tb.Text
    end)
end

-- ─────────────────────────────────────────
--  PAGE 3 – Replace section
-- ─────────────────────────────────────────
local MAX_REPLACE = 10

local replaceSection = Instance.new("Frame")
replaceSection.Size             = UDim2.new(1, 0, 0, FILTER_SECTION_H)
replaceSection.BackgroundColor3 = C.bg2
replaceSection.LayoutOrder      = 0
replaceSection.Parent           = page3
corner(replaceSection, UDim.new(0, 7))
stroke(replaceSection, C.accentDim, 1)

-- Header row
local replaceHeaderRow = Instance.new("Frame")
replaceHeaderRow.Size                   = UDim2.new(1, 0, 0, 34)
replaceHeaderRow.Position               = UDim2.new(0, 0, 0, 0)
replaceHeaderRow.BackgroundTransparency = 1
replaceHeaderRow.Parent                 = replaceSection

local replaceLabel = Instance.new("TextLabel")
replaceLabel.Size                   = UDim2.new(1, -20, 1, 0)
replaceLabel.Position               = UDim2.new(0, 12, 0, 0)
replaceLabel.BackgroundTransparency = 1
replaceLabel.Font                   = Enum.Font.Gotham
replaceLabel.TextSize               = 13
replaceLabel.TextColor3             = C.textPri
replaceLabel.TextXAlignment         = Enum.TextXAlignment.Left
replaceLabel.Text                   = "Replace  (blank = none)"
replaceLabel.Parent                 = replaceHeaderRow

local replaceDivider = Instance.new("Frame")
replaceDivider.Size             = UDim2.new(1, -16, 0, 1)
replaceDivider.Position         = UDim2.new(0, 8, 0, 34)
replaceDivider.BackgroundColor3 = C.accentDim
replaceDivider.BorderSizePixel  = 0
replaceDivider.Parent           = replaceSection

-- Split-column scroll frame
local replaceScroll = Instance.new("ScrollingFrame")
replaceScroll.Size                   = UDim2.new(1, -8, 0, SCROLL_H)
replaceScroll.Position               = UDim2.new(0, 4, 0, 39)
replaceScroll.BackgroundColor3       = C.bg3
replaceScroll.BackgroundTransparency = 0.2
replaceScroll.BorderSizePixel        = 0
replaceScroll.ScrollBarThickness     = 3
replaceScroll.ScrollBarImageColor3   = C.accentDim
replaceScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
replaceScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
replaceScroll.ClipsDescendants       = true
replaceScroll.Parent                 = replaceSection
corner(replaceScroll, UDim.new(0, 5))

local replaceScrollLayout = Instance.new("UIListLayout")
replaceScrollLayout.Padding             = UDim.new(0, BOX_GAP)
replaceScrollLayout.SortOrder           = Enum.SortOrder.LayoutOrder
replaceScrollLayout.FillDirection       = Enum.FillDirection.Vertical
replaceScrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
replaceScrollLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
replaceScrollLayout.Parent              = replaceScroll

local replaceScrollPad = Instance.new("UIPadding")
replaceScrollPad.PaddingLeft   = UDim.new(0, 5)
replaceScrollPad.PaddingRight  = UDim.new(0, 5)
replaceScrollPad.PaddingTop    = UDim.new(0, 5)
replaceScrollPad.PaddingBottom = UDim.new(0, 5)
replaceScrollPad.Parent        = replaceScroll

local function saveReplaceRules()
    cfg.replaceRules = {}
    for i = 1, MAX_REPLACE do
        cfg.replaceRules[i] = { kw = replaceRules[i].kw, rep = replaceRules[i].rep }
    end
    saveConfig()
end

for i = 1, MAX_REPLACE do
    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(1, 0, 0, BOX_H)
    row.BackgroundColor3       = C.inputBg
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel        = 0
    row.LayoutOrder            = i
    row.Parent                 = replaceScroll
    corner(row, UDim.new(0, 4))

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color           = C.accentDim
    rowStroke.Thickness       = 1
    rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rowStroke.Parent          = row

    -- Badge
    local badge = Instance.new("TextLabel")
    badge.Size                   = UDim2.new(0, 14, 1, 0)
    badge.Position               = UDim2.new(0, 4, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Font                   = Enum.Font.GothamBold
    badge.TextSize               = 9
    badge.TextColor3             = C.textMuted
    badge.TextXAlignment         = Enum.TextXAlignment.Center
    badge.Text                   = tostring(i)
    badge.Parent                 = row

    -- Half-width: keyword (left side)
    local kwBox = Instance.new("TextBox")
    kwBox.Size                   = UDim2.new(0.5, -18, 1, -4)
    kwBox.Position               = UDim2.new(0, 20, 0, 2)
    kwBox.BackgroundTransparency = 1
    kwBox.BorderSizePixel        = 0
    kwBox.Font                   = Enum.Font.GothamBold
    kwBox.TextSize               = 11
    kwBox.TextColor3             = C.textPri
    kwBox.PlaceholderText        = "keyword " .. i
    kwBox.PlaceholderColor3      = C.textMuted
    kwBox.TextXAlignment         = Enum.TextXAlignment.Left
    kwBox.ClearTextOnFocus       = false
    kwBox.Text                   = replaceRules[i].kw
    kwBox.Parent                 = row

    -- Vertical splitter
    local splitter = Instance.new("Frame")
    splitter.Size             = UDim2.new(0, 1, 1, -6)
    splitter.Position         = UDim2.new(0.5, -1, 0, 3)
    splitter.BackgroundColor3 = C.accentDim
    splitter.BorderSizePixel  = 0
    splitter.Parent           = row

    -- Half-width: replacement (right side)
    local repBox = Instance.new("TextBox")
    repBox.Size                   = UDim2.new(0.5, -8, 1, -4)
    repBox.Position               = UDim2.new(0.5, 4, 0, 2)
    repBox.BackgroundTransparency = 1
    repBox.BorderSizePixel        = 0
    repBox.Font                   = Enum.Font.GothamBold
    repBox.TextSize               = 11
    repBox.TextColor3             = C.accentSec
    repBox.PlaceholderText        = "edited " .. i
    repBox.PlaceholderColor3      = C.textMuted
    repBox.TextXAlignment         = Enum.TextXAlignment.Left
    repBox.ClearTextOnFocus       = false
    repBox.Text                   = replaceRules[i].rep
    repBox.Parent                 = row

    -- Focus highlight on either box
    kwBox.Focused:Connect(function()
        TweenService:Create(rowStroke, C.tweenFast, { Color = C.accent }):Play()
    end)
    kwBox.FocusLost:Connect(function()
        TweenService:Create(rowStroke, C.tweenFast, { Color = C.accentDim }):Play()
        local old = replaceRules[i].kw
        replaceRules[i].kw = kwBox.Text
        saveReplaceRules()
    end)
    kwBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].kw = kwBox.Text
    end)

    repBox.Focused:Connect(function()
        TweenService:Create(rowStroke, C.tweenFast, { Color = C.accent }):Play()
    end)
    repBox.FocusLost:Connect(function()
        TweenService:Create(rowStroke, C.tweenFast, { Color = C.accentDim }):Play()
        local old = replaceRules[i].rep
        replaceRules[i].rep = repBox.Text
        saveReplaceRules()
    end)
    repBox:GetPropertyChangedSignal("Text"):Connect(function()
        replaceRules[i].rep = repBox.Text
    end)
end

-- ─────────────────────────────────────────
--  TABS + MINIMIZE
-- ─────────────────────────────────────────
local isMinimized = cfg.minimized == true
local currentTab  = (cfg.activeTab == 2) and 2 or (cfg.activeTab == 3) and 3 or (cfg.activeTab == 4) and 4 or 1

local FULL_H_STATUS = TITLE_H + TABBAR_H + PAGE2_H  -- same height as keyword page

local function currentTabHeight()
    if currentTab == 1 then return FULL_H_MAIN
    elseif currentTab == 2 then return FULL_H_KEY
    elseif currentTab == 3 then return FULL_H_REP
    else return FULL_H_STATUS
    end
end

-- Resizes the panel for the current minimized/tab state.
local function applyLayout(instant)
    local targetH = isMinimized and MIN_H or currentTabHeight()
    contentFrame.Visible = not isMinimized
    tabBar.Visible        = not isMinimized
    tabUnderline.Visible  = not isMinimized
    minBtn.Text           = isMinimized and "+" or "–"
    if instant then
        mainFrame.Size = UDim2.new(0, 310, 0, targetH)
    else
        TweenService:Create(mainFrame, C.tweenMed, { Size = UDim2.new(0, 310, 0, targetH) }):Play()
    end
end

-- Switches which page is visible and restyles the tab buttons.
local function setActiveTab(idx)
    currentTab = idx
    page1.Visible = (idx == 1)
    page2.Visible = (idx == 2)
    page3.Visible = (idx == 3)
    page4.Visible = (idx == 4)

    tabMainBtn.BackgroundColor3    = idx == 1 and C.toggleOn or C.bg2
    tabKeyBtn.BackgroundColor3     = idx == 2 and C.toggleOn or C.bg2
    tabReplaceBtn.BackgroundColor3 = idx == 3 and C.toggleOn or C.bg2
    tabStatusBtn.BackgroundColor3  = idx == 4 and C.toggleOn or C.bg2
    tabMainBtn.TextColor3          = idx == 1 and C.activeTabText or C.textMuted
    tabKeyBtn.TextColor3           = idx == 2 and C.activeTabText or C.textMuted
    tabReplaceBtn.TextColor3       = idx == 3 and C.activeTabText or C.textMuted
    tabStatusBtn.TextColor3        = idx == 4 and C.activeTabText or C.textMuted
end

setActiveTab(currentTab)
applyLayout(true)

tabMainBtn.MouseButton1Click:Connect(function()
    if currentTab == 1 then return end
    setActiveTab(1)
    cfg.activeTab = 1
    applyLayout(false)
    saveConfig()
end)
tabKeyBtn.MouseButton1Click:Connect(function()
    if currentTab == 2 then return end
    setActiveTab(2)
    cfg.activeTab = 2
    applyLayout(false)
    saveConfig()
end)
tabReplaceBtn.MouseButton1Click:Connect(function()
    if currentTab == 3 then return end
    setActiveTab(3)
    cfg.activeTab = 3
    applyLayout(false)
    saveConfig()
end)
tabStatusBtn.MouseButton1Click:Connect(function()
    if currentTab == 4 then return end
    setActiveTab(4)
    cfg.activeTab = 4
    applyLayout(false)
    saveConfig()
end)

tabMainBtn.MouseEnter:Connect(function()
    if currentTab ~= 1 then
        TweenService:Create(tabMainBtn, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    end
end)
tabMainBtn.MouseLeave:Connect(function()
    if currentTab ~= 1 then
        TweenService:Create(tabMainBtn, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    end
end)
tabKeyBtn.MouseEnter:Connect(function()
    if currentTab ~= 2 then
        TweenService:Create(tabKeyBtn, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    end
end)
tabKeyBtn.MouseLeave:Connect(function()
    if currentTab ~= 2 then
        TweenService:Create(tabKeyBtn, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    end
end)
tabReplaceBtn.MouseEnter:Connect(function()
    if currentTab ~= 3 then
        TweenService:Create(tabReplaceBtn, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    end
end)
tabReplaceBtn.MouseLeave:Connect(function()
    if currentTab ~= 3 then
        TweenService:Create(tabReplaceBtn, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    end
end)
tabStatusBtn.MouseEnter:Connect(function()
    if currentTab ~= 4 then
        TweenService:Create(tabStatusBtn, C.tweenFast, { BackgroundColor3 = Color3.fromRGB(32, 30, 24) }):Play()
    end
end)
tabStatusBtn.MouseLeave:Connect(function()
    if currentTab ~= 4 then
        TweenService:Create(tabStatusBtn, C.tweenFast, { BackgroundColor3 = C.bg2 }):Play()
    end
end)

minBtn.MouseButton1Click:Connect(function()
    isMinimized     = not isMinimized
    cfg.minimized   = isMinimized
    applyLayout(false)
    saveConfig()
end)
minBtn.MouseEnter:Connect(function()
    TweenService:Create(minBtn, C.tweenFast, { BackgroundColor3 = C.toggleOn }):Play()
end)
minBtn.MouseLeave:Connect(function()
    TweenService:Create(minBtn, C.tweenFast, { BackgroundColor3 = C.accentDim }):Play()
end)

-- ─────────────────────────────────────────
--  DRAG  (saves position on release)
-- ─────────────────────────────────────────
do
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
           input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging  = true
        dragStart = input.Position
        startPos  = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging     = false
                cfg.posX     = mainFrame.Position.X.Offset
                cfg.posY     = mainFrame.Position.Y.Offset
                saveConfig()
            end
        end)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and
           input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end

print("loaded")
logStatus("Script loaded – i love you <3")
