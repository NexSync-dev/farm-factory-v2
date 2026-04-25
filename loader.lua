local REPO_BASE = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/"
local function fetch(path)
    local url = REPO_BASE .. path .. "?t=" .. tick()
    local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not ok then return nil end
    return result
end

local LoaderUI = fetch("ui/loader.lua")
local ui = nil
if LoaderUI then ui = LoaderUI.show() end
local function step(text) if ui then ui.update(text) end end

step("loading core...")
local Utils = fetch("core/utils.lua")
local AntiAFK = fetch("modules/antiafk.lua")

step("starting engine...")
local State = {
    Utils = Utils,
    Config = {
        Running = true,
        Farmer = {
            enabled = false,
            batchSize = 15,
            clusterRadius = 25,
            maxPerCycle = 9999,
            collectDelay = 0,
            useStrictMode = false,
            priorityFruits = {},
            tpMode = "FastSnap",
            safeTpStep = 100,
        },
        Sniper = {
            SniperActive = false,
            targetFruits = {},
            minEarnings = 0,
            instantMode = false,
            rollSpeed = 0.05,
            autoBuyMatch = false,
            stopOnMatch = true,
            autoProceedAfterBuy = true,
            ProceedDelay = 1.2,
        },
        AutoSell = false,
        SellInterval = 0.6,
        AutoUpgrades = { Click = false, SprinkerPower = false, SeedLuck = false, SeedRolls = false },
        AntiAFK = { antiAFK = true, noClip = true },
        StrictFarm = false,
        PriorityList = {},
        Collect = false,
        BypassMode = "FastSnap",
        CollectDelay = 0,
    },
    SniperLock = { locked = false },
    _connections = {}
}

step("loading modules...")
local Farmer = fetch("modules/farmer.lua")
local Sniper = fetch("modules/sniper.lua")
local Economy = fetch("modules/economy.lua")

State.Farmer = Farmer
State.Sniper = Sniper
State.Economy = Economy

if Farmer then Farmer.init(State) end
if Sniper then Sniper.init(State) end
if Economy then Economy.init(State) end
if AntiAFK then AntiAFK.init(State) end

step("building gui...")
local GUI = fetch("ui/gui.lua")
if GUI then pcall(function() GUI.build(State) end) end

step("ready")
if ui then ui.finish() end

if Farmer then Farmer.run(State) end
if Sniper then Sniper.run(State) end
if Economy then Economy.run(State) end
