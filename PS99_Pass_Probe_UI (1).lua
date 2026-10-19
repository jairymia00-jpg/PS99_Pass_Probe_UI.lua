-- Pet Simulator 99 pass diagnostic panel. F1 toggles the panel.
-- This observes marketplace calls and ownership responses; it does not grant passes.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G

if type(env.PS99PassProbeStop) == "function" then
    pcall(env.PS99PassProbeStop)
end

local alive = true
local connections = {}
local passes = {"Mega Lucky", "Huge Hunter", "VIP"}
local ids = {}
local labelsById = {}
local selected = passes[1]
local selectedManual = false
local rows = {}
local maxRows = 45
local rowNumber = 0
local reportLines = {}
local lastGameClick
local remoteCaptureUntil = 0
local remoteCount = 0
local captureNumber = 0
local remoteSeen = {}
local remoteConnections = 0
local productFetched = {}
local checkOwnership

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end

local gui = make("ScreenGui", {
    Name = "PS99PassProbeUI", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 1000
}, playerGui)

local panel = make("Frame", {
    Size = UDim2.fromOffset(520, 410),
    Position = UDim2.new(0.5, -260, 0.5, -205),
    BackgroundColor3 = Color3.fromRGB(19, 23, 35),
    BorderSizePixel = 0, Active = true, Draggable = true
}, gui)
corner(panel, 12)
make("UIStroke", {Color = Color3.fromRGB(72, 140, 245), Thickness = 2}, panel)

make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 7),
    BackgroundTransparency = 1, Text = "PS99  |  PASS DIAGNOSTICS  |  F1",
    TextColor3 = Color3.fromRGB(237, 242, 255), Font = Enum.Font.GothamBold,
    TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left
}, panel)

local status = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 35), Position = UDim2.fromOffset(12, 47),
    BackgroundColor3 = Color3.fromRGB(34, 42, 62), BorderSizePixel = 0,
    Text = "Installing marketplace logger...", TextWrapped = true,
    TextColor3 = Color3.fromRGB(255, 210, 110), Font = Enum.Font.GothamMedium,
    TextSize = 13
}, panel)
corner(status, 6)

local function button(text, x, y, width)
    local b = make("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 32),
        BackgroundColor3 = Color3.fromRGB(40, 52, 78), BorderSizePixel = 0,
        Text = text, TextColor3 = Color3.fromRGB(245, 248, 255),
        Font = Enum.Font.GothamMedium, TextSize = 13
    }, panel)
    corner(b, 6)
    return b
end

local passButtons = {}
for i, name in ipairs(passes) do
    local b = button(name, 12 + (i - 1) * 166, 92, 158)
    passButtons[name] = b
    table.insert(connections, b.MouseButton1Click:Connect(function()
        selected = name
        selectedManual = true
        for label, item in pairs(passButtons) do
            item.BackgroundColor3 = (label == selected)
                and Color3.fromRGB(40, 112, 194) or Color3.fromRGB(40, 52, 78)
        end
        status.Text = ids[name]
            and (name .. " selected | pass ID " .. tostring(ids[name]))
            or (name .. " selected | click its tile in the game shop")
        status.TextColor3 = Color3.fromRGB(255, 210, 110)
    end))
end
passButtons[selected].BackgroundColor3 = Color3.fromRGB(40, 112, 194)

local selectedInfo = make("TextLabel", {
    Position = UDim2.fromOffset(12, 133), Size = UDim2.new(1, -24, 0, 24),
    BackgroundTransparency = 1,
    Text = "Select a pass above, then click its shop tile to identify its ID.",
    TextColor3 = Color3.fromRGB(180, 194, 220), Font = Enum.Font.Gotham,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
}, panel)

local checkButton = button("Check ownership", 12, 166, 158)
local copyButton = button("Copy report", 178, 166, 158)
local clearButton = button("Clear activity", 344, 166, 158)

local scroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 208), Size = UDim2.new(1, -24, 1, -220),
    BackgroundColor3 = Color3.fromRGB(25, 31, 46), BorderSizePixel = 0,
    ScrollBarThickness = 5, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, panel)
corner(scroll, 6)
make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

-- The selectable text box is a fallback for executors without setclipboard.
local copyPanel = make("Frame", {
    Position = UDim2.fromOffset(12, 207), Size = UDim2.new(1, -24, 1, -219),
    BackgroundColor3 = Color3.fromRGB(32, 41, 61), BorderSizePixel = 0,
    Visible = false, ZIndex = 10
}, panel)
corner(copyPanel, 6)
local copyText = make("TextBox", {
    Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -40),
    BackgroundColor3 = Color3.fromRGB(20, 26, 39), BorderSizePixel = 0,
    ClearTextOnFocus = false, MultiLine = true, TextEditable = true,
    Text = "", TextColor3 = Color3.fromRGB(235, 240, 255),
    Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 11
}, copyPanel)
local closeCopy = make("TextButton", {
    Position = UDim2.new(1, -65, 0, 4), Size = UDim2.fromOffset(58, 25),
    BackgroundColor3 = Color3.fromRGB(70, 82, 110), BorderSizePixel = 0,
    Text = "Close", TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamMedium, TextSize = 12, ZIndex = 11
}, copyPanel)
make("TextLabel", {
    Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -75, 0, 26),
    BackgroundTransparency = 1, Text = "Select all: Ctrl+A, then copy: Ctrl+C",
    TextColor3 = Color3.fromRGB(215, 230, 255), Font = Enum.Font.Gotham,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11
}, copyPanel)
table.insert(connections, closeCopy.MouseButton1Click:Connect(function()
    copyPanel.Visible = false
end))

local function addLog(message, color)
    if not alive then return end
    table.insert(reportLines, os.date("%H:%M:%S") .. "  " .. message)
    if #reportLines > 250 then table.remove(reportLines, 1) end
    rowNumber += 1
    local row = make("TextLabel", {
        Size = UDim2.new(1, -12, 0, 38), BackgroundTransparency = 1,
        Text = reportLines[#reportLines],
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = color or Color3.fromRGB(204, 216, 240),
        Font = Enum.Font.Code, TextSize = 12,
        LayoutOrder = rowNumber
    }, scroll)
    table.insert(rows, row)
    if #rows > maxRows then
        local first = table.remove(rows, 1)
        first:Destroy()
    end
    task.defer(function()
        if alive then scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y) end
    end)
end

table.insert(connections, copyButton.MouseButton1Click:Connect(function()
    local report = "PS99 pass diagnostic report | place " .. tostring(game.PlaceId)
        .. " | " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        .. "Mode: UI + marketplace events; client observations only\n"
        .. table.concat(reportLines, "\n")
    local clipboard = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
    local copied = false
    if clipboard then copied = pcall(clipboard, report) end
    copyText.Text = report
    copyPanel.Visible = true
    status.Text = copied and "Report copied. Paste it here."
        or "Select report text with Ctrl+A, then Ctrl+C and paste it here."
    status.TextColor3 = Color3.fromRGB(105, 235, 145)
    if not copied then
        task.defer(function()
            if alive and copyPanel.Visible then copyText:CaptureFocus() end
        end)
    end
end))

local function short(value, maxLength)
    local s = tostring(value):gsub("[\r\n]", " ")
    local limit = maxLength or 90
    return #s > limit and (s:sub(1, limit) .. "...") or s
end

local function passFromText(text)
    local lower = string.lower(text)
    for _, pass in ipairs(passes) do
        if string.find(lower, string.lower(pass), 1, true) then return pass end
    end
end

local function inspectGameClick(input)
    local pos = input.Position
    if panel.Visible then
        local a, b = panel.AbsolutePosition, panel.AbsoluteSize
        if pos.X >= a.X and pos.X <= a.X + b.X
            and pos.Y >= a.Y and pos.Y <= a.Y + b.Y then return end
    end
    local ok, objects = pcall(function()
        return playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
    end)
    if not ok or not objects then return end
    local hit
    for _, object in ipairs(objects) do
        if object:IsA("GuiObject") and not object:IsDescendantOf(gui) then
            hit = object
            break
        end
    end
    if not hit then return end

    local widget = hit
    local node = hit
    for _ = 1, 5 do
        if node:IsA("GuiButton") then widget = node break end
        if not node.Parent or node.Parent == playerGui then break end
        node = node.Parent
    end
    local texts = {}
    local inferred
    local scanned = 0
    local tile = widget.Parent and widget.Parent:IsA("GuiObject") and widget.Parent or widget
    for _, descendant in ipairs(tile:GetDescendants()) do
        scanned += 1
        if scanned > 100 then break end
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local value = short(descendant.Text, 60)
            if value ~= "" and #texts < 5 then table.insert(texts, value) end
            inferred = inferred or passFromText(value)
        end
    end
    if hit:IsA("TextLabel") or hit:IsA("TextButton") then
        inferred = inferred or passFromText(hit.Text)
    end
    if inferred then
        selected = inferred
        selectedManual = false
        for label, item in pairs(passButtons) do
            item.BackgroundColor3 = (label == selected)
                and Color3.fromRGB(40, 112, 194) or Color3.fromRGB(40, 52, 78)
        end
    end

    local path = short(widget:GetFullName(), 180)
    lastGameClick = {
        at = os.clock(), label = inferred or (selectedManual and selected or nil), path = path
    }
    remoteCaptureUntil = os.clock() + 6
    remoteCount = 0
    captureNumber += 1
    local thisCapture = captureNumber
    table.clear(remoteSeen)
    addLog("GAME UI CLICK | widget=" .. path)
    addLog("Visible tile text: " .. (#texts > 0 and table.concat(texts, " | ") or "(none)"))
    addLog("Pass guess: " .. (inferred or (selectedManual and selected
        .. " [selected tab; unconfirmed]" or "unknown; check pass metadata")))
    local attrs = {}
    for key, value in pairs(widget:GetAttributes()) do
        if #attrs >= 5 then break end
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            table.insert(attrs, short(key, 35) .. "=" .. short(value, 45))
        end
    end
    if #attrs > 0 then addLog("Widget attributes: " .. table.concat(attrs, ", ")) end
    if widget:IsA("GuiButton") and type(getconnections) == "function" then
        local okHandlers, handlers = pcall(getconnections, widget.Activated)
        if okHandlers and type(handlers) == "table" then
            addLog("UI Activated handlers visible to executor: " .. tostring(#handlers))
        end
    end
    status.Text = "Captured game UI click | watching responses for 6 seconds"
    status.TextColor3 = Color3.fromRGB(105, 235, 145)
    local knownId = inferred and ids[inferred]
    if knownId then checkOwnership(knownId, inferred) end
    task.delay(6.1, function()
        if alive and captureNumber == thisCapture then
            addLog("Capture complete | unique incoming RemoteEvents=" .. tostring(remoteCount)
                .. " | outbound/server-only checks not visible in this mode")
        end
    end)
end

local function describeArg(value)
    local kind = typeof(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return short(value, 35)
    end
    if kind == "Instance" then return short(value.ClassName .. ":" .. value.Name, 45) end
    return "<" .. kind .. ">"
end

local function watchRemote(instance)
    if not instance:IsA("RemoteEvent") or remoteConnections >= 250 then return end
    remoteConnections += 1
    table.insert(connections, instance.OnClientEvent:Connect(function(...)
        if not alive or os.clock() > remoteCaptureUntil or remoteCount >= 12 then return end
        local name = short(instance:GetFullName(), 120)
        if remoteSeen[name] then return end
        remoteSeen[name] = true
        remoteCount += 1
        local args = {...}
        local display = {}
        for i = 1, math.min(#args, 3) do display[i] = describeArg(args[i]) end
        addLog("Incoming RemoteEvent | " .. name .. " | args: " .. table.concat(display, ", "))
    end))
end

for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do watchRemote(instance) end
table.insert(connections, ReplicatedStorage.DescendantAdded:Connect(watchRemote))
addLog("Watching up to " .. tostring(remoteConnections) .. " incoming RemoteEvents (6s after game UI click).")

local function showId(id, method)
    if not alive then return end
    if method == "PromptGamePassPurchase" and selected then
        ids[selected] = id
        labelsById[id] = selected
        selectedInfo.Text = selected .. " = pass ID " .. tostring(id)
        status.Text = "Detected " .. selected .. " | ID " .. tostring(id) .. " | purchase NOT confirmed"
        status.TextColor3 = Color3.fromRGB(255, 210, 110)
    end
end

checkOwnership = function(id, label)
    task.spawn(function()
        addLog("Checking Roblox ownership for " .. label .. " (ID " .. tostring(id) .. ")")
        local ok, result = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end)
        if not alive then return end
        if ok then
            local owned = result == true
            status.Text = label .. " | Roblox ownership response: " .. tostring(owned)
                .. " | in-game perk unverified"
            status.TextColor3 = owned and Color3.fromRGB(105, 235, 145)
                or Color3.fromRGB(255, 210, 110)
            addLog("UserOwnsGamePassAsync ID " .. tostring(id) .. " -> " .. tostring(result),
                owned and Color3.fromRGB(105, 235, 145) or Color3.fromRGB(255, 205, 115))
        else
            status.Text = "Ownership check failed; see activity"
            status.TextColor3 = Color3.fromRGB(255, 125, 125)
            addLog("Ownership check error: " .. tostring(result), Color3.fromRGB(255, 125, 125))
        end
    end)
end

local function inspectProduct(id)
    if productFetched[id] then return end
    productFetched[id] = true
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass)
        end)
        if not ok then
            ok, info = pcall(function()
                return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
            end)
        end
        if not alive then return end
        if not ok or type(info) ~= "table" then
            addLog("Pass metadata ID " .. tostring(id) .. " -> " .. short(info, 90),
                Color3.fromRGB(255, 205, 115))
            return
        end
        local productName = tostring(info.Name or "(no name)")
        local matchingPass = passFromText(productName)
        if matchingPass then
            ids[matchingPass] = id
            labelsById[id] = matchingPass
            if selected == matchingPass then
                selectedInfo.Text = matchingPass .. " = pass ID " .. tostring(id)
            end
        end
        addLog("Pass metadata | ID " .. tostring(id)
            .. " | name=" .. short(productName, 70)
            .. " | price=" .. tostring(info.PriceInRobux)
            .. " | forSale=" .. tostring(info.IsForSale))
    end)
end

table.insert(connections, checkButton.MouseButton1Click:Connect(function()
    local id = ids[selected]
    if id then
        checkOwnership(id, selected)
    else
        addLog("No ID for " .. selected .. ". Click its tile in the shop first.",
            Color3.fromRGB(255, 205, 115))
    end
end))

table.insert(connections, clearButton.MouseButton1Click:Connect(function()
    for _, row in ipairs(rows) do row:Destroy() end
    table.clear(rows)
    table.clear(reportLines)
    addLog("Activity cleared. Saved pass IDs remain available.")
end))

table.insert(connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F1 then
        panel.Visible = not panel.Visible
    elseif input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        inspectGameClick(input)
    end
end))

table.insert(connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(promptPlayer, id, purchased)
    if not alive or promptPlayer ~= player then return end
    local recent = lastGameClick and (os.clock() - lastGameClick.at <= 12)
    local label = labelsById[id] or (recent and lastGameClick.label)
        or (selectedManual and selected) or "Unknown pass"
    if label ~= "Unknown pass" and not ids[label] then
        ids[label] = id
        labelsById[id] = label
        if selected == label then selectedInfo.Text = label .. " = pass ID " .. tostring(id) end
    end
    addLog("Prompt closed | ID " .. tostring(id) .. " | pass=" .. tostring(label)
        .. " | purchased=" .. tostring(purchased),
        purchased and Color3.fromRGB(105, 235, 145) or Color3.fromRGB(255, 205, 115))
    status.Text = "Prompt closed | purchased=" .. tostring(purchased) .. " | perk unverified"
    status.TextColor3 = Color3.fromRGB(255, 210, 110)
    inspectProduct(id)
    task.delay(purchased and 2 or 0.3, function()
        if alive then checkOwnership(id, labelsById[id] or "Pass") end
    end)
end))

local hookReady = false
if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
    local old
    local wrapper = function(self, ...)
        if not alive or self ~= MarketplaceService then return old(self, ...) end
        if type(checkcaller) == "function" and checkcaller() then return old(self, ...) end
        local method = getnamecallmethod()
        if method ~= "PromptGamePassPurchase" and method ~= "UserOwnsGamePassAsync" then
            return old(self, ...)
        end
        local id = select(2, ...)
        if method == "PromptGamePassPurchase" then
            task.defer(function()
                if alive then
                    showId(id, method)
                    addLog("PromptGamePassPurchase called | ID " .. tostring(id)
                        .. " | waiting for prompt result")
                end
            end)
            return old(self, ...)
        end
        local result = table.pack(old(self, ...))
        task.defer(function()
            if alive then
                addLog("Game checked ownership | ID " .. tostring(id)
                    .. " | returned " .. tostring(result[1]))
            end
        end)
        return table.unpack(result, 1, result.n)
    end
    local ok, err = pcall(function()
        old = hookmetamethod(game, "__namecall",
            type(newcclosure) == "function" and newcclosure(wrapper) or wrapper)
    end)
    hookReady = ok and type(old) == "function"
    if not hookReady then addLog("Marketplace hook failed: " .. tostring(err or "no original function"), Color3.fromRGB(255, 125, 125)) end
else
    addLog("Executor does not expose hookmetamethod/getnamecallmethod.", Color3.fromRGB(255, 125, 125))
end

if hookReady then
    status.Text = "Logger active | select a pass and click its in-game tile"
    status.TextColor3 = Color3.fromRGB(105, 235, 145)
    addLog("Marketplace hook installed; awaiting a pass click.")
else
    status.Text = "UI + prompt capture active | outgoing call hook unavailable"
    status.TextColor3 = Color3.fromRGB(255, 210, 110)
end

-- IDs observed in the user's previous screenshot. Resolve official names before
-- associating an ID with a tab; unknown names remain in the activity report.
for _, id in ipairs({264808140, 257811346, 205379487}) do
    inspectProduct(id)
end

env.PS99PassProbeStop = function()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    gui:Destroy()
end
