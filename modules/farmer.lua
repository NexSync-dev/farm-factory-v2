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
    firesPerCycle = 120,        -- Main speed control (higher = faster, but more lag)
    tpMode = "True Bypass",
    usePlantsFolder = true,     -- Keep this on for best performance
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

    -- Build list of only tiles that have plants
    local tilesToHarvest = {}
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local tileName = plant.Name
        local tile = tilesFolder:FindFirstChild(tileName) or tilesFolder:FindFirstChild(tileName, true)
        
        if tile then
            table.insert(tilesToHarvest, tile)
        end
    end

    if #tilesToHarvest == 0 then return end

    _stats.cycleCount = _stats.cycleCount + 1
    local fired = 0
    local maxFires = getConfig("firesPerCycle")

    for _, tile in ipairs(tilesToHarvest) do
        if fired >= maxFires or not getConfig("enabled") then 
            break 
        end

        -- Main click on the tile
        pcall(function()
            Network.fireBypass(ClickEvent, tile)
        end)

        -- Fallback: click visible parts inside the tile
        for _, desc in ipairs(tile:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Transparency < 1 then
                pcall(function()
                    Network.fireBypass(ClickEvent, desc)
                end)
                break
            end
        end

        fired = fired + 1
    end

    _stats.tilesThisCycle = fired
    _stats.totalHarvested = _stats.totalHarvested + fired
end

-- Public API
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

    -- Apply defaults
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then 
            Cfg[k] = v 
        end
    end
    state.Config.Farmer = Cfg

    -- Find remote
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:FindFirstChild("ClickPlant")
    end

    -- Register fast scheduler
    Scheduler.register("Farmer", tick, 0.01)  -- 100Hz
end

return Farmer
