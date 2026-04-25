local Network = {}
local unpackArgs = table.unpack or unpack

local _state = nil
local _limits = {}
local _stats = {
    totalFired = 0,
    totalInvoked = 0,
    totalErrors = 0,
}

local function now()
    return os.clock()
end

local function getLimit(name)
    local rule = _limits[name]
    if not rule then
        return nil
    end
    return rule
end

local function isAllowed(name, isInvoke)
    local rule = getLimit(name)
    if not rule then
        return true
    end

    local t = now()
    local minGap = isInvoke and rule.invokeGap or rule.fireGap
    local lastKey = isInvoke and "lastInvoke" or "lastFire"

    if minGap and minGap > 0 then
        local last = rule[lastKey] or 0
        if (t - last) < minGap then
            return false
        end
        rule[lastKey] = t
    end

    return true
end

function Network.setLimit(remoteName, fireRate, invokeRate)
    local fireGap = (type(fireRate) == "number" and fireRate > 0) and (1 / fireRate) or 0
    local invokeGap = (type(invokeRate) == "number" and invokeRate > 0) and (1 / invokeRate) or 0
    _limits[remoteName] = {
        fireGap = fireGap,
        invokeGap = invokeGap,
        lastFire = 0,
        lastInvoke = 0,
    }
end

function Network.fire(remote, ...)
    if not remote then
        return false
    end
    local name = remote.Name or "unknown"
    if not isAllowed(name, false) then
        return false
    end

    local args = table.pack(...)
    local ok = pcall(function()
        remote.FireServer(remote, unpackArgs(args, 1, args.n))
    end)
    if ok then
        _stats.totalFired = _stats.totalFired + 1
        return true
    end
    _stats.totalErrors = _stats.totalErrors + 1
    return false
end

function Network.invoke(remote, ...)
    if not remote then
        return false, nil
    end
    local name = remote.Name or "unknown"
    if not isAllowed(name, true) then
        return false, nil
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return remote.InvokeServer(remote, unpackArgs(args, 1, args.n))
    end)
    if ok then
        _stats.totalInvoked = _stats.totalInvoked + 1
        return true, result
    end
    _stats.totalErrors = _stats.totalErrors + 1
    return false, nil
end

function Network.fireBypass(remote, ...)
    if not remote then
        return false
    end
    local args = table.pack(...)
    local ok = pcall(function()
        remote.FireServer(remote, unpackArgs(args, 1, args.n))
    end)
    if ok then
        _stats.totalFired = _stats.totalFired + 1
        return true
    end
    _stats.totalErrors = _stats.totalErrors + 1
    return false
end

function Network.invokeBypass(remote, ...)
    if not remote then
        return false, nil
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return remote.InvokeServer(remote, unpackArgs(args, 1, args.n))
    end)
    if ok then
        _stats.totalInvoked = _stats.totalInvoked + 1
        return true, result
    end
    _stats.totalErrors = _stats.totalErrors + 1
    return false, nil
end

function Network.getStats()
    return _stats
end

function Network.resetStats()
    _stats = {
        totalFired = 0,
        totalInvoked = 0,
        totalErrors = 0,
    }
end

function Network.init(state)
    _state = state
    Network.setLimit("ClickPlant", 30, 30)
    Network.setLimit("DoRoll", 20, 20)
    Network.setLimit("SellCrate", 5, 5)
end

return Network
