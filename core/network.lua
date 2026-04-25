--[[
    FarmV2 — core/network.lua
    Rate-limited, adaptive network layer.
    All FireServer / InvokeServer calls go through here.
]]

local Network = {}

local RunService = game:GetService("RunService")

-- Dependencies (injected via init)
local Utils = nil

-------------------------------------------------
-- Token bucket rate limiter
-------------------------------------------------
local buckets = {} -- [remoteName] = { tokens, maxTokens, refillRate, lastRefill }

local DEFAULT_MAX_TOKENS   = 30  -- max burst
local DEFAULT_REFILL_RATE  = 30  -- tokens/sec
local THROTTLE_PING_THRESHOLD = 200 -- ms; if ping > this, halve the rate
local THROTTLE_MULTIPLIER  = 0.4

-- Configure limits for a specific remote
function Network.setLimit(remoteName, maxTokens, refillRate)
    buckets[remoteName] = {
        tokens     = maxTokens,
        maxTokens  = maxTokens,
        refillRate = refillRate,
        lastRefill = os.clock(),
    }
end

local function getBucket(remoteName)
    if not buckets[remoteName] then
        Network.setLimit(remoteName, DEFAULT_MAX_TOKENS, DEFAULT_REFILL_RATE)
    end
    return buckets[remoteName]
end

local function refillBucket(bucket)
    local now = os.clock()
    local elapsed = now - bucket.lastRefill
    bucket.lastRefill = now
    bucket.tokens = math.min(bucket.maxTokens, bucket.tokens + elapsed * bucket.refillRate)
end

local function consumeToken(remoteName)
    local bucket = getBucket(remoteName)
    refillBucket(bucket)

    -- Adaptive: check ping and throttle if high
    local ping = Utils and Utils.getPing() or 0
    if ping > THROTTLE_PING_THRESHOLD then
        -- Temporarily reduce available tokens
        bucket.tokens = bucket.tokens * THROTTLE_MULTIPLIER
    end

    if bucket.tokens >= 1 then
        bucket.tokens = bucket.tokens - 1
        return true
    end
    return false
end

local function waitForToken(remoteName)
    local attempts = 0
    while not consumeToken(remoteName) do
        RunService.Heartbeat:Wait()
        attempts = attempts + 1
        if attempts > 300 then -- 5 second safety timeout
            if Utils then Utils.log("WARN", "Network throttle timeout for " .. remoteName) end
            return false
        end
    end
    return true
end

-------------------------------------------------
-- Stats tracking
-------------------------------------------------
local stats = {
    totalFired   = 0,
    totalInvoked = 0,
    totalErrors  = 0,
    throttled    = 0,
}

function Network.getStats()
    return stats
end

function Network.resetStats()
    stats.totalFired   = 0
    stats.totalInvoked = 0
    stats.totalErrors  = 0
    stats.throttled    = 0
end

-------------------------------------------------
-- Core API
-------------------------------------------------

--- Fire a RemoteEvent with rate limiting.
--- @param remote RemoteEvent
--- @param ... any arguments
--- @return boolean success
function Network.fire(remote, ...)
    local name = remote.Name
    if not waitForToken(name) then
        stats.throttled = stats.throttled + 1
        return false
    end

    local ok, err = pcall(function(...)
        remote:FireServer(...)
    end, ...)

    if ok then
        stats.totalFired = stats.totalFired + 1
    else
        stats.totalErrors = stats.totalErrors + 1
        if Utils then Utils.log("ERROR", "FireServer failed [" .. name .. "]: " .. tostring(err)) end
    end
    return ok
end

--- Invoke a RemoteFunction with rate limiting + retry.
--- @param remote RemoteFunction
--- @param maxRetries number (default 3)
--- @param ... any arguments
--- @return boolean success, any result
function Network.invoke(remote, maxRetries, ...)
    local name = remote.Name
    maxRetries = maxRetries or 3

    if not waitForToken(name) then
        stats.throttled = stats.throttled + 1
        return false, nil
    end

    local args = {...}
    for attempt = 1, maxRetries do
        local ok, result = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)

        if ok then
            stats.totalInvoked = stats.totalInvoked + 1
            return true, result
        else
            stats.totalErrors = stats.totalErrors + 1
            if Utils then
                Utils.log("WARN", string.format(
                    "InvokeServer attempt %d/%d failed [%s]: %s",
                    attempt, maxRetries, name, tostring(result)
                ))
            end
            if attempt < maxRetries then
                task.wait(0.5 * attempt) -- exponential-ish backoff
            end
        end
    end

    return false, nil
end

--- Fire multiple remotes in one frame (batch helper).
--- Fires up to `batchSize` events, then yields one frame.
--- @param remote RemoteEvent
--- @param argsList table[] — array of {arg1, arg2, ...} tables
--- @param batchSize number (default 5)
function Network.fireBatch(remote, argsList, batchSize)
    batchSize = batchSize or 5
    for i, args in ipairs(argsList) do
        Network.fire(remote, unpack(args))
        if i % batchSize == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end

-------------------------------------------------
-- Init
-------------------------------------------------
function Network.init(state)
    Utils = state.Utils

    -- Set game-specific rate limits for "Build A Farm Factory" remotes
    Network.setLimit("ClickPlant",  30, 30)  -- harvesting: 30/sec burst
    Network.setLimit("SellCrate",   5,  5)   -- selling: 5/sec
    Network.setLimit("DoRoll",      20, 20)  -- sniper: 20/sec
    Network.setLimit("BuyUpgrade",  5,  5)   -- upgrades: 5/sec
    Network.setLimit("BuySeeds",    5,  5)   -- buying: 5/sec

    if Utils then Utils.log("INFO", "Network layer initialized") end
end

return Network
