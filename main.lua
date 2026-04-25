local function tryLoadModule(urls)
    local lastErr = "unknown error"
    for _, url in ipairs(urls) do
        local ok, result = pcall(function()
            local src = game:HttpGet(url)
            local chunk, compileErr = loadstring(src)
            if not chunk then
                error("compile failed: " .. tostring(compileErr))
            end
            local mod = chunk()
            if not mod then
                error("module returned nil")
            end
            return mod
        end)
        if ok and result then
            return result
        end
        lastErr = string.format("%s -> %s", url, tostring(result))
    end
    error("FarmV2 > [fatal] failed loading remote module: " .. tostring(lastErr))
end

local Library = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua',
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua',
})
local ThemeManager = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua',
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/addons/ThemeManager.lua',
})
local SaveManager = tryLoadModule({
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua',
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/addons/SaveManager.lua',
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local Comms = ReplicatedStorage:WaitForChild("Communication")
local ClickEvent = Comms:WaitForChild("ClickPlant")
local SellEvent = Comms:WaitForChild("SellCrate")
local RollEvent = Comms:WaitForChild("DoRoll")
local UpgradeEvent = Comms:WaitForChild("BuyUpgrade")
local BuyEvent = Comms:WaitForChild("BuySeeds")

local FruitList = {}
for _, fruit in ipairs(ReplicatedStorage.Storage.Fruit:GetChildren()) do
    table.insert(FruitList, fruit.Name)
end
table.sort(FruitList)

local Window = Library:CreateWindow({ Title = 'Farm Tool | Ultra Bypass V6.3', Center = true, AutoShow = true })
local Tabs = {
    Main = Window:AddTab('Main'),
    Farming = Window:AddTab('Farming'),
    Upgrades = Window:AddTab('Upgrades'),
    Sniper = Window:AddTab('Roll Sniper'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local Cfg = {
    Running = true,
    DebugMode = true,
    AntiAFK = true,
    NoClip = true,
    Collect = false,
    CollectDelay = 0,
    BypassMode = 'FastSnap',
    StrictFarm = false,
    PrioritizeSelected = true,
    PriorityList = {},
    MaxHarvestPerCycle = 9999,
    UseNetworkOwnership = true,
    AutoSell = false,
    SellInterval = 0.6,
    SniperActive = false,
    InstantMode = false,
    SniperThreads = 1,
    AutoBuyMatch = false,
    AutoProceedAfterBuy = true,
    TargetFruits = {},
    MinEarnings = 0,
    StopOnMatch = true,
    AutoRollSpeed = 0.05,
}

local GlobalSniperLock = false
local AutoUpgrades = { Click = false, SprinkerPower = false, SeedLuck = false, SeedRolls = false }

local function getPlot()
    return workspace.Plots:FindFirstChild(LP.Name) or workspace.Plots:FindFirstChild(LP.DisplayName)
end

local function getPosition(obj)
    if not obj or not obj.Parent then return nil end
    return obj:IsA("Model") and obj:GetPivot().Position or obj:IsA("BasePart") and obj.Position or nil
end

LP.Idled:Connect(function()
    if Cfg.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

RunService.Stepped:Connect(function()
    if not Cfg.Running then return end
    if (Cfg.Collect or Cfg.SniperActive) and Cfg.NoClip and LP.Character then
        for _, v in ipairs(LP.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

local function processResult(result)
    if not result or type(result) ~= "table" or not result[1] then return false end
    local item = result[1]
    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0
    local isMatch = (next(Cfg.TargetFruits) == nil or Cfg.TargetFruits[itemType]) and (itemEarnings >= Cfg.MinEarnings)

    if isMatch then
        GlobalSniperLock = true 
        if Cfg.AutoBuyMatch then
            local idx = item.StumpIndex or item.Index or 0
            pcall(function() BuyEvent:FireServer(idx) end)
            if Cfg.StopOnMatch then
                Cfg.SniperActive = false
            elseif Cfg.AutoProceedAfterBuy then
                task.wait(1.2)
                GlobalSniperLock = false
            end
        elseif Cfg.StopOnMatch then
            Cfg.SniperActive = false
        end
        return true
    end
    return false
end

task.spawn(function()
    while Cfg.Running do
        if Cfg.SniperActive and not GlobalSniperLock then
            local ok, result = pcall(function() return RollEvent:InvokeServer() end)
            if ok and result then processResult(result) end
            if not Cfg.InstantMode then task.wait(Cfg.AutoRollSpeed) else RunService.Heartbeat:Wait() end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while Cfg.Running do
        if Cfg.Collect and not GlobalSniperLock then
            local plot = getPlot()
            local tiles = plot and plot:FindFirstChild("Tiles")
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if tiles and hrp then
                for _, tile in ipairs(tiles:GetChildren()) do
                    if GlobalSniperLock or not Cfg.Collect then break end
                    local tPos = getPosition(tile)
                    if tPos then
                        local oldCF = hrp.CFrame
                        hrp.CFrame = CFrame.new(tPos + Vector3.new(0, 3.5, 0))
                        ClickEvent:FireServer(tile)
                        hrp.CFrame = oldCF
                        if Cfg.CollectDelay > 0 then task.wait(Cfg.CollectDelay) end
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while Cfg.Running do
        if not GlobalSniperLock then
            if Cfg.AutoSell then SellEvent:FireServer() end
            for n, on in pairs(AutoUpgrades) do
                if on then UpgradeEvent:FireServer(n) task.wait(0.1) end
            end
        end
        task.wait(Cfg.SellInterval)
    end
end)

local QuickBox = Tabs.Main:AddLeftGroupbox('Quick Controls')
QuickBox:AddToggle('CollectPlants', { Text = 'Auto Collect', Default = false, Callback = function(v) Cfg.Collect = v end })
QuickBox:AddToggle('DebugMode', { Text = 'Debug Mode', Default = true, Callback = function(v) Cfg.DebugMode = v end })
QuickBox:AddToggle('AntiAFK', { Text = 'Anti-AFK', Default = true, Callback = function(v) Cfg.AntiAFK = v end })

local FarmingBox = Tabs.Farming:AddLeftGroupbox('Harvesting')
FarmingBox:AddSlider('MaxHarvestPerCycle', { Text = 'Max per Cycle', Default = 9999, Min = 10, Max = 9999, Rounding = 0, Callback = function(v) Cfg.MaxHarvestPerCycle = v end })
FarmingBox:AddSlider('CollectDelay', { Text = 'Extra Delay', Default = 0, Min = 0, Max = 0.05, Rounding = 4, Callback = function(v) Cfg.CollectDelay = v end })

local BypassBox = Tabs.Farming:AddRightGroupbox('Bypass Settings')
BypassBox:AddDropdown('BypassMode', { Values = { 'NoBypass', 'Snap', 'FastSnap', 'Tween' }, Default = 'FastSnap', Text = 'Bypass Technique', Callback = function(v) Cfg.BypassMode = v end })
BypassBox:AddToggle('NoClip', { Text = 'NoClip', Default = true, Callback = function(v) Cfg.NoClip = v end })

local FilterBox = Tabs.Farming:AddLeftGroupbox('Filter')
FilterBox:AddToggle('StrictActive', { Text = 'Only Farm Selected', Default = false, Callback = function(v) Cfg.StrictFarm = v end })
FilterBox:AddDropdown('PrioList', { Values = FruitList, Multi = true, Text = 'Priority Fruits', AllowNull = true, Callback = function(v) Cfg.PriorityList = v end })

local MiscBox = Tabs.Farming:AddRightGroupbox('Misc')
MiscBox:AddToggle('AutoSell', { Text = 'Auto Sell', Default = false, Callback = function(v) Cfg.AutoSell = v end })
MiscBox:AddSlider('SellInterval', { Text = 'Sell Interval', Default = 0.6, Min = 0.1, Max = 2, Rounding = 2, Callback = function(v) Cfg.SellInterval = v end })
MiscBox:AddButton('Unload', function() Cfg.Running = false Library:Unload() end)

local UpgradeBox = Tabs.Upgrades:AddLeftGroupbox('Auto Upgrades')
for _, n in ipairs({ 'Click', 'SprinkerPower', 'SeedLuck', 'SeedRolls' }) do
    UpgradeBox:AddToggle('Auto' .. n, { Text = 'Auto ' .. n, Default = false, Callback = function(v) AutoUpgrades[n] = v end })
end

local SniperBox = Tabs.Sniper:AddLeftGroupbox('Sniper Settings')
SniperBox:AddDropdown('TargetFruits', { Values = FruitList, Multi = true, Text = 'Target Fruits', AllowNull = true, Callback = function(v) Cfg.TargetFruits = v end })
SniperBox:AddInput('MinEarnings', { Text = 'Min Earnings', Default = '0', Numeric = true, Callback = function(v) Cfg.MinEarnings = tonumber(v) or 0 end })
SniperBox:AddToggle('InstantMode', { Text = '⚡ Instant Mode', Default = false, Callback = function(v) Cfg.InstantMode = v end })
SniperBox:AddSlider('AutoRollSpeed', { Text = 'Normal Roll Speed', Default = 0.05, Min = 0.02, Max = 0.2, Rounding = 3, Callback = function(v) Cfg.AutoRollSpeed = v end })
SniperBox:AddToggle('AutoBuyMatch', { Text = 'Auto Buy on Match', Default = false, Callback = function(v) Cfg.AutoBuyMatch = v end })
SniperBox:AddToggle('StopOnMatch', { Text = 'Stop on Match', Default = true, Callback = function(v) Cfg.StopOnMatch = v end })
SniperBox:AddButton('▶ Start Sniper', function() Cfg.SniperActive = true GlobalSniperLock = false end)
SniperBox:AddButton('⏹ Stop Sniper', function() Cfg.SniperActive = false GlobalSniperLock = false end)
SniperBox:AddButton('Auto Roller One Click', function()
    local url = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/refs/heads/master/oneclick.lua"
    if url ~= "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/refs/heads/master/oneclick.lua" then
        loadstring(game:HttpGet(url))()
    else
        Library:Notify("Please configure the URL in the script first!")
    end
end)

SaveManager:SetLibrary(Library)
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs['UI Settings'])
