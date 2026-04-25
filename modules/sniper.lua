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
    if type(item) ~= "table" then
        return false
    end
    Utils.log("DEBUG", "Result Item: " .. Utils.dump(item))
    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0
    local targetFruits = getConfig("targetFruits")
    local minEarnings = getConfig("minEarnings")
    local isMatch = false
    local hasTargetSelection = false
    if targetFruits then
        for _, v in pairs(targetFruits) do if v then hasTargetSelection = true break end end
    end
    if not hasTargetSelection or targetFruits[itemType] then
        if itemEarnings >= minEarnings then
            isMatch = true
        end
    end
    if isMatch then
        _stats.matches = _stats.matches + 1
        _lastMatchInfo = { type = itemType, earnings = itemEarnings, time = os.clock() }
        Utils.log("INFO", string.format("match: %s (%d)", itemType, itemEarnings))
        if getConfig("autoBuyMatch") then
            _buyLock = true
            Scheduler.pause("Farmer")
            task.wait(0.2)
            local idx = item.StumpIndex or item.Index or 0
            if idx == 0 and Utils.getClosestTileIndex then
                idx = Utils.getClosestTileIndex()
            end
            if BuyEvent then
                local buyArgs = {}
                if type(idx) == "number" and idx > 0 then
                    table.insert(buyArgs, idx)
                end
                table.insert(buyArgs, itemType)
                if item.Title and item.Title ~= itemType then
                    table.insert(buyArgs, item.Title)
                end

                local bought = false
                for _, arg in ipairs(buyArgs) do
                    if Network.fireBypass(BuyEvent, arg) then
                        bought = true
                        Utils.log("INFO", string.format("buy attempt %s with arg %s", itemType, tostring(arg)))
                        break
                    end
                end

                if bought then
                    _stats.bought = _stats.bought + 1
                else
                    Utils.log("ERROR", "buy failed for " .. itemType .. " (no valid args)")
                end
            end
            if getConfig("stopOnMatch") then
                Cfg.enabled = false
                _buyLock = false
            else
                if getConfig("autoProceedAfterBuy") then
                    task.wait(getConfig("autoProceedDelay"))
                end
                _buyLock = false
            end
            Scheduler.resume("Farmer")
        elseif getConfig("stopOnMatch") then
            Cfg.enabled = false
        end
        return true
    end
    return false
end

local function processResult(result)
    if not result or type(result) ~= "table" then
        return false
    end

    if result[1] ~= nil then
        for _, entry in ipairs(result) do
            if processItem(entry) then
                return true
            end
        end
        return false
    end

    if type(result.Item) == "table" then
        return processItem(result.Item)
    end

    return processItem(result)
end
local function tick()
    if not getConfig("enabled") then return end
    if _buyLock then return end
    if not RollEvent then return end
    local burst = math.max(1, math.floor(getConfig("rollBurst") or 1))
    for i = 1, burst do
        if not getConfig("enabled") or _buyLock then
            break
        end
        _stats.attempts = _stats.attempts + 1
        local ok, result = Network.invokeBypass(RollEvent, 2)
        if ok then
            _stats.totalRolls = _stats.totalRolls + 1
            local matched = processResult(result)
            if not matched then
                _stats.skipped = _stats.skipped + 1
            end
        else
            _stats.skipped = _stats.skipped + 1
        end
        if i < burst then
            RunService.Heartbeat:Wait()
        end
    end
end
function Sniper.getStats()
    return _stats
end
function Sniper.getLastMatch()
    return _lastMatchInfo
end
function Sniper.resetStats()
    _stats = { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }
    _lastMatchInfo = nil
end
function Sniper.setEnabled(v)
    Cfg.enabled = v
    if not v then
        _buyLock = false
    end
    if v then
        local interval = getConfig("instantMode") and 0 or getConfig("rollSpeed")
        Scheduler.setInterval("Sniper", interval)
    end
end
function Sniper.start()
    Sniper.setEnabled(true)
end
function Sniper.stop()
    Sniper.setEnabled(false)
end
function Sniper.isEnabled()
    return getConfig("enabled")
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
