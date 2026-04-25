local Sniper = {}
local RunService = game:GetService("RunService")

local RollEvent = nil
local BuyEvent = nil
local Cfg = nil
local _sniperLock = nil
local _stats = { totalRolls = 0, matches = 0, bought = 0 }

function Sniper.init(state)
    Cfg = state.Config
    _sniperLock = state.SniperLock
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        RollEvent = Comms:WaitForChild("DoRoll", 5)
        BuyEvent = Comms:WaitForChild("BuySeeds", 5)
    end
end

local function processResult(result)
    if not result or type(result) ~= "table" or not result[1] then return false end
    local item = result[1]
    local itemType = item.Type or item.Title or ""
    local itemEarnings = tonumber(item.Earnings) or 0

    local hasTarget = false
    if Cfg.TargetFruits then
        for _, v in pairs(Cfg.TargetFruits) do
            if v then hasTarget = true break end
        end
    end

    local isMatch = (not hasTarget or (Cfg.TargetFruits and Cfg.TargetFruits[itemType])) and (itemEarnings >= Cfg.MinEarnings)

    if isMatch then
        _sniperLock.locked = true
        _stats.matches = _stats.matches + 1
        print("FarmV2 > [info]", string.format("match: %s (%d earnings)", itemType, itemEarnings))

        if Cfg.AutoBuyMatch then
            local idx = item.StumpIndex or item.Index or 0
            pcall(function() BuyEvent:FireServer(idx) end)
            _stats.bought = _stats.bought + 1
            print("FarmV2 > [info]", string.format("bought %s (idx %s)", itemType, tostring(idx)))

            if Cfg.StopOnMatch then
                Cfg.SniperActive = false
            elseif Cfg.AutoProceedAfterBuy then
                task.wait(Cfg.ProceedDelay or 1.2)
                _sniperLock.locked = false
            end
        elseif Cfg.StopOnMatch then
            Cfg.SniperActive = false
        end
        return true
    end
    return false
end

function Sniper.run(state)
    task.spawn(function()
        while Cfg.Running do
            if Cfg.SniperActive and not _sniperLock.locked then
                local ok, result = pcall(function() return RollEvent:InvokeServer() end)
                if ok and result then
                    _stats.totalRolls = _stats.totalRolls + 1
                    processResult(result)
                end
                if not Cfg.InstantMode then
                    task.wait(Cfg.AutoRollSpeed)
                else
                    RunService.Heartbeat:Wait()
                end
            else
                task.wait(0.1)
            end
        end
    end)
end

function Sniper.start()
    Cfg.SniperActive = true
    _sniperLock.locked = false
end

function Sniper.stop()
    Cfg.SniperActive = false
    _sniperLock.locked = false
end

function Sniper.getStats() return _stats end
function Sniper.resetStats() _stats = { totalRolls = 0, matches = 0, bought = 0 } end

return Sniper
