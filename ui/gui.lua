local GUI = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Utils, Scheduler, Network, Farmer, Sniper, AutoSell, Upgrades, AntiAFK, Config
local Library, ThemeManager, SaveManager
local function buildFruitList()
    local fruits = {}
    pcall(function()
        local storage = game:GetService("ReplicatedStorage"):FindFirstChild("Storage")
        if storage then
            local fruitFolder = storage:FindFirstChild("Fruit")
            if fruitFolder then
                for _, fruit in ipairs(fruitFolder:GetChildren()) do
                    table.insert(fruits, fruit.Name)
                end
            end
        end
    end)
    table.sort(fruits)
    return fruits
end
function GUI.build(state)
    Utils, Scheduler, Network, Farmer, Sniper, AutoSell, Upgrades, AntiAFK, Config = state.Utils, state.Scheduler, state.Network, state.Farmer, state.Sniper, state.AutoSell, state.Upgrades, state.AntiAFK, state.Config
    local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
    Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    local FruitList = buildFruitList()
    local Window = Library:CreateWindow({ Title = "Farm Tool | V2", Center = true, AutoShow = true })
    local Tabs = {
        Main = Window:AddTab("Main"),
        Farming = Window:AddTab("Farming"),
        Upgrades = Window:AddTab("Upgrades"),
        Sniper = Window:AddTab("Roll Sniper"),
        ["UI Settings"] = Window:AddTab("UI Settings"),
    }
    state._library = Library
    local StatusBox = Tabs.Main:AddLeftGroupbox("Quick Controls")
    StatusBox:AddToggle("MasterToggle", { Text = "▶ Master Enable", Default = true, Callback = function(v) if v then Scheduler.start() else Scheduler.stop() end end })
    local statsLabel = StatusBox:AddLabel("Loading stats...")
    StatusBox:AddButton({
        Text = "Reset Stats",
        Func = function()
            if Farmer and Farmer.resetStats then Farmer.resetStats() end
            if Sniper and Sniper.resetStats then Sniper.resetStats() end
            if Network and Network.resetStats then Network.resetStats() end
        end
    })
    StatusBox:AddButton({
        Text = "Launch Advanced Roller",
        Func = function()
            local url = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/refs/heads/master/oneclick.lua"
            if url ~= "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/refs/heads/master/oneclick.lua" then
                loadstring(game:HttpGet(url))()
            else
                Library:Notify("Please configure the URL in the script first!")
            end
        end
    })
    local InfoBox = Tabs.Main:AddRightGroupbox("Info")
    InfoBox:AddLabel("Fast V2 mode")
    InfoBox:AddLabel("No V1 fallback")
    InfoBox:AddButton({ Text = "Unload", Func = function() Scheduler.stop() if state._connections then for _, c in ipairs(state._connections) do if c.Connected then c:Disconnect() end end end Library:Unload() end })
    local HarvestBox = Tabs.Farming:AddLeftGroupbox("Harvesting")
    HarvestBox:AddToggle("FarmerEnabled", { Text = "Auto Collect", Default = Config.Farmer.enabled or false, Callback = function(v) Config.Farmer.enabled = v end })
    HarvestBox:AddSlider("BatchSize", { Text = "Clicks per Frame", Default = Config.Farmer.batchSize or 15, Min = 1, Max = 30, Rounding = 0, Callback = function(v) Config.Farmer.batchSize = v end })
    HarvestBox:AddSlider("MaxPerCycle", { Text = "Max Tiles per Cycle", Default = Config.Farmer.maxPerCycle or 9999, Min = 10, Max = 9999, Rounding = 0, Callback = function(v) Config.Farmer.maxPerCycle = v end })
    HarvestBox:AddSlider("CollectDelay", { Text = "Extra Delay (s)", Default = Config.Farmer.collectDelay or 0, Min = 0, Max = 0.1, Rounding = 4, Callback = function(v) Config.Farmer.collectDelay = v end })
    local FilterBox = Tabs.Farming:AddRightGroupbox("Filters")
    FilterBox:AddToggle("StrictMode", { Text = "Selected Fruits Only", Default = Config.Farmer.useStrictMode or false, Callback = function(v) Config.Farmer.useStrictMode = v end })
    FilterBox:AddDropdown("PriorityFruits", { Values = FruitList, Multi = true, Text = "Selected Fruits", AllowNull = true, Callback = function(v) Config.Farmer.priorityFruits = v end })
    local TpBox = Tabs.Farming:AddRightGroupbox("Bypass Settings")
    TpBox:AddDropdown("TpMode", { Values = { "True Bypass", "instant", "safe" }, Default = Config.Farmer.tpMode or "instant", Text = "TP Mode", Callback = function(v) Config.Farmer.tpMode = v end })
    TpBox:AddSlider("SafeTpStep", { Text = "Safe TP Step (studs)", Default = Config.Farmer.safeTpStep or 100, Min = 10, Max = 500, Rounding = 0, Callback = function(v) Config.Farmer.safeTpStep = v end })
    local SniperBox = Tabs.Sniper:AddLeftGroupbox("Sniper Settings")
    SniperBox:AddDropdown("TargetFruits", { Values = FruitList, Multi = true, Text = "Target Fruits", AllowNull = true, Callback = function(v) Config.Sniper.targetFruits = v end })
    SniperBox:AddInput("MinEarnings", { Text = "Min Earnings", Default = tostring(Config.Sniper.minEarnings or 0), Numeric = true, Callback = function(v) Config.Sniper.minEarnings = tonumber(v) or 0 end })
    SniperBox:AddToggle("InstantMode", { Text = "Instant Mode", Default = Config.Sniper.instantMode or false, Callback = function(v) Config.Sniper.instantMode = v; Scheduler.setInterval("Sniper", v and 0 or Config.Sniper.rollSpeed) end })
    SniperBox:AddSlider("RollSpeed", { Text = "Normal Roll Speed (s)", Default = Config.Sniper.rollSpeed or 0.05, Min = 0.02, Max = 0.3, Rounding = 3, Callback = function(v) Config.Sniper.rollSpeed = v; if not Config.Sniper.instantMode then Scheduler.setInterval("Sniper", v) end end })
    SniperBox:AddSlider("RollBurst", { Text = "Rolls per Tick", Default = Config.Sniper.rollBurst or 1, Min = 1, Max = 5, Rounding = 0, Callback = function(v) Config.Sniper.rollBurst = v end })
    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("Controls")
    SniperCtrl:AddToggle("AutoBuyMatch", { Text = "Auto Buy on Match", Default = Config.Sniper.autoBuyMatch or false, Callback = function(v) Config.Sniper.autoBuyMatch = v end })
    SniperCtrl:AddToggle("StopOnMatch", { Text = "Stop on Match", Default = Config.Sniper.stopOnMatch or true, Callback = function(v) Config.Sniper.stopOnMatch = v end })
    SniperCtrl:AddToggle("AutoProceedAfterBuy", { Text = "Continue Rolling After Buy", Default = Config.Sniper.autoProceedAfterBuy ~= false, Callback = function(v) Config.Sniper.autoProceedAfterBuy = v end })
    SniperCtrl:AddSlider("AutoProceedDelay", { Text = "Proceed Delay (s)", Default = Config.Sniper.autoProceedDelay or 1.2, Min = 0.1, Max = 5, Rounding = 1, Callback = function(v) Config.Sniper.autoProceedDelay = v end })
    SniperCtrl:AddButton({ Text = "▶ Start Sniper", Func = function() if Sniper and Sniper.start then Sniper.start() end end })
    SniperCtrl:AddButton({ Text = "⏹ Stop Sniper", Func = function() if Sniper and Sniper.stop then Sniper.stop() end end })
    local sniperStatsLabel = SniperCtrl:AddLabel("Attempts: 0 | Rolls: 0 | Matches: 0 | Bought: 0 | Skipped: 0")
    local SellBox = Tabs.Farming:AddRightGroupbox("Misc")
    if AutoSell then
        SellBox:AddToggle("AutoSellEnabled", { Text = "Auto Sell", Default = Config.AutoSell.enabled or false, Callback = function(v) Config.AutoSell.enabled = v end })
        SellBox:AddSlider("SellInterval", { Text = "Sell Interval", Default = Config.AutoSell.sellInterval or 0.6, Min = 0.1, Max = 5, Rounding = 2, Callback = function(v) Config.AutoSell.sellInterval = v; Scheduler.setInterval("AutoSell", v) end })
    else
        SellBox:AddLabel("AutoSell module unavailable")
    end
    local UpgradeBox = Tabs.Upgrades:AddLeftGroupbox("Auto Upgrades")
    if Upgrades and Upgrades.getUpgradeNames then
        for _, name in ipairs(Upgrades.getUpgradeNames()) do
            UpgradeBox:AddToggle("Auto" .. name, { Text = "Auto " .. name, Default = Config.Upgrades[name] or false, Callback = function(v) Upgrades.setUpgrade(name, v) end })
        end
    else
        UpgradeBox:AddLabel("Upgrades module unavailable")
    end
    local GenBox = Tabs.Main:AddLeftGroupbox("General")
    GenBox:AddToggle("AntiAFK", { Text = "Anti-AFK", Default = Config.AntiAFK.antiAFK ~= false, Callback = function(v) if AntiAFK and AntiAFK.setAntiAFK then AntiAFK.setAntiAFK(v) end end })
    GenBox:AddToggle("NoClip", { Text = "NoClip", Default = Config.AntiAFK.noClip ~= false, Callback = function(v) if AntiAFK and AntiAFK.setNoClip then AntiAFK.setNoClip(v) end end })
    GenBox:AddToggle("DebugMode", { Text = "Debug Logging", Default = true, Callback = function(v) Utils.setDebug(v) end })
    local NetBox = Tabs.Main:AddRightGroupbox("Network Tuning")
    NetBox:AddSlider("ClickRate", { Text = "ClickPlant Rate", Default = 30, Min = 5, Max = 60, Rounding = 0, Callback = function(v) if Network and Network.setLimit then Network.setLimit("ClickPlant", v, v) end end })
    NetBox:AddSlider("RollRate", { Text = "DoRoll Rate", Default = 20, Min = 5, Max = 40, Rounding = 0, Callback = function(v) if Network and Network.setLimit then Network.setLimit("DoRoll", v, v) end end })
    NetBox:AddSlider("SellRate", { Text = "SellCrate Rate", Default = 5, Min = 1, Max = 20, Rounding = 0, Callback = function(v) if Network and Network.setLimit then Network.setLimit("SellCrate", v, v) end end })
    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
    task.spawn(function()
        while Library do
            local farmerStats = (Farmer and Farmer.getStats and Farmer.getStats()) or { totalHarvested = 0, cycleCount = 0 }
            local netStats = (Network and Network.getStats and Network.getStats()) or { totalFired = 0, totalInvoked = 0, totalErrors = 0 }
            local ping = Utils.getPing()
            local sniperStats = (Sniper and Sniper.getStats and Sniper.getStats()) or { totalRolls = 0, matches = 0, bought = 0 }
            pcall(function()
                statsLabel:SetText(string.format("Harvested: %d | Cycles: %d\nPing: %dms | Calls: %d | Errors: %d", farmerStats.totalHarvested, farmerStats.cycleCount, ping, netStats.totalFired + netStats.totalInvoked, netStats.totalErrors))
                sniperStatsLabel:SetText(string.format("Attempts: %d | Rolls: %d | Matches: %d | Bought: %d | Skipped: %d", sniperStats.attempts or 0, sniperStats.totalRolls or 0, sniperStats.matches or 0, sniperStats.bought or 0, sniperStats.skipped or 0))
            end)
            task.wait(1)
        end
    end)
end
return GUI
