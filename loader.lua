local REPO_BASE = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/"
local function fetch(path)
    local url = REPO_BASE .. path .. "?t=" .. tick()
    local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not ok then return nil end
    return result
end
local Utils = fetch("core/utils.lua")
if not Utils then error("[FarmV2] Failed to load core/utils.lua") end
local Network = fetch("core/network.lua")
local Scheduler = fetch("core/scheduler.lua")
local State = { Utils = Utils, Network = Network, Scheduler = Scheduler, Config = { Farmer = {}, Sniper = {}, AutoSell = {}, Upgrades = {}, AntiAFK = {} }, _connections = {} }
Network.init(State)
Scheduler.init(State)
local Farmer = fetch("modules/farmer.lua")
local Sniper = fetch("modules/sniper.lua")
local AutoSell = fetch("modules/autosell.lua")
local UpgradesMod = fetch("modules/upgrades.lua")
local AntiAFKMod = fetch("modules/antiafk.lua")
local moduleList = { { name = "Farmer", mod = Farmer }, { name = "Sniper", mod = Sniper }, { name = "AutoSell", mod = AutoSell }, { name = "Upgrades", mod = UpgradesMod }, { name = "AntiAFK", mod = AntiAFKMod } }
for _, entry in ipairs(moduleList) do
    if entry.mod then pcall(function() entry.mod.init(State) end) end
end
State.Farmer, State.Sniper, State.AutoSell, State.Upgrades, State.AntiAFK = Farmer, Sniper, AutoSell, UpgradesMod, AntiAFKMod
local GUI = fetch("ui/gui.lua")
if GUI then pcall(function() GUI.build(State) end) end
Scheduler.start()
