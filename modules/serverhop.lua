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
}

function ServerHop.rejoin()
    if _isHopping then return end
    _isHopping = true
    if Utils then Utils.log("INFO", "ServerHop: Rejoining...") end
    TeleportService:Teleport(game.PlaceId, LP)
    task.wait(5)
    _isHopping = false
end

function ServerHop.getServers(sortType)
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then return {} end
    local data = HttpService:JSONDecode(response)
    if not data or not data.data then return {} end
    
    local servers = data.data
    
    if sortType == "lowest_players" then
        table.sort(servers, function(a, b) return a.playing < b.playing end)
    elseif sortType == "highest_players" then
        table.sort(servers, function(a, b) return a.playing > b.playing end)
    end
    
    local candidates = {}
    for _, s in ipairs(servers) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            table.insert(candidates, s)
        end
    end
    
    return candidates
end

function ServerHop.hop(serverId)
    if _isHopping then return end
    _isHopping = true
    
    if serverId then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LP)
    else
        local servers = ServerHop.getServers("lowest_players")
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, LP)
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
            if Cfg.autoHop and #Players:GetPlayers() > Cfg.autoHopThreshold then
                ServerHop.hop()
            end
            task.wait(10)
        end
    end)
end

return ServerHop
