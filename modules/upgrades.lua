local Upgrades = {}

local Network = nil
local Scheduler = nil
local Cfg = nil
local UpgradeEvent = nil

local upgradeOrder = { "Click", "SprinkerPower", "SeedLuck", "SeedRolls" }
local defaults = {
    Click = false,
    SprinkerPower = false,
    SeedLuck = false,
    SeedRolls = false,
    interval = 0.6,
}

local function tick()
    if not UpgradeEvent then
        return
    end

    for _, name in ipairs(upgradeOrder) do
        if Cfg[name] then
            Network.fire(UpgradeEvent, name)
            task.wait(0.1)
        end
    end
end

function Upgrades.getUpgradeNames()
    return upgradeOrder
end

function Upgrades.setUpgrade(name, enabled)
    Cfg[name] = enabled
end

function Upgrades.isEnabled(name)
    return Cfg[name] == true
end

function Upgrades.init(state)
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.Upgrades or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then
            Cfg[k] = v
        end
    end
    state.Config.Upgrades = Cfg

    local comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if comms then
        UpgradeEvent = comms:FindFirstChild("BuyUpgrade")
    end

    Scheduler.register("Upgrades", tick, Cfg.interval)
end

return Upgrades
