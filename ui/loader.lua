local Loader = {}
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
function Loader.show()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FarmV2Loader"
    sg.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0.5, -50)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "FarmV2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 0.4, 0)
    status.BackgroundTransparency = 1
    status.Text = "initializing modules..."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.Parent = frame
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(0.8, 0, 0, 6)
    barBg.Position = UDim2.new(0.1, 0, 0.75, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBg
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    bar.BorderSizePixel = 0
    bar.Parent = barBg
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = bar
    local function update(perc, text)
        status.Text = text or status.Text
        TweenService:Create(bar, TweenInfo.new(0.3), {Size = UDim2.new(perc, 0, 1, 0)}):Play()
    end
    return {
        update = update,
        finish = function()
            update(1, "ready")
            task.wait(0.5)
            TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            TweenService:Create(status, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            TweenService:Create(barBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            TweenService:Create(bar, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            task.wait(0.5)
            sg:Destroy()
        end
    }
end
return Loader
