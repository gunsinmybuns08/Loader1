local ESP = {}
ESP.__index = ESP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Default Settings
ESP.Settings = {
    Enabled = true,
    Boxes = true,
    Names = true,
    HealthBars = true,
    Skeletons = true,
    HeadDots = true,
    
    BoxColor = Color3.fromRGB(255, 255, 255),
    OutlineColor = Color3.fromRGB(10, 10, 10),
    TextColor = Color3.fromRGB(255, 255, 255),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    HeadDotColor = Color3.fromRGB(255, 255, 255),
    
    MaxFontSize = 14,
    MinFontSize = 10
}

local R6Connections = {
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local R15Connections = {
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local ActiveESP = {}
local Connections = {}

local function hidePlayerESP(objects)
    if not objects then return end
    
    objects.Name.Visible = false
    objects.Top.Visible = false
    objects.Left.Visible = false
    objects.Right.Visible = false
    objects.Bottom.Visible = false
    objects.TopOutline.Visible = false
    objects.LeftOutline.Visible = false
    objects.RightOutline.Visible = false
    objects.BottomOutline.Visible = false
    objects.HealthBg.Visible = false
    objects.HealthFill.Visible = false
    objects.HeadDot.Visible = false
    objects.HeadLine.Visible = false
    
    if objects.Skeleton then
        for _, line in ipairs(objects.Skeleton) do
            line.Visible = false
        end
    end
end

local function createPlayerESP(targetPlayer)
    if targetPlayer == LocalPlayer or ActiveESP[targetPlayer] then return end

    local objects = {
        Name = Drawing.new("Text"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        TopOutline = Drawing.new("Line"),
        BottomOutline = Drawing.new("Line"),
        LeftOutline = Drawing.new("Line"),
        RightOutline = Drawing.new("Line"),
        HealthBg = Drawing.new("Line"),
        HealthFill = Drawing.new("Line"),
        HeadDot = Drawing.new("Circle"),
        HeadLine = Drawing.new("Line"),
        Skeleton = {}
    }

    -- Set default properties
    objects.Name.Center = true
    objects.Name.Outline = true
    objects.Name.ZIndex = 2

    local linesToSetup = {
        {objects.Top, 1, 2}, {objects.Bottom, 1, 2}, {objects.Left, 1, 2}, {objects.Right, 1, 2},
        {objects.TopOutline, 2, 1}, {objects.BottomOutline, 2, 1}, {objects.LeftOutline, 2, 1}, {objects.RightOutline, 2, 1},
        {objects.HealthBg, 3, 1}, {objects.HealthFill, 1, 2}, {objects.HeadLine, 1, 2}
    }

    for _, item in ipairs(linesToSetup) do
        item[1].Thickness = item[2]
        item[1].ZIndex = item[3]
        item[1].Transparency = 1
        item[1].Visible = false
    end

    objects.HealthBg.Color = Color3.fromRGB(10, 10, 10)

    objects.HeadDot.Thickness = 1
    objects.HeadDot.NumSides = 18
    objects.HeadDot.Filled = true
    objects.HeadDot.Transparency = 1
    objects.HeadDot.ZIndex = 3

    for i = 1, 15 do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Transparency = 1
        line.ZIndex = 2
        line.Visible = false
        table.insert(objects.Skeleton, line)
    end

    local renderConn
    renderConn = RunService.RenderStepped:Connect(function()
        local char = targetPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        local canRender = ESP.Settings.Enabled and char and hrp and hum and hum.Health > 0
        if canRender then
            local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local scale = (char:FindFirstChild("Head") and char.Head.Size.Y / 2) or 1
                local size = Vector3.new(2, 3, 0) * (scale * 2)
                local boxCFrame = CFrame.new(hrp.Position, Camera.CFrame.Position)

                local TL = Camera:WorldToViewportPoint((boxCFrame * CFrame.new(-size.X, size.Y, 0)).Position)
                local TR = Camera:WorldToViewportPoint((boxCFrame * CFrame.new(size.X, size.Y, 0)).Position)
                local BL = Camera:WorldToViewportPoint((boxCFrame * CFrame.new(-size.X, -size.Y, 0)).Position)
                local BR = Camera:WorldToViewportPoint((boxCFrame * CFrame.new(size.X, -size.Y, 0)).Position)

                local minX = math.min(TL.X, TR.X, BL.X, BR.X)
                local maxX = math.max(TL.X, TR.X, BL.X, BR.X)
                local minY = math.min(TL.Y, TR.Y, BL.Y, BR.Y)
                local maxY = math.max(TL.Y, TR.Y, BL.Y, BR.Y)

                local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
                local fontScale = math.clamp(1000 / distance, ESP.Settings.MinFontSize, ESP.Settings.MaxFontSize)

                -- Name
                if ESP.Settings.Names then
                    objects.Name.Position = Vector2.new(minX + ((maxX - minX) / 2), minY - fontScale - 2)
                    objects.Name.Size = fontScale
                    objects.Name.Text = targetPlayer.Name
                    objects.Name.Color = ESP.Settings.TextColor
                    objects.Name.Visible = true
                else
                    objects.Name.Visible = false
                end

                -- Boxes
                if ESP.Settings.Boxes then
                    local topLeft = Vector2.new(minX, minY)
                    local topRight = Vector2.new(maxX, minY)
                    local bottomLeft = Vector2.new(minX, maxY)
                    local bottomRight = Vector2.new(maxX, maxY)

                    objects.Top.From, objects.Top.To = topLeft, topRight
                    objects.Left.From, objects.Left.To = topLeft, bottomLeft
                    objects.Right.From, objects.Right.To = topRight, bottomRight
                    objects.Bottom.From, objects.Bottom.To = bottomLeft, bottomRight

                    objects.TopOutline.From, objects.TopOutline.To = topLeft, topRight
                    objects.LeftOutline.From, objects.LeftOutline.To = topLeft, bottomLeft
                    objects.RightOutline.From, objects.RightOutline.To = topRight, bottomRight
                    objects.BottomOutline.From, objects.BottomOutline.To = bottomLeft, bottomRight

                    objects.Top.Color = ESP.Settings.BoxColor
                    objects.Left.Color = ESP.Settings.BoxColor
                    objects.Right.Color = ESP.Settings.BoxColor
                    objects.Bottom.Color = ESP.Settings.BoxColor

                    objects.TopOutline.Color = ESP.Settings.OutlineColor
                    objects.LeftOutline.Color = ESP.Settings.OutlineColor
                    objects.RightOutline.Color = ESP.Settings.OutlineColor
                    objects.BottomOutline.Color = ESP.Settings.OutlineColor

                    objects.Top.Visible = true
                    objects.Left.Visible = true
                    objects.Right.Visible = true
                    objects.Bottom.Visible = true
                    objects.TopOutline.Visible = true
                    objects.LeftOutline.Visible = true
                    objects.RightOutline.Visible = true
                    objects.BottomOutline.Visible = true
                else
                    objects.Top.Visible = false
                    objects.Left.Visible = false
                    objects.Right.Visible = false
                    objects.Bottom.Visible = false
                    objects.TopOutline.Visible = false
                    objects.LeftOutline.Visible = false
                    objects.RightOutline.Visible = false
                    objects.BottomOutline.Visible = false
                end

                -- Health Bar
                if ESP.Settings.HealthBars then
                    local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barX = minX - 5
                    local barHeight = maxY - minY
                    local healthHeight = barHeight * healthPercent

                    objects.HealthBg.From = Vector2.new(barX, minY)
                    objects.HealthBg.To = Vector2.new(barX, maxY)
                    objects.HealthBg.Visible = true

                    objects.HealthFill.From = Vector2.new(barX, maxY)
                    objects.HealthFill.To = Vector2.new(barX, maxY - healthHeight)
                    objects.HealthFill.Color = Color3.fromRGB(255 - (healthPercent * 255), healthPercent * 255, 0)
                    objects.HealthFill.Visible = true
                else
                    objects.HealthBg.Visible = false
                    objects.HealthFill.Visible = false
                end

                -- Skeleton
                if ESP.Settings.Skeletons then
                    local connections = (hum.RigType == Enum.HumanoidRigType.R15) and R15Connections or R6Connections
                    for i, pair in ipairs(connections) do
                        local partA, partB = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                        local line = objects.Skeleton[i]

                        if partA and partB and line then
                            local posA, visA = Camera:WorldToViewportPoint(partA.Position)
                            local posB, visB = Camera:WorldToViewportPoint(partB.Position)
                            if visA and visB then
                                line.From = Vector2.new(posA.X, posA.Y)
                                line.To = Vector2.new(posB.X, posB.Y)
                                line.Color = ESP.Settings.SkeletonColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        elseif line then
                            line.Visible = false
                        end
                    end
                    for i = #connections + 1, #objects.Skeleton do
                        objects.Skeleton[i].Visible = false
                    end
                else
                    for _, line in ipairs(objects.Skeleton) do
                        line.Visible = false
                    end
                end

                -- Head Dot and Neck/Torso Line
                if ESP.Settings.HeadDots then
                    local headPart = char:FindFirstChild("Head")
                    local torsoPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")

                    if headPart then
                        local headPos, headVis = Camera:WorldToViewportPoint(headPart.Position)
                        local topHeadPos = Camera:WorldToViewportPoint(headPart.Position + Vector3.new(0, headPart.Size.Y / 2, 0))
                        
                        if headVis then
                            objects.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
                            objects.HeadDot.Radius = math.max(math.abs(headPos.Y - topHeadPos.Y), 2)
                            objects.HeadDot.Color = ESP.Settings.HeadDotColor
                            objects.HeadDot.Visible = true

                            -- Line from head dot to torso/skeleton
                            if torsoPart then
                                local torsoPos, torsoVis = Camera:WorldToViewportPoint(torsoPart.Position)
                                if torsoVis then
                                    objects.HeadLine.From = Vector2.new(headPos.X, headPos.Y)
                                    objects.HeadLine.To = Vector2.new(torsoPos.X, torsoPos.Y)
                                    objects.HeadLine.Color = ESP.Settings.HeadDotColor
                                    objects.HeadLine.Visible = true
                                else
                                    objects.HeadLine.Visible = false
                                end
                            else
                                objects.HeadLine.Visible = false
                            end
                        else
                            objects.HeadDot.Visible = false
                            objects.HeadLine.Visible = false
                        end
                    else
                        objects.HeadDot.Visible = false
                        objects.HeadLine.Visible = false
                    end
                else
                    objects.HeadDot.Visible = false
                    objects.HeadLine.Visible = false
                end
                return
            end
        end

        -- Explicitly hide all elements on off-screen/dead/disabled
        hidePlayerESP(objects)
    end)

    ActiveESP[targetPlayer] = {
        Objects = objects,
        Connection = renderConn
    }
end

local function removePlayerESP(targetPlayer)
    if ActiveESP[targetPlayer] then
        local entry = ActiveESP[targetPlayer]
        
        -- Disconnect render loop
        if entry.Connection then 
            entry.Connection:Disconnect() 
            entry.Connection = nil
        end
        
        -- Hide first, then remove drawing instances
        if entry.Objects then
            hidePlayerESP(entry.Objects)
            
            for _, v in pairs(entry.Objects) do
                if type(v) == "table" then
                    for _, line in ipairs(v) do 
                        line:Remove() 
                    end
                else
                    v:Remove()
                end
            end
        end
        
        ActiveESP[targetPlayer] = nil
    end
end

-- Library Methods
function ESP:Unload()
    -- Disconnect global player listeners
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    table.clear(Connections)

    -- Collect keys safely to prevent issues during table iteration
    local targets = {}
    for plr in pairs(ActiveESP) do
        table.insert(targets, plr)
    end

    -- Clean up drawing objects per player
    for _, plr in ipairs(targets) do
        removePlayerESP(plr)
    end
    
    table.clear(ActiveESP)
end

function ESP:Init()
    ESP:Unload()

    for _, plr in ipairs(Players:GetPlayers()) do
        createPlayerESP(plr)
    end
    
    table.insert(Connections, Players.PlayerAdded:Connect(createPlayerESP))
    table.insert(Connections, Players.PlayerRemoving:Connect(removePlayerESP))
end

return ESP
