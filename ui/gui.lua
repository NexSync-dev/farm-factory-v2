local GUI = {}
local Players = game:GetService("Players")

local Utils, Farmer, Sniper, Economy, AntiAFK, Config
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
    Utils, Farmer, Sniper, Economy, AntiAFK, Config = state.Utils, state.Farmer, state.Sniper, state.Economy, state.AntiAFK, state.Config
    local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
    Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

    local FruitList = buildFruitList()
    local Window = Library:CreateWindow({ Title = "Farm Tool | Ultra Bypass V6.3 (Rewrite)", Center = true, AutoShow = true })

    local Tabs = {
        Dashboard = Window:AddTab("🏠 Dashboard"),
        Farmer = Window:AddTab("🌾 Farmer"),
        Sniper = Window:AddTab("🎰 Sniper"),
        Economy = Window:AddTab("💰 Economy"),
        Settings = Window:AddTab("⚙ Settings")
    }

    state._library = Library

    local StatusBox = Tabs.Dashboard:AddLeftGroupbox("Status")
    local statsLabel = StatusBox:AddLabel("Loading stats...")
    StatusBox:AddButton({ Text = "🔄 Reset Stats", Func = function() Farmer.resetStats() Sniper.resetStats() end })

    local InfoBox = Tabs.Dashboard:AddRightGroupbox("Info")
    InfoBox:AddLabel("FarmV2 — Modular V1 Match")
    InfoBox:AddLabel("Game: Build A Farm Factory 🌱")
    InfoBox:AddButton({ Text = "⏏ Unload Script", Func = function()
        Config.Running = false
        if state._connections then
            for _, c in ipairs(state._connections) do
                if c.Connected then c:Disconnect() end
            end
        end
        Library:Unload()
    end })

    local HarvestBox = Tabs.Farmer:AddLeftGroupbox("Harvesting")
    HarvestBox:AddToggle("CollectPlants", { Text = "🌿 Auto Harvest", Default = Config.Collect, Callback = function(v) Config.Collect = v end })
    HarvestBox:AddSlider("CollectDelay", { Text = "Extra Delay (s)", Default = Config.CollectDelay, Min = 0, Max = 0.1, Rounding = 4, Callback = function(v) Config.CollectDelay = v end })

    local FilterBox = Tabs.Farmer:AddRightGroupbox("Filters")
    FilterBox:AddToggle("StrictActive", { Text = "🔒 Only Farm Selected", Default = Config.StrictFarm, Callback = function(v) Config.StrictFarm = v end })
    FilterBox:AddDropdown("PrioList", { Values = FruitList, Multi = true, Text = "Priority Fruits", AllowNull = true, Callback = function(v) Config.PriorityList = v end })

    local TpBox = Tabs.Farmer:AddRightGroupbox("Teleport")
    TpBox:AddDropdown("BypassMode", { Values = { "True Bypass", "FastSnap" }, Default = Config.BypassMode, Text = "Bypass Technique", Callback = function(v) Config.BypassMode = v end })

    local SniperBox = Tabs.Sniper:AddLeftGroupbox("Roll Sniper")
    SniperBox:AddDropdown("TargetFruits", { Values = FruitList, Multi = true, Text = "Target Fruits", AllowNull = true, Callback = function(v) Config.Sniper.TargetFruits = v end })
    SniperBox:AddInput("MinEarnings", { Text = "Min Earnings", Default = tostring(Config.Sniper.MinEarnings or 0), Numeric = true, Callback = function(v) Config.Sniper.MinEarnings = tonumber(v) or 0 end })
    SniperBox:AddToggle("InstantMode", { Text = "⚡ Instant Mode", Default = Config.Sniper.InstantMode, Callback = function(v) Config.Sniper.InstantMode = v end })
    SniperBox:AddSlider("AutoRollSpeed", { Text = "Normal Roll Speed (s)", Default = Config.Sniper.AutoRollSpeed, Min = 0.02, Max = 0.3, Rounding = 3, Callback = function(v) Config.Sniper.AutoRollSpeed = v end })

    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("Controls")
    SniperCtrl:AddToggle("AutoBuyMatch", { Text = "🛒 Auto Buy on Match", Default = Config.Sniper.AutoBuyMatch, Callback = function(v) Config.Sniper.AutoBuyMatch = v end })
    SniperCtrl:AddToggle("StopOnMatch", { Text = "⏸ Stop on Match", Default = Config.Sniper.StopOnMatch, Callback = function(v) Config.Sniper.StopOnMatch = v end })
    SniperCtrl:AddSlider("ProceedDelay", { Text = "Proceed Delay (s)", Default = Config.Sniper.ProceedDelay, Min = 0.1, Max = 5, Rounding = 1, Callback = function(v) Config.Sniper.ProceedDelay = v end })
    SniperCtrl:AddButton({ Text = "▶ Start Sniper", Func = function() Sniper.start() end })
    SniperCtrl:AddButton({ Text = "⏹ Stop Sniper", Func = function() Sniper.stop() end })
    local sniperStatsLabel = SniperCtrl:AddLabel("Rolls: 0 | Matches: 0 | Bought: 0")

    local SellBox = Tabs.Economy:AddLeftGroupbox("Auto Sell")
    SellBox:AddToggle("AutoSell", { Text = "💵 Auto Sell", Default = Config.AutoSell, Callback = function(v) Config.AutoSell = v end })
    SellBox:AddSlider("SellInterval", { Text = "Sell Interval (s)", Default = Config.SellInterval, Min = 0.1, Max = 5, Rounding = 2, Callback = function(v) Config.SellInterval = v end })

    local UpgradeBox = Tabs.Economy:AddRightGroupbox("Auto Upgrades")
    for _, name in ipairs(Economy.getUpgradeNames()) do
        UpgradeBox:AddToggle("Auto" .. name, { Text = "⬆ Auto " .. name, Default = Config.AutoUpgrades[name] or false, Callback = function(v) Config.AutoUpgrades[name] = v end })
    end

    local GenBox = Tabs.Settings:AddLeftGroupbox("General")
    GenBox:AddToggle("AntiAFK", { Text = "🛡 Anti-AFK", Default = Config.AntiAFK.antiAFK, Callback = function(v) AntiAFK.setAntiAFK(v) end })
    GenBox:AddToggle("NoClip", { Text = "👻 NoClip", Default = Config.AntiAFK.noClip, Callback = function(v) AntiAFK.setNoClip(v) end })
    GenBox:AddToggle("DebugMode", { Text = "🐛 Debug Logging", Default = true, Callback = function(v) Utils.setDebug(v) end })

    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.Settings)

    task.spawn(function()
        while Library and Config.Running do
            local fStats = Farmer.getStats()
            local sStats = Sniper.getStats()
            pcall(function()
                statsLabel:SetText(string.format("🌾 Harvested: %d | 🔄 Cycles: %d", fStats.totalHarvested, fStats.cycleCount))
                sniperStatsLabel:SetText(string.format("🎲 Rolls: %d | 🎯 Matches: %d | 🛒 Bought: %d", sStats.totalRolls, sStats.matches, sStats.bought))
            end)
            task.wait(1)
        end
    end)
end

return GUI
