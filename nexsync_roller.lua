local function tryLoadModule(urls)
    for _, url in ipairs(urls) do
        local ok, src = pcall(game.HttpGet, game, url)
        if ok then
            local chunk, err = loadstring(src)
            if chunk then return chunk() end
        end
    end
    error("Failed to load dependency")
end

local Library = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua',
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua',
})
local ThemeManager = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua',
})
local SaveManager = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua',
})

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local FruitList = {}
local fruitFolder = ReplicatedStorage:WaitForChild("Storage", 5) and ReplicatedStorage.Storage:WaitForChild("Fruit", 5)
if fruitFolder then
    for _, fruit in ipairs(fruitFolder:GetChildren()) do
        table.insert(FruitList, fruit.Name)
    end
    table.sort(FruitList)
end

local Stats = {
    totalRolls = 0,
    matches = 0,
    spent = 0,
    lastFound = "None",
    startTime = os.time()
}

local Cfg = {
    enabled = false,
    instant = false,
    burst = 5,
    speed = 0.05,
    autoBuy = false,
    autoUpgradeLuck = false,
    autoUpgradeRolls = false,
    stopOnMatch = true,
    targetFruits = {},
    minEarnings = 0,
    blackscreen = false,
    worldDestroyer = false,
    webhookEnabled = false,
    webhookUrl = "",
    disconnectOnFind = false,
    disconnectTargets = {},
    antiAfk = true
}

local _loopActive = false
local _buyLock = false
local _blackscreenGui = nil
local _originalCFrame = nil

local Comms = ReplicatedStorage:WaitForChild("Communication", 10)
local RollEvent = Comms and Comms:WaitForChild("DoRoll", 5)
local BuyEvent = Comms and Comms:WaitForChild("BuySeeds", 5)
local UpgradeEvent = Comms and Comms:WaitForChild("BuyUpgrade", 5)

local function getPlot()
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end
    return Plots:FindFirstChild(LP.Name) or Plots:FindFirstChild(LP.DisplayName)
end

local function findStumpIndex(itemName)
    local plot = getPlot()
    if not plot then return nil end
    local lowerItem = itemName:lower()
    for _, child in ipairs(plot:GetChildren()) do
        if child.Name == "Stump" or child.Name:match("^Stump_%d+$") then
            local titleObj = child:FindFirstChild("Model")
                and child.Model:FindFirstChild("BuyableDisplay")
                and child.Model.BuyableDisplay:FindFirstChild("Title")
            if titleObj then
                local text = titleObj.Text:lower()
                if text:find(lowerItem, 1, true) or lowerItem:find(text, 1, true) then
                    local num = child.Name:match("%d+")
                    return num and tonumber(num) or 1
                end
            end
        end
    end
    return nil
end

local function sendWebhook(itemName, earnings)
    if not Cfg.webhookEnabled or Cfg.webhookUrl == "" then return end
    local data = {
        ["embeds"] = {{
            ["title"] = "🎯 Rare Item Found!",
            ["color"] = 65280,
            ["fields"] = {
                {["name"] = "Player", ["value"] = LP.Name, ["inline"] = true},
                {["name"] = "Item", ["value"] = itemName, ["inline"] = true},
                {["name"] = "Earnings", ["value"] = tostring(earnings), ["inline"] = true},
                {["name"] = "Total Rolls", ["value"] = tostring(Stats.totalRolls), ["inline"] = false},
                {["name"] = "Job ID", ["value"] = "```" .. game.JobId .. "```", ["inline"] = false}
            },
            ["footer"] = {["text"] = "NexSync Standalone Roller"},
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    task.spawn(function()
        local originalUrl = Cfg.webhookUrl
        local proxyUrl = originalUrl:gsub("discord.com", "webhook.lewisakura.moe"):gsub("ptb.discord.com", "webhook.lewisakura.moe"):gsub("canary.discord.com", "webhook.lewisakura.moe")
        local function send(targetUrl)
            local request = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request
            if request then
                local response = request({
                    Url = targetUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(data)
                })
                return response and (response.StatusCode == 204 or response.StatusCode == 200), response and response.StatusCode
            else
                local ok = pcall(function() HttpService:PostAsync(targetUrl, HttpService:JSONEncode(data)) end)
                return ok, ok and 204 or 0
            end
        end
        local ok, status = send(proxyUrl)
        if not ok then ok, status = send(originalUrl) end
        if ok then Library:Notify("Webhook sent successfully!") else Library:Notify("Webhook failed! Status: " .. tostring(status or "Unknown")) end
    end)
end

local function processResult(result)
    if not result or type(result) ~= "table" then return end
    local items = result[1] and result or {result}
    if result.Item then items = {result.Item} end
    for _, item in ipairs(items) do
        local name = item.Type or item.Title or "Unknown"
        local earnings = tonumber(item.Earnings) or 0
        local isTarget = Cfg.targetFruits[name] or (next(Cfg.targetFruits) == nil)
        local meetsEarnings = earnings >= Cfg.minEarnings
        if isTarget and meetsEarnings then
            Stats.matches = Stats.matches + 1
            Stats.lastFound = name
            if Cfg.webhookEnabled then sendWebhook(name, earnings) end
            if Cfg.autoBuy then
                _buyLock = true
                task.wait(0.3)
                local stumpIdx = nil
                for i = 1, 5 do
                    stumpIdx = findStumpIndex(name)
                    if stumpIdx then break end
                    task.wait(0.1)
                end
                stumpIdx = stumpIdx or item.StumpIndex or item.Index or 0
                if stumpIdx and BuyEvent then
                    pcall(function() BuyEvent:FireServer(stumpIdx) end)
                    Stats.spent = Stats.spent + 1
                end
                task.wait(0.2)
                _buyLock = false
            end
            if Cfg.disconnectOnFind and (Cfg.disconnectTargets[name] or next(Cfg.disconnectTargets) == nil) then
                LP:Kick("\n[NexSync] Target Found: " .. name .. "\nDisconnecting to save progress.")
                return true
            end
            if Cfg.stopOnMatch then
                Cfg.enabled = false
                Library:Notify("Match Found: " .. name .. "! Stopping roller.")
                return true
            end
        end
    end
    return false
end

local function roll()
    if not RollEvent then return end
    local ok, result = pcall(function() return RollEvent:InvokeServer() end)
    if ok and result then
        Stats.totalRolls = Stats.totalRolls + 1
        return processResult(result)
    end
    return false
end

local function handleUpgrades()
    if not UpgradeEvent then return end
    if Cfg.autoUpgradeLuck then pcall(function() UpgradeEvent:FireServer("SeedLuck") end) end
    if Cfg.autoUpgradeRolls then pcall(function() UpgradeEvent:FireServer("SeedRolls") end) end
end

task.spawn(function()
    local upgradeTick = 0
    while true do
        if not Cfg.enabled or _buyLock then task.wait(0.1) continue end
        if os.clock() - upgradeTick > 5 then
            handleUpgrades()
            upgradeTick = os.clock()
        end
        local burst = Cfg.instant and Cfg.burst or 1
        for i = 1, burst do if roll() then break end end
        if Cfg.instant then RunService.Heartbeat:Wait() else task.wait(Cfg.speed) end
    end
end)

local function setBlackscreen(v)
    Cfg.blackscreen = v
    RunService:Set3dRenderingEnabled(not v)
    if v then
        if not _blackscreenGui then
            _blackscreenGui = Instance.new("ScreenGui")
            _blackscreenGui.Name = "NexSync_Blackscreen"
            _blackscreenGui.IgnoreGuiInset = true
            _blackscreenGui.DisplayOrder = 999
            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromScale(1, 1)
            frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            frame.Parent = _blackscreenGui
            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromScale(1, 0.8)
            label.Position = UDim2.fromScale(0, 0)
            label.BackgroundTransparency = 1
            label.Text = "NEXSYNC STANDALONE ROLLER ACTIVE\n3D RENDERING DISABLED"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Font = Enum.Font.Code
            label.TextSize = 24
            label.Parent = frame
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 200, 0, 50)
            btn.Position = UDim2.fromScale(0.5, 0.8)
            btn.AnchorPoint = Vector2.new(0.5, 0.5)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.Text = "DISABLE BLACKSCREEN"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.Code
            btn.TextSize = 18
            btn.Parent = frame
            btn.MouseButton1Click:Connect(function() setBlackscreen(false) end)
            _blackscreenGui.Parent = game:GetService("CoreGui")
        end
        _blackscreenGui.Enabled = true
    elseif _blackscreenGui then
        _blackscreenGui.Enabled = false
    end
end

local function ultraOptimize(v)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if v then
        _originalCFrame = hrp.CFrame
        hrp.CFrame = CFrame.new(0, 10000, 0)
        task.wait(0.1)
        hrp.Anchored = true
        Library:Notify("Teleported to the Void!")
    else
        hrp.Anchored = false
        if _originalCFrame then hrp.CFrame = _originalCFrame end
        Library:Notify("Returned to World.")
    end
end

local function destroyWorld()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(LP.Character) then v:Destroy()
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") then v:Destroy() end
    end
end

local Window = Library:CreateWindow({ Title = 'NEXSYNC | Standalone Roller V2', Center = true, AutoShow = true })
local Tabs = {
    Main = Window:AddTab('Roller'),
    Optimization = Window:AddTab('Optimization'),
    Automation = Window:AddTab('Automation'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local RollBox = Tabs.Main:AddLeftGroupbox('Rolling Engine')
RollBox:AddToggle('RollEnabled', { Text = 'Enable Roller', Default = false, Callback = function(v) Cfg.enabled = v end })
RollBox:AddToggle('InstantMode', { Text = '⚡ Instant Mode', Default = false, Callback = function(v) Cfg.instant = v end })
RollBox:AddSlider('BurstAmount', { Text = 'Burst (Rolls/Frame)', Default = 5, Min = 1, Max = 50, Rounding = 0, Callback = function(v) Cfg.burst = v end })
RollBox:AddSlider('NormalSpeed', { Text = 'Normal Speed', Default = 0.05, Min = 0.01, Max = 1, Rounding = 2, Callback = function(v) Cfg.speed = v end })

local MatchBox = Tabs.Main:AddRightGroupbox('Match Settings')
MatchBox:AddDropdown('TargetFruits', { Values = FruitList, Multi = true, Text = 'Target Fruits', AllowNull = true, Callback = function(v) Cfg.targetFruits = v end })
MatchBox:AddToggle('AutoBuy', { Text = 'Auto Buy Seeds', Default = false, Callback = function(v) Cfg.autoBuy = v end })
MatchBox:AddToggle('AutoUpgradeLuck', { Text = 'Auto Upgrade Luck', Default = false, Callback = function(v) Cfg.autoUpgradeLuck = v end })
MatchBox:AddToggle('AutoUpgradeRolls', { Text = 'Auto Upgrade Rolls', Default = false, Callback = function(v) Cfg.autoUpgradeRolls = v end })
MatchBox:AddToggle('StopOnMatch', { Text = 'Stop on Match', Default = true, Callback = function(v) Cfg.stopOnMatch = v end })
MatchBox:AddInput('MinEarnings', { Text = 'Min Earnings', Default = '0', Numeric = true, Callback = function(v) Cfg.minEarnings = tonumber(v) or 0 end })

local StatsBox = Tabs.Main:AddLeftGroupbox('Statistics')
local RollLabel = StatsBox:AddLabel('Total Rolls: 0')
local MatchLabel = StatsBox:AddLabel('Matches Found: 0')
local LastLabel = StatsBox:AddLabel('Last Found: None')

task.spawn(function()
    while true do
        RollLabel:SetText('Total Rolls: ' .. Stats.totalRolls)
        MatchLabel:SetText('Matches Found: ' .. Stats.matches)
        LastLabel:SetText('Last Found: ' .. Stats.lastFound)
        task.wait(0.5)
    end
end)

local FPSBox = Tabs.Optimization:AddLeftGroupbox('FPS Boosters')
FPSBox:AddToggle('Blackscreen', { Text = 'Blackscreen (Rendering Off)', Default = false, Callback = function(v) setBlackscreen(v) end })
FPSBox:AddToggle('UltraOptimize', { Text = 'Ultra Optimize (Void TP)', Default = false, Callback = function(v) ultraOptimize(v) end })
FPSBox:AddButton('Destroy World (Permanent)', function() destroyWorld() end)

local MiscBox = Tabs.Optimization:AddRightGroupbox('Misc')
LP.Idled:Connect(function() if Cfg.antiAfk then game:GetService("VirtualUser"):CaptureController() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end end)

local WebhookBox = Tabs.Automation:AddLeftGroupbox('Discord Integration')
WebhookBox:AddToggle('WebhookEnabled', { Text = 'Enable Webhook', Default = false, Callback = function(v) Cfg.webhookEnabled = v end })
WebhookBox:AddInput('WebhookUrl', { Text = 'Webhook URL', Default = '', Callback = function(v) Cfg.webhookUrl = v end })
WebhookBox:AddButton('Test Webhook', function() sendWebhook("Test Item", 999999) end)

local SecurityBox = Tabs.Automation:AddRightGroupbox('Security')
SecurityBox:AddDropdown('DisconnectTargets', { Values = FruitList, Multi = true, Text = 'Disconnect Targets', AllowNull = true, Callback = function(v) Cfg.disconnectTargets = v end })
SecurityBox:AddToggle('DisconnectOnFind', { Text = 'Disconnect on Rare', Default = false, Callback = function(v) Cfg.disconnectOnFind = v end })

local UISettingsBox = Tabs['UI Settings']:AddLeftGroupbox("Menu Settings")
UISettingsBox:AddLabel("Menu Toggle"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu Toggle",
    Callback = function() Library:Toggle() end
})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:BuildConfigSection(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()
Library:Notify("NexSync Standalone Roller V2 Loaded!")
