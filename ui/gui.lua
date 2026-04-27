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
            local folder = storage:FindFirstChild("Fruit")
            if folder then
                for _, f in ipairs(folder:GetChildren()) do table.insert(fruits, f.Name) end
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
    local list = buildFruitList()
    local Window = Library:CreateWindow({ Title = "Farm Tool | V2", Center = true, AutoShow = true })
    local Tabs = {
        Main = Window:AddTab("Main"),
        Farming = Window:AddTab("Farm"),
        Upgrades = Window:AddTab("Upgrades"),
        Sniper = Window:AddTab("Sniper"),
        Bees = Window:AddTab("Bees"),
        Settings = Window:AddTab("UI"),
    }
    state._library = Library
    state._unloaded = false
    local Status = Tabs.Main:AddLeftGroupbox("status")
    Status:AddToggle("MasterToggle", {
        Text = "on/off",
        Default = true,
        Callback = function(v) if v then Scheduler.start() else Scheduler.stop() end end
    })
    local stats = Status:AddLabel("wait...")
    Status:AddButton({
        Text = "reset",
        Func = function()
            if Farmer then Farmer.resetStats() end
            if Sniper then Sniper.resetStats() end
            if Network then Network.resetStats() end
            if BeeBuyer then BeeBuyer.resetStats() end
        end
    })
    Status:AddButton({
        Text = "standalone roller",
        Func = function()
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/nexsync_roller.lua?t=" .. tostring(os.time())))()
            end)
        end
    })
    local Info = Tabs.Main:AddRightGroupbox("info")
    Info:AddLabel("NexSync V2")
    Info:AddButton({
        Text = "unload",
        Func = function()
            state._unloaded = true
            Scheduler.stop()
            if state._connections then
                for _, c in ipairs(state._connections) do if c.Connected then c:Disconnect() end end
            end
            Library:Unload()
        end
    })
    local Hide = Tabs.Main:AddLeftGroupbox("visuals")
    Hide:AddToggle("HideUsEnabled", {
        Text = "avatars",
        Default = false,
        Callback = function(v) Visuals.setHideUs(v) end
    })
    Hide:AddToggle("SpoofNameEnabled", {
        Text = "names",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofNameEnabled", v) end
    })
    Hide:AddInput("SpoofName", {
        Text = "name to show",
        Default = "sorry",
        Callback = function(v) Visuals.setConfig("spoofName", v) end
    })
    Hide:AddInput("AvatarID", {
        Text = "id to use",
        Default = "1",
        Numeric = true,
        Callback = function(v) Visuals.setConfig("avatarId", tonumber(v) or 1) end
    })
    Hide:AddToggle("SpoofCurrencies", {
        Text = "fake cash",
        Default = false,
        Callback = function(v) Visuals.setConfig("spoofCurrencies", v) end
    })
    Hide:AddToggle("HidePlot", {
        Text = "hide plot",
        Default = false,
        Callback = function(v) Visuals.setConfig("hidePlot", v) end
    })
    local General = Tabs.Main:AddRightGroupbox("misc")
    General:AddToggle("AntiAFK", {
        Text = "anti-afk",
        Default = true,
        Callback = function(v) if AntiAFK then AntiAFK.setAntiAFK(v) end end
    })
    General:AddToggle("NoClip", {
        Text = "noclip",
        Default = false,
        Callback = function(v) if AntiAFK then AntiAFK.setNoClip(v) end end
    })
    local NetworkBox = Tabs.Main:AddRightGroupbox("net")
    NetworkBox:AddSlider("ClickRate", {
        Text = "click rate",
        Default = 30, Min = 5, Max = 60, Rounding = 0,
        Callback = function(v) if Network then Network.setLimit("ClickPlant", v, v) end end
    })
    local Harvest = Tabs.Farming:AddLeftGroupbox("farming")
    Harvest:AddToggle("FarmerEnabled", {
        Text = "auto collect",
        Default = false,
        Callback = function(v) Config.Farmer.enabled = v end
    })
    Harvest:AddDropdown("HarvestMode", {
        Values = { "bypass", "snap", "batch" },
        Default = "batch",
        Text = "mode",
        Callback = function(v) Config.Farmer.harvestMode = v end
    })
    local Upgrade = Tabs.Upgrades:AddLeftGroupbox("auto upgrades")
    if Upgrades and Upgrades.getUpgradeNames then
        for _, n in ipairs(Upgrades.getUpgradeNames()) do
            Upgrade:AddToggle("Auto" .. n, {
                Text = n,
                Default = false,
                Callback = function(v) Upgrades.setUpgrade(n, v) end
            })
        end
    end
    local SniperBox = Tabs.Sniper:AddLeftGroupbox("settings")
    SniperBox:AddDropdown("TargetFruits", {
        Values = list, Multi = true,
        Text = "fruits", AllowNull = true,
        Callback = function(v) Config.Sniper.targetFruits = v end
    })
    SniperBox:AddInput("MinEarnings", {
        Text = "min cash",
        Default = "0",
        Numeric = true,
        Callback = function(v) Config.Sniper.minEarnings = tonumber(v) or 0 end
    })
    local SniperCtrl = Tabs.Sniper:AddRightGroupbox("controls")
    SniperCtrl:AddToggle("AutoBuyMatch", {
        Text = "auto buy",
        Default = false,
        Callback = function(v) Config.Sniper.autoBuyMatch = v end
    })
    SniperCtrl:AddButton({
        Text = "start",
        Func = function() if Sniper then Sniper.start() end end
    })
    SniperCtrl:AddButton({
        Text = "stop",
        Func = function() if Sniper then Sniper.stop() end end
    })
    local sniperStats = SniperCtrl:AddLabel("stats: 0/0/0")
    local BeeBox = Tabs.Bees:AddLeftGroupbox("shop")
    local bees = (BeeBuyer and BeeBuyer.getBeeList and BeeBuyer.getBeeList()) or {}
    if #bees > 0 then
        local selected = nil
        BeeBox:AddDropdown("BeeSelect", {
            Values = bees,
            Text = "select bee",
            AllowNull = true,
            Callback = function(v) selected = v end
        })
        BeeBox:AddButton({
            Text = "buy",
            Func = function()
                if not selected then return end
                BeeBuyer.buyBee(selected)
            end
        })
        local beeStats = BeeBox:AddLabel("bought: 0")
        state._beeStatsLabel = beeStats
    end
    local MenuBox = Tabs.Settings:AddLeftGroupbox("menu")
    MenuBox:AddLabel("toggle"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "toggle",
        Callback = function() Library:Toggle() end
    })
    Library.ToggleKeybind = Options.MenuKeybind
    SaveManager:SetLibrary(Library)
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.Settings)
    task.spawn(function()
        while not state._unloaded do
            local fs = (Farmer and Farmer.getStats()) or { totalHarvested = 0, cycleCount = 0 }
            local ns = (Network and Network.getStats()) or { totalFired = 0, totalErrors = 0 }
            local ss = (Sniper and Sniper.getStats()) or { totalRolls = 0, matches = 0, bought = 0 }
            pcall(function()
                stats:SetText(string.format("harvest: %d | net: %d", fs.totalHarvested, ns.totalFired))
                sniperStats:SetText(string.format("rolls: %d | found: %d", ss.totalRolls, ss.matches))
                if state._beeStatsLabel and BeeBuyer then
                    local bs = BeeBuyer.getStats()
                    state._beeStatsLabel:SetText(string.format("bought: %d", bs.bought))
                end
            end)
            task.wait(1)
        end
    end)
end
return GUI
