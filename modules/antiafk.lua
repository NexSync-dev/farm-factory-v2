--[[
    FarmV2 — modules/antiafk.lua
    Anti-AFK + NoClip with cached character parts.
]]

local AntiAFK = {}

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local VirtualUser      = game:GetService("VirtualUser")

local Utils     = nil
local Scheduler = nil
local Cfg       = nil

-- Cached character parts for NoClip (refreshed on respawn)
local cachedParts    = {}
local cachedCharId   = nil -- character object ref to detect respawn

local connections = {}

-------------------------------------------------
-- Config defaults
-------------------------------------------------
local defaults = {
    antiAFK  = true,
    noClip   = true,
}

local function getConfig(key)
    return Cfg[key] ~= nil and Cfg[key] or defaults[key]
end

-------------------------------------------------
-- NoClip: cache parts on spawn, set CanCollide each frame
-------------------------------------------------
local function refreshPartCache()
    local LP   = Players.LocalPlayer
    local char = LP and LP.Character
    if not char then
        cachedParts  = {}
        cachedCharId = nil
        return
    end

    -- Only rebuild if character changed
    if char == cachedCharId then return end
    cachedCharId = char

    cachedParts = {}
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            table.insert(cachedParts, v)
        end
    end

    -- Also listen for new parts added later (accessories etc)
    local conn = char.DescendantAdded:Connect(function(v)
        if v:IsA("BasePart") then
            table.insert(cachedParts, v)
        end
    end)
    table.insert(connections, conn)
end

local function noClipTick()
    if not getConfig("noClip") then return end

    refreshPartCache()

    for _, part in ipairs(cachedParts) do
        if part and part.Parent then
            part.CanCollide = false
        end
    end
end

-------------------------------------------------
-- Anti-AFK
-------------------------------------------------
local function setupAntiAFK()
    local LP = Players.LocalPlayer
    local conn = LP.Idled:Connect(function()
        if getConfig("antiAFK") then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
    table.insert(connections, conn)
end

-------------------------------------------------
-- Init
-------------------------------------------------
function AntiAFK.setAntiAFK(v)
    Cfg.antiAFK = v
end

function AntiAFK.setNoClip(v)
    Cfg.noClip = v
end

function AntiAFK.init(state)
    Utils     = state.Utils
    Scheduler = state.Scheduler
    Cfg       = state.Config.AntiAFK or {}

    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.AntiAFK = Cfg

    -- Anti-AFK via Idled event (doesn't need scheduler)
    setupAntiAFK()

    -- NoClip runs on Stepped (highest priority render step)
    local conn = RunService.Stepped:Connect(function()
        local ok, err = pcall(noClipTick)
        if not ok and Utils then
            Utils.log("ERROR", "NoClip error: " .. tostring(err))
        end
    end)
    table.insert(connections, conn)

    -- Store connections for cleanup
    state._connections = state._connections or {}
    for _, c in ipairs(connections) do
        table.insert(state._connections, c)
    end

    Utils.log("INFO", "AntiAFK + NoClip initialized")
end

return AntiAFK
