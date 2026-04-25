local Economy = {}
local Cfg = nil
local SellEvent = nil
local UpgradeEvent = nil
local _sniperLock = nil
local UPGRADE_NAMES = { "Click", "SprinkerPower", "SeedLuck", "SeedRolls" }

function Economy.init(state)
    Cfg = state.Config
    _sniperLock = state.SniperLock
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        SellEvent = Comms:FindFirstChild("SellCrate")
        UpgradeEvent = Comms:FindFirstChild("BuyUpgrade")
    end
end

function Economy.run(state)
    task.spawn(function()
        while Cfg.Running do
            if not _sniperLock.locked then
                if Cfg.AutoSell and SellEvent then
                    pcall(function() SellEvent:FireServer() end)
                end
                if UpgradeEvent then
                    for _, n in ipairs(UPGRADE_NAMES) do
                        if Cfg.AutoUpgrades[n] then
                            pcall(function() UpgradeEvent:FireServer(n) end)
                            task.wait(0.1)
                        end
                    end
                end
            end
            task.wait(Cfg.SellInterval)
        end
    end)
end

function Economy.getUpgradeNames() return UPGRADE_NAMES end

return Economy
