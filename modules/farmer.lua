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
    batchSize = 40,           -- higher = faster, but risk of kick
    maxPerCycle = 9999,
    tpMode = "True Bypass",
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
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

    -- Get ALL tiles (no heavy filtering)
    local allTiles = Utils.getProcessedTiles(plot, {}, hrp.Position)
    if not allTiles or #allTiles == 0 then return end

    _stats.cycleCount += 1
    local harvested = 0
    local batchCount = 0
    local oldCF = hrp.CFrame

    for _, entry in ipairs(allTiles) do
        if harvested >= maxPerCycle or not getConfig("enabled") then
            break
        end

        -- Skip empty tiles if possible (adjust field name if needed)
        if entry.empty == true then
            continue
        end

        if tpMode ~= "True Bypass" then
            -- moveToTile function here if you need it
        end

        if ClickEvent and entry.tile then
            Network.fireBypass(ClickEvent, entry.tile)
            -- Utils.log("DEBUG", "Firing on: " .. tostring(entry.tile.Name))
        end

        harvested += 1
        batchCount += 1

        if batchCount >= batchSize then
            batchCount = 0
            RunService.Heartbeat:Wait()   -- small yield to not freeze
        end
    end

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
    end

    Scheduler.register("Farmer", tick, 0.01)  -- very fast tick
end

return Farmer