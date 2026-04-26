local Farmer = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local Utils = nil
local Network = nil
local Scheduler = nil
local Cfg = nil
local ClickEvent = nil

local _stats = { cycleCount = 0, tilesThisCycle = 0, totalHarvested = 0 }

local defaults = {
    enabled = false,
    firesPerCycle = 120,
    useStrictMode = false,
    priorityFruits = {},
    collectDelay = 0,
    harvestMode = "batch",         -- "bypass" | "snap" | "batch"
    tilesPerFrame = 10,            -- How many tiles to process per frame (batch mode)
    yOffset = 3.5,                 -- Height above tile to TP
    claimOwnership = false,        -- Try to claim network ownership of tile parts
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

-- Attempt to claim network ownership of a part
-- Works on most executors (sethiddenproperty / setnewworkowner fallbacks)
local function tryClaimOwnership(part)
    if not part or not part:IsA("BasePart") then return end
    pcall(function()
        if setnewworkowner then
            setnewworkowner(part, LP)
        elseif sethiddenproperty then
            sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end
    end)
end

local function claimTileOwnership(tile)
    tryClaimOwnership(tile)
    for _, desc in ipairs(tile:GetDescendants()) do
        if desc:IsA("BasePart") then
            tryClaimOwnership(desc)
        end
    end
end

-------------------------------------------------------------------
-- HARVEST STRATEGIES
-------------------------------------------------------------------

-- True Bypass: fire without any TP (only works if no server distance check)
local function harvestBypass(tilesToHarvest, maxFires)
    local fired = 0
    for _, tile in ipairs(tilesToHarvest) do
        if fired >= maxFires or not getConfig("enabled") then break end
        Network.fire(ClickEvent, tile)
        fired = fired + 1
    end
    return fired
end

-- Anchored Snap: anchor → TP → fire → restore → unanchor (1 tile per frame)
local function harvestSnap(tilesToHarvest, maxFires)
    local hrp = Utils.getHRP()
    if not hrp then return 0 end

    local delay = getConfig("collectDelay")
    local yOffset = getConfig("yOffset")
    local wantOwnership = getConfig("claimOwnership")
    local fired = 0

    for _, tile in ipairs(tilesToHarvest) do
        if fired >= maxFires or not getConfig("enabled") then break end

        local tilePos = Utils.getPosition(tile)
        if not tilePos then continue end

        -- Save state
        local savedCF = hrp.CFrame
        local savedVel = hrp.AssemblyLinearVelocity

        -- Freeze physics
        hrp.Anchored = true

        -- Claim ownership if enabled
        if wantOwnership then
            claimTileOwnership(tile)
        end

        -- Snap to tile, fire, restore — all before any yield
        hrp.CFrame = CFrame.new(tilePos + Vector3.new(0, yOffset, 0))
        Network.fire(ClickEvent, tile)
        hrp.CFrame = savedCF

        -- Unfreeze
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        fired = fired + 1

        -- Yield per tile (gives other clients time to see original position)
        if delay > 0 then
            task.wait(delay)
        else
            RunService.Heartbeat:Wait()
        end
    end

    return fired
end

-- Batch Snap: same as anchored snap but processes N tiles per frame
-- Maximum throughput while staying invisible
local function harvestBatch(tilesToHarvest, maxFires)
    local hrp = Utils.getHRP()
    if not hrp then return 0 end

    local tilesPerFrame = getConfig("tilesPerFrame")
    local yOffset = getConfig("yOffset")
    local wantOwnership = getConfig("claimOwnership")
    local fired = 0

    local i = 1
    while i <= #tilesToHarvest and fired < maxFires and getConfig("enabled") do
        -- Save state once per batch
        local savedCF = hrp.CFrame

        -- Freeze physics for the entire batch
        hrp.Anchored = true

        -- Process a batch of tiles within this frame
        local batchEnd = math.min(i + tilesPerFrame - 1, #tilesToHarvest)
        for j = i, batchEnd do
            if fired >= maxFires or not getConfig("enabled") then break end

            local tile = tilesToHarvest[j]
            local tilePos = Utils.getPosition(tile)
            if tilePos then
                -- Claim ownership if enabled
                if wantOwnership then
                    claimTileOwnership(tile)
                end

                -- Snap → Fire → Restore (no yield between these!)
                hrp.CFrame = CFrame.new(tilePos + Vector3.new(0, yOffset, 0))
                Network.fire(ClickEvent, tile)
                hrp.CFrame = savedCF
                fired = fired + 1
            end
        end

        -- Restore position and unfreeze BEFORE yielding
        hrp.CFrame = savedCF
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        i = batchEnd + 1

        -- Now yield — other clients only see original position
        RunService.Heartbeat:Wait()
    end

    return fired
end

-------------------------------------------------------------------
-- MAIN TICK
-------------------------------------------------------------------

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
    local maxFires = getConfig("firesPerCycle")
    local mode = getConfig("harvestMode")

    local fired = 0
    if mode == "bypass" then
        fired = harvestBypass(tilesToHarvest, maxFires)
    elseif mode == "snap" then
        fired = harvestSnap(tilesToHarvest, maxFires)
    else -- "batch" (default)
        fired = harvestBatch(tilesToHarvest, maxFires)
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
    -- Safety: if disabling, make sure HRP is unanchored
    if not v then
        pcall(function()
            local hrp = Utils.getHRP()
            if hrp and hrp.Anchored then
                hrp.Anchored = false
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    end
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

    Scheduler.register("Farmer", tick, 0.05)
end

return Farmer
