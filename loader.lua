local REPO_BASE = "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/"
local function fetch(path)
    local url = REPO_BASE .. path .. "?t=" .. tick()
    local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not ok then return nil end
    return result
end
local LoaderUI = fetch("ui/loader.lua")
local ui = nil
if LoaderUI then ui = LoaderUI.show() end
local function step(perc, text) if ui then ui.update(perc, text) end end
step(0.1, "loading core...")
local Utils = fetch("core/utils.lua")
if not Utils then error("FarmV2 > [fatal] failed to load core/utils.lua") end
local Network = fetch("core/network.lua")
local Scheduler = fetch("core/scheduler.lua")
step(0.3, "starting engine...")
local State = { Utils = Utils, Network = Network, Scheduler = Scheduler, Config = { Farmer = {}, Sniper = {}, AutoSell = {}, Upgrades = {}, AntiAFK = {} }, _connections = {} }
Network.init(State)
Scheduler.init(State)
step(0.5, "loading modules...")
local modules = { "modules/farmer.lua", "modules/sniper.lua", "modules/autosell.lua", "modules/upgrades.lua", "modules/antiafk.lua" }
local loaded = {}
for i, path in ipairs(modules) do
    step(0.5 + (i/#modules)*0.3, "loading " .. path)
    local mod = fetch(path)
    if mod then
        table.insert(loaded, mod)
        pcall(function() mod.init(State) end)
    end
end
State.Farmer, State.Sniper, State.AutoSell, State.Upgrades, State.AntiAFK = loaded[1], loaded[2], loaded[3], loaded[4], loaded[5]
step(0.9, "building gui...")
local GUI = fetch("ui/gui.lua")
if GUI then pcall(function() GUI.build(State) end) end
step(1.0, "done")
if ui then ui.finish() end
Scheduler.start()
