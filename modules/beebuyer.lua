local BeeBuyer = {}
local Network = nil
local Utils = nil
local Cfg = nil
local BuyBeeEvent = nil
local _beeList = {}
local _stats = { bought = 0, failed = 0, lastBought = "None" }
local defaults = {
    selectedBee = nil,
    autoBuy = false,
    autoBuyInterval = 5,
}
local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end
local function fetchBeeList()
    local list = {}
    pcall(function()
        local storage = game:GetService("ReplicatedStorage"):FindFirstChild("Storage")
        if storage then
            local beeFolder = storage:FindFirstChild("Bees")
            if beeFolder then
                for _, bee in ipairs(beeFolder:GetChildren()) do
                    table.insert(list, bee.Name)
                end
            end
        end
    end)
    table.sort(list)
    return list
end
function BeeBuyer.getBeeList()
    return _beeList
end
function BeeBuyer.getStats()
    return _stats
end
function BeeBuyer.resetStats()
    _stats = { bought = 0, failed = 0, lastBought = "None" }
end
function BeeBuyer.buyBee(beeName)
    if not beeName or beeName == "" then
        if Utils then Utils.log("ERROR", "BeeBuyer: No bee selected") end
        return false, "No bee selected"
    end
    if not BuyBeeEvent then
        if Utils then Utils.log("ERROR", "BeeBuyer: BuyBee remote not found") end
        return false, "BuyBee remote not found"
    end
    local ok, result = pcall(function()
        return BuyBeeEvent:InvokeServer(beeName)
    end)
    if ok then
        _stats.bought = _stats.bought + 1
        _stats.lastBought = beeName
        if Utils then Utils.log("INFO", "BeeBuyer: Bought " .. beeName) end
        return true, result
    else
        _stats.failed = _stats.failed + 1
        if Utils then Utils.log("ERROR", "BeeBuyer: Failed to buy " .. beeName .. " — " .. tostring(result)) end
        return false, tostring(result)
    end
end

function BeeBuyer.buyAndLeave(beeName)
    if not beeName or beeName == "" then return false, "No bee selected" end
    if not BuyBeeEvent then return false, "BuyBee remote not found" end
    
    if Utils then Utils.log("INFO", "BeeBuyer: Executing Buy & Leave exploit with Network Lockdown for " .. beeName) end
    
    -- Network Lockdown: Hook remotes to prevent saving
    local function lockdown()
        local ok, err = pcall(function()
            local oldFire, oldInvoke
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local name = self.Name:lower()
                
                if (method == "FireServer" or method == "InvokeServer") then
                    if name:find("save") or name:find("sync") or name:find("data") or name:find("store") then
                        if Utils then Utils.log("DEBUG", "BeeBuyer: Blocked save request to " .. self.Name) end
                        return nil
                    end
                end
                return oldNamecall(self, ...)
            end)
            
            setreadonly(mt, true)
        end)
        if not ok and Utils then Utils.log("ERROR", "BeeBuyer: Failed to initialize Network Lockdown: " .. tostring(err)) end
    end
    
    lockdown()
    
    -- Fire and forget, then crash/leave
    task.spawn(function()
        pcall(function()
            BuyBeeEvent:InvokeServer(beeName)
        end)
    end)
    
    task.wait(0.1) -- Minimal wait to ensure packet is sent
    game:Shutdown()
    return true
end
function BeeBuyer.init(state)
    Utils = state.Utils
    Network = state.Network
    Cfg = state.Config.BeeBuyer or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.BeeBuyer = Cfg
    _beeList = fetchBeeList()
    local Comms = game:GetService("ReplicatedStorage"):WaitForChild("Communication", 10)
    if Comms then
        BuyBeeEvent = Comms:FindFirstChild("BuyBee")
    end
    if Utils then
        Utils.log("INFO", "BeeBuyer: Loaded " .. #_beeList .. " bees, remote " .. (BuyBeeEvent and "found" or "NOT found"))
    end
end
return BeeBuyer
