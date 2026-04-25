local Scheduler = {}
local RunService = game:GetService("RunService")
local Utils = nil
local modules = {}
function Scheduler.register(name, tickFn, interval)
    modules[name] = {
        tickFn = tickFn,
        interval = interval or 0,
        paused = false,
        running = false,
        lastTick = 0,
        errorCount = 0,
        maxErrors = 10,
    }
end
function Scheduler.unregister(name)
    modules[name] = nil
end
function Scheduler.pause(name)
    if modules[name] then
        modules[name].paused = true
    end
end
function Scheduler.resume(name)
    if modules[name] then
        modules[name].paused = false
        modules[name].errorCount = 0
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
local alive = false
local connections = {}
function Scheduler.start()
    if alive then return end
    alive = true
    for name, mod in pairs(modules) do
        mod.running = true
        task.spawn(function()
            while alive and modules[name] do
                if not mod.paused then
                    local now = os.clock()
                    if (now - mod.lastTick) >= mod.interval then
                        mod.lastTick = now
                        local ok, err = pcall(mod.tickFn, now - mod.lastTick)
                        if not ok then
                            mod.errorCount = mod.errorCount + 1
                            if Utils then
                                Utils.log("ERROR", string.format("module '%s' error (%d/%d): %s", name, mod.errorCount, mod.maxErrors, tostring(err)))
                            end
                            if mod.errorCount >= mod.maxErrors then
                                mod.paused = true
                            end
                        else
                            mod.errorCount = 0
                        end
                    end
                end
                if mod.interval > 0.03 then
                    task.wait(mod.interval)
                else
                    RunService.Heartbeat:Wait()
                end
            end
            mod.running = false
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
end
function Scheduler.isAlive()
    return alive
end
function Scheduler.init(state)
    Utils = state.Utils
end
return Scheduler
