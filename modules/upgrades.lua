--[[
    FarmV2 — modules/upgrades.lua
    Auto-upgrade purchasing on its own timer (decoupled from sell).
]]

local Upgrades = {}

local Utils     = nil
local Network   = nil
local Scheduler = nil
local Cfg       = nil

-- Remote
local UpgradeEvent = nil

-- Available upgrade names
local UPGRADE_NAMES = { "Click", "SprinkerPower", "SeedLuck", "SeedRolls" }

-------------------------------------------------
-- Config defaults
-------------------------------------------------
local defaults = {
    Click          = false,
    SprinkerPower  = false,
    SeedLuck       = false,
    SeedRolls      = false,
    upgradeInterval = 2.0,  -- seconds; slower than sell, no need to spam
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

-------------------------------------------------
-- Tick — try each enabled upgrade
-------------------------------------------------
local function tick()
    if not UpgradeEvent then return end

    local anyEnabled = false
    for _, name in ipairs(UPGRADE_NAMES) do
        if getConfig(name) then
            anyEnabled = true
            Network.fire(UpgradeEvent, name)
            -- Small stagger between different upgrades to avoid burst
            task.wait(0.15)
        end
    end

    if not anyEnabled then return end
end

-------------------------------------------------
-- Public API
-------------------------------------------------
function Upgrades.setUpgrade(name, enabled)
    Cfg[name] = enabled
end

function Upgrades.isUpgradeEnabled(name)
    return getConfig(name)
end

function Upgrades.getUpgradeNames()
    return UPGRADE_NAMES
end

-------------------------------------------------
-- Init
-------------------------------------------------
function Upgrades.init(state)
    Utils     = state.Utils
    Network   = state.Network
    Scheduler = state.Scheduler
    Cfg       = state.Config.Upgrades or {}

    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Upgrades = Cfg

    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        UpgradeEvent = Comms:FindFirstChild("BuyUpgrade")
    end

    if not UpgradeEvent then
        Utils.log("WARN", "Upgrades: BuyUpgrade remote not found")
    end

    Scheduler.register("Upgrades", tick, getConfig("upgradeInterval"))
    Utils.log("INFO", "Upgrades module initialized")
end

return Upgrades
