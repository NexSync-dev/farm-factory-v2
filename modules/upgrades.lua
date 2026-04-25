local Upgrades = {}
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local UpgradeEvent = nil
local UPGRADE_NAMES = { "Click", "SprinkerPower", "SeedLuck", "SeedRolls" }
local defaults = { Click = false, SprinkerPower = false, SeedLuck = false, SeedRolls = false, upgradeInterval = 2.0 }
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end
local function tick()
    if not UpgradeEvent then return end
    local anyEnabled = false
    for _, name in ipairs(UPGRADE_NAMES) do
        if getConfig(name) then
            anyEnabled = true
            Network.fire(UpgradeEvent, name)
            task.wait(0.15)
        end
    end
end
function Upgrades.setUpgrade(name, enabled)
    Cfg[name] = enabled
end
function Upgrades.isUpgradeEnabled(name)
    return getConfig(name)
end
function Upgrades.getUpgradeNames()
    return UPGRADE_NAMES
end
function Upgrades.init(state)
    Utils = state.Utils
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.Upgrades or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Upgrades = Cfg
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        UpgradeEvent = Comms:FindFirstChild("BuyUpgrade")
    end
    Scheduler.register("Upgrades", tick, getConfig("upgradeInterval"))
end
return Upgrades
