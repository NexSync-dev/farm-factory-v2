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

    local Window = Library:CreateWindow({ Title = "farm factory v2", Center = true, AutoShow = true })
    local Tabs = {
        Main = Window:AddTab("main"),
        Farming = Window:AddTab("farm"),
        Junk = Window:AddTab("junk"),
        Upgrades = Window:AddTab("upgrades"),
        Sniper = Window:AddTab("sniper"),
        Bees = Window:AddTab("bees"),
        Server = Window:AddTab("server"),
        ["UI Settings"] = Window:AddTab("ui"),
    }

    -- ... (in the build function)

    local JunkBox = Tabs.Junk:AddLeftGroupbox("sell junk")
    local selectedJunk = {}
    local autoSellJunkEnabled = false

    JunkBox:AddDropdown("JunkSelect", {
        Values = FruitList, Multi = true, Text = "select fruits", AllowNull = true,
        Callback = function(v) selectedJunk = v end
    })

    JunkBox:AddToggle("AutoSellJunk", {
        Text = "auto sell junk",
        Default = false,
        Callback = function(v)
            autoSellJunkEnabled = v
            if v then
                task.spawn(function()
                    while autoSellJunkEnabled do
                        local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
                        if backpack then
                            for name, isSelected in pairs(selectedJunk) do
                                if isSelected and autoSellJunkEnabled then
                                    local item = backpack:FindFirstChild(name)
                                    if item then
                                        local character = Players.LocalPlayer.Character
                                        if character then
                                            local humanoid = character:FindFirstChild("Humanoid")
                                            if humanoid then
                                                -- Equip
                                                humanoid:EquipTool(item)
                                                task.wait(0.5) -- Allow time to equip
                                                -- Delete
                                                local Event = game:GetService("ReplicatedStorage"):FindFirstChild("Communication") 
                                                    and game:GetService("ReplicatedStorage").Communication:FindFirstChild("DeleteHeldItem")
                                                if Event then
                                                    Event:FireServer()
                                                end
                                                task.wait(0.5) -- Allow time to process delete
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(1)
                    end
                end)
            end
        end
    })

    state._library = Library
    state._unloaded = false

    local StatusBox = Tabs.Main:AddLeftGroupbox("status")
    StatusBox:AddToggle("MasterToggle", {
        Text = "master toggle",
        Default = true,
        Callback = function(v)
            if v then Scheduler.start() else Scheduler.stop() end
        end
    })

    local statsLabel = StatusBox:AddLabel("wait...")

    StatusBox:AddButton({
        Text = "reset",
        Func = function()
            if Farmer and Farmer.resetStats then Farmer.resetStats() end
            if Sniper and Sniper.resetStats then Sniper.resetStats() end
            if Network and Network.resetStats then Network.resetStats() end
            if BeeBuyer and BeeBuyer.resetStats then BeeBuyer.resetStats() end
        end
    })

    StatusBox:AddButton({
        Text = "open roller",
        Func = function()
            local ok, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/nexsync_roller.lua?t=" .. tostring(os.time())
                ))()
            end)
            if not ok then
                Library:Notify("failed: " .. tostring(err))
            end
        end
    })

    local InfoBox = Tabs.Main:AddRightGroupbox("info")
    InfoBox:AddLabel("farm factory v2")
    InfoBox:AddLabel("modular engine")
    InfoBox:AddButton({
        Text = "unload",
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

    local HideBox = Tabs.Main:AddLeftGroupbox("hide us")
    HideBox:AddToggle("HideUsEnabled", {
        Text = "avatar spoof",
        Default = false,
        Callback = function(v) Visuals.setHideUs(v) end
    })
    HideBox:AddToggle("SpoofNameEnabled", {
        Text = "name spoof",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofNameEnabled", v) end
    })
    HideBox:AddInput("SpoofName", {
        Text = "fake name",
        Default = "sorry",
        Callback = function(v) Visuals.setConfig("spoofName", v) end
    })
    HideBox:AddInput("AvatarID", {
        Text = "avatar id",
        Default = "4050212733",
        Numeric = true,
        Callback = function(v) Visuals.setConfig("avatarId", tonumber(v) or 4050212733) end
    })
    HideBox:AddToggle("SpoofCurrencies", {
        Text = "fake currency",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofCurrencies", v) end
    })
    HideBox:AddToggle("HidePlot", {
        Text = "hide plot",
        Default = false,
        Callback = function(v) Visuals.setConfig("hidePlot", v) end
    })

    local GenBox = Tabs.Main:AddRightGroupbox("general")
    GenBox:AddToggle("AntiAFK", {
        Text = "anti afk",
        Default = Config.AntiAFK.antiAFK ~= false,
        Callback = function(v)
            if AntiAFK and AntiAFK.setAntiAFK then AntiAFK.setAntiAFK(v) end
        end
    })
    GenBox:AddToggle("NoClip", {
        Text = "noclip",
        Default = Config.AntiAFK.noClip ~= false,
        Callback = function(v)
            if AntiAFK and AntiAFK.setNoClip then AntiAFK.setNoClip(v) end
        end
    })
    GenBox:AddToggle("DebugMode", {
        Text = "debug",
        Default = true,
        Callback = function(v) Utils.setDebug(v) end
    })
    GenBox:AddToggle("AutoOpenRoller", {
        Text = "auto open roller",
        Default = Config.AutoOpenRoller or false,
        Callback = function(v) Config.AutoOpenRoller = v end
    })

    local NetBox = Tabs.Main:AddRightGroupbox("tuning")
    NetBox:AddSlider("ClickRate", {
        Text = "click rate",
        Default = 30, Min = 5, Max = 60, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("ClickPlant", v, v) end
        end
    })
    NetBox:AddSlider("RollRate", {
        Text = "roll rate",
        Default = 20, Min = 5, Max = 40, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("DoRoll", v, v) end
        end
    })
    NetBox:AddSlider("SellRate", {
        Text = "sell rate",
        Default = 5, Min = 1, Max = 20, Rounding = 0,
        Callback = function(v)
            if Network and Network.setLimit then Network.setLimit("SellCrate", v, v) end
        end
    })

    local HarvestBox = Tabs.Farming:AddLeftGroupbox("harvest")
    HarvestBox:AddToggle("FarmerEnabled", {
        Text = "auto collect",
        Default = Config.Farmer.enabled or false,
        Callback = function(v) Config.Farmer.enabled = v end
    })
    HarvestBox:AddDropdown("HarvestMode", {
        Values = { "bypass", "snap", "batch" },
        Default = (Config.Farmer.harvestMode == "bypass" and "bypass")
            or (Config.Farmer.harvestMode == "snap" and "snap")
            or "batch",
        Text = "mode",
        Callback = function(v)
            Config.Farmer.harvestMode = v
        end
    })
    HarvestBox:AddSlider("TilesPerFrame", {
        Text = "batch speed",
        Default = Config.Farmer.tilesPerFrame or 10,
        Min = 1, Max = 30, Rounding = 0,
        Callback = function(v) Config.Farmer.tilesPerFrame = v end
    })
    HarvestBox:AddSlider("FiresPerCycle", {
        Text = "max fires",
        Default = Config.Farmer.firesPerCycle or 120,
        Min = 10, Max = 9999, Rounding = 0,
        Callback = function(v) Config.Farmer.firesPerCycle = v end
    })
    HarvestBox:AddSlider("CollectDelay", {
        Text = "delay",
        Default = Config.Farmer.collectDelay or 0,
        Min = 0, Max = 0.1, Rounding = 4,
        Callback = function(v) Config.Farmer.collectDelay = v end
    })

    local BypassBox = Tabs.Farming:AddRightGroupbox("bypass")
    BypassBox:AddToggle("ClaimOwnership", {
        Text = "claim network",
        Default = Config.Farmer.claimOwnership or false,
        Callback = function(v) Config.Farmer.claimOwnership = v end
    })
    BypassBox:AddSlider("YOffset", {
        Text = "tp offset",
        Default = Config.Farmer.yOffset or 3.5,
        Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) Config.Farmer.yOffset = v end
    })

    local FilterBox = Tabs.Farming:AddRightGroupbox("filters")
    FilterBox:AddToggle("StrictMode", {
        Text = "strict",
        Default = Config.Farmer.useStrictMode or false,
        Callback = function(v) Config.Farmer.useStrictMode = v end
    })
    FilterBox:AddDropdown("PriorityFruits", {
        Values = FruitList, Multi = true,
        Text = "fruits", AllowNull = true,
        Callback = function(v) Config.Farmer.priorityFruits = v end
    })

    local SellBox = Tabs.Farming:AddRightGroupbox("misc")
    if AutoSell then
        SellBox:AddToggle("AutoSellEnabled", {
            Text = "auto sell",
            Default = Config.AutoSell.enabled or false,
            Callback = function(v) Config.AutoSell.enabled = v end
        })
        SellBox:AddSlider("SellInterval", {
            Text = "sell wait",
            Default = Config.AutoSell.sellInterval or 0.6,
            Min = 0.1, Max = 5, Rounding = 2,
            Callback = function(v)
                Config.AutoSell.sellInterval = v
                Scheduler.setInterval("AutoSell", v)
            end
        })
    end

    local UpgradeBox = Tabs.Upgrades:AddLeftGroupbox("upgrades")
    if Upgrades and Upgrades.getUpgradeNames then
        for _, name in ipairs(Upgrades.getUpgradeNames()) do
            UpgradeBox:AddToggle("Auto" .. name, {
                Text = "auto " .. name:lower(),
                Default = Config.Upgrades[name] or false,
                Callback = function(v) Upgrades.setUpgrade(name, v) end
            })
        end
    end

    local SniperBox = Tabs.Sniper:AddLeftGroupbox("settings")
    SniperBox:AddDropdown("TargetFruits", {
        Values = FruitList, Multi = true,
        Text = "targets", AllowNull = true,
        Callback = function(v) Config.Sniper.targetFruits = v end
    })
    SniperBox:AddInput("MinEarnings", {
        Text = "min earnings",
        Default = tostring(Config.Sniper.minEarnings or 0),
        Numeric = true,
        Callback = function(v) Config.Sniper.minEarnings = tonumber(v) or 0 end
    })
    SniperBox:AddToggle("InstantMode", {
        Text = "instant",
        Default = Config.Sniper.instantMode or false,
        Callback = function(v) Config.Sniper.instantMode = v end
    })
    SniperBox:AddSlider("RollSpeed", {
        Text = "speed",
        Default = Config.Sniper.rollSpeed or 0.05,
        Min = 0.02, Max = 0.3, Rounding = 3,
        Callback = function(v) Config.Sniper.rollSpeed = v end
    })
    SniperBox:AddSlider("RollBurst", {
        Text = "burst",
        Default = Config.Sniper.rollBurst or 1,
        Min = 1, Max = 5, Rounding = 0,
        Callback = function(v) Config.Sniper.rollBurst = v end
    })

    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("controls")
    SniperCtrl:AddToggle("AutoBuyMatch", {
        Text = "auto buy",
        Default = Config.Sniper.autoBuyMatch or false,
        Callback = function(v) Config.Sniper.autoBuyMatch = v end
    })
    SniperCtrl:AddToggle("StopOnMatch", {
        Text = "stop on match",
        Default = Config.Sniper.stopOnMatch or true,
        Callback = function(v) Config.Sniper.stopOnMatch = v end
    })
    SniperCtrl:AddToggle("AutoProceedAfterBuy", {
        Text = "continue after buy",
        Default = Config.Sniper.autoProceedAfterBuy ~= false,
        Callback = function(v) Config.Sniper.autoProceedAfterBuy = v end
    })
    SniperCtrl:AddSlider("AutoProceedDelay", {
        Text = "wait",
        Default = Config.Sniper.autoProceedDelay or 1.2,
        Min = 0.1, Max = 5, Rounding = 1,
        Callback = function(v) Config.Sniper.autoProceedDelay = v end
    })
    SniperCtrl:AddButton({
        Text = "start",
        Func = function()
            if Sniper and Sniper.start then Sniper.start() end
        end
    })
    SniperCtrl:AddButton({
        Text = "stop",
        Func = function()
            if Sniper and Sniper.stop then Sniper.stop() end
        end
    })
    local sniperStatsLabel = SniperCtrl:AddLabel("stat: 0")

    local BeeBox = Tabs.Bees:AddLeftGroupbox("shop")
    local beeList = (BeeBuyer and BeeBuyer.getBeeList and BeeBuyer.getBeeList()) or {}

    if #beeList > 0 then
        local selectedBee = nil

        BeeBox:AddDropdown("BeeSelect", {
            Values = beeList,
            Text = "bee",
            AllowNull = true,
            Callback = function(v) selectedBee = v end
        })

        BeeBox:AddButton({
            Text = "buy",
            Func = function()
                if not selectedBee then
                    Library:Notify("no bee")
                    return
                end
                local ok, result = BeeBuyer.buyBee(selectedBee)
                if ok then
                    Library:Notify("bought")
                else
                    Library:Notify("failed")
                end
            end
        })

        BeeBox:AddButton({
            Text = "buy & leave",
            Func = function()
                if not selectedBee then
                    Library:Notify("no bee")
                    return
                end
                BeeBuyer.buyAndLeave(selectedBee)
            end
        })

        local beeStatsLabel = BeeBox:AddLabel("bought: 0")
        state._beeStatsLabel = beeStatsLabel
    else
        BeeBox:AddLabel("no bees found")
    end

    local BeeInfoBox = Tabs.Bees:AddRightGroupbox("info")
    BeeInfoBox:AddLabel("buy bees here")

    local ServerHop = state.ServerHop
    local HopBox = Tabs.Server:AddLeftGroupbox("manual hop")
    HopBox:AddButton({
        Text = "lowest ping",
        Func = function()
            local servers = ServerHop.getServers("lowest_ping")
            if #servers > 0 then ServerHop.hop(servers[1].id) end
        end
    })
    HopBox:AddButton({
        Text = "lowest players",
        Func = function()
            local servers = ServerHop.getServers("lowest_players")
            if #servers > 0 then ServerHop.hop(servers[1].id) end
        end
    })
    HopBox:AddButton({
        Text = "highest players",
        Func = function()
            local servers = ServerHop.getServers("highest_players")
            if #servers > 0 then ServerHop.hop(servers[1].id) end
        end
    })
    HopBox:AddButton({
        Text = "highest ping",
        Func = function()
            local servers = ServerHop.getServers("highest_ping")
            if #servers > 0 then ServerHop.hop(servers[1].id) end
        end
    })

    local AutoHopBox = Tabs.Server:AddRightGroupbox("auto hop")
    AutoHopBox:AddToggle("AutoHop", {
        Text = "enabled",
        Default = Config.ServerHop.autoHop or false,
        Callback = function(v) Config.ServerHop.autoHop = v end
    })
    AutoHopBox:AddSlider("AutoHopThreshold", {
        Text = "player limit",
        Default = Config.ServerHop.autoHopThreshold or 10,
        Min = 1, Max = 50, Rounding = 0,
        Callback = function(v) Config.ServerHop.autoHopThreshold = v end
    })
    AutoHopBox:AddToggle("HopOnPing", {
        Text = "hop on high ping",
        Default = Config.ServerHop.hopOnPing or false,
        Callback = function(v) Config.ServerHop.hopOnPing = v end
    })
    AutoHopBox:AddSlider("MaxPing", {
        Text = "max ping",
        Default = Config.ServerHop.maxPing or 300,
        Min = 50, Max = 1000, Rounding = 0,
        Callback = function(v) Config.ServerHop.maxPing = v end
    })

    local UISettingsBox = Tabs["UI Settings"]:AddLeftGroupbox("menu")
    UISettingsBox:AddLabel("toggle"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "toggle",
        Callback = function() Library:Toggle() end
    })

    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs["UI Settings"])

    -- Auto Load Config
    pcall(function()
        SaveManager:LoadAutoloadConfig()
        Library:Notify("Config Auto-Loaded")
        
        if Config.AutoOpenRoller then
            task.spawn(function()
                task.wait(1)
                local ok, err = pcall(function()
                    loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/nexsync_roller.lua?t=" .. tostring(os.time())
                    ))()
                end)
                if ok then Library:Notify("Roller Auto-Opened") end
            end)
        end
    end)

    task.spawn(function()
        while not state._unloaded do
            local farmerStats = (Farmer and Farmer.getStats and Farmer.getStats()) or { totalHarvested = 0, cycleCount = 0 }
            local netStats = (Network and Network.getStats and Network.getStats()) or { totalFired = 0, totalInvoked = 0, totalErrors = 0 }
            local ping = Utils.getPing()
            local sniperStats = (Sniper and Sniper.getStats and Sniper.getStats()) or { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }

            pcall(function()
                statsLabel:SetText(string.format(
                    "harvest: %d | cyc: %d\nping: %dms | err: %d",
                    farmerStats.totalHarvested, farmerStats.cycleCount,
                    ping, netStats.totalErrors
                ))
                sniperStatsLabel:SetText(string.format(
                    "rolls: %d | match: %d",
                    sniperStats.totalRolls or 0, sniperStats.matches or 0
                ))
            end)

            if state._beeStatsLabel and BeeBuyer and BeeBuyer.getStats then
                pcall(function()
                    local bs = BeeBuyer.getStats()
                    state._beeStatsLabel:SetText(string.format(
                        "bought: %d | fail: %d",
                        bs.bought, bs.failed
                    ))
                end)
            end

            task.wait(1)
        end
    end)
end

return GUI
