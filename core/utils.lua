local Utils = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
Utils._debugEnabled = true
function Utils.setDebug(enabled)
    Utils._debugEnabled = enabled
end
function Utils.log(level, msg)
    if not Utils._debugEnabled and level == "DEBUG" then return end
    local prefix = string.format("FarmV2 > [%s]", level:lower())
    if level == "ERROR" then
        warn(prefix .. " " .. tostring(msg))
    else
        print(prefix, tostring(msg))
    end
end
function Utils.dump(tbl, indent)
    if not tbl then return "nil" end
    indent = indent or 0
    local s = "{\n"
    for k, v in pairs(tbl) do
        s = s .. string.rep("  ", indent + 1) .. tostring(k) .. " = "
        if type(v) == "table" then
            s = s .. Utils.dump(v, indent + 1) .. ",\n"
        else
            s = s .. tostring(v) .. ",\n"
        end
    end
    return s .. string.rep("  ", indent) .. "}"
end
function Utils.getPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    return plots:FindFirstChild(LP.Name) or plots:FindFirstChild(LP.DisplayName)
end
function Utils.getPosition(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("Model") then
        return obj:GetPivot().Position
    elseif obj:IsA("BasePart") then
        return obj.Position
    end
    return nil
end
function Utils.getProcessedTiles(plot, priorityList, hrpPos)
    local tilesFolder = plot and plot:FindFirstChild("Tiles")
    if not tilesFolder then return {} end
    local result = {}
    local hasPrio = (priorityList and next(priorityList) ~= nil)
    for _, tile in ipairs(tilesFolder:GetChildren()) do
        local pos = Utils.getPosition(tile)
        local dist = (pos and hrpPos) and (pos - hrpPos).Magnitude or 9999
        local isPriority = false
        local isEmpty = true
        for _, child in ipairs(tile:GetChildren()) do
            if child.Name ~= "Soil" and child.Name ~= "Base" and child.Name ~= "Hitbox" then
                isEmpty = false
                if hasPrio then
                    for fruitName, enabled in pairs(priorityList) do
                        if enabled and (child.Name:find(fruitName) or fruitName:find(child.Name)) then
                            isPriority = true
                            break
                        end
                    end
                end
            end
        end
        table.insert(result, {
            tile = tile,
            position = pos,
            distance = dist,
            priority = isPriority,
            empty = isEmpty,
        })
    end
    table.sort(result, function(a, b)
        if a.priority ~= b.priority then return a.priority end
        if a.empty ~= b.empty then return not a.empty end
        return a.distance < b.distance
    end)
    return result
end
function Utils.getClosestTileIndex()
    local plot = Utils.getPlot()
    local hrp = Utils.getHRP()
    if not plot or not hrp then return 0 end
    local tilesFolder = plot:FindFirstChild("Tiles")
    if not tilesFolder then return 0 end
    local closestDist = 9999
    local closestIdx = 0
    local children = tilesFolder:GetChildren()
    for i, tile in ipairs(children) do
        local pos = Utils.getPosition(tile)
        if pos then
            local dist = (pos - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                local num = string.match(tile.Name, "%d+")
                closestIdx = num and tonumber(num) or i
            end
        end
    end
    return closestIdx
end
function Utils.safeTP(hrp, targetPos, maxStep)
    if not hrp or not hrp.Parent then return false end
    maxStep = maxStep or 100
    local startPos = hrp.Position
    local delta = targetPos - startPos
    local totalDist = delta.Magnitude
    if totalDist <= maxStep then
        hrp.CFrame = CFrame.new(targetPos)
        return true
    end
    local direction = delta.Unit
    local steps = math.ceil(totalDist / maxStep)
    for i = 1, steps do
        if not hrp or not hrp.Parent then return false end
        local fraction = math.min(i / steps, 1)
        local pos = startPos + direction * (totalDist * fraction)
        hrp.CFrame = CFrame.new(pos)
        if i < steps then
            RunService.Heartbeat:Wait()
        end
    end
    return true
end
function Utils.instantTP(hrp, targetPos, yOffset)
    if not hrp or not hrp.Parent then return false end
    yOffset = yOffset or 3.5
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, yOffset, 0))
    return true
end
function Utils.getHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
function Utils.getCharacterParts()
    local char = LP.Character
    if not char then return {} end
    local parts = {}
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            table.insert(parts, v)
        end
    end
    return parts
end
function Utils.getPing()
    local ok, ping = pcall(function()
        local stats = game:GetService("Stats")
        local networkStats = stats:FindFirstChild("PerformanceStats")
        if networkStats then
            local pingItem = networkStats:FindFirstChild("Ping")
            if pingItem then return pingItem:GetValue() end
        end
        return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and ping or 0
end
return Utils
