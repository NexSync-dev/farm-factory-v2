--[[
    FarmV2 — modules/farmer.lua
    High-performance harvesting engine.
    - Priority queue (harvestable tiles first, sorted by priority fruit + distance)
    - Batch clicking (N clicks per frame instead of 1)
    - Proximity grouping (teleport once per cluster)
    - Adaptive delay based on ping
]]

local Farmer = {}

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local Utils     = nil
local Network   = nil
local Scheduler = nil
local Cfg       = nil

-- Remotes (cached on init)
local ClickEvent = nil

-- Internal state
local _active     = false
local _stats      = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }

-------------------------------------------------
-- Config defaults
-------------------------------------------------
local defaults = {
    enabled          = false,
    batchSize        = 5,       -- clicks per frame
    clusterRadius    = 20,      -- studs; tiles within this radius = 1 teleport
    maxPerCycle      = 9999,
    collectDelay     = 0,       -- extra delay between tiles (0 = none)
    useStrictMode    = false,   -- only farm selected priority fruits
    priorityFruits   = {},      -- {[fruitName] = true}
    tpMode           = "instant", -- "instant" | "safe"
    safeTpStep       = 100,     -- studs per step when tpMode == "safe"
}

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function teleportTo(hrp, pos)
    if getConfig("tpMode") == "safe" then
        Utils.safeTP(hrp, pos, getConfig("safeTpStep"))
    else
        Utils.instantTP(hrp, pos, 3.5)
    end
end

-- Group tiles into clusters by proximity.
-- Returns {{tiles}, {tiles}, ...} where each group can be reached from one TP.
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

-------------------------------------------------
-- Main tick (called by scheduler)
-------------------------------------------------
local function tick()
    if not getConfig("enabled") then return end

    local LP  = Players.LocalPlayer
    local hrp = Utils.getHRP()
    if not hrp then return end

    local plot = Utils.getPlot()
    if not plot then return end

    local hrpPos = hrp.Position
    local priorityList = getConfig("priorityFruits")
    local strictMode   = getConfig("useStrictMode")

    -- Get tiles sorted by priority + distance
    local tiles
    if strictMode and next(priorityList) then
        tiles = Utils.getHarvestableTiles(plot, priorityList, hrpPos)
        -- In strict mode, filter out non-priority tiles
        local filtered = {}
        for _, entry in ipairs(tiles) do
            if entry.priority then
                table.insert(filtered, entry)
            end
        end
        tiles = filtered
    else
        tiles = Utils.getHarvestableTiles(plot, priorityList, hrpPos)
    end

    if #tiles == 0 then return end

    -- Cluster nearby tiles
    local clusters = clusterTiles(tiles, getConfig("clusterRadius"))
    local batchSize    = getConfig("batchSize")
    local maxPerCycle  = getConfig("maxPerCycle")
    local collectDelay = getConfig("collectDelay")
    local harvested    = 0

    _stats.cycleCount = _stats.cycleCount + 1

    local oldCF = hrp.CFrame -- remember original position

    for _, cluster in ipairs(clusters) do
        if harvested >= maxPerCycle then break end
        if not getConfig("enabled") then break end -- allow mid-cycle stop

        -- Teleport to the first tile in the cluster
        local anchorPos = cluster[1].position
        if anchorPos then
            teleportTo(hrp, anchorPos)
        end

        -- Fire click events for all tiles in this cluster
        local batchCount = 0
        for _, entry in ipairs(cluster) do
            if harvested >= maxPerCycle then break end
            if not getConfig("enabled") then break end

            Network.fire(ClickEvent, entry.tile)
            harvested = harvested + 1
            batchCount = batchCount + 1

            -- Yield every batchSize clicks to spread load
            if batchCount >= batchSize then
                batchCount = 0
                RunService.Heartbeat:Wait()
            end

            -- Optional extra delay
            if collectDelay > 0 then
                task.wait(collectDelay)
            end
        end

        -- Small yield between clusters
        RunService.Heartbeat:Wait()
    end

    -- Teleport back to original position
    if hrp and hrp.Parent then
        hrp.CFrame = oldCF
    end

    _stats.tilesThisCycle = harvested
    _stats.totalHarvested = _stats.totalHarvested + harvested

    if Utils then
        Utils.log("DEBUG", ("Farmer cycle #%d: harvested %d tiles (%d clusters)"):format(
            _stats.cycleCount, harvested, #clusters
        ))
    end
end

-------------------------------------------------
-- Public API
-------------------------------------------------
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

-------------------------------------------------
-- Init
-------------------------------------------------
function Farmer.init(state)
    Utils     = state.Utils
    Network   = state.Network
    Scheduler = state.Scheduler
    Cfg       = state.Config.Farmer or {}

    -- Apply defaults
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Farmer = Cfg

    -- Cache remote
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:FindFirstChild("ClickPlant")
    end

    if not ClickEvent then
        Utils.log("WARN", "Farmer: ClickPlant remote not found — harvesting will not work")
    end

    -- Register with scheduler (tick every 0.3s — fast enough, not too spammy)
    Scheduler.register("Farmer", tick, 0.3)

    Utils.log("INFO", "Farmer module initialized")
end

return Farmer
