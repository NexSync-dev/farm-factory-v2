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
    local Window = Library:CreateWindow({ Title = "FarmV2 | Build A Farm Factory", Center = true, AutoShow = true })
    local Tabs = { Dashboard = Window:AddTab("🏠 Dashboard"), Farmer = Window:AddTab("🌾 Farmer"), Sniper = Window:AddTab("🎰 Sniper"), Economy = Window:AddTab("💰 Economy"), Settings = Window:AddTab("⚙ Settings") }
    state._library = Library
    local StatusBox = Tabs.Dashboard:AddLeftGroupbox("Status")
    StatusBox:AddToggle("MasterToggle", { Text = "▶ Master Enable", Default = true, Callback = function(v) if v then Scheduler.start() else Scheduler.stop() end end })
    local statsLabel = StatusBox:AddLabel("Loading stats...")
    StatusBox:AddButton({ Text = "🔄 Reset Stats", Func = function() Farmer.resetStats() Sniper.resetStats() Network.resetStats() end })
    local InfoBox = Tabs.Dashboard:AddRightGroupbox("Info")
    InfoBox:AddLabel("FarmV2 — Modular Rewrite")
    InfoBox:AddLabel("Game: Build A Farm Factory 🌱")
    InfoBox:AddButton({ Text = "⏏ Unload Script", Func = function() Scheduler.stop() if state._connections then for _, c in ipairs(state._connections) do if c.Connected then c:Disconnect() end end end Library:Unload() end })
    local HarvestBox = Tabs.Farmer:AddLeftGroupbox("Harvesting")
    HarvestBox:AddToggle("FarmerEnabled", { Text = "🌿 Auto Harvest", Default = Config.Farmer.enabled or false, Callback = function(v) Config.Farmer.enabled = v end })
    HarvestBox:AddSlider("BatchSize", { Text = "Clicks per Frame", Default = Config.Farmer.batchSize or 5, Min = 1, Max = 20, Rounding = 0, Callback = function(v) Config.Farmer.batchSize = v end })
    HarvestBox:AddSlider("ClusterRadius", { Text = "Cluster Radius (studs)", Default = Config.Farmer.clusterRadius or 20, Min = 5, Max = 100, Rounding = 0, Callback = function(v) Config.Farmer.clusterRadius = v end })
    HarvestBox:AddSlider("MaxPerCycle", { Text = "Max Tiles per Cycle", Default = Config.Farmer.maxPerCycle or 9999, Min = 10, Max = 9999, Rounding = 0, Callback = function(v) Config.Farmer.maxPerCycle = v end })
    HarvestBox:AddSlider("CollectDelay", { Text = "Extra Delay (s)", Default = Config.Farmer.collectDelay or 0, Min = 0, Max = 0.1, Rounding = 4, Callback = function(v) Config.Farmer.collectDelay = v end })
    local FilterBox = Tabs.Farmer:AddRightGroupbox("Filters")
    FilterBox:AddToggle("StrictMode", { Text = "🔒 Only Farm Selected", Default = Config.Farmer.useStrictMode or false, Callback = function(v) Config.Farmer.useStrictMode = v end })
    FilterBox:AddDropdown("PriorityFruits", { Values = FruitList, Multi = true, Text = "Priority Fruits", AllowNull = true, Callback = function(v) Config.Farmer.priorityFruits = v end })
    local TpBox = Tabs.Farmer:AddRightGroupbox("Teleport")
    TpBox:AddDropdown("TpMode", { Values = { "True Bypass", "instant", "safe" }, Default = Config.Farmer.tpMode or "instant", Text = "TP Mode", Callback = function(v) Config.Farmer.tpMode = v end })
    TpBox:AddSlider("SafeTpStep", { Text = "Safe TP Step (studs)", Default = Config.Farmer.safeTpStep or 100, Min = 10, Max = 500, Rounding = 0, Callback = function(v) Config.Farmer.safeTpStep = v end })
    local SniperBox = Tabs.Sniper:AddLeftGroupbox("Roll Sniper")
    SniperBox:AddDropdown("TargetFruits", { Values = FruitList, Multi = true, Text = "Target Fruits", AllowNull = true, Callback = function(v) Config.Sniper.targetFruits = v end })
    SniperBox:AddInput("MinEarnings", { Text = "Min Earnings", Default = tostring(Config.Sniper.minEarnings or 0), Numeric = true, Callback = function(v) Config.Sniper.minEarnings = tonumber(v) or 0 end })
    SniperBox:AddToggle("InstantMode", { Text = "⚡ Instant Mode", Default = Config.Sniper.instantMode or false, Callback = function(v) Config.Sniper.instantMode = v end })
    SniperBox:AddSlider("RollSpeed", { Text = "Normal Roll Speed (s)", Default = Config.Sniper.rollSpeed or 0.05, Min = 0.02, Max = 0.3, Rounding = 3, Callback = function(v) Config.Sniper.rollSpeed = v end })
    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("Controls")
    SniperCtrl:AddToggle("AutoBuyMatch", { Text = "🛒 Auto Buy on Match", Default = Config.Sniper.autoBuyMatch or false, Callback = function(v) Config.Sniper.autoBuyMatch = v end })
    SniperCtrl:AddToggle("StopOnMatch", { Text = "⏸ Stop on Match", Default = Config.Sniper.stopOnMatch or true, Callback = function(v) Config.Sniper.stopOnMatch = v end })
    SniperCtrl:AddButton({ Text = "▶ Start Sniper", Func = function() Sniper.start() end })
    SniperCtrl:AddButton({ Text = "⏹ Stop Sniper", Func = function() Sniper.stop() end })
    local sniperStatsLabel = SniperCtrl:AddLabel("Rolls: 0 | Matches: 0 | Bought: 0")
    local SellBox = Tabs.Economy:AddLeftGroupbox("Auto Sell")
    SellBox:AddToggle("AutoSellEnabled", { Text = "💵 Auto Sell", Default = Config.AutoSell.enabled or false, Callback = function(v) Config.AutoSell.enabled = v end })
    SellBox:AddSlider("SellInterval", { Text = "Sell Interval (s)", Default = Config.AutoSell.sellInterval or 0.6, Min = 0.1, Max = 5, Rounding = 2, Callback = function(v) Config.AutoSell.sellInterval = v end })
    local UpgradeBox = Tabs.Economy:AddRightGroupbox("Auto Upgrades")
    for _, name in ipairs(Upgrades.getUpgradeNames()) do
        UpgradeBox:AddToggle("Auto" .. name, { Text = "⬆ Auto " .. name, Default = Config.Upgrades[name] or false, Callback = function(v) Upgrades.setUpgrade(name, v) end })
    end
    local GenBox = Tabs.Settings:AddLeftGroupbox("General")
    GenBox:AddToggle("AntiAFK", { Text = "🛡 Anti-AFK", Default = Config.AntiAFK.antiAFK ~= false, Callback = function(v) AntiAFK.setAntiAFK(v) end })
    GenBox:AddToggle("NoClip", { Text = "👻 NoClip", Default = Config.AntiAFK.noClip ~= false, Callback = function(v) AntiAFK.setNoClip(v) end })
    GenBox:AddToggle("DebugMode", { Text = "🐛 Debug Logging", Default = true, Callback = function(v) Utils.setDebug(v) end })
    local NetBox = Tabs.Settings:AddRightGroupbox("Network Tuning")
    NetBox:AddSlider("ClickRate", { Text = "ClickPlant Rate", Default = 30, Min = 5, Max = 60, Rounding = 0, Callback = function(v) Network.setLimit("ClickPlant", v, v) end })
    NetBox:AddSlider("RollRate", { Text = "DoRoll Rate", Default = 20, Min = 5, Max = 40, Rounding = 0, Callback = function(v) Network.setLimit("DoRoll", v, v) end })
    NetBox:AddSlider("SellRate", { Text = "SellCrate Rate", Default = 5, Min = 1, Max = 20, Rounding = 0, Callback = function(v) Network.setLimit("SellCrate", v, v) end })
    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.Settings)
    task.spawn(function()
        while Library and Scheduler.isAlive() do
            local farmerStats = Farmer.getStats()
            local netStats = Network.getStats()
            local ping = Utils.getPing()
            local sniperStats = Sniper.getStats()
            pcall(function()
                statsLabel:SetText(string.format("🌾 Harvested: %d | 🔄 Cycles: %d\n📡 Ping: %dms | 🌐 Fired: %d | ❌ Errors: %d", farmerStats.totalHarvested, farmerStats.cycleCount, ping, netStats.totalFired + netStats.totalInvoked, netStats.totalErrors))
                sniperStatsLabel:SetText(string.format("🎲 Rolls: %d | 🎯 Matches: %d | 🛒 Bought: %d", sniperStats.totalRolls, sniperStats.matches, sniperStats.bought))
            end)
            task.wait(1)
        end
    end)
end
return GUI
