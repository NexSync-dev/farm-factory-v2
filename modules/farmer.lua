local Farmer = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local ClickEvent = nil
local _stats = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }
local defaults = {
    enabled = false,
    batchSize = 15,
    clusterRadius = 25,
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
local function teleportTo(hrp, pos)
    local mode = getConfig("tpMode")
    if mode == "True Bypass" then return end
    if mode == "safe" then
        Utils.safeTP(hrp, pos, getConfig("safeTpStep"))
    else
        Utils.instantTP(hrp, pos, 3.5)
    end
end
local function clusterTiles(sortedTiles, radius)
    local clusters = {}
    local used = {}
    for i, entry in ipairs(sortedTiles) do
        if not used[i] and entry.position then
            local cluster = { entry }
            used[i] = true
            for j = i + 1, #sortedTiles do
                if not used[j] and sortedTiles[j].position then
                    local dist = (entry.position - sortedTiles[j].position).Magnitude
                    if dist <= radius then
                        table.insert(cluster, sortedTiles[j])
                        used[j] = true
                    end
                end
            end
            table.insert(clusters, cluster)
        end
    end
    return clusters
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
    local tiles
    local allTiles = Utils.getProcessedTiles(plot, priorityList, hrpPos)
    if strictMode and next(priorityList) then
        local filtered = {}
        for _, entry in ipairs(allTiles) do
            if entry.priority or entry.empty then
                table.insert(filtered, entry)
            end
        end
        tiles = filtered
    else
        tiles = allTiles
    end
    if #tiles == 0 then return end
    local tpMode = getConfig("tpMode")
    local clusters = clusterTiles(tiles, tpMode == "True Bypass" and 9999 or getConfig("clusterRadius"))
    local batchSize = getConfig("batchSize")
    local maxPerCycle = getConfig("maxPerCycle")
    local collectDelay = getConfig("collectDelay")
    local harvested = 0
    _stats.cycleCount = _stats.cycleCount + 1
    local oldCF = hrp.CFrame
    for _, cluster in ipairs(clusters) do
        if harvested >= maxPerCycle then break end
        if not getConfig("enabled") then break end
        local anchorPos = cluster[1].position
        if anchorPos and tpMode ~= "True Bypass" then
            teleportTo(hrp, anchorPos)
        end
        local batchCount = 0
        for _, entry in ipairs(cluster) do
            if harvested >= maxPerCycle then break end
            if not getConfig("enabled") then break end
            Network.fire(ClickEvent, entry.tile)
            harvested = harvested + 1
            batchCount = batchCount + 1
            if batchCount >= batchSize then
                batchCount = 0
                RunService.Heartbeat:Wait()
            end
            if collectDelay > 0 then
                task.wait(collectDelay)
            end
        end
        if tpMode ~= "True Bypass" then RunService.Heartbeat:Wait() end
    end
    if tpMode ~= "True Bypass" and hrp and hrp.Parent then
        hrp.CFrame = oldCF
    end
    _stats.tilesThisCycle = harvested
    _stats.totalHarvested = _stats.totalHarvested + harvested
    Utils.log("DEBUG", string.format("farm cycle #%d done: %d tiles", _stats.cycleCount, harvested))
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
    Scheduler.register("Farmer", tick, 0.1)
end
return Farmer
