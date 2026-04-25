local Sniper = {}
local RunService = game:GetService("RunService")

local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local RollEvent = nil
local BuyEvent = nil

local _stats = { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }
local _lastMatchInfo = nil
local _buyLock = false
local _resumeTime = 0

local defaults = {
    enabled = false,
    targetFruits = {},
    minEarnings = 0,
    instantMode = false,
    rollSpeed = 0.05,
    rollBurst = 1,
    autoBuyMatch = false,
    stopOnMatch = true,
    autoProceedAfterBuy = true,
    autoProceedDelay = 1.2,
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function processItem(item)
    if type(item) ~= "table" then return false end

    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0
    local targetFruits = getConfig("targetFruits")
    local minEarnings = getConfig("minEarnings")

    local hasTarget = next(targetFruits) ~= nil
    local isTarget = not hasTarget or targetFruits[itemType]

    if isTarget and itemEarnings >= minEarnings then
        _stats.matches += 1
        _lastMatchInfo = { type = itemType, earnings = itemEarnings, time = os.clock() }
        Utils.log("INFO", string.format("Match: %s (%d)", itemType, itemEarnings))

        if getConfig("autoBuyMatch") and BuyEvent and not _buyLock then
            _buyLock = true
            task.spawn(function()
                Scheduler.pause("Farmer")
                task.wait(0.2)

                local idx = item.StumpIndex or item.Index or 0
                local success = Network.fireBypass(BuyEvent, idx)

                if success then
                    _stats.bought += 1
                    Utils.log("INFO", "Successfully bought: " .. itemType)
                else
                    Utils.log("ERROR", "Buy failed for " .. itemType)
                end

                Scheduler.resume("Farmer")
                _buyLock = false

                if getConfig("stopOnMatch") then
                    Sniper.setEnabled(false)
                elseif getConfig("autoProceedAfterBuy") then
                    _resumeTime = os.clock() + getConfig("autoProceedDelay")
                end
            end)
        elseif getConfig("stopOnMatch") then
            Sniper.setEnabled(false)
        end
        return true
    end
    return false
end

local function processResult(result)
    if not result or type(result) ~= "table" then return false end

    if result[1] then
        for _, entry in ipairs(result) do
            if processItem(entry) then return true end
        end
    elseif result.Item then
        return processItem(result.Item)
    else
        return processItem(result)
    end
    return false
end

local function tick()
    if not getConfig("enabled") or _buyLock or os.clock() < _resumeTime then return end
    if not RollEvent then return end

    local burst = math.max(1, getConfig("rollBurst") or 1)
    for i = 1, burst do
        if not getConfig("enabled") or _buyLock or os.clock() < _resumeTime then break end

        _stats.attempts += 1
        local ok, result = Network.invokeBypass(RollEvent, 2)

        if ok then
            _stats.totalRolls += 1
            local matched = processResult(result)
            if not matched then _stats.skipped += 1 end
        else
            _stats.skipped += 1
        end

        if i < burst then
            RunService.Heartbeat:Wait()
        end
    end
end

-- Public API
function Sniper.getStats() return _stats end
function Sniper.getLastMatch() return _lastMatchInfo end
function Sniper.resetStats()
    _stats = { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }
    _lastMatchInfo = nil
end

function Sniper.setEnabled(v)
    Cfg.enabled = v
    if not v then _buyLock = false end
end

function Sniper.isEnabled() return getConfig("enabled") end

function Sniper.init(state)
    Utils = state.Utils
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.Sniper or {}

    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Sniper = Cfg

    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        RollEvent = Comms:WaitForChild("DoRoll", 5)
        BuyEvent = Comms:WaitForChild("BuySeeds", 5)
    end

    Scheduler.register("Sniper", tick, getConfig("instantMode") and 0 or getConfig("rollSpeed"))
end

return Sniper

