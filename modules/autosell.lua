local AutoSell = {}
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local SellEvent = nil
local _stats = { totalSells = 0 }
local defaults = { enabled = false, sellInterval = 0.6 }
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end
local function tick()
    if not getConfig("enabled") then return end
    if not SellEvent then return end
    local ok = Network.fire(SellEvent)
    if ok then
        _stats.totalSells = _stats.totalSells + 1
    end
end
function AutoSell.getStats()
    return _stats
end
function AutoSell.setEnabled(v)
    Cfg.enabled = v
end
function AutoSell.isEnabled()
    return getConfig("enabled")
end
function AutoSell.init(state)
    Utils = state.Utils
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.AutoSell or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.AutoSell = Cfg
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        SellEvent = Comms:FindFirstChild("SellCrate")
    end
    Scheduler.register("AutoSell", tick, getConfig("sellInterval"))
end
return AutoSell
