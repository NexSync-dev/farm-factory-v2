local Sniper = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local RollEvent = nil
local BuyEvent = nil
local _stats = { totalRolls = 0, matches = 0, bought = 0, attempts = 0, skipped = 0 }
local _lastMatchInfo = nil
local _buyLock = false
local _loopActive = false
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

local function findStumpIndex(itemName)
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then
        Utils.log("ERROR", "StumpResolver: workspace.Plots not found")
        return nil
    end

    local LocalPlayer = Players.LocalPlayer
    local plot = Plots:FindFirstChild(LocalPlayer.Name)
    if not plot then
        if Utils.getPlot then
            plot = Utils.getPlot()
        end
        if not plot then
            Utils.log("ERROR", "StumpResolver: Could not find plot for " .. LocalPlayer.Name)
            return nil
        end
    end

    local lowerItem = itemName:lower()
    for _, child in ipairs(plot:GetChildren()) do
        if child.Name == "Stump" or child.Name:match("^Stump_%d+$") then
            local titleObj = child:FindFirstChild("Model")
                and child.Model:FindFirstChild("BuyableDisplay")
                and child.Model.BuyableDisplay:FindFirstChild("Title")
            if titleObj then
                local text = titleObj.Text:lower()
                if text:find(lowerItem, 1, true) or lowerItem:find(text, 1, true) then
                    local num = child.Name:match("%d+")
                    local idx = num and tonumber(num) or 1
                    Utils.log("DEBUG", string.format(
                        "StumpResolver: Found '%s' on %s (Index: %d)", itemName, child.Name, idx))
                    return idx
                end
            end
        end
    end

    Utils.log("DEBUG", "StumpResolver: No stump found for " .. itemName)
    return nil
end

local function isMatch(item)
    if type(item) ~= "table" then return false, 0, "" end
    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0
    local targetFruits = getConfig("targetFruits")
    local minEarnings = getConfig("minEarnings")

    local hasTargetSelection = false
    if targetFruits then
        for _, v in pairs(targetFruits) do if v then hasTargetSelection = true break end end
    end

    -- Case-insensitive so "Prickly Pear" / "prickly pear" both match
    local lowerType = itemType:lower()
    local matched = false
    if hasTargetSelection then
        for k, v in pairs(targetFruits) do
            if v and k:lower() == lowerType then
                matched = true
                break
            end
        end
    else
        matched = true
    end

    if matched and itemEarnings >= minEarnings then
        return true, itemEarnings, itemType
    end
    return false, 0, ""
end

local function processItem(item)
    local matched, itemEarnings, itemType = isMatch(item)
    if not matched then return false end

    _stats.matches = _stats.matches + 1
    _lastMatchInfo = { type = itemType, earnings = itemEarnings, time = os.clock() }
    Utils.log("INFO", string.format("SNIPER MATCH: %s (%d)", itemType, itemEarnings))

    if getConfig("autoBuyMatch") then
        _buyLock = true
        Scheduler.pause("Farmer")
        task.wait(0.2)

        local stumpIdx = findStumpIndex(itemType) or item.StumpIndex or item.Index

        local ok, err = pcall(function()
            if stumpIdx and BuyEvent then
                Utils.log("INFO", string.format(
                    "Attempting Buy: %s on Stump index %s", itemType, tostring(stumpIdx)))
                BuyEvent:FireServer(stumpIdx)
                _stats.bought = _stats.bought + 1
                Utils.log("INFO", "Fired buy for " .. itemType)
            else
                Utils.log("ERROR", "Failed to resolve stump index for " .. itemType)
            end

            local proceed = getConfig("autoProceedAfterBuy")
            local stop    = getConfig("stopOnMatch")

            if proceed then
                local delay = getConfig("autoProceedDelay") or 1.2
                Utils.log("INFO", string.format("Waiting %.1fs before proceeding...", delay))
                task.wait(delay)
                Scheduler.resume("Farmer")
                _buyLock = false
            elseif stop then
                Utils.log("INFO", "Stopping sniper (stopOnMatch enabled)")
                Scheduler.resume("Farmer")
                _buyLock = false
                Sniper.setEnabled(false)
            else
                Scheduler.resume("Farmer")
                _buyLock = false
            end
        end)

        if not ok then
            Utils.log("ERROR", "processItem buy block errored: " .. tostring(err))
            Scheduler.resume("Farmer")
            _buyLock = false
        end

        return true
    end

    if getConfig("stopOnMatch") then
        Sniper.setEnabled(false)
    end
    return true
end

-- Collects ALL matches from a roll result, sorts by earnings descending,
-- and attempts to buy each one so nothing is missed (e.g. 2x Prickly Pear).
local function processResult(result)
    if not result or type(result) ~= "table" then return false end

    local matches = {}

    local function evaluate(entry)
        local matched = isMatch(entry)
        if matched then
            table.insert(matches, entry)
        end
    end

    if result[1] ~= nil then
        for _, entry in ipairs(result) do evaluate(entry) end
    elseif result.Item then
        evaluate(result.Item)
    else
        evaluate(result)
    end

    if #matches == 0 then return false end

    -- Buy highest-earnings match first
    table.sort(matches, function(a, b)
        return (tonumber(a.Earnings) or 0) > (tonumber(b.Earnings) or 0)
    end)

    Utils.log("INFO", string.format("processResult: %d match(es) found this roll", #matches))

    for _, match in ipairs(matches) do
        processItem(match)
    end

    return true
end

local function startLoop()
    if _loopActive then return end
    _loopActive = true

    task.spawn(function()
        while _loopActive do
            if not getConfig("enabled") then
                task.wait(0.2)
                continue
            end

            if _buyLock then
                task.wait(0.1)
                continue
            end

            local isInstant = getConfig("instantMode")
            local rollSpeed = getConfig("rollSpeed") or 0.05
            local burst = math.max(1, math.floor(getConfig("rollBurst") or 1))

            for i = 1, burst do
                if not getConfig("enabled") or _buyLock then break end

                _stats.attempts = _stats.attempts + 1
                local ok, result = Network.invokeBypass(RollEvent)
                if ok then
                    _stats.totalRolls = _stats.totalRolls + 1
                    if processResult(result) then break end
                else
                    _stats.skipped = _stats.skipped + 1
                end

                if i < burst and not isInstant then
                    task.wait(0.01)
                end
            end

            if isInstant then
                RunService.Heartbeat:Wait()
            else
                task.wait(rollSpeed)
            end
        end
    end)
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
        BuyEvent  = Comms:WaitForChild("BuySeeds", 5)
    end
    startLoop()
end
return Sniper
