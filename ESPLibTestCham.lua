local ESP = {}
ESP.__index = ESP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Combined Settings
ESP.Settings = {
    Enabled = false,
    TeamCheck = false,
    Boxes = true,
    Names = true,
    HealthBars = true,
    Skeletons = true,
    HeadDots = true,
    
    UpdateInterval = 0,
    
    BoxColor = Color3.fromRGB(255, 255, 255),
    OutlineColor = Color3.fromRGB(10, 10, 10),
    TextColor = Color3.fromRGB(255, 255, 255),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    HeadDotColor = Color3.fromRGB(255, 255, 255),
    
    MaxFontSize = 14,
    MinFontSize = 10,

    Chams = false,
    Cham_Type = "Highlight",
    Occluded_Chams = false,
    Chams_Color_Visible = Color3.fromRGB(0, 255, 0),
    Chams_Color_Hidden = Color3.fromRGB(255, 0, 0),
    Glow_Enabled = true,
    ESP_Glow_Color = Color3.fromRGB(255, 255, 255),

    Highlight = {
        FillTransparency = 0.5,
        OutlineTransparency = 0
    },

    Adornment = {
        Transparency = 0.1,
        Glow_Layers = 4,
        Glow_Expansion = 0.04,
        Glow_Base_Transparency = 0.5,
        Glow_AlwaysOnTop = true
    }
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
local AdornmentCache = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function isCharacterVisible(targetCharacter)
    if not Camera or not LocalPlayer.Character then return false end
    local rootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}

    local origin = Camera.CFrame.Position
    local destination = rootPart.Position
    local direction = destination - origin

    local rayResult = Workspace:Raycast(origin, direction, raycastParams)
    return rayResult == nil
end

local function cleanupAdornmentCache(char)
    if AdornmentCache[char] then
        for _, box in ipairs(AdornmentCache[char].BaseBoxes) do
            box:Destroy()
        end
        for _, glowBox in ipairs(AdornmentCache[char].GlowBoxes) do
            glowBox:Destroy()
        end
        AdornmentCache[char] = nil
    end
end

local function destroyHighlight(char)
    local hl = char:FindFirstChild("ESPHighlight")
    if hl then
        hl:Destroy()
    end
end

local function destroyAllChams(char)
    if not char then return end
    cleanupAdornmentCache(char)
    destroyHighlight(char)
end

local function setupAdornmentCache(char)
    local glowShouldExist = ESP.Settings.Glow_Enabled
    if AdornmentCache[char] then
        local hasGlow = #AdornmentCache[char].GlowBoxes > 0
        if hasGlow == glowShouldExist then
            return AdornmentCache[char]
        else
            cleanupAdornmentCache(char)
        end
    end

    local cache = {
        BaseBoxes = {},
        GlowBoxes = {}
    }

    for _, b in ipairs(char:GetChildren()) do
        if b:IsA("BasePart") and b.Name ~= "HumanoidRootPart" and b.Transparency ~= 1 then
            local chamsBox = Instance.new("BoxHandleAdornment")
            chamsBox.Name = "Chams"
            chamsBox.ZIndex = 10
            chamsBox.Adornee = b
            chamsBox.Size = b.Size + Vector3.new(0.01, 0.01, 0.01)
            chamsBox.Parent = b
            table.insert(cache.BaseBoxes, chamsBox)

            if glowShouldExist then
                local maxLayers = math.min(ESP.Settings.Adornment.Glow_Layers, 2) 
                for i = 1, maxLayers do
                    local glowBox = Instance.new("BoxHandleAdornment")
                    glowBox.Name = "Glow_Layer_" .. i
                    glowBox.Adornee = b
                    glowBox.ZIndex = 10 - i
                    
                    local offset = ESP.Settings.Adornment.Glow_Expansion * i
                    glowBox.Size = b.Size + Vector3.new(offset, offset, offset)
                    
                    local alpha = (i - 1) / math.max(maxLayers, 1)
                    glowBox.Transparency = math.clamp(
                        ESP.Settings.Adornment.Glow_Base_Transparency + (alpha * (1 - ESP.Settings.Adornment.Glow_Base_Transparency)),
                        0, 1
                    )
                    glowBox.Parent = b
                    table.insert(cache.GlowBoxes, glowBox)
                end
            end
        end
    end

    AdornmentCache[char] = cache
    return cache
end

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

local chamsUpdateTick = {}

local function updateChams(targetPlayer, char)
    if not ESP.Settings.Chams then
        destroyAllChams(char)
        return
    end

    local now = tick()
    if chamsUpdateTick[targetPlayer] and (now - chamsUpdateTick[targetPlayer]) < 0.05 then
        return
    end
    chamsUpdateTick[targetPlayer] = now

    local visible = true
    if not ESP.Settings.Occluded_Chams then
        visible = isCharacterVisible(char)
    end

    if visible or ESP.Settings.Occluded_Chams then
        if ESP.Settings.Cham_Type == "Highlight" then
            cleanupAdornmentCache(char)

            local hl = char:FindFirstChild("ESPHighlight")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "ESPHighlight"
                hl.Adornee = char
                hl.Parent = char
            end

            hl.FillColor = visible and ESP.Settings.Chams_Color_Visible or ESP.Settings.Chams_Color_Hidden
            hl.FillTransparency = ESP.Settings.Highlight.FillTransparency
            hl.OutlineColor = ESP.Settings.ESP_Glow_Color
            hl.OutlineTransparency = ESP.Settings.Glow_Enabled and ESP.Settings.Highlight.OutlineTransparency or 1
            hl.DepthMode = ESP.Settings.Occluded_Chams and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded

        elseif ESP.Settings.Cham_Type == "Adornment" then
            destroyHighlight(char)

            local cache = setupAdornmentCache(char)
            local targetColor = visible and ESP.Settings.Chams_Color_Visible or ESP.Settings.Chams_Color_Hidden
            local alwaysOnTop = ESP.Settings.Occluded_Chams

            for _, box in ipairs(cache.BaseBoxes) do
                box.Color3 = targetColor
                box.AlwaysOnTop = alwaysOnTop
                box.Transparency = ESP.Settings.Adornment.Transparency
            end

            for _, glowBox in ipairs(cache.GlowBoxes) do
                glowBox.Color3 = ESP.Settings.ESP_Glow_Color
                glowBox.AlwaysOnTop = ESP.Settings.Adornment.Glow_AlwaysOnTop and alwaysOnTop
            end
        end
    else
        destroyAllChams(char)
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
        Skeleton = {},
        LastUpdate = 0
    }

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

    ActiveESP[targetPlayer] = objects
end

local function updatePlayerESP(targetPlayer, objects)
    local char = targetPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    local teamCheckPassed = not ESP.Settings.TeamCheck or (targetPlayer.Team ~= LocalPlayer.Team)
    local canRender = ESP.Settings.Enabled and teamCheckPassed and char and hrp and hum and hum.Health > 0

    if canRender then
        updateChams(targetPlayer, char)

        local now = tick()
        if ESP.Settings.UpdateInterval > 0 and (now - objects.LastUpdate) < ESP.Settings.UpdateInterval then
            return
        end
        objects.LastUpdate = now

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

            if ESP.Settings.Names then
                objects.Name.Position = Vector2.new(minX + ((maxX - minX) / 2), minY - fontScale - 2)
                objects.Name.Size = fontScale
                objects.Name.Text = targetPlayer.Name
                objects.Name.Color = ESP.Settings.TextColor
                objects.Name.Visible = true
            else
                objects.Name.Visible = false
            end

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

    hidePlayerESP(objects)
    if char then
        destroyAllChams(char)
    end
end

local function removePlayerESP(targetPlayer)
    if ActiveESP[targetPlayer] then
        local objects = ActiveESP[targetPlayer]
        
        hidePlayerESP(objects)
        
        for k, v in pairs(objects) do
            if type(v) == "table" then
                for _, line in ipairs(v) do 
                    line:Remove() 
                end
            elseif k ~= "LastUpdate" and type(v) == "userdata" and v.Remove then
                v:Remove()
            end
        end

        if targetPlayer.Character then
            destroyAllChams(targetPlayer.Character)
        end
        
        ActiveESP[targetPlayer] = nil
    end
end

function ESP:Unload()
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    table.clear(Connections)

    local targets = {}
    for plr in pairs(ActiveESP) do
        table.insert(targets, plr)
    end

    for _, plr in ipairs(targets) do
        removePlayerESP(plr)
    end
    
    table.clear(ActiveESP)
    table.clear(AdornmentCache)
end

function ESP:Init()
    ESP:Unload()

    for _, plr in ipairs(Players:GetPlayers()) do
        createPlayerESP(plr)
    end
    
    table.insert(Connections, Players.PlayerAdded:Connect(createPlayerESP))
    table.insert(Connections, Players.PlayerRemoving:Connect(removePlayerESP))

    local globalRenderConn = RunService.RenderStepped:Connect(function()
        if not ESP.Settings.Enabled then
            for _, objects in pairs(ActiveESP) do
                hidePlayerESP(objects)
            end
            return
        end

        for targetPlayer, objects in pairs(ActiveESP) do
            updatePlayerESP(targetPlayer, objects)
        end
    end)
    table.insert(Connections, globalRenderConn)
end

return ESP
