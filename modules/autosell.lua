--[[
    FarmV2 — modules/autosell.lua
    Automatic crate selling on a configurable timer.
]]

local AutoSell = {}

local Utils     = nil
local Network   = nil
local Scheduler = nil
local Cfg       = nil

-- Remote
local SellEvent = nil

-- Internal
local _stats = { totalSells = 0 }

-------------------------------------------------
-- Config defaults
-------------------------------------------------
local defaults = {
    enabled      = false,
    sellInterval = 0.6,   -- seconds between sell attempts
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

-------------------------------------------------
-- Tick
-------------------------------------------------
local function tick()
    if not getConfig("enabled") then return end
    if not SellEvent then return end

    local ok = Network.fire(SellEvent)
    if ok then
        _stats.totalSells = _stats.totalSells + 1
    end
end

-------------------------------------------------
-- Public API
-------------------------------------------------
function AutoSell.getStats()
    return _stats
end

function AutoSell.setEnabled(v)
    Cfg.enabled = v
end

function AutoSell.isEnabled()
    return getConfig("enabled")
end

-------------------------------------------------
-- Init
-------------------------------------------------
function AutoSell.init(state)
    Utils     = state.Utils
    Network   = state.Network
    Scheduler = state.Scheduler
    Cfg       = state.Config.AutoSell or {}

    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.AutoSell = Cfg

    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        SellEvent = Comms:FindFirstChild("SellCrate")
    end

    if not SellEvent then
        Utils.log("WARN", "AutoSell: SellCrate remote not found")
    end

    Scheduler.register("AutoSell", tick, getConfig("sellInterval"))
    Utils.log("INFO", "AutoSell module initialized")
end

return AutoSell
