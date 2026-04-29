local ServerHop = {}
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local Utils = nil
local Cfg = nil
local _isHopping = false

local defaults = {
    autoHop = false,
    autoHopThreshold = 10,
    hopOnPing = false,
    maxPing = 300,
}

function ServerHop.getServers(sortType)
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then
        if Utils then Utils.log("ERROR", "ServerHop: Failed to fetch servers") end
        return {}
    end
    
    local data = HttpService:JSONDecode(response)
    if not data or not data.data then return {} end
    
    local servers = data.data
    
    if sortType == "lowest_players" then
        table.sort(servers, function(a, b)
            return a.playing < b.playing
        end)
    elseif sortType == "highest_players" then
        table.sort(servers, function(a, b)
            return a.playing > b.playing
        end)
    elseif sortType == "lowest_ping" then
        table.sort(servers, function(a, b)
            return a.ping < b.ping
        end)
    elseif sortType == "highest_ping" then
        table.sort(servers, function(a, b)
            return a.ping > b.ping
        end)
    end
    
    return servers
end

function ServerHop.hop(serverId)
    if _isHopping then return end
    _isHopping = true
    
    if Utils then Utils.log("INFO", "ServerHop: Hopping to " .. tostring(serverId)) end
    
    if serverId then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LP)
    else
        -- Just random hop if no ID provided
        local servers = ServerHop.getServers("lowest_players")
        for _, s in ipairs(servers) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                break
            end
        end
    end
    
    task.wait(5)
    _isHopping = false
end

function ServerHop.init(state)
    Utils = state.Utils
    Cfg = state.Config.ServerHop or {}
    for k, v in pairs(defaults) do
        if Cfg[k] == nil then Cfg[k] = v end
    end
    state.Config.ServerHop = Cfg
    
    task.spawn(function()
        while true do
            if Cfg.autoHop then
                if #Players:GetPlayers() > Cfg.autoHopThreshold then
                    if Utils then Utils.log("INFO", "ServerHop: Player threshold reached, hopping...") end
                    ServerHop.hop()
                end
            end
            
            if Cfg.hopOnPing then
                local currentPing = Utils.getPing()
                if currentPing > Cfg.maxPing and currentPing < 5000 then -- 5000 is likely a freeze
                    if Utils then Utils.log("INFO", "ServerHop: Ping threshold reached (" .. currentPing .. "ms), hopping...") end
                    ServerHop.hop()
                end
            end
            
            task.wait(10)
        end
    end)
end

return ServerHop
