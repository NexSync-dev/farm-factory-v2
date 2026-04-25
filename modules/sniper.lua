local Sniper = {}
local RunService = game:GetService("RunService")
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local RollEvent = nil
local BuyEvent = nil
local _stats = { totalRolls = 0, matches = 0, bought = 0 }
local _lastMatchInfo = nil
local defaults = {
    enabled = false,
    targetFruits = {},
    minEarnings = 0,
    instantMode = false,
    rollSpeed = 0.05,
    autoBuyMatch = false,
    stopOnMatch = true,
    autoProceedDelay = 1.2,
}
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end
local function processResult(result)
    if not result or type(result) ~= "table" or not result[1] then
        return false
    end
    local item = result[1]
    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0
    local targetFruits = getConfig("targetFruits")
    local minEarnings = getConfig("minEarnings")
    local isMatch = (next(targetFruits) == nil or targetFruits[itemType])
                    and (itemEarnings >= minEarnings)
    if isMatch then
        _stats.matches = _stats.matches + 1
        _lastMatchInfo = { type = itemType, earnings = itemEarnings, time = os.clock() }
        Utils.log("INFO", string.format("🎯 SNIPER MATCH: %s (earnings: %d)", itemType, itemEarnings))
        if getConfig("autoBuyMatch") then
            local idx = item.StumpIndex or item.Index or 0
            if BuyEvent then
                Utils.log("DEBUG", string.format("🛒 Attempting to buy item at index %s", tostring(idx)))
                local buyOk = Network.fire(BuyEvent, idx)
                if buyOk then
                    _stats.bought = _stats.bought + 1
                    Utils.log("INFO", string.format("💰 Bought %s successfully", itemType))
                else
                    Utils.log("ERROR", string.format("❌ Failed to buy %s", itemType))
                end
            else
                Utils.log("ERROR", "❌ BuyEvent (BuySeeds) not found")
            end
            if getConfig("stopOnMatch") then
                Cfg.enabled = false
            else
                task.wait(getConfig("autoProceedDelay"))
            end
        elseif getConfig("stopOnMatch") then
            Cfg.enabled = false
        end
        return true
    end
    return false
end
local function tick()
    if not getConfig("enabled") then return end
    if not RollEvent then return end
    local ok, result = Network.invoke(RollEvent, 2)
    if ok and result then
        _stats.totalRolls = _stats.totalRolls + 1
        processResult(result)
    end
end
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
end
function Sniper.stop()
    Cfg.enabled = false
end
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
    local interval = getConfig("instantMode") and 0 or getConfig("rollSpeed")
    Scheduler.register("Sniper", tick, interval)
end
return Sniper
