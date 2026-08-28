local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Library = {}
Library.__index = Library
Library.ActiveColorPicker = nil -- Tracks the single open picker

function Library.new(titleText)
    local self = setmetatable({}, Library)
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = titleText or "UILibrary"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    self.Main = Instance.new("Frame")
    self.Main.Name = "Main"
    self.Main.Parent = self.ScreenGui
    self.Main.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    self.Main.BorderSizePixel = 0
    self.Main.Position = UDim2.new(0.399, 0, 0.328, 0)
    self.Main.Size = UDim2.new(0, 400, 0, 400)
    self.Main.Active = true

    self.shadow = Instance.new("UIShadow")
    self.shadow.BlurRadius = UDim.new(0, 16)
    self.shadow.Color = Color3.fromRGB(0, 0, 0)
    self.shadow.Transparency = 0.5
    self.shadow.Offset = UDim2.new(0, 0, 0, 0)
    self.shadow.Spread = UDim2.new(0, 0, 0, 0)
    self.shadow.Parent = self.Main

    local UICornerMain = Instance.new("UICorner")
    UICornerMain.CornerRadius = UDim.new(0, 4)
    UICornerMain.Parent = self.Main
    UICornerMain.TopLeftRadius = UDim.new(0,0)

    -- Native Roblox Hit Test Check
    local function isClickOnInteractiveElement(inputPosition)
        local objects = game.Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(inputPosition.X, inputPosition.Y)
        for _, guiObj in ipairs(objects) do
            if guiObj ~= self.Main and guiObj:IsDescendantOf(self.Main) then
                if guiObj:IsA("TextButton") or guiObj:IsA("ImageButton") or guiObj:IsA("TextBox") or guiObj.Name:lower():find("picker") or guiObj.Name:lower():find("slider") or guiObj.Name:lower():find("canvas") then
                    return true
                end
            end
        end
        return false
    end

    -- Smooth Dragging System
    local dragging, dragStart, startPos
    self.Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isClickOnInteractiveElement(input.Position) then 
                return 
            end

            dragging = true
            dragStart = input.Position
            startPos = self.Main.Position
        end
    end)
    
    self.Main.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Keybind Toggle (RightControl)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
            self.Main.Visible = not self.Main.Visible
        end
    end)

    self.TabHolder = Instance.new("Frame")
    self.TabHolder.Name = "TabHolder"
    self.TabHolder.Parent = self.Main
    self.TabHolder.BackgroundTransparency = 1
    self.TabHolder.Position = UDim2.new(0, 0, -0.0375, 0)
    self.TabHolder.Size = UDim2.new(0, 400, 0, 15)

    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.Parent = self.TabHolder
    TabListLayout.FillDirection = Enum.FillDirection.Horizontal
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    self.ContentContainer = Instance.new("Frame")
    self.ContentContainer.Name = "ContentContainer"
    self.ContentContainer.Parent = self.Main
    self.ContentContainer.BackgroundTransparency = 1
    self.ContentContainer.Size = UDim2.new(0, 400, 0, 400)

    self.Tabs = {}
    self.ActiveTab = nil

    return self
end

function Library:CreateTab(name)
    local TabModule = {}
    
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = name .. "Tab"
    tabBtn.Parent = self.TabHolder
    tabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    tabBtn.Size = UDim2.new(0, 87, 0, 15)
    tabBtn.Font = Enum.Font.Gotham
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabBtn.TextSize = 12
    tabBtn.AutoButtonColor = false

    local tabCorner = Instance.new("UICorner")
    tabCorner.Parent = tabBtn
    tabCorner.BottomLeftRadius = UDim.new(0, 0)
    tabCorner.BottomRightRadius = UDim.new(0, 0)

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Parent = self.ContentContainer
    page.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    page.Position = UDim2.new(0.0175, 0, 0.0175, 0)
    page.Size = UDim2.new(0, 385, 0, 385)
    page.Visible = false
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Color3.fromRGB(255, 92, 92)

    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, 4)
    pageCorner.Parent = page

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Parent = page
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 5)

    local pagePadding = Instance.new("UIPadding")
    pagePadding.Parent = page
    pagePadding.PaddingLeft = UDim.new(0, 15)
    pagePadding.PaddingTop = UDim.new(0, 5)

    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 10)
    end)

    local function selectTab()
        for _, t in pairs(self.Tabs) do
            t.Page.Visible = false
            TweenService:Create(t.Button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            }):Play()
        end
        page.Visible = true
        TweenService:Create(tabBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        }):Play()
        self.ActiveTab = TabModule
    end

    tabBtn.MouseButton1Click:Connect(selectTab)
    
    if #self.Tabs == 0 then
        selectTab()
    end

    TabModule.Button = tabBtn
    TabModule.Page = page

    function TabModule:AddToggle(label, default, callback)
        callback = callback or function() end
        local toggled = default or false

        local toggleFrame = Instance.new("Frame")
        toggleFrame.Name = label .. "Toggle"
        toggleFrame.Parent = page
        toggleFrame.BackgroundTransparency = 1
        toggleFrame.Size = UDim2.new(0, 370, 0, 25)

        local title = Instance.new("TextLabel")
        title.Parent = toggleFrame
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 101, 0, 25)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local pressBtn = Instance.new("TextButton")
        pressBtn.Parent = toggleFrame
        pressBtn.BackgroundColor3 = toggled and Color3.fromRGB(255, 92, 92) or Color3.fromRGB(20, 20, 20)
        pressBtn.BorderColor3 = Color3.fromRGB(45, 45, 45)
        pressBtn.Position = UDim2.new(0.271, 0, 0.2, 0)
        pressBtn.Size = UDim2.new(0, 15, 0, 15)
        pressBtn.Text = ""
        pressBtn.AutoButtonColor = false

        pressBtn.MouseButton1Click:Connect(function()
            toggled = not toggled
            TweenService:Create(pressBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = toggled and Color3.fromRGB(255, 92, 92) or Color3.fromRGB(20, 20, 20)
            }):Play()
            callback(toggled)
        end)
    end

    function TabModule:AddSlider(label, options, callback)
        options = options or {}
        local min = options.Min or 0
        local max = options.Max or 100
        local default = options.Default or min
        local suffix = options.Suffix or ""
        callback = callback or function() end

        local sliderFrame = Instance.new("Frame")
        sliderFrame.Name = label .. "Slider"
        sliderFrame.Parent = page
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Size = UDim2.new(0, 370, 0, 25)

        local title = Instance.new("TextLabel")
        title.Parent = sliderFrame
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 101, 0, 25)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local sliderHolder = Instance.new("Frame")
        sliderHolder.Name = "SliderHolder"
        sliderHolder.Parent = sliderFrame
        sliderHolder.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        sliderHolder.BorderSizePixel = 0
        sliderHolder.Position = UDim2.new(0.271, 0, 0.2, 0)
        sliderHolder.Size = UDim2.new(0, 180, 0, 15)

        local slideGrab = Instance.new("TextButton")
        slideGrab.Name = "SlideGrab"
        slideGrab.Parent = sliderHolder
        slideGrab.BackgroundColor3 = Color3.fromRGB(255, 92, 92)
        slideGrab.BorderSizePixel = 0
        slideGrab.Size = UDim2.new(0, 20, 0, 15)
        slideGrab.Text = ""
        slideGrab.AutoButtonColor = false

        local valDisplay = Instance.new("TextLabel")
        valDisplay.Parent = slideGrab
        valDisplay.BackgroundTransparency = 1
        valDisplay.Position = UDim2.new(-0.75, 0, -1.333, 0)
        valDisplay.Size = UDim2.new(0, 50, 0, 15)
        valDisplay.Font = Enum.Font.Gotham
        valDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        valDisplay.TextSize = 12
        valDisplay.TextTransparency = 1

        local draggingSlider = false
        local function update(input)
            local pos = math.clamp((input.Position.X - sliderHolder.AbsolutePosition.X) / sliderHolder.AbsoluteSize.X, 0, 1)
            slideGrab.Position = UDim2.new(pos - (slideGrab.AbsoluteSize.X / sliderHolder.AbsoluteSize.X * pos), 0, 0, 0)
            local value = math.floor(min + (max - min) * pos)
            valDisplay.Text = tostring(value) .. suffix
            callback(value)
        end

        local initPos = math.clamp((default - min) / (max - min), 0, 1)
        slideGrab.Position = UDim2.new(initPos - (20 / 180 * initPos), 0, 0, 0)
        valDisplay.Text = tostring(default) .. suffix

        slideGrab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSlider = true
                TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSlider = false
                TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
    end

    function TabModule:AddButton(label, callback)
        callback = callback or function() end

        local btnFrame = Instance.new("Frame")
        btnFrame.Name = label .. "ButtonFrame"
        btnFrame.Parent = page
        btnFrame.BackgroundTransparency = 1
        btnFrame.Size = UDim2.new(0, 370, 0, 25)

        local title = Instance.new("TextLabel")
        title.Parent = btnFrame
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 101, 0, 25)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local actionBtn = Instance.new("TextButton")
        actionBtn.Parent = btnFrame
        actionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        actionBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
        actionBtn.Position = UDim2.new(0.271, 0, 0.08, 0)
        actionBtn.Size = UDim2.new(0, 180, 0, 20)
        actionBtn.Font = Enum.Font.Gotham
        actionBtn.Text = label
        actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        actionBtn.TextSize = 12
        actionBtn.AutoButtonColor = false

        actionBtn.MouseButton1Click:Connect(function() 
            TweenService:Create(actionBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 92, 92)}):Play()
            task.wait(0.15)
            TweenService:Create(actionBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play()
            callback()
        end)
    end

    function TabModule:AddDropdown(label, options, callback)
        options = options or {}
        callback = callback or function() end
        local open = false

        local dropFrame = Instance.new("Frame")
        dropFrame.Name = label .. "Dropdown"
        dropFrame.Parent = page
        dropFrame.BackgroundTransparency = 1
        dropFrame.Size = UDim2.new(0, 370, 0, 25)
        dropFrame.ZIndex = 3

        local title = Instance.new("TextLabel")
        title.Parent = dropFrame
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 101, 0, 25)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local displayBtn = Instance.new("TextButton")
        displayBtn.Parent = dropFrame
        displayBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        displayBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
        displayBtn.Position = UDim2.new(0.271, 0, 0.08, 0)
        displayBtn.Size = UDim2.new(0, 180, 0, 20)
        displayBtn.Font = Enum.Font.Gotham
        displayBtn.Text = (options[1] or "Select...") .. " +"
        displayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        displayBtn.TextSize = 12
        displayBtn.AutoButtonColor = false

        local dropContent = Instance.new("Frame")
        dropContent.Name = "DropContent"
        dropContent.Parent = dropFrame
        dropContent.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        dropContent.BorderColor3 = Color3.fromRGB(255, 92, 92)
        dropContent.Position = UDim2.new(0.271, 0, 0.88, 0)
        dropContent.Size = UDim2.new(0, 180, 0, 0)
        dropContent.Visible = false
        dropContent.ZIndex = 4

        local dropLayout = Instance.new("UIListLayout")
        dropLayout.Parent = dropContent
        dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

        dropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dropContent.Size = UDim2.new(0, 180, 0, dropLayout.AbsoluteContentSize.Y)
        end)

        local optionBtns = {}
        local function toggleDrop()
            open = not open
            dropContent.Visible = open
            local currentVal = displayBtn.Text:gsub(" %-", ""):gsub(" %+", "")
            displayBtn.Text = currentVal .. (open and " -" or " +")
        end

        displayBtn.MouseButton1Click:Connect(toggleDrop)

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Parent = dropContent
            optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            optBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
            optBtn.Size = UDim2.new(0, 180, 0, 20)
            optBtn.Font = Enum.Font.Gotham
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            optBtn.TextSize = 12
            optBtn.AutoButtonColor = false
            optBtn.ZIndex = 5

            table.insert(optionBtns, optBtn)

            optBtn.MouseButton1Click:Connect(function()
                for _, b in ipairs(optionBtns) do
                    b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                end
                optBtn.BackgroundColor3 = Color3.fromRGB(255, 92, 92)
                displayBtn.Text = opt .. " +"
                dropContent.Visible = false
                open = false
                callback(opt)
            end)
        end
    end

    function TabModule:AddMultiDropdown(label, options, callback)
        options = options or {}
        callback = callback or function() end
        local open = false
        local selectedMap = {}

        local dropFrame = Instance.new("Frame")
        dropFrame.Name = label .. "MultiDropdown"
        dropFrame.Parent = page
        dropFrame.BackgroundTransparency = 1
        dropFrame.Size = UDim2.new(0, 370, 0, 25)
        dropFrame.ZIndex = 3

        local title = Instance.new("TextLabel")
        title.Parent = dropFrame
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 101, 0, 25)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local displayBtn = Instance.new("TextButton")
        displayBtn.Parent = dropFrame
        displayBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        displayBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
        displayBtn.Position = UDim2.new(0.271, 0, 0.08, 0)
        displayBtn.Size = UDim2.new(0, 180, 0, 20)
        displayBtn.Font = Enum.Font.Gotham
        displayBtn.Text = "None selected +"
        displayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        displayBtn.TextSize = 12
        displayBtn.AutoButtonColor = false

        local dropContent = Instance.new("Frame")
        dropContent.Name = "MultiDropContent"
        dropContent.Parent = dropFrame
        dropContent.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        dropContent.BorderColor3 = Color3.fromRGB(255, 92, 92)
        dropContent.Position = UDim2.new(0.271, 0, 0.88, 0)
        dropContent.Size = UDim2.new(0, 180, 0, 0)
        dropContent.Visible = false
        dropContent.ZIndex = 4

        local dropLayout = Instance.new("UIListLayout")
        dropLayout.Parent = dropContent
        dropLayout.SortOrder = Enum.SortOrder.LayoutOrder

        dropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dropContent.Size = UDim2.new(0, 180, 0, dropLayout.AbsoluteContentSize.Y)
        end)

        local function updateDisplayText()
            local selectedList = {}
            for opt, active in pairs(selectedMap) do
                if active then
                    table.insert(selectedList, opt)
                end
            end
            local textStr = #selectedList > 0 and table.concat(selectedList, ", ") or "None selected"
            displayBtn.Text = textStr .. (open and " -" or " +")
            callback(selectedList)
        end

        displayBtn.MouseButton1Click:Connect(function()
            open = not open
            dropContent.Visible = open
            updateDisplayText()
        end)

        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Parent = dropContent
            optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            optBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
            optBtn.Size = UDim2.new(0, 180, 0, 20)
            optBtn.Font = Enum.Font.Gotham
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            optBtn.TextSize = 12
            optBtn.AutoButtonColor = false
            optBtn.ZIndex = 5

            optBtn.MouseButton1Click:Connect(function()
                selectedMap[opt] = not selectedMap[opt]
                TweenService:Create(optBtn, TweenInfo.new(0.2), {
                    BackgroundColor3 = selectedMap[opt] and Color3.fromRGB(255, 92, 92) or Color3.fromRGB(45, 45, 45)
                }):Play()
                updateDisplayText()
            end)
        end
    end

    function TabModule:AddColorPicker(label, defaultColor, defaultAlpha, callback)
        if type(defaultAlpha) == "function" then
            callback = defaultAlpha
            defaultAlpha = 1
        end

        defaultColor = defaultColor or Color3.fromRGB(255, 255, 255)
        defaultAlpha = defaultAlpha or 1
        callback = callback or function() end

        local h, s, v = defaultColor:ToHSV()
        local a = math.clamp(defaultAlpha, 0, 1)

        page.ClipsDescendants = false

        local cpContainer = Instance.new("Frame")
        cpContainer.Name = label .. "ColorPickerContainer"
        cpContainer.Parent = page
        cpContainer.BackgroundTransparency = 1
        cpContainer.Size = UDim2.new(0, 370, 0, 25)
        cpContainer.ZIndex = 6

        local title = Instance.new("TextLabel")
        title.Parent = cpContainer
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 0, 0, 0)
        title.Size = UDim2.new(0, 101, 0, 20)
        title.Font = Enum.Font.Gotham
        title.Text = label
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left

        local previewBtn = Instance.new("TextButton")
        previewBtn.Name = "PreviewBtn"
        previewBtn.Parent = cpContainer
        previewBtn.BackgroundColor3 = defaultColor
        previewBtn.BackgroundTransparency = 1 - a
        previewBtn.BorderColor3 = Color3.fromRGB(255, 92, 92)
        previewBtn.Position = UDim2.new(0.271, 0, 0, 0)
        previewBtn.Size = UDim2.new(0, 180, 0, 20)
        previewBtn.Text = ""
        previewBtn.AutoButtonColor = false

        local ColorPicker = Instance.new("TextButton")
        ColorPicker.Name = "ColorPickerPopup"
        ColorPicker.Parent = cpContainer
        ColorPicker.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ColorPicker.BorderColor3 = Color3.fromRGB(255, 92, 92)
        ColorPicker.Position = UDim2.new(0.271, 0, 0, 25)
        ColorPicker.Size = UDim2.new(0, 180, 0, 170)
        ColorPicker.Visible = false
        ColorPicker.Text = ""
        ColorPicker.AutoButtonColor = false
        ColorPicker.ZIndex = 20

        local pickerObj = {}
        pickerObj.Container = cpContainer
        pickerObj.Popup = ColorPicker

        function pickerObj:Close()
            ColorPicker.Visible = false
            cpContainer.Size = UDim2.new(0, 370, 0, 25)
            if Library.ActiveColorPicker == pickerObj then
                Library.ActiveColorPicker = nil
            end
        end

        function pickerObj:Open()
            if Library.ActiveColorPicker and Library.ActiveColorPicker ~= pickerObj then
                Library.ActiveColorPicker:Close()
            end
            ColorPicker.Visible = true
            cpContainer.Size = UDim2.new(0, 370, 0, 200)
            Library.ActiveColorPicker = pickerObj
        end

        local colorCanvas = Instance.new("ImageButton")
        colorCanvas.Name = "ColorCanvas"
        colorCanvas.Parent = ColorPicker
        colorCanvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        colorCanvas.BorderSizePixel = 0
        colorCanvas.Position = UDim2.new(0.05, 0, 0.05, 0)
        colorCanvas.Size = UDim2.new(0, 130, 0, 130)
        colorCanvas.AutoButtonColor = false
        colorCanvas.ZIndex = 21

        local whiteGradFrame = Instance.new("Frame")
        whiteGradFrame.Parent = colorCanvas
        whiteGradFrame.Size = UDim2.new(1, 0, 1, 0)
        whiteGradFrame.BorderSizePixel = 0
        whiteGradFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        whiteGradFrame.ZIndex = 22

        local whiteGrad = Instance.new("UIGradient")
        whiteGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        }
        whiteGrad.Parent = whiteGradFrame

        local blackGradFrame = Instance.new("Frame")
        blackGradFrame.Parent = colorCanvas
        blackGradFrame.Size = UDim2.new(1, 0, 1, 0)
        blackGradFrame.BorderSizePixel = 0
        blackGradFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        blackGradFrame.ZIndex = 23

        local blackGrad = Instance.new("UIGradient")
        blackGrad.Rotation = 90
        blackGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0)
        }
        blackGrad.Parent = blackGradFrame

        local svCursor = Instance.new("Frame")
        svCursor.Parent = colorCanvas
        svCursor.Size = UDim2.new(0, 4, 0, 4)
        svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        svCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        svCursor.BorderColor3 = Color3.fromRGB(0, 0, 0)
        svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
        svCursor.ZIndex = 24

        local valDisplay = Instance.new("TextLabel")
        valDisplay.Parent = svCursor
        valDisplay.BackgroundTransparency = 1
        valDisplay.Position = UDim2.new(0.5, -45, 0, -18)
        valDisplay.Size = UDim2.new(0, 90, 0, 15)
        valDisplay.Font = Enum.Font.Gotham
        valDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        valDisplay.TextSize = 10
        valDisplay.TextTransparency = 1
        valDisplay.ZIndex = 25

        local colorSlider = Instance.new("ImageButton")
        colorSlider.Name = "ColorSlider"
        colorSlider.Parent = ColorPicker
        colorSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        colorSlider.BorderSizePixel = 0
        colorSlider.Position = UDim2.new(0.81, 0, 0.05, 0)
        colorSlider.Size = UDim2.new(0, 25, 0, 130)
        colorSlider.AutoButtonColor = false
        colorSlider.ZIndex = 21

        local hueGrad = Instance.new("UIGradient")
        hueGrad.Rotation = 90
        hueGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
        }
        hueGrad.Parent = colorSlider

        local hueCursor = Instance.new("Frame")
        hueCursor.Parent = colorSlider
        hueCursor.Size = UDim2.new(1, 0, 0, 2)
        hueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hueCursor.BorderColor3 = Color3.fromRGB(0, 0, 0)
        hueCursor.Position = UDim2.new(0, 0, h, 0)
        hueCursor.ZIndex = 22

        local alphaBg = Instance.new("ImageButton")
        alphaBg.Name = "AlphaSlider"
        alphaBg.Parent = ColorPicker
        alphaBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        alphaBg.BorderSizePixel = 0
        alphaBg.Position = UDim2.new(0.05, 0, 0.85, 0)
        alphaBg.Size = UDim2.new(0, 162, 0, 15)
        alphaBg.Image = "rbxassetid://13212877144"
        alphaBg.ScaleType = Enum.ScaleType.Tile
        alphaBg.TileSize = UDim2.new(0, 10, 0, 10)
        alphaBg.AutoButtonColor = false
        alphaBg.ZIndex = 21

        local alphaColorFill = Instance.new("Frame")
        alphaColorFill.Name = "alphaColorFill"
        alphaColorFill.Parent = alphaBg
        alphaColorFill.BackgroundColor3 = defaultColor
        alphaColorFill.BorderSizePixel = 0
        alphaColorFill.Size = UDim2.new(1, 0, 1, 0)
        alphaColorFill.ZIndex = 22

        local alphaGrad = Instance.new("UIGradient")
        alphaGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0)
        }
        alphaGrad.Parent = alphaColorFill

        local alphaCursor = Instance.new("Frame")
        alphaCursor.Parent = alphaBg
        alphaCursor.Size = UDim2.new(0, 2, 1, 0)
        alphaCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        alphaCursor.BorderColor3 = Color3.fromRGB(0, 0, 0)
        alphaCursor.Position = UDim2.new(a, -1, 0, 0)
        alphaCursor.ZIndex = 23

        local function updateColor()
            local currentColor = Color3.fromHSV(h, s, v)
            colorCanvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            previewBtn.BackgroundColor3 = currentColor
            previewBtn.BackgroundTransparency = 1 - a
            alphaColorFill.BackgroundColor3 = currentColor

            local r = math.round(currentColor.R * 255)
            local g = math.round(currentColor.G * 255)
            local b = math.round(currentColor.B * 255)
            valDisplay.Text = string.format("%d, %d, %d | A: %.2f", r, g, b, a)

            callback(currentColor, a)
        end

        local draggingSV = false
        local draggingHue = false
        local draggingAlpha = false

        local function updateSV(input)
            local posX = math.clamp((input.Position.X - colorCanvas.AbsolutePosition.X) / colorCanvas.AbsoluteSize.X, 0, 1)
            local posY = math.clamp((input.Position.Y - colorCanvas.AbsolutePosition.Y) / colorCanvas.AbsoluteSize.Y, 0, 1)
            s = posX
            v = 1 - posY
            svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            updateColor()
        end

        local function updateHue(input)
            local posY = math.clamp((input.Position.Y - colorSlider.AbsolutePosition.Y) / colorSlider.AbsoluteSize.Y, 0, 1)
            h = posY
            hueCursor.Position = UDim2.new(0, 0, h, 0)
            updateColor()
        end

        local function updateAlpha(input)
            local posX = math.clamp((input.Position.X - alphaBg.AbsolutePosition.X) / alphaBg.AbsoluteSize.X, 0, 1)
            a = posX
            alphaCursor.Position = UDim2.new(a, -1, 0, 0)
            updateColor()
        end

        colorCanvas.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSV = true
                TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
                updateSV(input)
            end
        end)

        colorSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingHue = true
                TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
                updateHue(input)
            end
        end)

        alphaBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingAlpha = true
                TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
                updateAlpha(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if draggingSV or draggingHue or draggingAlpha then
                    TweenService:Create(valDisplay, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                end
                draggingSV = false
                draggingHue = false
                draggingAlpha = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if draggingSV then
                    updateSV(input)
                elseif draggingHue then
                    updateHue(input)
                elseif draggingAlpha then
                    updateAlpha(input)
                end
            end
        end)

        previewBtn.MouseButton1Click:Connect(function()
            if ColorPicker.Visible then
                pickerObj:Close()
            else
                pickerObj:Open()
            end
        end)

        updateColor()
    end

    table.insert(self.Tabs, TabModule)
    return TabModule
end
return Library
