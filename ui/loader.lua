local Loader = {}
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
function Loader.show()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FarmV2Loader"
    sg.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 200)
    frame.Position = UDim2.new(0.5, -100, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(80, 200, 120)
    UIStroke.Thickness = 2
    UIStroke.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "FarmV2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 24
    title.Parent = frame
    local spinner = Instance.new("Frame")
    spinner.Size = UDim2.new(0, 64, 0, 64)
    spinner.Position = UDim2.new(0.5, -32, 0.5, -32)
    spinner.BackgroundTransparency = 1
    spinner.BorderSizePixel = 0
    spinner.Parent = frame

    local ring = Instance.new("Frame")
    ring.Size = UDim2.new(1, 0, 1, 0)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.Parent = spinner

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = ring

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Thickness = 3
    ringStroke.Color = Color3.fromRGB(80, 200, 120)
    ringStroke.Transparency = 0.2
    ringStroke.Parent = ring

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0.5, -5, 0, -2)
    dot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    dot.BorderSizePixel = 0
    dot.Parent = spinner

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local spinTween = TweenService:Create(spinner, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
    spinTween:Play()
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 1, -40)
    status.BackgroundTransparency = 1
    status.Text = "initializing..."
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Font = Enum.Font.SourceSans
    status.TextSize = 16
    status.Parent = frame
    return {
        update = function(perc, text)
            status.Text = text or status.Text
        end,
        finish = function()
            status.Text = "ready"
            task.wait(0.5)
            TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            TweenService:Create(UIStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
            TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            TweenService:Create(status, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            TweenService:Create(dot, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            TweenService:Create(ringStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
            task.wait(0.5)
            sg:Destroy()
        end
    }
end
return Loader
