local Network = {}
local RunService = game:GetService("RunService")
local Utils = nil
local buckets = {}
local DEFAULT_MAX_TOKENS = 30
local DEFAULT_REFILL_RATE = 30
local THROTTLE_PING_THRESHOLD = 200
local THROTTLE_MULTIPLIER = 0.4
function Network.setLimit(remoteName, maxTokens, refillRate)
    buckets[remoteName] = {
        tokens = maxTokens,
        maxTokens = maxTokens,
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
    local ping = Utils and Utils.getPing() or 0
    if ping > THROTTLE_PING_THRESHOLD then
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
        if attempts > 300 then
            return false
        end
    end
    return true
end
local stats = { totalFired = 0, totalInvoked = 0, totalErrors = 0, throttled = 0 }
function Network.getStats()
    return stats
end
function Network.resetStats()
    stats.totalFired = 0
    stats.totalInvoked = 0
    stats.totalErrors = 0
    stats.throttled = 0
end
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
                Utils.log("WARN", string.format("InvokeServer attempt %d/%d failed [%s]: %s", attempt, maxRetries, name, tostring(result)))
            end
            if attempt < maxRetries then
                task.wait(0.5 * attempt)
            end
        end
    end
    return false, nil
end
function Network.fireBatch(remote, argsList, batchSize)
    batchSize = batchSize or 5
    for i, args in ipairs(argsList) do
        Network.fire(remote, unpack(args))
        if i % batchSize == 0 then
            RunService.Heartbeat:Wait()
        end
    end
end
function Network.init(state)
    Utils = state.Utils
    Network.setLimit("ClickPlant", 30, 30)
    Network.setLimit("SellCrate", 5, 5)
    Network.setLimit("DoRoll", 20, 20)
    Network.setLimit("BuyUpgrade", 5, 5)
    Network.setLimit("BuySeeds", 5, 5)
end
return Network
