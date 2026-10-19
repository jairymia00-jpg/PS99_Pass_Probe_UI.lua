-- Pet Simulator 99 pass diagnostic panel. F1 toggles the panel.
-- This observes marketplace calls and ownership responses; it does not grant passes.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
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
local rows = {}
local maxRows = 45
local rowNumber = 0

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
}, player:WaitForChild("PlayerGui"))

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

local checkButton = button("Check selected ownership", 12, 166, 243)
local clearButton = button("Clear activity", 265, 166, 243)

local scroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 208), Size = UDim2.new(1, -24, 1, -220),
    BackgroundColor3 = Color3.fromRGB(25, 31, 46), BorderSizePixel = 0,
    ScrollBarThickness = 5, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, panel)
corner(scroll, 6)
make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

local function addLog(message, color)
    if not alive then return end
    rowNumber += 1
    local row = make("TextLabel", {
        Size = UDim2.new(1, -12, 0, 38), BackgroundTransparency = 1,
        Text = os.date("%H:%M:%S") .. "  " .. message,
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

local function checkOwnership(id, label)
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
    addLog("Activity cleared. Saved pass IDs remain available.")
end))

table.insert(connections, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F1 then
        panel.Visible = not panel.Visible
    end
end))

table.insert(connections, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(promptPlayer, id, purchased)
    if not alive or promptPlayer ~= player then return end
    if selected and not ids[selected] then
        ids[selected] = id
        labelsById[id] = selected
        selectedInfo.Text = selected .. " = pass ID " .. tostring(id)
    end
    addLog("Prompt closed | ID " .. tostring(id) .. " | purchased=" .. tostring(purchased),
        purchased and Color3.fromRGB(105, 235, 145) or Color3.fromRGB(255, 205, 115))
    status.Text = "Prompt closed | purchased=" .. tostring(purchased) .. " | perk unverified"
    status.TextColor3 = Color3.fromRGB(255, 210, 110)
    if purchased then
        local label = labelsById[id] or "Pass"
        task.delay(2, function()
            if alive then checkOwnership(id, label) end
        end)
    end
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
    status.Text = "Hook unavailable | purchase-finished events may still be visible"
    status.TextColor3 = Color3.fromRGB(255, 125, 125)
end

env.PS99PassProbeStop = function()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    gui:Destroy()
end
