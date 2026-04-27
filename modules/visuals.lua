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
    if player.DisplayName ~= _state.spoofName and _state.spoofNameEnabled then
        player.DisplayName = _state.spoofName
        pcall(function() player.Name = _state.spoofName end)
        pcall(function() player.UserId = 1 end)
    end
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if _state.spoofNameEnabled then
                humanoid.DisplayName = _state.spoofName
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
                local gui = LP.PlayerGui:FindFirstChild("Main")
                if gui then
                    if gui:FindFirstChild("Cash") then gui.Cash.Text = "inf" end
                    local sec = gui:FindFirstChild("SecondaryCurrencies")
                    if sec then
                        if sec:FindFirstChild("Stars") and sec.Stars:FindFirstChild("Display") then sec.Stars.Display.Text = "inf" end
                        if sec:FindFirstChild("Honey") and sec.Honey:FindFirstChild("Display") then sec.Honey.Display.Text = "inf" end
                    end
                end
            end)
        end
        pcall(function()
            local plots = workspace:FindFirstChild("Plots")
            if plots then
                local plot = plots:FindFirstChild(LP.Name) or plots:FindFirstChild(LP.DisplayName)
                if plot then
                    local trans = (_state.hideUs and _state.hidePlot) and 1 or 0
                    for _, v in ipairs(plot:GetDescendants()) do
                        if v:IsA("BasePart") then v.LocalTransparencyModifier = trans end
                    end
                end
            end
        end)
        task.wait(0.5)
    end
end)
RunService.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do applyToPlayer(p) end
end)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        applyToPlayer(p)
    end)
end)
function Visuals.init(state) end
function Visuals.setHideUs(v)
    _state.hideUs = v
    if not v then
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c then
                local t = c:FindFirstChild("NexSync_Spoofed")
                if t then t:Destroy() end
            end
        end
    end
end
function Visuals.setConfig(k, v) _state[k] = v end
return Visuals
