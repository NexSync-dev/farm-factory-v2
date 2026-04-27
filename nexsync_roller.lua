local function load(urls)
    for _, u in ipairs(urls) do
        local ok, s = pcall(game.HttpGet, game, u)
        if ok then
            local c = loadstring(s)
            if c then return c() end
        end
    end
    error("bad load")
end
local Lib = load({ 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua' })
local Theme = load({ 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua' })
local Save = load({ 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua' })
local Run = game:GetService("RunService")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local list = {}
local fruitFolder = RS:WaitForChild("Storage", 5) and RS.Storage:WaitForChild("Fruit", 5)
if fruitFolder then
    for _, f in ipairs(fruitFolder:GetChildren()) do table.insert(list, f.Name) end
    table.sort(list)
end
local stats = { rolls = 0, matches = 0, last = "none" }
local cfg = {
    on = false,
    inst = false,
    burst = 5,
    speed = 0.05,
    buy = false,
    upLuck = false,
    upRolls = false,
    stop = true,
    targets = {},
    min = 0,
    web = false,
    url = "",
    afk = true
}
local _lock = false
local Comms = RS:WaitForChild("Communication", 10)
local Roll = Comms and Comms:WaitForChild("DoRoll", 5)
local Buy = Comms and Comms:WaitForChild("BuySeeds", 5)
local Up = Comms and Comms:WaitForChild("BuyUpgrade", 5)
local function getPlot()
    local p = workspace:FindFirstChild("Plots")
    return p and (p:FindFirstChild(LP.Name) or p:FindFirstChild(LP.DisplayName))
end
local function getIdx(name)
    local p = getPlot()
    if not p then return nil end
    local n = name:lower()
    for _, c in ipairs(p:GetChildren()) do
        if c.Name:find("Stump") then
            local t = c:FindFirstChild("Model") and c.Model:FindFirstChild("BuyableDisplay") and c.Model.BuyableDisplay:FindFirstChild("Title")
            if t and (t.Text:lower():find(n) or n:find(t.Text:lower())) then
                return tonumber(c.Name:match("%d+")) or 1
            end
        end
    end
end
local function sendWeb(name, cash)
    if not cfg.web or cfg.url == "" then return end
    local data = { embeds = {{ title = "found!", fields = {{ name = "item", value = name }, { name = "cash", value = tostring(cash) }} }} }
    pcall(function()
        local r = (syn and syn.request) or request
        r({ Url = cfg.url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = Http:JSONEncode(data) })
    end)
end
local function handle(res)
    if not res then return end
    local items = res[1] and res or {res}
    for _, it in ipairs(items) do
        local n = it.Type or it.Title or "???"
        local e = tonumber(it.Earnings) or 0
        if (cfg.targets[n] or next(cfg.targets) == nil) and e >= cfg.min then
            stats.matches = stats.matches + 1
            stats.last = n
            if cfg.web then sendWeb(n, e) end
            if cfg.buy then
                _lock = true
                local idx = getIdx(n) or it.Index or 0
                if Buy then pcall(function() Buy:FireServer(idx) end) end
                task.wait(0.2)
                _lock = false
            end
            if cfg.stop then cfg.on = false return true end
        end
    end
end
local function roll()
    if not Roll then return end
    local ok, res = pcall(function() return Roll:InvokeServer() end)
    if ok and res then stats.rolls = stats.rolls + 1 return handle(res) end
end
task.spawn(function()
    while true do
        if not cfg.on or _lock then task.wait(0.1) continue end
        local b = cfg.inst and cfg.burst or 1
        for i = 1, b do if roll() then break end end
        if cfg.inst then Run.Heartbeat:Wait() else task.wait(cfg.speed) end
    end
end)
local Win = Lib:CreateWindow({ Title = 'Roller', Center = true, AutoShow = true })
local Tabs = {
    Main = Win:AddTab('roll'),
    Config = Win:AddTab('ui'),
}
local Box = Tabs.Main:AddLeftGroupbox('engine')
Box:AddToggle('on', { Text = 'on/off', Default = false, Callback = function(v) cfg.on = v end })
Box:AddToggle('inst', { Text = 'instant', Default = false, Callback = function(v) cfg.inst = v end })
Box:AddSlider('burst', { Text = 'burst', Default = 5, Min = 1, Max = 50, Rounding = 0, Callback = function(v) cfg.burst = v end })
local M = Tabs.Main:AddRightGroupbox('settings')
M:AddDropdown('t', { Values = list, Multi = true, Text = 'targets', AllowNull = true, Callback = function(v) cfg.targets = v end })
M:AddToggle('buy', { Text = 'auto buy', Default = false, Callback = function(v) cfg.buy = v end })
M:AddToggle('stop', { Text = 'stop on match', Default = true, Callback = function(v) cfg.stop = v end })
M:AddInput('min', { Text = 'min cash', Default = '0', Numeric = true, Callback = function(v) cfg.min = tonumber(v) or 0 end })
local S = Tabs.Main:AddLeftGroupbox('stats')
local L1 = S:AddLabel('rolls: 0')
local L2 = S:AddLabel('matches: 0')
task.spawn(function()
    while true do
        L1:SetText('rolls: ' .. stats.rolls)
        L2:SetText('matches: ' .. stats.matches)
        task.wait(0.5)
    end
end)
local U = Tabs.Config:AddLeftGroupbox("menu")
U:AddLabel("toggle"):AddKeyPicker("k", { Default = "RightShift", NoUI = true, Text = "toggle", Callback = function() Lib:Toggle() end })
Lib.ToggleKeybind = Options.k
Theme:SetLibrary(Lib)
Save:SetLibrary(Lib)
Theme:ApplyToTab(Tabs.Config)
Save:BuildConfigSection(Tabs.Config)
Save:LoadAutoloadConfig()
Lib:Notify("loaded")
