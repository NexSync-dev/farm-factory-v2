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
    batchSize = 35,      -- tweak between 20-50 depending on if you get kicked
    maxPerCycle = 9999,
    tpMode = "True Bypass",
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function tick()
    if not getConfig("enabled") then return end

    local plot = Utils.getPlot()
    if not plot then return end

    local batchSize = getConfig("batchSize")
    local maxPerCycle = getConfig("maxPerCycle")

    -- Get tiles (no filtering at all)
    local allTiles = Utils.getProcessedTiles(plot, {}, Vector3.new())
    if not allTiles or #allTiles == 0 then 
        Utils.log("DEBUG", "No tiles returned from Utils.getProcessedTiles")
        return 
    end

    _stats.cycleCount += 1
    local harvested = 0
    local batchCount = 0

    for _, entry in ipairs(allTiles) do
        if harvested >= maxPerCycle or not getConfig("enabled") then
            break
        end

        if ClickEvent and entry.tile then
            Network.fireBypass(ClickEvent, entry.tile)
            -- Uncomment the line below if you want to see what it's firing on
            -- Utils.log("DEBUG", "Firing ClickPlant on: " .. tostring(entry.tile.Name))
        end

        harvested += 1
        batchCount += 1

        if batchCount >= batchSize then
            batchCount = 0
            RunService.Heartbeat:Wait()
        end
    end

    _stats.tilesThisCycle = harvested
    _stats.totalHarvested += harvested
end

function Farmer.getStats() return _stats end
function Farmer.resetStats()
    _stats = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }
end
function Farmer.setEnabled(v) Cfg.enabled = v end
function Farmer.isEnabled() return Cfg.enabled or false end

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
        if not ClickEvent then
            Utils.log("ERROR", "ClickPlant remote not found!")
        end
    end

    Scheduler.register("Farmer", tick, 0.008)  -- very fast
end

return Farmer
