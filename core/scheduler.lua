local Scheduler = {}
local RunService = game:GetService("RunService")

local _jobs = {}
local _alive = false
local _thread = nil

local function timeNow()
    return os.clock()
end

local function runJob(job)
    if job.paused then
        return
    end
    if not job.fn then
        return
    end

    local t = timeNow()
    local interval = job.interval or 0
    if interval > 0 and (t - (job.lastRun or 0)) < interval then
        return
    end

    job.lastRun = t
    local ok = pcall(job.fn)
    if not ok then
        -- Keep scheduler alive even when one job fails.
    end
end

local function loop()
    while _alive do
        for _, job in pairs(_jobs) do
            runJob(job)
        end
        RunService.Heartbeat:Wait()
    end
    _thread = nil
end

function Scheduler.register(name, fn, interval)
    _jobs[name] = {
        fn = fn,
        interval = interval or 0.1,
        paused = false,
        lastRun = 0,
    }
end

function Scheduler.setInterval(name, interval)
    local job = _jobs[name]
    if not job then
        return
    end
    job.interval = interval or 0
end

function Scheduler.pause(name)
    local job = _jobs[name]
    if job then
        job.paused = true
    end
end

function Scheduler.resume(name)
    local job = _jobs[name]
    if job then
        job.paused = false
    end
end

function Scheduler.start()
    if _alive then
        return
    end
    _alive = true
    _thread = task.spawn(loop)
end

function Scheduler.stop()
    _alive = false
end

function Scheduler.isAlive()
    return _alive
end

function Scheduler.init(_state)
    -- Reserved for future shared state wiring.
end

return Scheduler
