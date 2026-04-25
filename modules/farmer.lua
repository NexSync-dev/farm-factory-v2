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
    batchSize = 30,           -- increased a bit, adjust based on how much the game tolerates
    maxPerCycle = 9999,
    useStrictMode = false,
    priorityFruits = {},
    tpMode = "True Bypass",
    safeTpStep = 100,
    onlyHarvestReady = true,  -- new: big performance win
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function moveToTile(hrp, entry, tpMode)
    if tpMode == "True Bypass" then
        return true
    end
    if not entry.position then return false end

    if tpMode == "safe" and Utils.safeTP then
        return Utils.safeTP(hrp, entry.position + Vector3.new(0, 3.5, 0), getConfig("safeTpStep"))
    elseif Utils.instantTP then
        return Utils.instantTP(hrp, entry.position, 3.5)
    else
        hrp.CFrame = CFrame.new(entry.position + Vector3.new(0, 3.5, 0))
        return true
    end
end

local function isReadyToHarvest(entry)
    -- If your Utils.getProcessedTiles already marks ready tiles, use that.
    -- Otherwise you may need to add a check here (e.g. entry.stage == "ready" or entry.growth >= 1)
    return not entry.empty and (entry.ready or entry.harvestable or true) -- adjust based on your Utils
end

local function tick()
    if not getConfig("enabled") then return end

    local hrp = Utils.getHRP()
    if not hrp then return end

    local plot = Utils.getPlot()
    if not plot then return end

    local tpMode = getConfig("tpMode")
    local batchSize = getConfig("batchSize")
    local maxPerCycle = getConfig("maxPerCycle")
    local onlyReady = getConfig("onlyHarvestReady")

    local priorityList = getConfig("priorityFruits")
    local strictMode = getConfig("useStrictMode")

    -- Get tiles ONCE per cycle
    local allTiles = Utils.getProcessedTiles(plot, priorityList, hrp.Position)
    if not allTiles or #allTiles == 0 then return end

    local tilesToHarvest = {}

    for _, entry in ipairs(allTiles) do
        if onlyReady and not isReadyToHarvest(entry) then
            continue
        end

        local isPriority = false
        if priorityList and #priorityList > 0 then
            -- simple check if this tile's fruit type is in priority (you may need to adjust key)
            for _, prio in ipairs(priorityList) do
                if entry.fruitType == prio or entry.name == prio then
                    isPriority = true
                    break
                end
            end
        end

        if strictMode then
            if isPriority and not entry.empty then
                table.insert(tilesToHarvest, entry)
            end
        else
            table.insert(tilesToHarvest, entry)
        end
    end

    if #tilesToHarvest == 0 then return end

    _stats.cycleCount += 1
    local harvested = 0
    local batchCount = 0
    local oldCF = hrp.CFrame

    for _, entry in ipairs(tilesToHarvest) do
        if harvested >= maxPerCycle or not getConfig("enabled") then
            break
        end

        -- Teleport only if needed
        if tpMode ~= "True Bypass" then
            moveToTile(hrp, entry, tpMode)
        end

        -- Fire the remote (this is the actual harvest)
        if ClickEvent and entry.tile then
            Network.fireBypass(ClickEvent, entry.tile)
            Utils.log("DEBUG", "Harvesting: " .. tostring(entry.tile.Name))
        end

        harvested += 1
        batchCount += 1

        -- Minimal yielding - only every batch
        if batchCount >= batchSize then
            batchCount = 0
            RunService.Heartbeat:Wait()   -- or task.wait() if you prefer
        end
    end

    -- Return to original position if we moved
    if tpMode ~= "True Bypass" then
        hrp.CFrame = oldCF
    end

    _stats.tilesThisCycle = harvested
    _stats.totalHarvested += harvested
end

-- Public API
function Farmer.getStats() return _stats end
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

    -- Apply defaults
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Farmer = Cfg

    -- Find the remote
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:FindFirstChild("ClickPlant")
    end

    -- Register with very low interval (you can go even lower if the game allows)
    Scheduler.register("Farmer", tick, 0.015)  -- ~66 Hz, adjust if needed
end

return Farmer