local Farmer = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local ClickEvent = nil
local Cfg = nil
local _sniperLock = nil
local _stats = { cycleCount = 0, totalHarvested = 0 }

function Farmer.init(state)
    Cfg = state.Config
    _sniperLock = state.SniperLock
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        ClickEvent = Comms:WaitForChild("ClickPlant", 5)
    end
end

local function getPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    return plots:FindFirstChild(LP.Name) or plots:FindFirstChild(LP.DisplayName)
end

local function getPosition(obj)
    if not obj or not obj.Parent then return nil end
    return obj:IsA("Model") and obj:GetPivot().Position or obj:IsA("BasePart") and obj.Position or nil
end

local function shouldHarvest(tile)
    if not Cfg.StrictFarm then return true end
    local hasPrio = false
    for _, v in pairs(Cfg.PriorityList) do
        if v then hasPrio = true break end
    end
    if not hasPrio then return true end
    for _, child in ipairs(tile:GetChildren()) do
        for fruitName, enabled in pairs(Cfg.PriorityList) do
            if enabled and (child.Name == fruitName or string.find(child.Name, fruitName, 1, true)) then
                return true
            end
        end
    end
    return false
end

function Farmer.run(state)
    task.spawn(function()
        while Cfg.Running do
            if Cfg.Collect and not _sniperLock.locked then
                local plot = getPlot()
                local tiles = plot and plot:FindFirstChild("Tiles")
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if tiles and hrp then
                    local oldCF = hrp.CFrame
                    for _, tile in ipairs(tiles:GetChildren()) do
                        if _sniperLock.locked or not Cfg.Collect then break end
                        if shouldHarvest(tile) then
                            local tPos = getPosition(tile)
                            if tPos then
                                if Cfg.BypassMode ~= "True Bypass" then
                                    hrp.CFrame = CFrame.new(tPos + Vector3.new(0, 3.5, 0))
                                end
                                pcall(function() ClickEvent:FireServer(tile) end)
                                if Cfg.BypassMode ~= "True Bypass" then
                                    hrp.CFrame = oldCF
                                end
                                if Cfg.CollectDelay > 0 then task.wait(Cfg.CollectDelay) end
                                RunService.Heartbeat:Wait()
                            end
                        end
                    end
                    _stats.cycleCount = _stats.cycleCount + 1
                    _stats.totalHarvested = _stats.totalHarvested + #tiles:GetChildren()
                end
            end
            task.wait(0.15)
        end
    end)
end

function Farmer.getStats() return _stats end
function Farmer.resetStats() _stats = { cycleCount = 0, totalHarvested = 0 } end

return Farmer
