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
    firesPerCycle = 120,           -- Max fires per scheduler tick (respects Network rate limits now)
    useStrictMode = false,         -- true = only priority fruits
    priorityFruits = {},           -- Multi-select from GUI
    collectDelay = 0,              -- Extra delay between fires (seconds)
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

local function tick()
    if not getConfig("enabled") then return end

    local plot = Utils.getPlot()
    if not plot then return end

    local plantsFolder = plot:FindFirstChild("Plants")
    if not plantsFolder then return end

    local tilesFolder = plot:FindFirstChild("Tiles") 
                     or (plot:FindFirstChild("PlotComponents") and plot.PlotComponents:FindFirstChild("Tiles"))
    if not tilesFolder then return end

    local priorityList = getConfig("priorityFruits")
    local strictMode = getConfig("useStrictMode")
    local hasPriority = next(priorityList) ~= nil

    local tilesToHarvest = {}

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local tileName = plant.Name
        local tile = tilesFolder:FindFirstChild(tileName) or tilesFolder:FindFirstChild(tileName, true)
        
        if tile then
            local shouldHarvest = true

            if strictMode and hasPriority then
                shouldHarvest = false
                for fruitName, _ in pairs(priorityList) do
                    if plant.Name:find(fruitName, 1, true) or 
                       (plant:FindFirstChild("FruitType") and plant.FruitType.Value == fruitName) then
                        shouldHarvest = true
                        break
                    end
                end
            end

            if shouldHarvest then
                table.insert(tilesToHarvest, tile)
            end
        end
    end

    if #tilesToHarvest == 0 then return end

    _stats.cycleCount = _stats.cycleCount + 1
    local fired = 0
    local maxFires = getConfig("firesPerCycle")
    local delay = getConfig("collectDelay")

    for _, tile in ipairs(tilesToHarvest) do
        -- Re-check enabled every iteration so toggling off stops immediately
        if fired >= maxFires or not getConfig("enabled") then 
            break 
        end

        -- Single fire per tile using rate-limited Network.fire (no bypass)
        Network.fire(ClickEvent, tile)
        fired = fired + 1

        if delay > 0 then
            task.wait(delay)
        end
    end

    _stats.tilesThisCycle = fired
    _stats.totalHarvested = _stats.totalHarvested + fired
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

    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.Farmer = Cfg

    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:FindFirstChild("ClickPlant")
    end

    Scheduler.register("Farmer", tick, 0.01)
end

return Farmer
