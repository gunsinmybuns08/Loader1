local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Aimbot = {}
Aimbot.__index = Aimbot

-- Configuration Options
Aimbot.Config = {
    smooth = true,
    smoothTime = 0.15,
    keybind = Enum.KeyCode.E,
    
    triggerMode = "Hold",        -- "Hold" or "Toggle"
    aimMode = "Mouse",           -- "Mouse" or "Camera"
    
    targetSelectionMode = "FOV", -- "FOV" or "Distance"
    fovRadius = 200,             -- Radius in screen pixels
    maxDistance = 2000,          -- Maximum 3D world distance limit in studs
    
    showFOV = true,              
    fovColor = Color3.fromRGB(0, 255, 150),
    fovThickness = 1.5,
    fovFilled = false,
    fovTransparency = 0.7,

    sensitivity = 1,             
    
    teamCheck = false,
    checkTeamColor = false,
    targetNeutral = false,
    
    targetHitbox = "Head",
    enabled = true
}

Aimbot.Aiming = false
local renderConnection = nil
local inputBeganConnection = nil
local inputEndedConnection = nil
local fovCircle = nil

-- Safe character validation
local function isAliveAndValid(player)
    if not player or player == LocalPlayer or not player.Character then 
        return false 
    end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getTargetPart(player, partName)
    if player and player.Character then
        return player.Character:FindFirstChild(partName) or player.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getLocalRootPart()
    if LocalPlayer and LocalPlayer.Character then
        return LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Create FOV Drawing instance safely
local function createFOVCircle()
    if Drawing and not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Visible = false
        fovCircle.NumSides = 60
    end
end

-- Team check method
function Aimbot:IsEnemy(player)
    if not isAliveAndValid(player) then 
        return false 
    end

    if not self.Config.teamCheck then 
        return true 
    end

    if player.Team == nil or LocalPlayer.Team == nil then
        return self.Config.targetNeutral
    end

    if self.Config.checkTeamColor then
        return player.TeamColor ~= LocalPlayer.TeamColor
    end

    return player.Team ~= LocalPlayer.Team
end

-- Target selection algorithm parsing all active players directly
function Aimbot:getClosestPlr()
    local localRoot = getLocalRootPart()
    if not localRoot then return nil end

    local closestDistance = math.huge
    local closestPlayer = nil
    local mouseLocation = UserInputService:GetMouseLocation()
    local rootPosition = localRoot.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if self:IsEnemy(player) then
            local character = player.Character
            local targetPart = getTargetPart(character, self.Config.targetHitbox)

            if targetPart then
                local worldDistance = (rootPosition - targetPart.Position).Magnitude
                
                if worldDistance <= self.Config.maxDistance then
                    if self.Config.targetSelectionMode == "FOV" then
                        local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local screenDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - mouseLocation).Magnitude
                            if screenDistance <= self.Config.fovRadius and screenDistance < closestDistance then
                                closestDistance = screenDistance
                                closestPlayer = player
                            end
                        end
                    elseif self.Config.targetSelectionMode == "Distance" then
                        if worldDistance < closestDistance then
                            closestDistance = worldDistance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

-- Aiming implementation
function Aimbot:AimMouse(targetPart, deltaTime)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return end

    local mouseLocation = UserInputService:GetMouseLocation()
    local deltaX = (screenPoint.X - mouseLocation.X) * self.Config.sensitivity
    local deltaY = (screenPoint.Y - mouseLocation.Y) * self.Config.sensitivity

    if self.Config.smooth and self.Config.smoothTime > 0 then
        local alpha = math.clamp(1 - math.exp(-self.Config.smoothTime * 60 * deltaTime), 0.01, 1)
        deltaX = deltaX * alpha
        deltaY = deltaY * alpha
    end

    if mousemoverel then
        mousemoverel(deltaX, deltaY)
    end
end

function Aimbot:AimCamera(targetPart, deltaTime)
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)

    if self.Config.smooth and self.Config.smoothTime > 0 then
        local alpha = math.clamp(1 - math.exp(-self.Config.smoothTime * 60 * deltaTime), 0, 1)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, alpha)
    else
        Camera.CFrame = targetCFrame
    end
end

function Aimbot:Aim(target, deltaTime)
    if not target then return end

    local targetPart = getTargetPart(target, self.Config.targetHitbox)
    if not targetPart then return end

    if self.Config.aimMode == "Mouse" then
        self:AimMouse(targetPart, deltaTime)
    else
        self:AimCamera(targetPart, deltaTime)
    end
end

-- Update FOV position & properties
function Aimbot:UpdateFOV()
    if not fovCircle then return end

    if self.Config.enabled and self.Config.showFOV and self.Config.targetSelectionMode == "FOV" then
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = self.Config.fovRadius
        fovCircle.Thickness = self.Config.fovThickness
        fovCircle.Color = self.Config.fovColor
        fovCircle.Filled = self.Config.fovFilled
        fovCircle.Transparency = self.Config.fovTransparency
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end

function Aimbot:Toggle(state)
    if state ~= nil then
        self.Aiming = state
    else
        self.Aiming = not self.Aiming
    end
end

function Aimbot:Init()
    self:Destroy() 
    createFOVCircle()

    renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
        self:UpdateFOV()
        
        if self.Config.enabled and self.Aiming then
            local target = self:getClosestPlr()
            self:Aim(target, deltaTime)
        end
    end)

    inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.Config.enabled then return end

        if input.KeyCode == self.Config.keybind then
            if self.Config.triggerMode == "Hold" then
                self:Toggle(true)
            else
                self:Toggle()
            end
        end
    end)

    inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed or not self.Config.enabled then return end

        if input.KeyCode == self.Config.keybind then
            if self.Config.triggerMode == "Hold" then
                self:Toggle(false)
            end
        end
    end)
end

function Aimbot:Destroy()
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    if inputBeganConnection then inputBeganConnection:Disconnect() inputBeganConnection = nil end
    if inputEndedConnection then inputEndedConnection:Disconnect() inputEndedConnection = nil end
    
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
    
    self.Aiming = false
end

return Aimbot
