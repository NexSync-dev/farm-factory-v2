--[[
    FarmV2 — core/scheduler.lua
    Task scheduler — runs modules as independent, error-isolated coroutines.
]]

local Scheduler = {}

local RunService = game:GetService("RunService")

local Utils = nil
local modules = {} -- [name] = { tickFn, interval, paused, running, lastTick, errorCount }

-------------------------------------------------
-- Module registration
-------------------------------------------------

--- Register a module's tick function with the scheduler.
--- @param name string — unique module name
--- @param tickFn function — called every interval; receives delta time
--- @param interval number — seconds between ticks (0 = every heartbeat)
function Scheduler.register(name, tickFn, interval)
    modules[name] = {
        tickFn     = tickFn,
        interval   = interval or 0,
        paused     = false,
        running    = false,
        lastTick   = 0,
        errorCount = 0,
        maxErrors  = 10, -- pause module after this many consecutive errors
    }
    if Utils then Utils.log("INFO", "Scheduler: registered module '" .. name .. "' (interval=" .. tostring(interval) .. "s)") end
end

--- Unregister a module.
function Scheduler.unregister(name)
    modules[name] = nil
end

-------------------------------------------------
-- Module control
-------------------------------------------------

function Scheduler.pause(name)
    if modules[name] then
        modules[name].paused = true
        if Utils then Utils.log("DEBUG", "Scheduler: paused '" .. name .. "'") end
    end
end

function Scheduler.resume(name)
    if modules[name] then
        modules[name].paused = false
        modules[name].errorCount = 0
        if Utils then Utils.log("DEBUG", "Scheduler: resumed '" .. name .. "'") end
    end
end

function Scheduler.isPaused(name)
    return modules[name] and modules[name].paused
end

function Scheduler.isRunning(name)
    return modules[name] and modules[name].running and not modules[name].paused
end

function Scheduler.getStatus(name)
    local m = modules[name]
    if not m then return "unregistered" end
    if m.paused then return "paused" end
    if m.running then return "running" end
    return "idle"
end

function Scheduler.getModuleNames()
    local names = {}
    for name in pairs(modules) do
        table.insert(names, name)
    end
    return names
end

-------------------------------------------------
-- Core loop
-------------------------------------------------
local alive = false
local connections = {}

function Scheduler.start()
    if alive then return end
    alive = true

    -- Each module gets its own coroutine for true independence.
    for name, mod in pairs(modules) do
        mod.running = true
        task.spawn(function()
            if Utils then Utils.log("INFO", "Scheduler: starting loop for '" .. name .. "'") end
            while alive and modules[name] do
                if not mod.paused then
                    local now = os.clock()
                    if (now - mod.lastTick) >= mod.interval then
                        mod.lastTick = now
                        local ok, err = pcall(mod.tickFn, now - mod.lastTick)
                        if not ok then
                            mod.errorCount = mod.errorCount + 1
                            if Utils then
                                Utils.log("ERROR", ("Module '%s' error (%d/%d): %s"):format(
                                    name, mod.errorCount, mod.maxErrors, tostring(err)
                                ))
                            end
                            if mod.errorCount >= mod.maxErrors then
                                mod.paused = true
                                if Utils then Utils.log("ERROR", "Module '" .. name .. "' auto-paused after too many errors") end
                            end
                        else
                            mod.errorCount = 0 -- reset on success
                        end
                    end
                end

                -- Yield: respect the module's interval
                if mod.interval > 0.03 then
                    task.wait(mod.interval)
                else
                    RunService.Heartbeat:Wait()
                end
            end
            mod.running = false
            if Utils then Utils.log("INFO", "Scheduler: loop ended for '" .. name .. "'") end
        end)
    end
end

function Scheduler.stop()
    alive = false
    for _, mod in pairs(modules) do
        mod.running = false
    end
    for _, conn in ipairs(connections) do
        if conn.Connected then conn:Disconnect() end
    end
    connections = {}
    if Utils then Utils.log("INFO", "Scheduler: all modules stopped") end
end

function Scheduler.isAlive()
    return alive
end

-------------------------------------------------
-- Init
-------------------------------------------------
function Scheduler.init(state)
    Utils = state.Utils
    if Utils then Utils.log("INFO", "Scheduler initialized") end
end

return Scheduler
