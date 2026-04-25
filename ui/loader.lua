local Loader = {}
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

function Loader.show()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FarmV2Loader"
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = CoreGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.4
    bg.BorderSizePixel = 0
    bg.Parent = sg

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 220, 0, 220)
    card.Position = UDim2.new(0.5, -110, 0.5, -110)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    card.BorderSizePixel = 0
    card.Parent = sg

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 16)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(60, 60, 80)
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.5
    cardStroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "FarmV2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 22
    title.Parent = card

    local spinnerHolder = Instance.new("Frame")
    spinnerHolder.Size = UDim2.new(0, 70, 0, 70)
    spinnerHolder.Position = UDim2.new(0.5, -35, 0.5, -35)
    spinnerHolder.BackgroundTransparency = 1
    spinnerHolder.Parent = card

    local dotCount = 10
    local radius = 28
    local dots = {}
    for i = 0, dotCount - 1 do
        local angle = (i / dotCount) * math.pi * 2
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0.5, x - 3, 0.5, y - 3)
        dot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        dot.BackgroundTransparency = 0.8
        dot.BorderSizePixel = 0
        dot.Parent = spinnerHolder
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot
        dots[i] = dot
    end

    task.spawn(function()
        local step = 0
        while sg.Parent do
            for i = 0, dotCount - 1 do
                local offset = (i - step) % dotCount
                local alpha = 1 - (offset / dotCount)
                dots[i].BackgroundTransparency = 1 - (alpha * 0.85)
                dots[i].Size = UDim2.new(0, 4 + alpha * 4, 0, 4 + alpha * 4)
            end
            step = (step + 1) % dotCount
            task.wait(0.08)
        end
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 20)
    status.Position = UDim2.new(0, 0, 1, -40)
    status.BackgroundTransparency = 1
    status.Text = "starting up..."
    status.TextColor3 = Color3.fromRGB(140, 140, 160)
    status.Font = Enum.Font.SourceSans
    status.TextSize = 14
    status.Parent = card

    return {
        update = function(text)
            status.Text = text or status.Text
        end,
        finish = function()
            status.Text = "ready"
            task.wait(0.4)
            local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(bg, fadeInfo, {BackgroundTransparency = 1}):Play()
            TweenService:Create(card, fadeInfo, {BackgroundTransparency = 1}):Play()
            TweenService:Create(cardStroke, fadeInfo, {Transparency = 1}):Play()
            TweenService:Create(title, fadeInfo, {TextTransparency = 1}):Play()
            TweenService:Create(status, fadeInfo, {TextTransparency = 1}):Play()
            for _, dot in pairs(dots) do
                TweenService:Create(dot, fadeInfo, {BackgroundTransparency = 1}):Play()
            end
            task.wait(0.5)
            sg:Destroy()
        end
    }
end

return Loader
