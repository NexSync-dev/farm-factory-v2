--[[
    FarmV2 — loader.lua
    Entry point for loadstring execution.
    Fetches all modules from GitHub, wires them together, and starts the scheduler.

    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/OWNER/REPO/main/loader.lua"))()

    Replace OWNER/REPO with the actual GitHub repository path after setup.
]]

-------------------------------------------------
-- Config: Set your repo base URL here
-------------------------------------------------
local REPO_BASE = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/"

-------------------------------------------------
-- Module loader
-------------------------------------------------
local function fetch(path)
    local url = REPO_BASE .. path
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn("[FarmV2] Failed to load module: " .. path .. " — " .. tostring(result))
        return nil
    end
    return result
end

-------------------------------------------------
-- Splash
-------------------------------------------------
print("==================================")
print("  FarmV2 — Build A Farm Factory")
print("  Loading modules...")
print("==================================")

-------------------------------------------------
-- Load core modules
-------------------------------------------------
local Utils     = fetch("core/utils.lua")
if not Utils then error("[FarmV2] CRITICAL: Failed to load core/utils.lua") end

local Network   = fetch("core/network.lua")
if not Network then error("[FarmV2] CRITICAL: Failed to load core/network.lua") end

local Scheduler = fetch("core/scheduler.lua")
if not Scheduler then error("[FarmV2] CRITICAL: Failed to load core/scheduler.lua") end

Utils.log("INFO", "Core modules loaded")

-------------------------------------------------
-- Shared state object — passed to all modules
-------------------------------------------------
local State = {
    Utils     = Utils,
    Network   = Network,
    Scheduler = Scheduler,

    Config = {
        Farmer   = {},
        Sniper   = {},
        AutoSell = {},
        Upgrades = {},
        AntiAFK  = {},
    },

    _connections = {},
}

-------------------------------------------------
-- Initialize core
-------------------------------------------------
Network.init(State)
Scheduler.init(State)

-------------------------------------------------
-- Load feature modules
-------------------------------------------------
local Farmer   = fetch("modules/farmer.lua")
local Sniper   = fetch("modules/sniper.lua")
local AutoSell = fetch("modules/autosell.lua")
local UpgradesMod = fetch("modules/upgrades.lua")
local AntiAFKMod  = fetch("modules/antiafk.lua")

-- Init each module (they register with the scheduler internally)
local moduleList = {
    { name = "Farmer",   mod = Farmer },
    { name = "Sniper",   mod = Sniper },
    { name = "AutoSell", mod = AutoSell },
    { name = "Upgrades", mod = UpgradesMod },
    { name = "AntiAFK",  mod = AntiAFKMod },
}

for _, entry in ipairs(moduleList) do
    if entry.mod then
        local ok, err = pcall(function()
            entry.mod.init(State)
        end)
        if ok then
            Utils.log("INFO", "Module loaded: " .. entry.name)
        else
            Utils.log("ERROR", "Module init failed: " .. entry.name .. " — " .. tostring(err))
        end
    else
        Utils.log("WARN", "Module not loaded (fetch failed): " .. entry.name)
    end
end

-- Store module refs in state for the GUI
State.Farmer   = Farmer
State.Sniper   = Sniper
State.AutoSell = AutoSell
State.Upgrades = UpgradesMod
State.AntiAFK  = AntiAFKMod

-------------------------------------------------
-- Load GUI (last, after all modules are ready)
-------------------------------------------------
local GUI = fetch("ui/gui.lua")
if GUI then
    local ok, err = pcall(function()
        GUI.build(State)
    end)
    if ok then
        Utils.log("INFO", "GUI built successfully")
    else
        Utils.log("ERROR", "GUI build failed: " .. tostring(err))
    end
else
    Utils.log("ERROR", "Failed to load GUI module")
end

-------------------------------------------------
-- Start the scheduler
-------------------------------------------------
Scheduler.start()

print("==================================")
print("  FarmV2 loaded successfully! 🌱")
print("  Modules active: " .. #Scheduler.getModuleNames())
print("==================================")
