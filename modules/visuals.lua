local Visuals = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local _state = {
    hideUs = false,
    avatarId = 1,
    spoofName = "sorry",
    spoofNameEnabled = false,
    spoofCurrencies = false,
    hidePlot = false
}
local function getBaconDesc(id)
    local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(id) end)
    return ok and desc or nil
end
local function applyToPlayer(player)
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if _state.spoofNameEnabled and _state.spoofName ~= "" then
                if humanoid.DisplayName ~= _state.spoofName then
                    humanoid.DisplayName = _state.spoofName
                end
            end
            if _state.hideUs then
                if not char:FindFirstChild("NexSync_Spoofed") then
                    local desc = getBaconDesc(_state.avatarId)
                    if desc then
                        pcall(function()
                            for _, v in ipairs(char:GetChildren()) do
                                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("CharacterMesh") or v:IsA("ShirtGraphic") then
                                    v:Destroy()
                                end
                            end
                            humanoid:ApplyDescription(desc)
                            local tag = Instance.new("BoolValue")
                            tag.Name = "NexSync_Spoofed"
                            tag.Parent = char
                        end)
                    end
                end
            end
        end
    end
end
task.spawn(function()
    while true do
        if _state.spoofCurrencies then
            pcall(function()
                local mainGui = LP.PlayerGui:FindFirstChild("Main")
                if mainGui then
                    if mainGui:FindFirstChild("Cash") then mainGui.Cash.Text = "inf" end
                    local secondary = mainGui:FindFirstChild("SecondaryCurrencies")
                    if secondary then
                        if secondary:FindFirstChild("Stars") and secondary.Stars:FindFirstChild("Display") then secondary.Stars.Display.Text = "inf" end
                        if secondary:FindFirstChild("Honey") and secondary.Honey:FindFirstChild("Display") then secondary.Honey.Display.Text = "inf" end
                    end
                end
            end)
        end
        pcall(function()
            local Plots = workspace:FindFirstChild("Plots")
            if Plots then
                local myPlot = Plots:FindFirstChild(LP.Name) or Plots:FindFirstChild(LP.DisplayName)
                if myPlot then
                    local targetTransparency = (_state.hideUs and _state.hidePlot) and 1 or 0
                    for _, part in ipairs(myPlot:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if part.LocalTransparencyModifier ~= targetTransparency then part.LocalTransparencyModifier = targetTransparency end
                        end
                    end
                end
            end
        end)
        if _state.spoofNameEnabled and _state.spoofName ~= "" then
            pcall(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.DisplayName ~= _state.spoofName then player.DisplayName = _state.spoofName end
                    pcall(function() if player.Name ~= _state.spoofName then player.Name = _state.spoofName end end)
                end
            end)
        end
        task.wait(0.5)
    end
end)
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(1)
        applyToPlayer(player)
    end)
end)
RunService.Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do applyToPlayer(player) end
end)
function Visuals.init(state) end
function Visuals.setHideUs(v)
    _state.hideUs = v
    if not v then
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char then
                local tag = char:FindFirstChild("NexSync_Spoofed")
                if tag then tag:Destroy() end
            end
        end
    end
end
function Visuals.setConfig(key, value) _state[key] = value end
return Visuals
