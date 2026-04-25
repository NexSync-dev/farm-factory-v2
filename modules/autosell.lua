local AutoSell = {}

local Network = nil
local Scheduler = nil
local Cfg = nil
local SellEvent = nil

local defaults = {
    enabled = false,
    sellInterval = 0.6,
}

local function getConfig(key)
    if Cfg[key] ~= nil then
        return Cfg[key]
    end
    return defaults[key]
end

local function tick()
    if not getConfig("enabled") then
        return
    end
    if not SellEvent then
        return
    end
    Network.fire(SellEvent)
end

function AutoSell.setEnabled(v)
    Cfg.enabled = v
end

function AutoSell.isEnabled()
    return getConfig("enabled")
end

function AutoSell.init(state)
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.AutoSell or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then
            Cfg[k] = v
        end
    end
    state.Config.AutoSell = Cfg

    local comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if comms then
        SellEvent = comms:FindFirstChild("SellCrate")
    end

    Scheduler.register("AutoSell", tick, getConfig("sellInterval"))
end

return AutoSell
