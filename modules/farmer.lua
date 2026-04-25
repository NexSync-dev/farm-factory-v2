local Farmer = {}
local RunService = game:GetService("RunService")
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local ClickEvent = nil
local _stats = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }
local defaults = {
    enabled = false,
    batchSize = 15,
    maxPerCycle = 9999,
    collectDelay = 0,
    useStrictMode = false,
    priorityFruits = {},
    tpMode = "instant",
    safeTpStep = 100,
}
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end
local function moveToTile(hrp, entry, tpMode)
    if tpMode == "True Bypass" then
        return true
    end
    if not entry.position then
        return false
    end
    if tpMode == "safe" and Utils.safeTP then
        return Utils.safeTP(hrp, entry.position + Vector3.new(0, 3.5, 0), getConfig("safeTpStep"))
    end
    if Utils.instantTP then
        return Utils.instantTP(hrp, entry.position, 3.5)
    end
    hrp.CFrame = CFrame.new(entry.position + Vector3.new(0, 3.5, 0))
    return true
end
local function tick()
    if not getConfig("enabled") then return end
    local hrp = Utils.getHRP()
    if not hrp then return end
    local plot = Utils.getPlot()
    if not plot then return end
    local hrpPos = hrp.Position
    local priorityList = getConfig("priorityFruits")
    local strictMode = getConfig("useStrictMode")
    local allTiles = Utils.getProcessedTiles(plot, priorityList, hrpPos)
    local tiles = {}
    local hasPrioritySelection = false
    if priorityList then
        for _, v in pairs(priorityList) do if v then hasPrioritySelection = true break end end
    end
    if strictMode then
        if hasPrioritySelection then
            for _, entry in ipairs(allTiles) do
                if entry.priority and not entry.empty then
                    table.insert(tiles, entry)
                end
            end
        end
    else
        for _, entry in ipairs(allTiles) do
            table.insert(tiles, entry)
        end
    end
    if #tiles == 0 then return end
    local tpMode = getConfig("tpMode")
    local batchSize = getConfig("batchSize")
    local maxPerCycle = getConfig("maxPerCycle")
    local collectDelay = getConfig("collectDelay")
    local harvested = 0
    _stats.cycleCount = _stats.cycleCount + 1
    local oldCF = hrp.CFrame
    local batchCount = 0
    for _, entry in ipairs(tiles) do
        if harvested >= maxPerCycle or not getConfig("enabled") then break end
        moveToTile(hrp, entry, tpMode)
        Network.fireBypass(ClickEvent, entry.tile)
        Utils.log("DEBUG", "Harvesting tile: " .. tostring(entry.tile and entry.tile.Name or "unknown"))
        harvested = harvested + 1
        batchCount = batchCount + 1
        if tpMode ~= "True Bypass" then
            hrp.CFrame = oldCF
            RunService.Heartbeat:Wait()
        else
            if batchCount >= batchSize then
                batchCount = 0
                RunService.Heartbeat:Wait()
            end
        end
        if collectDelay > 0 then
            task.wait(collectDelay)
        end
    end
    _stats.tilesThisCycle = harvested
    _stats.totalHarvested = _stats.totalHarvested + harvested
end
function Farmer.getStats()
    return _stats
end
function Farmer.resetStats()
    _stats = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }
end
function Farmer.setEnabled(v)
    Cfg.enabled = v
end
function Farmer.isEnabled()
    return getConfig("enabled")
end
function Farmer.init(state)
    Utils = state.Utils
    Network = state.Network
    Scheduler = state.Scheduler
    Cfg = state.Config.Farmer or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Farmer = Cfg
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:FindFirstChild("ClickPlant")
    end
    Scheduler.register("Farmer", tick, 0.02)
end
return Farmer
