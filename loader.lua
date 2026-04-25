local REPO_BASES = {
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/main/",
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/",
}
local function runScript(path)
    for _, base in ipairs(REPO_BASES) do
        local url = base .. path .. "?t=" .. tick()
        local ok = pcall(function()
            local src = game:HttpGet(url)
            loadstring(src)()
        end)
        if ok then
            return true
        end
    end
    return false
end
local function fetch(path)
    for _, base in ipairs(REPO_BASES) do
        local url = base .. path .. "?t=" .. tick()
        local ok, result = pcall(function()
            local src = game:HttpGet(url)
            return loadstring(src)()
        end)
        if ok and result then
            return result
        end
    end
    return nil
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
if not Network or not Scheduler then
    step(0.3, "fallback to V1 main.lua...")
    local ok = runScript("main.lua")
    if not ok then
        error("FarmV2 > [fatal] failed to load core modules and main.lua fallback")
    end
    if ui then ui.finish() end
    return
end
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
        loaded[path] = mod
        pcall(function() mod.init(State) end)
    end
end
State.Farmer = loaded["modules/farmer.lua"]
State.Sniper = loaded["modules/sniper.lua"]
State.AutoSell = loaded["modules/autosell.lua"]
State.Upgrades = loaded["modules/upgrades.lua"]
State.AntiAFK = loaded["modules/antiafk.lua"]
step(0.9, "building gui...")
local GUI = fetch("ui/gui.lua")
if GUI then pcall(function() GUI.build(State) end) end
step(1.0, "done")
if ui then ui.finish() end
Scheduler.start()
