--[[
    FarmV2 — modules/sniper.lua
    Roll sniper — fully independent from the farmer.
    Rolls seeds, checks against target criteria, auto-buys matches.
]]

local Sniper = {}

local RunService = game:GetService("RunService")

local Utils     = nil
local Network   = nil
local Scheduler = nil
local Cfg       = nil

-- Remotes
local RollEvent  = nil
local BuyEvent   = nil

-- Internal state
local _stats = { totalRolls = 0, matches = 0, bought = 0 }
local _lastMatchInfo = nil

-------------------------------------------------
-- Config defaults
-------------------------------------------------
local defaults = {
    enabled          = false,
    targetFruits     = {},      -- {[fruitName] = true}
    minEarnings      = 0,
    instantMode      = false,
    rollSpeed        = 0.05,    -- seconds between rolls (normal mode)
    autoBuyMatch     = false,
    stopOnMatch      = true,
    autoProceedDelay = 1.2,     -- seconds to wait after buy before resuming
}

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function processResult(result)
    if not result or type(result) ~= "table" or not result[1] then
        return false
    end

    local item = result[1]
    local itemType     = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0

    local targetFruits = getConfig("targetFruits")
    local minEarnings  = getConfig("minEarnings")

    -- Match if: (no targets set OR fruit is in targets) AND earnings >= min
    local isMatch = (next(targetFruits) == nil or targetFruits[itemType])
                    and (itemEarnings >= minEarnings)

    if isMatch then
        _stats.matches = _stats.matches + 1
        _lastMatchInfo = {
            type     = itemType,
            earnings = itemEarnings,
            time     = os.clock(),
        }

        Utils.log("INFO", ("🎯 SNIPER MATCH: %s (earnings: %d)"):format(itemType, itemEarnings))

        if getConfig("autoBuyMatch") then
            local idx = item.StumpIndex or item.Index or 0
            local buyOk = Network.fire(BuyEvent, idx)
            if buyOk then
                _stats.bought = _stats.bought + 1
                Utils.log("INFO", "💰 Auto-bought: " .. itemType)
            end

            if getConfig("stopOnMatch") then
                Cfg.enabled = false
            else
                -- Wait before resuming to let the purchase settle
                task.wait(getConfig("autoProceedDelay"))
            end
        elseif getConfig("stopOnMatch") then
            Cfg.enabled = false
        end

        return true
    end

    return false
end

-------------------------------------------------
-- Main tick
-------------------------------------------------
local function tick()
    if not getConfig("enabled") then return end
    if not RollEvent then return end

    local ok, result = Network.invoke(RollEvent, 2) -- 2 retries
    if ok and result then
        _stats.totalRolls = _stats.totalRolls + 1
        processResult(result)
    end
end

-------------------------------------------------
-- Public API
-------------------------------------------------
function Sniper.getStats()
    return _stats
end

function Sniper.getLastMatch()
    return _lastMatchInfo
end

function Sniper.resetStats()
    _stats = { totalRolls = 0, matches = 0, bought = 0 }
    _lastMatchInfo = nil
end

function Sniper.setEnabled(v)
    Cfg.enabled = v
end

function Sniper.isEnabled()
    return getConfig("enabled")
end

function Sniper.start()
    Cfg.enabled = true
    Utils.log("INFO", "Sniper started")
end

function Sniper.stop()
    Cfg.enabled = false
    Utils.log("INFO", "Sniper stopped")
end

-------------------------------------------------
-- Init
-------------------------------------------------
function Sniper.init(state)
    Utils     = state.Utils
    Network   = state.Network
    Scheduler = state.Scheduler
    Cfg       = state.Config.Sniper or {}

    -- Apply defaults
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Sniper = Cfg

    -- Cache remotes
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        RollEvent = Comms:FindFirstChild("DoRoll")
        BuyEvent  = Comms:FindFirstChild("BuySeeds")
    end

    if not RollEvent then
        Utils.log("WARN", "Sniper: DoRoll remote not found")
    end

    -- Register with scheduler.
    -- Interval is dynamic based on instantMode/rollSpeed, so we use a short base
    -- and handle timing internally.
    local interval = getConfig("instantMode") and 0 or getConfig("rollSpeed")
    Scheduler.register("Sniper", tick, interval)

    Utils.log("INFO", "Sniper module initialized")
end

return Sniper
