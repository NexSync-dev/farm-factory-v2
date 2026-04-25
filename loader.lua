local REPO_BASES = {
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/main/",
    "https://raw.githubusercontent.com/NexSync-dev/farm-factory-v2/master/",
}

local function fetch(path)
    local errors = {}
    for _, base in ipairs(REPO_BASES) do
        local url = base .. path .. "?t=" .. tick()
        local ok, result = pcall(function()
            local src = game:HttpGet(url)
            if type(src) ~= "string" or src == "" then
                error("empty response")
            end
            local lowered = string.lower(src)
            if lowered:find("404: not found", 1, true) or lowered:find("<html", 1, true) then
                error("http body is not lua (likely 404)")
            end
            local chunk, compileErr = loadstring(src)
            if not chunk then
                error("compile failed: " .. tostring(compileErr))
            end

            local value = chunk()
            if value == nil then
                error("module returned nil")
            end
            return value
        end)

        if ok then
            return result
        end
        table.insert(errors, string.format("%s -> %s", url, tostring(result)))
    end

    error("FarmV2 > [fatal] failed loading " .. path .. ":\n- " .. table.concat(errors, "\n- "))
end
local LoaderUI = fetch("ui/loader.lua")
local ui = nil
if LoaderUI then ui = LoaderUI.show() end
local function step(perc, text) if ui then ui.update(perc, text) end end
step(0.1, "loading core...")
local Utils = fetch("core/utils.lua")
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
    loaded[path] = mod
    pcall(function() mod.init(State) end)
end
State.Farmer = loaded["modules/farmer.lua"]
State.Sniper = loaded["modules/sniper.lua"]
State.AutoSell = loaded["modules/autosell.lua"]
State.Upgrades = loaded["modules/upgrades.lua"]
State.AntiAFK = loaded["modules/antiafk.lua"]
step(0.9, "building gui...")
local GUI = fetch("ui/gui.lua")
pcall(function() GUI.build(State) end)
step(1.0, "done")
if ui then ui.finish() end
Scheduler.start()
