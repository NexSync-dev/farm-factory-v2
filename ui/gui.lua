local GUI = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Utils, Scheduler, Network, Farmer, Sniper, AutoSell, Upgrades, AntiAFK, BeeBuyer, Visuals, Config
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
    Utils = state.Utils
    Scheduler = state.Scheduler
    Network = state.Network
    Farmer = state.Farmer
    Sniper = state.Sniper
    AutoSell = state.AutoSell
    Upgrades = state.Upgrades
    AntiAFK = state.AntiAFK
    BeeBuyer = state.BeeBuyer
    Visuals = state.Visuals
    Config = state.Config

    if state._LinoriaLib and state._ThemeManager and state._SaveManager then
        Library = state._LinoriaLib
        ThemeManager = state._ThemeManager
        SaveManager = state._SaveManager
    else
        local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
        Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
        ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
        SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    end

    local FruitList = buildFruitList()

    local Window = Library:CreateWindow({ Title = "Farm Tool | V2", Center = true, AutoShow = true })
    local Tabs = {
        Main = Window:AddTab("Main"),
        Farming = Window:AddTab("Farm"),
        Upgrades = Window:AddTab("Upgrades"),
        Sniper = Window:AddTab("Sniper"),
        Bees = Window:AddTab("Bees"),
        ["UI Settings"] = Window:AddTab("UI"),
    }

    state._library = Library
    state._unloaded = false

    local StatusBox = Tabs.Main:AddLeftGroupbox("Quick Controls")
    StatusBox:AddToggle("MasterToggle", {
        Text = "▶ Master Enable",
        Default = true,
        Callback = function(v)
            if v then Scheduler.start() else Scheduler.stop() end
        end
    })

    local statsLabel = StatusBox:AddLabel("Loading stats...")

    StatusBox:AddButton({
        Text = "Reset Stats",
        Func = function()
            if Farmer and Farmer.resetStats then Farmer.resetStats() end
            if Sniper and Sniper.resetStats then Sniper.resetStats() end
            if Network and Network.resetStats then Network.resetStats() end
            if BeeBuyer and BeeBuyer.resetStats then BeeBuyer.resetStats() end
        end
    })

    StatusBox:AddButton({
        Text = "🚀 Launch Advanced Roller",
        Func = function()
            local ok, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/nexsync_roller.lua?t=" .. tostring(os.time())
                ))()
            end)
            if not ok then
                Library:Notify("Failed to load roller: " .. tostring(err))
            end
        end
    })

    local InfoBox = Tabs.Main:AddRightGroupbox("Info")
    InfoBox:AddLabel("Farm Factory V2")
    InfoBox:AddLabel("Modular Engine")
    InfoBox:AddButton({
        Text = "Unload",
        Func = function()
            state._unloaded = true
            Scheduler.stop()
            if state._connections then
                for _, c in ipairs(state._connections) do
                    if c.Connected then c:Disconnect() end
                end
            end
            Library:Unload()
        end
    })

    local HideBox = Tabs.Main:AddLeftGroupbox("Hide Us")
    HideBox:AddToggle("HideUsEnabled", {
        Text = "Enable Hide Us (Avatars)",
        Default = false,
        Callback = function(v) Visuals.setHideUs(v) end
    })
    HideBox:AddToggle("SpoofNameEnabled", {
        Text = "Enable Name Spoof",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofNameEnabled", v) end
    })
    HideBox:AddInput("SpoofName", {
        Text = "Spoof Name",
        Default = "sorry",
        Callback = function(v) Visuals.setConfig("spoofName", v) end
    })
    HideBox:AddInput("AvatarID", {
        Text = "Avatar/Bacon ID",
        Default = "4050212733",
        Numeric = true,
        Callback = function(v) Visuals.setConfig("avatarId", tonumber(v) or 4050212733) end
    })
    HideBox:AddToggle("SpoofCurrencies", {
        Text = "Fake Inf Currencies",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofCurrencies", v) end
    })
    HideBox:AddToggle("HidePlot", {
        Text = "Hide My Plot",
        Default = false,
        Callback = function(v) Visuals.setConfig("hidePlot", v) end
    })

    local GenBox = Tabs.Main:AddRightGroupbox("General")
    GenBox:AddToggle("AntiAFK", {
        Text = "Anti-AFK",
        Default = Config.AntiAFK.antiAFK ~= false,
        Callback = function(v)
            if AntiAFK and AntiAFK.setAntiAFK then AntiAFK.setAntiAFK(v) end
        end
    })
    GenBox:AddToggle("NoClip", {
        Text = "NoClip",
        Default = Config.AntiAFK.noClip ~= false,
        Callback = function(v)
            if AntiAFK and AntiAFK.setNoClip then AntiAFK.setNoClip(v) end
        end
    })
    GenBox:AddToggle("DebugMode", {
        Text = "Debug Logging",
        Default = true,
        Callback = function(v) Utils.setDebug(v) end
    })

    local NetBox = Tabs.Main:AddRightGroupbox("Network Tuning")
    NetBox:AddSlider("ClickRate", {
        Text = "ClickPlant Rate",
        Default = 30, Min = 5, Max = 60, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("ClickPlant", v, v) end
        end
    })
    NetBox:AddSlider("RollRate", {
        Text = "DoRoll Rate",
        Default = 20, Min = 5, Max = 40, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("DoRoll", v, v) end
        end
    })
    NetBox:AddSlider("SellRate", {
        Text = "SellCrate Rate",
        Default = 5, Min = 1, Max = 20, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("SellCrate", v, v) end
        end
    })

    local HarvestBox = Tabs.Farming:AddLeftGroupbox("Harvesting")
    HarvestBox:AddToggle("FarmerEnabled", {
        Text = "Auto Collect",
        Default = Config.Farmer.enabled or false,
        Callback = function(v) Config.Farmer.enabled = v end
    })
    HarvestBox:AddDropdown("HarvestMode", {
        Values = { "True Bypass", "Anchored Snap", "Batch Snap" },
        Default = (Config.Farmer.harvestMode == "bypass" and "True Bypass")
            or (Config.Farmer.harvestMode == "snap" and "Anchored Snap")
            or "Batch Snap",
        Text = "Harvest Mode",
        Callback = function(v)
            local map = { ["True Bypass"] = "bypass", ["Anchored Snap"] = "snap", ["Batch Snap"] = "batch" }
            Config.Farmer.harvestMode = map[v] or "batch"
        end
    })
    HarvestBox:AddSlider("TilesPerFrame", {
        Text = "Tiles per Frame (Batch)",
        Default = Config.Farmer.tilesPerFrame or 10,
        Min = 1, Max = 30, Rounding = 0,
        Callback = function(v) Config.Farmer.tilesPerFrame = v end
    })
    HarvestBox:AddSlider("FiresPerCycle", {
        Text = "Max Fires per Cycle",
        Default = Config.Farmer.firesPerCycle or 120,
        Min = 10, Max = 9999, Rounding = 0,
        Callback = function(v) Config.Farmer.firesPerCycle = v end
    })
    HarvestBox:AddSlider("CollectDelay", {
        Text = "Extra Delay (s)",
        Default = Config.Farmer.collectDelay or 0,
        Min = 0, Max = 0.1, Rounding = 4,
        Callback = function(v) Config.Farmer.collectDelay = v end
    })

    local BypassBox = Tabs.Farming:AddRightGroupbox("Bypass Settings")
    BypassBox:AddToggle("ClaimOwnership", {
        Text = "Claim Network Ownership",
        Default = Config.Farmer.claimOwnership or false,
        Callback = function(v) Config.Farmer.claimOwnership = v end
    })
    BypassBox:AddSlider("YOffset", {
        Text = "TP Height Offset",
        Default = Config.Farmer.yOffset or 3.5,
        Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) Config.Farmer.yOffset = v end
    })

    local FilterBox = Tabs.Farming:AddRightGroupbox("Filters")
    FilterBox:AddToggle("StrictMode", {
        Text = "Selected Fruits Only",
        Default = Config.Farmer.useStrictMode or false,
        Callback = function(v) Config.Farmer.useStrictMode = v end
    })
    FilterBox:AddDropdown("PriorityFruits", {
        Values = FruitList, Multi = true,
        Text = "Selected Fruits", AllowNull = true,
        Callback = function(v) Config.Farmer.priorityFruits = v end
    })

    local SellBox = Tabs.Farming:AddRightGroupbox("Misc")
    if AutoSell then
        SellBox:AddToggle("AutoSellEnabled", {
            Text = "Auto Sell",
            Default = Config.AutoSell.enabled or false,
            Callback = function(v) Config.AutoSell.enabled = v end
        })
        SellBox:AddSlider("SellInterval", {
            Text = "Sell Interval",
            Default = Config.AutoSell.sellInterval or 0.6,
            Min = 0.1, Max = 5, Rounding = 2,
            Callback = function(v)
                Config.AutoSell.sellInterval = v
                Scheduler.setInterval("AutoSell", v)
            end
        })
    else
        SellBox:AddLabel("AutoSell module unavailable")
    end

    local UpgradeBox = Tabs.Upgrades:AddLeftGroupbox("Auto Upgrades")
    if Upgrades and Upgrades.getUpgradeNames then
        for _, name in ipairs(Upgrades.getUpgradeNames()) do
            UpgradeBox:AddToggle("Auto" .. name, {
                Text = "Auto " .. name,
                Default = Config.Upgrades[name] or false,
                Callback = function(v) Upgrades.setUpgrade(name, v) end
            })
        end
    else
        UpgradeBox:AddLabel("Upgrades module unavailable")
    end

    local SniperBox = Tabs.Sniper:AddLeftGroupbox("Sniper Settings")
    SniperBox:AddDropdown("TargetFruits", {
        Values = FruitList, Multi = true,
        Text = "Target Fruits", AllowNull = true,
        Callback = function(v) Config.Sniper.targetFruits = v end
    })
    SniperBox:AddInput("MinEarnings", {
        Text = "Min Earnings",
        Default = tostring(Config.Sniper.minEarnings or 0),
        Numeric = true,
        Callback = function(v) Config.Sniper.minEarnings = tonumber(v) or 0 end
    })
    SniperBox:AddToggle("InstantMode", {
        Text = "⚡ Instant Mode",
        Default = Config.Sniper.instantMode or false,
        Callback = function(v) Config.Sniper.instantMode = v end
    })
    SniperBox:AddSlider("RollSpeed", {
        Text = "Normal Roll Speed (s)",
        Default = Config.Sniper.rollSpeed or 0.05,
        Min = 0.02, Max = 0.3, Rounding = 3,
        Callback = function(v) Config.Sniper.rollSpeed = v end
    })
    SniperBox:AddSlider("RollBurst", {
        Text = "Rolls per Tick",
        Default = Config.Sniper.rollBurst or 1,
        Min = 1, Max = 5, Rounding = 0,
        Callback = function(v) Config.Sniper.rollBurst = v end
    })

    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("Controls")
    SniperCtrl:AddToggle("AutoBuyMatch", {
        Text = "Auto Buy on Match",
        Default = Config.Sniper.autoBuyMatch or false,
        Callback = function(v) Config.Sniper.autoBuyMatch = v end
    })
    SniperCtrl:AddToggle("StopOnMatch", {
        Text = "Stop on Match",
        Default = Config.Sniper.stopOnMatch or true,
        Callback = function(v) Config.Sniper.stopOnMatch = v end
    })
    SniperCtrl:AddToggle("AutoProceedAfterBuy", {
        Text = "Continue Rolling After Buy",
        Default = Config.Sniper.autoProceedAfterBuy ~= false,
        Callback = function(v) Config.Sniper.autoProceedAfterBuy = v end
    })
    SniperCtrl:AddSlider("AutoProceedDelay", {
        Text = "Proceed Delay (s)",
        Default = Config.Sniper.autoProceedDelay or 1.2,
        Min = 0.1, Max = 5, Rounding = 1,
        Callback = function(v) Config.Sniper.autoProceedDelay = v end
    })
    SniperCtrl:AddButton({
        Text = "▶ Start Sniper",
        Func = function()
            if Sniper and Sniper.start then Sniper.start() end
        end
    })
    SniperCtrl:AddButton({
        Text = "⏹ Stop Sniper",
        Func = function()
            if Sniper and Sniper.stop then Sniper.stop() end
        end
    })
    local sniperStatsLabel = SniperCtrl:AddLabel("Attempts: 0 | Rolls: 0 | Matches: 0 | Bought: 0 | Skipped: 0")

    local BeeBox = Tabs.Bees:AddLeftGroupbox("Bee Shop")
    local beeList = (BeeBuyer and BeeBuyer.getBeeList and BeeBuyer.getBeeList()) or {}

    if #beeList > 0 then
        local selectedBee = nil

        BeeBox:AddDropdown("BeeSelect", {
            Values = beeList,
            Text = "Select Bee",
            AllowNull = true,
            Callback = function(v) selectedBee = v end
        })

        BeeBox:AddButton({
            Text = "🐝 Buy Selected Bee",
            Func = function()
                if not selectedBee then
                    Library:Notify("No bee selected!")
                    return
                end
                local ok, result = BeeBuyer.buyBee(selectedBee)
                if ok then
                    Library:Notify("Bought: " .. selectedBee)
                else
                    Library:Notify("Failed: " .. tostring(result))
                end
            end
        })

        local beeStatsLabel = BeeBox:AddLabel("Bought: 0 | Failed: 0 | Last: None")
        state._beeStatsLabel = beeStatsLabel
    else
        BeeBox:AddLabel("No bees found in ReplicatedStorage")
        BeeBox:AddLabel("Bee Salesman may be closed")
    end

    local BeeInfoBox = Tabs.Bees:AddRightGroupbox("Info")
    BeeInfoBox:AddLabel("Select a bee from the dropdown")
    BeeInfoBox:AddLabel("and click Buy to purchase it.")
    BeeInfoBox:AddLabel("")
    BeeInfoBox:AddLabel("Possible errors:")
    BeeInfoBox:AddLabel("• Not enough money")
    BeeInfoBox:AddLabel("• Bee Salesman is closed")

    local UISettingsBox = Tabs["UI Settings"]:AddLeftGroupbox("Menu Settings")
    UISettingsBox:AddLabel("Menu Toggle"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Menu Toggle",
        Callback = function() Library:Toggle() end
    })
    Library.ToggleKeybind = Options.MenuKeybind

    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs["UI Settings"])

    task.spawn(function()
        while not state._unloaded do
            local farmerStats = (Farmer and Farmer.getStats and Farmer.getStats()) or { totalHarvested = 0, cycleCount = 0 }
            local netStats = (Network and Network.getStats and Network.getStats()) or { totalFired = 0, totalInvoked = 0, totalErrors = 0 }
            local ping = Utils.getPing()
            local sniperStats = (Sniper and Sniper.getStats and Sniper.getStats()) or { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }

            pcall(function()
                statsLabel:SetText(string.format(
                    "Harvested: %d | Cycles: %d\nPing: %dms | Calls: %d | Errors: %d",
                    farmerStats.totalHarvested, farmerStats.cycleCount,
                    ping, netStats.totalFired + netStats.totalInvoked, netStats.totalErrors
                ))
                sniperStatsLabel:SetText(string.format(
                    "Attempts: %d | Rolls: %d | Matches: %d | Bought: %d | Skipped: %d",
                    sniperStats.attempts or 0, sniperStats.totalRolls or 0,
                    sniperStats.matches or 0, sniperStats.bought or 0, sniperStats.skipped or 0
                ))
            end)

            if state._beeStatsLabel and BeeBuyer and BeeBuyer.getStats then
                pcall(function()
                    local bs = BeeBuyer.getStats()
                    state._beeStatsLabel:SetText(string.format(
                        "Bought: %d | Failed: %d | Last: %s",
                        bs.bought, bs.failed, bs.lastBought
                    ))
                end)
            end

            task.wait(1)
        end
    end)
end

return GUI
