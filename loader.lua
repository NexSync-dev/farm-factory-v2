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

local function fetchOptional(path)
    local ok, result = pcall(fetch, path)
    if ok then
        return result
    end
    warn("FarmV2 > [warn] optional module load failed for " .. path .. ": " .. tostring(result))
    return nil
end

-- Load LinoriaLib once here, pass to GUI via State
local function loadLinoria()
    local function tryLoad(urls)
        for _, url in ipairs(urls) do
            local ok, result = pcall(function()
                return loadstring(game:HttpGet(url))()
            end)
            if ok and result then return result end
        end
        return nil
    end
    local lib = tryLoad({
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua",
    })
    local theme = tryLoad({
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua",
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/addons/ThemeManager.lua",
    })
    local save = tryLoad({
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua",
        "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/addons/SaveManager.lua",
    })
    return lib, theme, save
end

local LoaderUI = fetch("ui/loader.lua")
local ui = nil
if LoaderUI then ui = LoaderUI.show() end
local function step(perc, text) if ui then ui.update(perc, text) end end

step(0.05, "loading LinoriaLib...")
local LinoriaLib, ThemeManager, SaveManager = loadLinoria()

step(0.15, "loading core...")
local Utils = fetch("core/utils.lua")
local Network = fetch("core/network.lua")
local Scheduler = fetch("core/scheduler.lua")

step(0.3, "starting engine...")
local State = {
    Utils = Utils,
    Network = Network,
    Scheduler = Scheduler,
    Config = {
        Farmer = {},
        Sniper = {},
        AutoSell = {},
        Upgrades = {},
        AntiAFK = {},
        BeeBuyer = {},
    },
    _connections = {},
    _LinoriaLib = LinoriaLib,
    _ThemeManager = ThemeManager,
    _SaveManager = SaveManager,
}
Network.init(State)
Scheduler.init(State)

step(0.5, "loading modules...")
local requiredModules = { "modules/visuals.lua", "modules/farmer.lua", "modules/sniper.lua", "modules/antiafk.lua" }
local optionalModules = { "modules/autosell.lua", "modules/upgrades.lua", "modules/beebuyer.lua" }
local loaded = {}
local totalMods = #requiredModules + #optionalModules

for i, path in ipairs(requiredModules) do
    step(0.5 + (i / totalMods) * 0.3, "loading " .. path)
    local mod = fetch(path)
    loaded[path] = mod
    pcall(function() mod.init(State) end)
end
for j, path in ipairs(optionalModules) do
    local i = #requiredModules + j
    step(0.5 + (i / totalMods) * 0.3, "loading " .. path)
    local mod = fetchOptional(path)
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
State.BeeBuyer = loaded["modules/beebuyer.lua"]
State.Visuals = loaded["modules/visuals.lua"]

step(0.9, "building gui...")
local GUI = fetch("ui/gui.lua")
pcall(function() GUI.build(State) end)
step(1.0, "done")
if ui then ui.finish() end
Scheduler.start()
