local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Library = {}
Library.Flags = {}
Library.Elements = {}
Library.Theme = {
	Background = Color3.fromRGB(30, 30, 35),
	Container = Color3.fromRGB(40, 40, 45),
	ContentBackground = Color3.fromRGB(24, 24, 28),
	Separator = Color3.fromRGB(55, 55, 62),
	Accent = Color3.fromRGB(0, 162, 255),
	Text = Color3.fromRGB(245, 245, 245),
	MutedText = Color3.fromRGB(150, 150, 150),
	font = "Code"
}

Library.Keybinds = {}
Library.ThemeObjects = {}
Library.ActiveColorpicker = nil
Library.ActiveWindow = nil

--------------------------------------------------------------------------------
-- CONFIG SYSTEM
--------------------------------------------------------------------------------

local function SerializeValue(value)
	if typeof(value) == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	elseif typeof(value) == "EnumItem" then
		return { __type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name }
	end
	return value
end

local function DeserializeValue(value)
	if type(value) == "table" then
		if value.__type == "Color3" or (value.R and value.G and value.B) then
			return Color3.new(value.R, value.G, value.B)
		elseif value.__type == "EnumItem" then
			local enumTable = Enum[value.EnumType]
			if enumTable and enumTable[value.Name] then
				return enumTable[value.Name]
			end
		end
	end
	return value
end

function Library:SaveConfig(fileName)
	fileName = fileName or "default_config"
	if not writefile then return end

	local dataToSave = {}
	for flag, value in pairs(Library.Flags) do
		dataToSave[flag] = SerializeValue(value)
	end

	-- Save Window Size if window exists
	if Library.ActiveWindow and Library.ActiveWindow.MainFrame then
		local size = Library.ActiveWindow.MainFrame.AbsoluteSize
		dataToSave["__WindowSize"] = { Width = size.X, Height = size.Y }
	end

	local success, err = pcall(function()
		writefile(fileName .. ".json", HttpService:JSONEncode(dataToSave))
	end)

	if not success then
		warn("[Library Config]: Failed to save config - " .. tostring(err))
	end
end

function Library:LoadConfig(fileName)
	fileName = fileName or "default_config"
	local path = fileName .. ".json"
	
	if not (isfile and readfile and isfile(path)) then return end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)

	if success and type(decoded) == "table" then
		for flag, rawValue in pairs(decoded) do
			if flag == "__WindowSize" and type(rawValue) == "table" then
				if Library.ActiveWindow and Library.ActiveWindow.Resize then
					Library.ActiveWindow:Resize(rawValue.Width, rawValue.Height)
				end
			else
				local value = DeserializeValue(rawValue)
				Library.Flags[flag] = value

				local element = Library.Elements[flag]
				if element and element.Set then
					element:Set(value)
				end
			end
		end
	else
		warn("[Library Config]: Failed to load config file.")
	end
end

function Library:GetConfigs()
	local configs = {}
	
	-- Check if the executor supports directory listing
	if not listfiles then
		warn("[Library Config]: Your executor does not support 'listfiles'.")
		return configs
	end

	local files = listfiles("") or {}
	for _, path in ipairs(files) do
		-- Handle different path formats returned by various executors
		local fileName = path:match("([^/\\]+)%.json$")
		if fileName then
			table.insert(configs, fileName)
		end
	end

	return configs
end

function Library:RefreshConfigs(targetDropdown, callback)
	local configs = Library:GetConfigs()
	
	-- Update a target dropdown element if passed
	if targetDropdown then
		if typeof(targetDropdown) == "string" and Library.Elements[targetDropdown] then
			targetDropdown = Library.Elements[targetDropdown]
		end

		if targetDropdown.RefreshOptions then
			targetDropdown:RefreshOptions(configs)
		elseif targetDropdown.SetOptions then
			targetDropdown:SetOptions(configs)
		end
	end

	-- Execute an optional callback returning the fetched configuration list
	if type(callback) == "function" then
		callback(configs)
	end

	return configs
end

function Library:DeleteConfig(fileName)
	fileName = fileName or "default_config"
	local path = fileName .. ".json"
	if isfile and delfile and isfile(path) then
		delfile(path)
	end
end




--------------------------------------------------------------------------------
-- THEME & INPUT SYSTEM
--------------------------------------------------------------------------------

function Library:changeTheme(themeKey, newColor)
	if Library.Theme[themeKey] then
		Library.Theme[themeKey] = newColor
		
		for _, reg in ipairs(Library.ThemeObjects) do
			if reg.Key == themeKey and reg.Object and reg.Object.Parent then
				reg.Object[reg.Property] = newColor
			end
		end
	end
end

local function RegisterTheme(guiObject, propertyName, themeKey)
	guiObject[propertyName] = Library.Theme[themeKey]
	table.insert(Library.ThemeObjects, {
		Object = guiObject,
		Property = propertyName,
		Key = themeKey
	})
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local pressedKey = (input.UserInputType == Enum.UserInputType.Keyboard) and input.KeyCode or input.UserInputType

	for _, keybind in ipairs(Library.Keybinds) do
		if keybind.Key == pressedKey and type(keybind.Callback) == "function" then
			task.spawn(keybind.Callback, pressedKey)
		end
	end
end)




--------------------------------------------------------------------------------
-- SCREEN GUI CONTAINER (Move above Notify so it exists in scope)
--------------------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomUILibrary"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999999
ScreenGui.IgnoreGuiInset = true

-- Protect parent assignment if running before PlayerGui loads
pcall(function()
	ScreenGui.Parent = PlayerGui
end)

--------------------------------------------------------------------------------
-- NOTIFICATION SYSTEM
--------------------------------------------------------------------------------

function Library:Notify(options)
	options = options or {}
	local titleText = options.Title or "Notification"
	local messageText = options.Text or ""
	local duration = options.Duration or 0
	local callback = options.Callback or function() end

	local windowWidth, windowHeight = 280, options.YesNo and 130 or 110
	local parentGui = ScreenGui or PlayerGui:FindFirstChild("CustomUILibrary")

	local NotifyFrame = Instance.new("Frame")
	NotifyFrame.Name = "NotificationWindow"
	NotifyFrame.Size = UDim2.new(0, windowWidth, 0, windowHeight)
	NotifyFrame.Position = UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2)
	RegisterTheme(NotifyFrame, "BackgroundColor3", "Container")
	NotifyFrame.BorderSizePixel = 0
	NotifyFrame.ZIndex = 200
	NotifyFrame.Parent = parentGui

	local FrameCorner = Instance.new("UICorner")
	FrameCorner.CornerRadius = UDim.new(0, 6)
	FrameCorner.Parent = NotifyFrame

	-- Title Bar
	local TitleBar = Instance.new("Frame")
	TitleBar.Size = UDim2.new(1, 0, 0, 28)
	RegisterTheme(TitleBar, "BackgroundColor3", "Background")
	TitleBar.BorderSizePixel = 0
	TitleBar.ZIndex = 201
	TitleBar.Parent = NotifyFrame

	local TitleCorner = Instance.new("UICorner")
	TitleCorner.CornerRadius = UDim.new(0, 6)
	TitleCorner.Parent = TitleBar

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Size = UDim2.new(1, -30, 1, 0)
	TitleLabel.Position = UDim2.new(0, 10, 0, 0)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Text = titleText
	RegisterTheme(TitleLabel, "TextColor3", "Text")
	TitleLabel.TextSize = 13
	TitleLabel.Font = Enum.Font.SourceSansBold
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.ZIndex = 202
	TitleLabel.Parent = TitleBar

	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Size = UDim2.new(0, 28, 0, 28)
	CloseBtn.Position = UDim2.new(1, -28, 0, 0)
	CloseBtn.BackgroundTransparency = 1
	CloseBtn.Text = "X"
	RegisterTheme(CloseBtn, "TextColor3", "Text")
	CloseBtn.TextSize = 12
	CloseBtn.Font = Enum.Font.SourceSansBold
	CloseBtn.ZIndex = 202
	CloseBtn.Parent = TitleBar

	local function CloseWindow()
		if NotifyFrame and NotifyFrame.Parent then
			NotifyFrame:Destroy()
		end
	end

	CloseBtn.MouseButton1Click:Connect(CloseWindow)

	-- Message Text
	local MessageLabel = Instance.new("TextLabel")
	MessageLabel.Size = UDim2.new(1, -20, 0, 35)
	MessageLabel.Position = UDim2.new(0, 10, 0, 34)
	MessageLabel.BackgroundTransparency = 1
	MessageLabel.Text = messageText
	RegisterTheme(MessageLabel, "TextColor3", "Text")
	MessageLabel.TextSize = 13
	MessageLabel.Font = Enum.Font.SourceSans
	MessageLabel.TextWrapped = true
	MessageLabel.ZIndex = 201
	MessageLabel.Parent = NotifyFrame

	-- Action Buttons
	if options.YesNo then
		local YesBtn = Instance.new("TextButton")
		YesBtn.Size = UDim2.new(0.45, 0, 0, 26)
		YesBtn.Position = UDim2.new(0.04, 0, 1, -34)
		RegisterTheme(YesBtn, "BackgroundColor3", "Accent")
		YesBtn.Text = "Yes"
		RegisterTheme(YesBtn, "TextColor3", "Text")
		YesBtn.TextSize = 12
		YesBtn.Font = Enum.Font.SourceSansBold
		YesBtn.ZIndex = 201
		YesBtn.Parent = NotifyFrame

		local YesCorner = Instance.new("UICorner")
		YesCorner.CornerRadius = UDim.new(0, 4)
		YesCorner.Parent = YesBtn

		local NoBtn = Instance.new("TextButton")
		NoBtn.Size = UDim2.new(0.45, 0, 0, 26)
		NoBtn.Position = UDim2.new(0.51, 0, 1, -34)
		RegisterTheme(NoBtn, "BackgroundColor3", "Background")
		NoBtn.Text = "No"
		RegisterTheme(NoBtn, "TextColor3", "Text")
		NoBtn.TextSize = 12
		NoBtn.Font = Enum.Font.SourceSansBold
		NoBtn.ZIndex = 201
		NoBtn.Parent = NotifyFrame

		local NoCorner = Instance.new("UICorner")
		NoCorner.CornerRadius = UDim.new(0, 4)
		NoCorner.Parent = NoBtn

		YesBtn.MouseButton1Click:Connect(function()
			CloseWindow()
			callback(true)
		end)

		NoBtn.MouseButton1Click:Connect(function()
			CloseWindow()
			callback(false)
		end)
	else
		local OkBtn = Instance.new("TextButton")
		OkBtn.Size = UDim2.new(0.92, 0, 0, 24)
		OkBtn.Position = UDim2.new(0.04, 0, 1, -30)
		RegisterTheme(OkBtn, "BackgroundColor3", "Background")
		OkBtn.Text = "OK"
		RegisterTheme(OkBtn, "TextColor3", "Text")
		OkBtn.TextSize = 12
		OkBtn.Font = Enum.Font.SourceSansBold
		OkBtn.ZIndex = 201
		OkBtn.Parent = NotifyFrame

		local OkCorner = Instance.new("UICorner")
		OkCorner.CornerRadius = UDim.new(0, 4)
		OkCorner.Parent = OkBtn

		OkBtn.MouseButton1Click:Connect(CloseWindow)
	end

	-- Auto Close Timer
	if duration > 0 then
		task.delay(duration, function()
			CloseWindow()
		end)
	end
end


--------------------------------------------------------------------------------
-- WINDOW CREATION
--------------------------------------------------------------------------------

function Library:CreateWindow(titleText)
	local Window = {
		Tabs = {},
		ActiveTab = nil,
		windowVisible = true,
		BaseWidth = 450,
		BaseHeight = 340
	}

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, Window.BaseWidth, 0, Window.BaseHeight)
	MainFrame.Position = UDim2.new(0.5, -Window.BaseWidth / 2, 0.5, -Window.BaseHeight / 2)
	RegisterTheme(MainFrame, "BackgroundColor3", "Background")
	MainFrame.BorderSizePixel = 0
	MainFrame.Active = true
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = ScreenGui

	Window.MainFrame = MainFrame
	Library.ActiveWindow = Window

	local dragging, dragInput, dragStart, startPos
	local gui = MainFrame

	local function update(input)
		local delta = input.Position - dragStart
		local tweenInf = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local goal = { Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) }

		TweenService:Create(gui, tweenInf, goal):Play()
	end

	gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = gui.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	gui.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)

	function Window:isWindowOpen()
		return MainFrame.Visible
	end

	function Window:Toggle()
		MainFrame.Visible = not MainFrame.Visible
		self.windowVisible = MainFrame.Visible
	
		if not self.windowVisible then
			-- Close active colorpicker when menu is toggled off
			if Library.ActiveColorpicker then
				Library.ActiveColorpicker:Destroy()
				Library.ActiveColorpicker = nil
			end
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	
		return self.windowVisible
	end

	function Window:Resize(width, height)
		if width and height then
			MainFrame.Size = UDim2.new(0, width, 0, height)
		end
	end

	RunService.RenderStepped:Connect(function()
		if Window.windowVisible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end)

	
	
	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, -20, 0, 35)
	Title.Position = UDim2.new(0, 10, 0, 0)
	Title.BackgroundTransparency = 1
	Title.Text = titleText or "UI Window"
	RegisterTheme(Title, "TextColor3", "Text")
	Title.TextSize = 16
	Title.Font = Enum.Font.SourceSansBold
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = MainFrame

	local TabBar = Instance.new("Frame")
	TabBar.Name = "TabBar"
	TabBar.Size = UDim2.new(1, -20, 0, 30)
	TabBar.Position = UDim2.new(0, 10, 0, 35)
	TabBar.BackgroundTransparency = 1
	TabBar.Parent = MainFrame

	local TabListLayout = Instance.new("UIListLayout")
	TabListLayout.FillDirection = Enum.FillDirection.Horizontal
	TabListLayout.Padding = UDim.new(0, 6)
	TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	TabListLayout.Parent = TabBar

	local Separator = Instance.new("Frame")
	Separator.Name = "TabSeparator"
	Separator.Size = UDim2.new(1, -20, 0, 2)
	Separator.Position = UDim2.new(0, 10, 0, 68)
	RegisterTheme(Separator, "BackgroundColor3", "Separator")
	Separator.BorderSizePixel = 0
	Separator.Parent = MainFrame

	local ActiveLine = Instance.new("Frame")
	ActiveLine.Name = "ActiveTabLine"
	ActiveLine.Size = UDim2.new(0, 0, 0, 3)
	ActiveLine.Position = UDim2.new(0, 10, 0, 67)
	RegisterTheme(ActiveLine, "BackgroundColor3", "Accent")
	ActiveLine.BorderSizePixel = 0
	ActiveLine.BackgroundTransparency = 1
	ActiveLine.ZIndex = 2
	ActiveLine.Parent = MainFrame

	local ActiveLineCorner = Instance.new("UICorner")
	ActiveLineCorner.CornerRadius = UDim.new(0, 2)
	ActiveLineCorner.Parent = ActiveLine

	local ContentFrame = Instance.new("Frame")
	ContentFrame.Name = "ContentFrame"
	ContentFrame.Size = UDim2.new(1, -20, 1, -85)
	ContentFrame.Position = UDim2.new(0, 10, 0, 78)
	RegisterTheme(ContentFrame, "BackgroundColor3", "ContentBackground")
	ContentFrame.BorderSizePixel = 0
	ContentFrame.Parent = MainFrame

	local ContentCorner = Instance.new("UICorner")
	ContentCorner.CornerRadius = UDim.new(0, 3)
	ContentCorner.Parent = ContentFrame

	local PageContainer = Instance.new("Frame")
	PageContainer.Name = "PageContainer"
	PageContainer.Size = UDim2.new(1, -16, 1, -16)
	PageContainer.Position = UDim2.new(0, 8, 0, 8)
	PageContainer.BackgroundTransparency = 1
	PageContainer.Parent = ContentFrame

	local function UpdateActiveLine()
		if Window.ActiveTab and Window.ActiveTab.Button then
			local btn = Window.ActiveTab.Button
			local targetPosition = UDim2.new(0, btn.AbsolutePosition.X - MainFrame.AbsolutePosition.X, 0, 66)
			local targetSize = UDim2.new(0, btn.AbsoluteSize.X, 0, 3)

			TweenService:Create(ActiveLine, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = targetPosition,
				Size = targetSize,
				BackgroundTransparency = 0
			}):Play()
		end
	end

	local function AdjustWindowBounds(contentWidth, contentHeight)
		local tabWidth = 100
		local tabPadding = 6
		local sideMargin = 20
		local totalTabs = #Window.Tabs

		local requiredWidthForTabs = (totalTabs * tabWidth) + ((totalTabs - 1) * tabPadding) + sideMargin
		local requiredWidthForContent = (contentWidth or 400) + 36

		local targetWidth = math.max(requiredWidthForTabs, requiredWidthForContent, Window.BaseWidth)
		local targetHeight = math.max((contentHeight or 0) + 101, Window.BaseHeight)

		-- Update size without resetting MainFrame.Position
		MainFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
	end

	local ResizeHandle = Instance.new("TextButton")
	ResizeHandle.Name = "ResizeHandle"
	ResizeHandle.Size = UDim2.new(0, 15, 0, 15)
	ResizeHandle.Position = UDim2.new(1, -15, 1, -15)
	RegisterTheme(ResizeHandle, "BackgroundColor3", "Background")
	ResizeHandle.BackgroundTransparency = 0.5
	ResizeHandle.Text = "◢"
	RegisterTheme(ResizeHandle, "TextColor3", "Text")
	ResizeHandle.TextSize = 10
	ResizeHandle.BorderSizePixel = 0
	ResizeHandle.AutoButtonColor = false
	ResizeHandle.Parent = MainFrame

	local minSize = Vector2.new(300, 200)
	local resizing = false
	local startMousePos, startSize

	MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateActiveLine)

	ResizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			startMousePos = Vector2.new(input.Position.X, input.Position.Y)
			startSize = MainFrame.AbsoluteSize
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - startMousePos
			local newX = math.max(minSize.X, startSize.X + delta.X)
			local newY = math.max(minSize.Y, startSize.Y + delta.Y)

			MainFrame.Size = UDim2.new(0, newX, 0, newY)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)

	local function CreateComponents(TargetContainer)
		local Comp = {}

		function Comp:Spacing(height)
			local Spacer = Instance.new("Frame")
			Spacer.Name = "Spacer"
			Spacer.Size = UDim2.new(1, 0, 0, height or 10)
			Spacer.BackgroundTransparency = 1
			Spacer.BorderSizePixel = 0
			Spacer.Parent = TargetContainer
			return Spacer
		end

		function Comp:AddButton(text, callback)
			callback = callback or function() end
			
			local Button = Instance.new("TextButton")
			Button.Size = UDim2.new(1, 0, 0, 32)
			RegisterTheme(Button, "BackgroundColor3", "Container")
			Button.Text = text
			RegisterTheme(Button, "TextColor3", "Text")
			Button.TextSize = 13
			Button.Font = Library.Theme.font
			Button.AutoButtonColor = false
			Button.Parent = TargetContainer
			
			local BtnCorner = Instance.new("UICorner")
			BtnCorner.CornerRadius = UDim.new(0, 5)
			BtnCorner.Parent = Button
			
			Button.MouseEnter:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent}):Play()
			end)
			
			Button.MouseLeave:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Container}):Play()
			end)
			
			Button.MouseButton1Click:Connect(callback)
		end

		function Comp:AddToggle(text, defaultState, flag, callback)
		    if type(flag) == "function" then
		        callback = flag
		        flag = text
		    end
		    callback = callback or function() end
		    flag = flag or text
		
		    local toggled = defaultState or false
		    Library.Flags[flag] = toggled
		
		    -- Main container holding both the toggle bar and any expanded sub-elements
		    local ContainerFrame = Instance.new("Frame")
		    ContainerFrame.Name = text .. "_ToggleContainer"
		    ContainerFrame.Size = UDim2.new(1, 0, 0, 32)
		    ContainerFrame.BackgroundTransparency = 1
		    ContainerFrame.Parent = TargetContainer
		
		    local ContainerLayout = Instance.new("UIListLayout")
		    ContainerLayout.Padding = UDim.new(0, 6)
		    ContainerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    ContainerLayout.Parent = ContainerFrame
		
		    -- Toggle Bar
		    local ToggleFrame = Instance.new("Frame")
		    ToggleFrame.Name = "ToggleFrame"
		    ToggleFrame.Size = UDim2.new(1, 0, 0, 32)
		    RegisterTheme(ToggleFrame, "BackgroundColor3", "Container")
		    ToggleFrame.Transparency = 0
		    ToggleFrame.Parent = ContainerFrame
		
		    local ToggleCorner = Instance.new("UICorner")
		    ToggleCorner.CornerRadius = UDim.new(0, 5)
		    ToggleCorner.Parent = ToggleFrame
		
		    local Label = Instance.new("TextLabel")
		    Label.Size = UDim2.new(1, -50, 1, 0)
		    Label.Position = UDim2.new(0, 35, 0, 0)
		    Label.BackgroundTransparency = 1
		    Label.Text = text
		    RegisterTheme(Label, "TextColor3", "Text")
		    Label.TextSize = 13
		    Label.Font = Enum.Font.SourceSans
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.Parent = ToggleFrame
		
		    local Indicator = Instance.new("Frame")
		    Indicator.Size = UDim2.new(0, 15, 0, 15)
		    Indicator.Position = UDim2.new(0, 10, 0.5, -7)
		    RegisterTheme(Indicator, "BackgroundColor3", toggled and "Accent" or "Background")
		    Indicator.BorderSizePixel = 0
		    Indicator.Parent = ToggleFrame
		
		    local ClickArea = Instance.new("TextButton")
		    ClickArea.Size = UDim2.new(1, 0, 1, 0)
		    ClickArea.BackgroundTransparency = 1
		    ClickArea.Text = ""
		    ClickArea.Parent = ToggleFrame
		
		    -- Container for child elements (Hidden by default unless toggled is true)
		    local ChildrenHolder = Instance.new("Frame")
		    ChildrenHolder.Name = "ChildrenHolder"
		    ChildrenHolder.Size = UDim2.new(1, 0, 0, 0)
		    ChildrenHolder.BackgroundTransparency = 1
		    ChildrenHolder.Visible = toggled
		    ChildrenHolder.Parent = ContainerFrame
		
		    local ChildrenLayout = Instance.new("UIListLayout")
		    ChildrenLayout.Padding = UDim.new(0, 6)
		    ChildrenLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    ChildrenLayout.Parent = ChildrenHolder
		
		    -- Automatically resize ChildrenHolder & ContainerFrame based on contents
		    ChildrenLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		        local height = ChildrenLayout.AbsoluteContentSize.Y
		        ChildrenHolder.Size = UDim2.new(1, 0, 0, height)
		        
		        if toggled then
		            ContainerFrame.Size = UDim2.new(1, 0, 0, 32 + (height > 0 and (height + 6) or 0))
		        end
		    end)
		
		    local function SetState(state)
		        toggled = state
		        Library.Flags[flag] = toggled
		
		        local targetColor = toggled and Library.Theme.Accent or Library.Theme.Background
		        TweenService:Create(Indicator, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
		
		        ChildrenHolder.Visible = toggled
		
		        local childHeight = ChildrenLayout.AbsoluteContentSize.Y
		        local targetContainerHeight = toggled and (32 + (childHeight > 0 and (childHeight + 6) or 0)) or 32
		        
		        TweenService:Create(ContainerFrame, TweenInfo.new(0.2), {
		            Size = UDim2.new(1, 0, 0, targetContainerHeight)
		        }):Play()
		
		        callback(toggled)
		    end
		
		    ClickArea.MouseButton1Click:Connect(function()
		        SetState(not toggled)
		    end)
		
		    -- Create element component builder bound to ChildrenHolder
		    local ToggleObj = CreateComponents(ChildrenHolder)
		
		    function ToggleObj:Set(val)
		        SetState(val)
		    end
		
		    Library.Elements[flag] = ToggleObj
		    return ToggleObj
		end
		function Comp:AddKeybind(text, defaultKey, flag, callback)
			if type(flag) == "function" then
				callback = flag
				flag = text
			end
			callback = callback or function() end
			flag = flag or text

			local currentKey = defaultKey or Enum.KeyCode.E
			Library.Flags[flag] = currentKey
			local listening = false

			local keybindData = {
				Key = currentKey,
				Callback = callback
			}
			table.insert(Library.Keybinds, keybindData)

			local KeybindFrame = Instance.new("Frame")
			KeybindFrame.Size = UDim2.new(1, 0, 0, 32)
			RegisterTheme(KeybindFrame, "BackgroundColor3", "Container")
			KeybindFrame.Parent = TargetContainer

			local KeybindCorner = Instance.new("UICorner")
			KeybindCorner.CornerRadius = UDim.new(0, 5)
			KeybindCorner.Parent = KeybindFrame

			local Label = Instance.new("TextLabel")
			Label.Size = UDim2.new(1, -100, 1, 0)
			Label.Position = UDim2.new(0, 10, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = text
			RegisterTheme(Label, "TextColor3", "Text")
			Label.TextSize = 13
			Label.Font = Enum.Font.SourceSans
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.Parent = KeybindFrame

			local KeyButton = Instance.new("TextButton")
			KeyButton.Size = UDim2.new(0, 75, 0, 22)
			KeyButton.Position = UDim2.new(1, -83, 0.5, -11)
			RegisterTheme(KeyButton, "BackgroundColor3", "Background")
			KeyButton.Text = type(currentKey) == "userdata" and currentKey.Name or tostring(currentKey)
			RegisterTheme(KeyButton, "TextColor3", "Text")
			KeyButton.TextSize = 12
			KeyButton.Font = Enum.Font.SourceSansBold
			KeyButton.AutoButtonColor = false
			KeyButton.Parent = KeybindFrame

			local KeyCorner = Instance.new("UICorner")
			KeyCorner.CornerRadius = UDim.new(0, 4)
			KeyCorner.Parent = KeyButton

			local function SetKey(newKey)
				currentKey = newKey
				keybindData.Key = newKey
				Library.Flags[flag] = newKey
				KeyButton.Text = type(newKey) == "userdata" and newKey.Name or tostring(newKey)
			end

			local rebindConnection
			KeyButton.MouseButton1Click:Connect(function()
				if listening then return end
				listening = true
				KeyButton.Text = "..."
				TweenService:Create(KeyButton, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent}):Play()

				rebindConnection = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Keyboard or 
					input.UserInputType == Enum.UserInputType.MouseButton1 or 
					input.UserInputType == Enum.UserInputType.MouseButton2 then
						
						local newKey = (input.UserInputType == Enum.UserInputType.Keyboard) and input.KeyCode or input.UserInputType
						SetKey(newKey)
						listening = false

						TweenService:Create(KeyButton, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Background}):Play()
						
						if rebindConnection then
							rebindConnection:Disconnect()
							rebindConnection = nil
						end
					end
				end)
			end)

			Library.Elements[flag] = { 
				Set = function(self, val)
					SetKey(val)
				end 
			}
		end

		function Comp:AddSlider(text, min, max, default, flag, callback)
			if type(flag) == "function" then
				callback = flag
				flag = text
			end
			callback = callback or function() end
			flag = flag or text

			min = min or 0
			max = max or 100
			default = math.clamp(default or min, min, max)
			Library.Flags[flag] = default

			local SliderFrame = Instance.new("Frame")
			SliderFrame.Size = UDim2.new(1, 0, 0, 42)
			RegisterTheme(SliderFrame, "BackgroundColor3", "Container")
			SliderFrame.Parent = TargetContainer

			local SliderCorner = Instance.new("UICorner")
			SliderCorner.CornerRadius = UDim.new(0, 5)
			SliderCorner.Parent = SliderFrame

			local Label = Instance.new("TextLabel")
			Label.Size = UDim2.new(0.6, 0, 0, 18)
			Label.Position = UDim2.new(0, 10, 0, 4)
			Label.BackgroundTransparency = 1
			Label.Text = text
			RegisterTheme(Label, "TextColor3", "Text")
			Label.TextSize = 13
			Label.Font = Enum.Font.SourceSans
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.Parent = SliderFrame

			local ValueLabel = Instance.new("TextLabel")
			ValueLabel.Size = UDim2.new(0.35, -10, 0, 18)
			ValueLabel.Position = UDim2.new(0.65, 0, 0, 4)
			ValueLabel.BackgroundTransparency = 1
			ValueLabel.Text = tostring(default) .. " / " .. tostring(max)
			RegisterTheme(ValueLabel, "TextColor3", "MutedText")
			ValueLabel.TextSize = 12
			ValueLabel.Font = Enum.Font.SourceSansBold
			ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			ValueLabel.Parent = SliderFrame

			local Track = Instance.new("TextButton")
			Track.Name = "SliderTrack"
			Track.Size = UDim2.new(1, -20, 0, 6)
			Track.Position = UDim2.new(0, 10, 0, 26)
			RegisterTheme(Track, "BackgroundColor3", "Background")
			Track.AutoButtonColor = false
			Track.Text = ""
			Track.Parent = SliderFrame

			local TrackCorner = Instance.new("UICorner")
			TrackCorner.CornerRadius = UDim.new(0, 3)
			TrackCorner.Parent = Track

			local Fill = Instance.new("Frame")
			Fill.Name = "SliderFill"
			local initialScale = (default - min) / (max - min)
			Fill.Size = UDim2.new(initialScale, 0, 1, 0)
			RegisterTheme(Fill, "BackgroundColor3", "Accent")
			Fill.BorderSizePixel = 0
			Fill.Parent = Track

			local FillCorner = Instance.new("UICorner")
			FillCorner.CornerRadius = UDim.new(0, 3)
			FillCorner.Parent = Fill

			local dragging = false

			local function SetValue(val)
				val = math.clamp(val, min, max)
				Library.Flags[flag] = val
				local scale = (val - min) / (max - min)
				Fill.Size = UDim2.new(scale, 0, 1, 0)
				ValueLabel.Text = tostring(val) .. " / " .. tostring(max)
				callback(val)
			end

			local function UpdateSlider(input)
				local relativeX = math.clamp(input.Position.X - Track.AbsolutePosition.X, 0, Track.AbsoluteSize.X)
				local scale = relativeX / Track.AbsoluteSize.X
				local value = math.floor(min + (max - min) * scale)
				SetValue(value)
			end

			Track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					UpdateSlider(input)
				end
			end)

			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					UpdateSlider(input)
				end
			end)

			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			Library.Elements[flag] = { 
				Set = function(self, val)
					SetValue(val)
				end 
			}
		end

		function Comp:AddDropdown(text, options, defaultOption, flag, callback)
		    if type(flag) == "function" then
		        callback = flag
		        flag = text
		    end
		    callback = callback or function() end
		    flag = flag or text
		
		    options = options or {}
		    local selected = defaultOption or options[1] or "Select..."
		    Library.Flags[flag] = selected
		    local open = false
		
		    -- Outer container wrapping the dropdown frame and option sub-elements
		    local ContainerFrame = Instance.new("Frame")
		    ContainerFrame.Name = text .. "_DropdownContainer"
		    ContainerFrame.Size = UDim2.new(1, 0, 0, 32)
		    ContainerFrame.BackgroundTransparency = 1
		    ContainerFrame.Parent = TargetContainer
		
		    local ContainerLayout = Instance.new("UIListLayout")
		    ContainerLayout.Padding = UDim.new(0, 6)
		    ContainerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    ContainerLayout.Parent = ContainerFrame
		
		    -- Dropdown Main Bar
		    local DropdownFrame = Instance.new("Frame")
		    DropdownFrame.Name = "DropdownFrame"
		    DropdownFrame.Size = UDim2.new(1, 0, 0, 32)
		    RegisterTheme(DropdownFrame, "BackgroundColor3", "Container")
		    DropdownFrame.ClipsDescendants = true
		    DropdownFrame.Parent = ContainerFrame
		
		    local DropdownCorner = Instance.new("UICorner")
		    DropdownCorner.CornerRadius = UDim.new(0, 5)
		    DropdownCorner.Parent = DropdownFrame
		
		    local Label = Instance.new("TextLabel")
		    Label.Size = UDim2.new(0.5, -10, 0, 32)
		    Label.Position = UDim2.new(0, 10, 0, 0)
		    Label.BackgroundTransparency = 1
		    Label.Text = text
		    RegisterTheme(Label, "TextColor3", "Text")
		    Label.TextSize = 13
		    Label.Font = Enum.Font.SourceSans
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.Parent = DropdownFrame
		
		    local SelectedButton = Instance.new("TextButton")
		    SelectedButton.Size = UDim2.new(0.5, -10, 0, 22)
		    SelectedButton.Position = UDim2.new(0.5, 0, 0, 5)
		    RegisterTheme(SelectedButton, "BackgroundColor3", "Background")
		    SelectedButton.Text = selected .. "  ▼"
		    RegisterTheme(SelectedButton, "TextColor3", "Text")
		    SelectedButton.TextSize = 12
		    SelectedButton.Font = Enum.Font.SourceSansBold
		    SelectedButton.AutoButtonColor = false
		    SelectedButton.Parent = DropdownFrame
		
		    local SelectedCorner = Instance.new("UICorner")
		    SelectedCorner.CornerRadius = UDim.new(0, 4)
		    SelectedCorner.Parent = SelectedButton
		
		    local OptionsHolder = Instance.new("Frame")
		    OptionsHolder.Name = "OptionsHolder"
		    OptionsHolder.Size = UDim2.new(1, -20, 0, 0)
		    OptionsHolder.Position = UDim2.new(0, 10, 0, 35)
		    OptionsHolder.BackgroundTransparency = 1
		    OptionsHolder.Parent = DropdownFrame
		
		    local OptionsLayout = Instance.new("UIListLayout")
		    OptionsLayout.Padding = UDim.new(0, 3)
		    OptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    OptionsLayout.Parent = OptionsHolder
		
		    local SubHolders = {}
		    local OptionComponents = {}
		    local DropdownObj = {}
		
		    -- Function to adjust ContainerFrame size when the dropdown state changes
		    local function UpdateContainerHeight()
		        local currentSub = SubHolders[selected]
		        local subHeight = 0
		
		        if currentSub and currentSub.Visible then
		            local layout = currentSub:FindFirstChildOfClass("UIListLayout")
		            if layout then
		                subHeight = layout.AbsoluteContentSize.Y
		            end
		        end
		
		        local dropdownHeight = open and (35 + (#options * 25)) or 32
		        local totalHeight = dropdownHeight + (subHeight > 0 and (subHeight + 6) or 0)
		
		        TweenService:Create(DropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		            Size = UDim2.new(1, 0, 0, dropdownHeight)
		        }):Play()
		
		        TweenService:Create(ContainerFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		            Size = UDim2.new(1, 0, 0, totalHeight)
		        }):Play()
		    end
		
		    local function ToggleDropdown(forceState)
		        if forceState ~= nil then
		            open = forceState
		        else
		            open = not open
		        end
		        SelectedButton.Text = selected .. (open and "  ▲" or "  ▼")
		        UpdateContainerHeight()
		    end
		
		    local function SetSelected(option)
		        selected = option or "None"
		        Library.Flags[flag] = selected
		        SelectedButton.Text = selected .. (open and "  ▲" or "  ▼")
		
		        for optName, holder in pairs(SubHolders) do
		            holder.Visible = (optName == selected)
		        end
		
		        UpdateContainerHeight()
		        callback(selected)
		    end
		
		    local function EnsureOptionHolder(optName)
		        if not SubHolders[optName] then
		            local Holder = Instance.new("Frame")
		            Holder.Name = optName .. "_Holder"
		            Holder.Size = UDim2.new(1, 0, 0, 0)
		            Holder.BackgroundTransparency = 1
		            Holder.Visible = (optName == selected)
		            Holder.Parent = ContainerFrame
		
		            local Layout = Instance.new("UIListLayout")
		            Layout.Padding = UDim.new(0, 6)
		            Layout.SortOrder = Enum.SortOrder.LayoutOrder
		            Layout.Parent = Holder
		
		            Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		                Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
		                if Holder.Visible then
		                    UpdateContainerHeight()
		                end
		            end)
		
		            SubHolders[optName] = Holder
		            OptionComponents[optName] = CreateComponents(Holder)
		        end
		        return OptionComponents[optName]
		    end
		
		    local function BuildOptions()
		        for _, child in ipairs(OptionsHolder:GetChildren()) do
		            if child:IsA("TextButton") then
		                child:Destroy()
		            end
		        end
		
		        OptionsHolder.Size = UDim2.new(1, -20, 0, #options * 25)
		
		        for _, option in ipairs(options) do
		            EnsureOptionHolder(option)
		
		            local OptionBtn = Instance.new("TextButton")
		            OptionBtn.Size = UDim2.new(1, 0, 0, 22)
		            RegisterTheme(OptionBtn, "BackgroundColor3", "Background")
		            OptionBtn.Text = option
		            RegisterTheme(OptionBtn, "TextColor3", "MutedText")
		            OptionBtn.TextSize = 12
		            OptionBtn.Font = Enum.Font.SourceSans
		            OptionBtn.AutoButtonColor = false
		            OptionBtn.Parent = OptionsHolder
		
		            local OptionCorner = Instance.new("UICorner")
		            OptionCorner.CornerRadius = UDim.new(0, 4)
		            OptionCorner.Parent = OptionBtn
		
		            OptionBtn.MouseEnter:Connect(function()
		                TweenService:Create(OptionBtn, TweenInfo.new(0.15), {
		                    BackgroundColor3 = Library.Theme.Accent,
		                    TextColor3 = Library.Theme.Text
		                }):Play()
		            end)
		
		            OptionBtn.MouseLeave:Connect(function()
		                TweenService:Create(OptionBtn, TweenInfo.new(0.15), {
		                    BackgroundColor3 = Library.Theme.Background,
		                    TextColor3 = Library.Theme.MutedText
		                }):Play()
		            end)
		
		            OptionBtn.MouseButton1Click:Connect(function()
		                SetSelected(option)
		                ToggleDropdown(false)
		            end)
		        end
		    end
		
		    SelectedButton.MouseButton1Click:Connect(function()
		        ToggleDropdown()
		    end)
		
		    BuildOptions()
		
		    function DropdownObj:AddOptionElement(optionName, builderFunc)
		        local comp = EnsureOptionHolder(optionName)
		        if type(builderFunc) == "function" then
		            builderFunc(comp)
		        end
		        UpdateContainerHeight()
		    end
		
		    function DropdownObj:Set(option)
		        SetSelected(option)
		    end
		
		    function DropdownObj:Refresh(newOptions, targetSelection)
		        options = newOptions or {}
		        BuildOptions()
		        
		        local newSelect = targetSelection or options[1] or "None"
		        SetSelected(newSelect)
		    end
		
		    Library.Elements[flag] = DropdownObj
		    return DropdownObj
		end
		function Comp:AddColorpicker(text, defaultColor, useAlpha, defaultAlpha, flag, callback)
			if type(useAlpha) == "function" then
				callback = useAlpha
				flag = text
				useAlpha = false
				defaultAlpha = 1
			elseif type(defaultAlpha) == "function" then
				callback = defaultAlpha
				flag = useAlpha
				useAlpha = false
				defaultAlpha = 1
			elseif type(flag) == "function" then
				callback = flag
				flag = text
			end

			callback = callback or function() end
			flag = flag or text

			local currentColor = defaultColor or Color3.fromRGB(255, 255, 255)
			local originalColor = currentColor
			local currentAlpha = math.clamp(defaultAlpha or 1, 0, 1)
			Library.Flags[flag] = currentColor

			local ColorpickerFrame = Instance.new("Frame")
			ColorpickerFrame.Name = "ColorpickerFrame"
			ColorpickerFrame.Size = UDim2.new(1, 0, 0, 32)
			RegisterTheme(ColorpickerFrame, "BackgroundColor3", "Container")
			ColorpickerFrame.ClipsDescendants = true
			ColorpickerFrame.Parent = TargetContainer

			local FrameCorner = Instance.new("UICorner")
			FrameCorner.CornerRadius = UDim.new(0, 5)
			FrameCorner.Parent = ColorpickerFrame

			local Label = Instance.new("TextLabel")
			Label.Size = UDim2.new(0.5, -10, 0, 32)
			Label.Position = UDim2.new(0, 10, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = text
			RegisterTheme(Label, "TextColor3", "Text")
			Label.TextSize = 13
			Label.Font = Enum.Font.SourceSans
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.Parent = ColorpickerFrame

			local ColorPreview = Instance.new("TextButton")
			ColorPreview.Size = UDim2.new(0, 45, 0, 20)
			ColorPreview.Position = UDim2.new(1, -55, 0, 6)
			ColorPreview.BackgroundColor3 = currentColor
			ColorPreview.BackgroundTransparency = 1 - currentAlpha
			ColorPreview.Text = ""
			ColorPreview.AutoButtonColor = false
			ColorPreview.Parent = ColorpickerFrame

			local PreviewCorner = Instance.new("UICorner")
			PreviewCorner.CornerRadius = UDim.new(0, 4)
			PreviewCorner.Parent = ColorPreview

			local function SetColor(newCol, newAlpha)
				if type(newCol) == "table" and newCol.R then
					newCol = Color3.new(newCol.R, newCol.G, newCol.B)
				end

				currentColor = newCol or Color3.fromRGB(255, 255, 255)
				if newAlpha then currentAlpha = newAlpha end
				Library.Flags[flag] = currentColor

				ColorPreview.BackgroundColor3 = currentColor
				ColorPreview.BackgroundTransparency = 1 - currentAlpha

				if useAlpha then
					callback(currentColor, currentAlpha)
				else
					callback(currentColor)
				end
			end

			local function OpenColorpickerWindow()
				if Library.ActiveColorpicker and Library.ActiveColorpicker.Name == "ColorpickerWindow_" .. text then
					Library.ActiveColorpicker:Destroy()
					Library.ActiveColorpicker = nil
					return
				end

				if Library.ActiveColorpicker then
					Library.ActiveColorpicker:Destroy()
					Library.ActiveColorpicker = nil
				end

				local windowWidth, windowHeight = 260, useAlpha and 280 or 255
				local ScreenGui = ColorpickerFrame:FindFirstAncestorWhichIsA("ScreenGui") or TargetContainer

				local Window = Instance.new("Frame")
				Window.Name = "ColorpickerWindow_" .. text
				Window.Size = UDim2.new(0, windowWidth, 0, windowHeight)
				Window.Position = UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2)
				RegisterTheme(Window, "BackgroundColor3", "Container")
				Window.BorderSizePixel = 0
				Window.ZIndex = 100
				Window.Parent = ScreenGui
				
				Library.ActiveColorpicker = Window

				local WindowCorner = Instance.new("UICorner")
				WindowCorner.CornerRadius = UDim.new(0, 6)
				WindowCorner.Parent = Window

				local TitleBar = Instance.new("Frame")
				TitleBar.Size = UDim2.new(1, 0, 0, 28)
				RegisterTheme(TitleBar, "BackgroundColor3", "Background")
				TitleBar.BorderSizePixel = 0
				TitleBar.ZIndex = 101
				TitleBar.Parent = Window

				local TitleCorner = Instance.new("UICorner")
				TitleCorner.CornerRadius = UDim.new(0, 6)
				TitleCorner.Parent = TitleBar

				local TitleLabel = Instance.new("TextLabel")
				TitleLabel.Size = UDim2.new(1, -30, 1, 0)
				TitleLabel.Position = UDim2.new(0, 10, 0, 0)
				TitleLabel.BackgroundTransparency = 1
				TitleLabel.Text = text .. " - Color Picker"
				RegisterTheme(TitleLabel, "TextColor3", "Text")
				TitleLabel.TextSize = 13
				TitleLabel.Font = Enum.Font.SourceSansBold
				TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
				TitleLabel.ZIndex = 102
				TitleLabel.Parent = TitleBar

				local CloseBtn = Instance.new("TextButton")
				CloseBtn.Size = UDim2.new(0, 28, 0, 28)
				CloseBtn.Position = UDim2.new(1, -28, 0, 0)
				CloseBtn.BackgroundTransparency = 1
				CloseBtn.Text = "X"
				RegisterTheme(CloseBtn, "TextColor3", "Text")
				CloseBtn.TextSize = 12
				CloseBtn.Font = Enum.Font.SourceSansBold
				CloseBtn.ZIndex = 102
				CloseBtn.Parent = TitleBar

				CloseBtn.MouseButton1Click:Connect(function()
					if Library.ActiveColorpicker == Window then
						Library.ActiveColorpicker:Destroy()
						Library.ActiveColorpicker = nil
					else
						Window:Destroy()
					end
				end)

				local dragging, dragInput, dragStart, startPos
				TitleBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						dragStart = input.Position
						startPos = Window.Position
						input.Changed:Connect(function()
							if input.UserInputState == Enum.UserInputState.End then
								dragging = false
							end
						end)
					end
				end)

				TitleBar.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						dragInput = input
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if input == dragInput and dragging then
						local delta = input.Position - dragStart
						Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
					end
				end)

				local PickerHolder = Instance.new("Frame")
				PickerHolder.Size = UDim2.new(1, -20, 1, -38)
				PickerHolder.Position = UDim2.new(0, 10, 0, 32)
				PickerHolder.BackgroundTransparency = 1
				PickerHolder.ZIndex = 101
				PickerHolder.Parent = Window

				local SVCanvas = Instance.new("TextButton")
				SVCanvas.Size = UDim2.new(0, 130, 0, 120)
				SVCanvas.Position = UDim2.new(0, 0, 0, 0)
				SVCanvas.BackgroundColor3 = currentColor
				SVCanvas.AutoButtonColor = false
				SVCanvas.Text = ""
				SVCanvas.ZIndex = 102
				SVCanvas.Parent = PickerHolder

				local SVCorner = Instance.new("UICorner")
				SVCorner.CornerRadius = UDim.new(0, 3)
				SVCorner.Parent = SVCanvas

				-- Vertical Black/Darkness Gradient (Value)
				local ValueGradient = Instance.new("UIGradient")
				ValueGradient.Rotation = 90
				ValueGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0))
				ValueGradient.Parent = SVCanvas

				-- Horizontal White Gradient Overlay (Saturation)
				local SaturationOverlay = Instance.new("Frame")
				SaturationOverlay.Size = UDim2.new(1, 0, 1, 0)
				SaturationOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				SaturationOverlay.BorderSizePixel = 0
				SaturationOverlay.ZIndex = 102
				SaturationOverlay.Parent = SVCanvas

				local SatCorner = Instance.new("UICorner")
				SatCorner.CornerRadius = UDim.new(0, 3)
				SatCorner.Parent = SaturationOverlay

				local SaturationGradient = Instance.new("UIGradient")
				SaturationGradient.Rotation = 0
				SaturationGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1)
				})
				SaturationGradient.Parent = SaturationOverlay

				local SVKnob = Instance.new("Frame")
				SVKnob.Size = UDim2.new(0, 8, 0, 8)
				SVKnob.AnchorPoint = Vector2.new(0.5, 0.5)
				SVKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				SVKnob.BorderSizePixel = 0
				SVKnob.ZIndex = 104
				SVKnob.Parent = SVCanvas

				local KnobCorner = Instance.new("UICorner")
				KnobCorner.CornerRadius = UDim.new(1, 0)
				KnobCorner.Parent = SVKnob

				local HueBar = Instance.new("TextButton")
				HueBar.Size = UDim2.new(0, 16, 0, 120)
				HueBar.Position = UDim2.new(0, 136, 0, 0)
				HueBar.AutoButtonColor = false
				HueBar.Text = ""
				HueBar.ZIndex = 102
				HueBar.Parent = PickerHolder

				local HueCorner = Instance.new("UICorner")
				HueCorner.CornerRadius = UDim.new(0, 3)
				HueCorner.Parent = HueBar

				local HueGradient = Instance.new("UIGradient")
				HueGradient.Rotation = 90
				HueGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
				})
				HueGradient.Parent = HueBar

				local SwatchesFrame = Instance.new("Frame")
				SwatchesFrame.Size = UDim2.new(1, -158, 0, 120)
				SwatchesFrame.Position = UDim2.new(0, 158, 0, 0)
				SwatchesFrame.BackgroundTransparency = 1
				SwatchesFrame.ZIndex = 102
				SwatchesFrame.Parent = PickerHolder

				local CurrentLabel = Instance.new("TextLabel")
				CurrentLabel.Size = UDim2.new(1, 0, 0, 14)
				CurrentLabel.BackgroundTransparency = 1
				CurrentLabel.Text = "Current"
				RegisterTheme(CurrentLabel, "TextColor3", "Text")
				CurrentLabel.TextSize = 11
				CurrentLabel.Font = Enum.Font.SourceSans
				CurrentLabel.TextXAlignment = Enum.TextXAlignment.Left
				CurrentLabel.ZIndex = 102
				CurrentLabel.Parent = SwatchesFrame

				local CurrentBox = Instance.new("Frame")
				CurrentBox.Size = UDim2.new(1, 0, 0, 32)
				CurrentBox.Position = UDim2.new(0, 0, 0, 15)
				CurrentBox.BackgroundColor3 = currentColor
				CurrentBox.BackgroundTransparency = 0 -- Opaque display
				CurrentBox.BorderSizePixel = 0
				CurrentBox.ZIndex = 102
				CurrentBox.Parent = SwatchesFrame

				local OriginalLabel = Instance.new("TextLabel")
				OriginalLabel.Size = UDim2.new(1, 0, 0, 14)
				OriginalLabel.Position = UDim2.new(0, 0, 0, 52)
				OriginalLabel.BackgroundTransparency = 1
				OriginalLabel.Text = "Original"
				RegisterTheme(OriginalLabel, "TextColor3", "Text")
				OriginalLabel.TextSize = 11
				OriginalLabel.Font = Enum.Font.SourceSans
				OriginalLabel.TextXAlignment = Enum.TextXAlignment.Left
				OriginalLabel.ZIndex = 102
				OriginalLabel.Parent = SwatchesFrame

				local OriginalBox = Instance.new("Frame")
				OriginalBox.Size = UDim2.new(1, 0, 0, 32)
				OriginalBox.Position = UDim2.new(0, 0, 0, 67)
				OriginalBox.BackgroundColor3 = originalColor
				OriginalBox.BackgroundTransparency = 0
				OriginalBox.BorderSizePixel = 0
				OriginalBox.ZIndex = 102
				OriginalBox.Parent = SwatchesFrame

				local ReadoutFrame = Instance.new("Frame")
				ReadoutFrame.Size = UDim2.new(1, 0, 0, 40)
				ReadoutFrame.Position = UDim2.new(0, 0, 0, 126)
				ReadoutFrame.BackgroundTransparency = 1
				ReadoutFrame.ZIndex = 102
				ReadoutFrame.Parent = PickerHolder

				local function CreateReadout(name, position, size)
					local Box = Instance.new("TextBox")
					Box.Size = size
					Box.Position = position
					RegisterTheme(Box, "BackgroundColor3", "Background")
					RegisterTheme(Box, "TextColor3", "Text")
					Box.TextSize = 11
					Box.Font = Enum.Font.SourceSans
					Box.Text = name .. ": 0"
					Box.ClearTextOnFocus = false
					Box.ZIndex = 103
					Box.Parent = ReadoutFrame

					local Corner = Instance.new("UICorner")
					Corner.CornerRadius = UDim.new(0, 2)
					Corner.Parent = Box
					return Box
				end

				local rBox = CreateReadout("R", UDim2.new(0, 0, 0, 0), UDim2.new(0.31, 0, 0, 18))
				local gBox = CreateReadout("G", UDim2.new(0.34, 0, 0, 0), UDim2.new(0.31, 0, 0, 18))
				local bBox = CreateReadout("B", UDim2.new(0.68, 0, 0, 0), UDim2.new(0.32, 0, 0, 18))

				local hBox = CreateReadout("H", UDim2.new(0, 0, 0, 21), UDim2.new(0.31, 0, 0, 18))
				local sBox = CreateReadout("S", UDim2.new(0.34, 0, 0, 21), UDim2.new(0.31, 0, 0, 18))
				local vBox = CreateReadout("V", UDim2.new(0.68, 0, 0, 21), UDim2.new(0.32, 0, 0, 18))

				local HexBox = Instance.new("TextBox")
				HexBox.Size = UDim2.new(1, 0, 0, 20)
				HexBox.Position = UDim2.new(0, 0, 0, 172)
				RegisterTheme(HexBox, "BackgroundColor3", "Background")
				RegisterTheme(HexBox, "TextColor3", "Text")
				HexBox.TextSize = 12
				HexBox.Font = Enum.Font.SourceSans
				HexBox.TextXAlignment = Enum.TextXAlignment.Left
				HexBox.Text = "#" .. currentColor:ToHex()
				HexBox.ZIndex = 103
				HexBox.Parent = PickerHolder

				local HexCorner = Instance.new("UICorner")
				HexCorner.CornerRadius = UDim.new(0, 2)
				HexCorner.Parent = HexBox

				local h, s, v = currentColor:ToHSV()
				local draggingHue, draggingSV, draggingAlpha = false, false, false

				local AlphaBar, AlphaFill
				if useAlpha then
					AlphaBar = Instance.new("TextButton")
					AlphaBar.Size = UDim2.new(1, 0, 0, 14)
					AlphaBar.Position = UDim2.new(0, 0, 0, 198)
					RegisterTheme(AlphaBar, "BackgroundColor3", "Background")
					AlphaBar.AutoButtonColor = false
					AlphaBar.Text = ""
					AlphaBar.ZIndex = 102
					AlphaBar.Parent = PickerHolder

					local AlphaCorner = Instance.new("UICorner")
					AlphaCorner.CornerRadius = UDim.new(0, 2)
					AlphaCorner.Parent = AlphaBar

					AlphaFill = Instance.new("Frame")
					AlphaFill.Size = UDim2.new(currentAlpha, 0, 1, 0)
					AlphaFill.BackgroundColor3 = currentColor
					AlphaFill.BorderSizePixel = 0
					AlphaFill.ZIndex = 103
					AlphaFill.Parent = AlphaBar

					local FillCorner = Instance.new("UICorner")
					FillCorner.CornerRadius = UDim.new(0, 2)
					FillCorner.Parent = AlphaFill
				end

				local function UpdateColor(skipInputs)
					local newCol = Color3.fromHSV(h, s, v)
					SetColor(newCol, currentAlpha)

					CurrentBox.BackgroundColor3 = currentColor
					CurrentBox.BackgroundTransparency = 0
					SVCanvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					SVKnob.Position = UDim2.new(s, 0, 1 - v, 0)

					if not skipInputs then
						rBox.Text = "R: " .. math.floor(currentColor.R * 255)
						gBox.Text = "G: " .. math.floor(currentColor.G * 255)
						bBox.Text = "B: " .. math.floor(currentColor.B * 255)

						hBox.Text = "H: " .. math.floor(h * 360)
						sBox.Text = "S: " .. math.floor(s * 100)
						vBox.Text = "V: " .. math.floor(v * 100)

						HexBox.Text = "#" .. currentColor:ToHex():upper()
					end

					if useAlpha and AlphaFill then
						AlphaFill.BackgroundColor3 = currentColor
						AlphaFill.Size = UDim2.new(currentAlpha, 0, 1, 0)
					end
				end

				HueBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						draggingHue = true
						local relativeY = math.clamp(input.Position.Y - HueBar.AbsolutePosition.Y, 0, HueBar.AbsoluteSize.Y)
						h = relativeY / HueBar.AbsoluteSize.Y
						UpdateColor()
					end
				end)

				SVCanvas.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						draggingSV = true
						local relativeX = math.clamp(input.Position.X - SVCanvas.AbsolutePosition.X, 0, SVCanvas.AbsoluteSize.X)
						local relativeY = math.clamp(input.Position.Y - SVCanvas.AbsolutePosition.Y, 0, SVCanvas.AbsoluteSize.Y)
						s = relativeX / SVCanvas.AbsoluteSize.X
						v = 1 - (relativeY / SVCanvas.AbsoluteSize.Y)
						UpdateColor()
					end
				end)

				if useAlpha and AlphaBar then
					AlphaBar.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							draggingAlpha = true
							local relativeX = math.clamp(input.Position.X - AlphaBar.AbsolutePosition.X, 0, AlphaBar.AbsoluteSize.X)
							currentAlpha = relativeX / AlphaBar.AbsoluteSize.X
							UpdateColor()
						end
					end)
				end

				HexBox.FocusLost:Connect(function()
					local hexStr = HexBox.Text:gsub("#", "")
					local success, result = pcall(function()
						return Color3.fromHex(hexStr)
					end)

					if success and result then
						currentColor = result
						h, s, v = currentColor:ToHSV()
						UpdateColor()
					else
						HexBox.Text = "#" .. currentColor:ToHex():upper()
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if draggingHue then
							local relativeY = math.clamp(input.Position.Y - HueBar.AbsolutePosition.Y, 0, HueBar.AbsoluteSize.Y)
							h = relativeY / HueBar.AbsoluteSize.Y
							UpdateColor()
						elseif draggingSV then
							local relativeX = math.clamp(input.Position.X - SVCanvas.AbsolutePosition.X, 0, SVCanvas.AbsoluteSize.X)
							local relativeY = math.clamp(input.Position.Y - SVCanvas.AbsolutePosition.Y, 0, SVCanvas.AbsoluteSize.Y)
							s = relativeX / SVCanvas.AbsoluteSize.X
							v = 1 - (relativeY / SVCanvas.AbsoluteSize.Y)
							UpdateColor()
						elseif draggingAlpha and useAlpha and AlphaBar then
							local relativeX = math.clamp(input.Position.X - AlphaBar.AbsolutePosition.X, 0, AlphaBar.AbsoluteSize.X)
							currentAlpha = relativeX / AlphaBar.AbsoluteSize.X
							UpdateColor()
						end
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						draggingHue = false
						draggingSV = false
						draggingAlpha = false
					end
				end)

				UpdateColor()
			end

			ColorPreview.MouseButton1Click:Connect(OpenColorpickerWindow)

			Library.Elements[flag] = { 
				Set = function(self, newCol, newAlpha)
					SetColor(newCol, newAlpha)
				end 
			}
		end

		function Comp:AddTextbox(text, placeholderText, defaultText, flag, callback)
			if type(flag) == "function" then
				callback = flag
				flag = text
			end
			callback = callback or function() end
			flag = flag or text

			placeholderText = placeholderText or "Enter text..."
			defaultText = defaultText or ""
			Library.Flags[flag] = defaultText

			local TextboxFrame = Instance.new("Frame")
			TextboxFrame.Name = "TextboxFrame"
			TextboxFrame.Size = UDim2.new(1, 0, 0, 32)
			RegisterTheme(TextboxFrame, "BackgroundColor3", "Container")
			TextboxFrame.Parent = TargetContainer

			local FrameCorner = Instance.new("UICorner")
			FrameCorner.CornerRadius = UDim.new(0, 5)
			FrameCorner.Parent = TextboxFrame

			local Label = Instance.new("TextLabel")
			Label.Size = UDim2.new(0.5, -10, 1, 0)
			Label.Position = UDim2.new(0, 10, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = text
			RegisterTheme(Label, "TextColor3", "Text")
			Label.TextSize = 13
			Label.Font = Enum.Font.SourceSans
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.Parent = TextboxFrame

			local InputBox = Instance.new("TextBox")
			InputBox.Size = UDim2.new(0.5, -10, 0, 22)
			InputBox.Position = UDim2.new(0.5, 0, 0.5, -11)
			RegisterTheme(InputBox, "BackgroundColor3", "Background")
			InputBox.Text = defaultText
			InputBox.PlaceholderText = placeholderText
			RegisterTheme(InputBox, "PlaceholderColor3", "MutedText")
			RegisterTheme(InputBox, "TextColor3", "Text")
			InputBox.TextSize = 12
			InputBox.Font = Enum.Font.SourceSans
			InputBox.ClearTextOnFocus = false
			InputBox.Parent = TextboxFrame

			local InputCorner = Instance.new("UICorner")
			InputCorner.CornerRadius = UDim.new(0, 4)
			InputCorner.Parent = InputBox

			local function SetText(txt)
				InputBox.Text = txt
				Library.Flags[flag] = txt
				callback(txt, true)
			end

			InputBox.Focused:Connect(function()
				TweenService:Create(InputBox, TweenInfo.new(0.2), {
					BackgroundColor3 = Library.Theme.Separator
				}):Play()
			end)

			InputBox.FocusLost:Connect(function(enterPressed)
				TweenService:Create(InputBox, TweenInfo.new(0.2), {
					BackgroundColor3 = Library.Theme.Background
				}):Play()
				Library.Flags[flag] = InputBox.Text
				callback(InputBox.Text, enterPressed)
			end)

			Library.Elements[flag] = { 
				Set = function(self, val)
					SetText(val)
				end 
			}
		end

		return Comp
	end

	function Window:CreateTab(tabName)
		local Tab = {}

		local TabButton = Instance.new("TextButton")
		TabButton.Name = tabName .. "TabButton"
		TabButton.Size = UDim2.new(0, 100, 1, -3)
		RegisterTheme(TabButton, "BackgroundColor3", "Container")
		TabButton.Text = tabName
		RegisterTheme(TabButton, "TextColor3", "MutedText")
		TabButton.TextSize = 13
		TabButton.Font = Enum.Font.SourceSansBold
		TabButton.AutoButtonColor = false
		TabButton.Parent = TabBar

		local TabBtnCorner = Instance.new("UICorner")
		TabBtnCorner.CornerRadius = UDim.new(0, 5)
		TabBtnCorner.Parent = TabButton

		local PageFrame = Instance.new("Frame")
		PageFrame.Name = tabName .. "PageFrame"
		PageFrame.Size = UDim2.new(1, 0, 1, 0)
		PageFrame.BackgroundTransparency = 1
		PageFrame.Visible = false
		PageFrame.Parent = PageContainer

		local MainScroll = Instance.new("ScrollingFrame")
		MainScroll.Name = tabName .. "MainScroll"
		MainScroll.Size = UDim2.new(1, 0, 1, 0)
		MainScroll.BackgroundTransparency = 1
		MainScroll.BorderSizePixel = 0
		MainScroll.ScrollBarThickness = 4
		MainScroll.Parent = PageFrame

		-- Container setup for 2 distinct fixed-width columns
		local ColumnHolder = Instance.new("Frame")
		ColumnHolder.Name = "ColumnHolder"
		ColumnHolder.Size = UDim2.new(1, 0, 1, 0)
		ColumnHolder.BackgroundTransparency = 1
		ColumnHolder.Parent = MainScroll

		local HolderLayout = Instance.new("UIListLayout")
		HolderLayout.FillDirection = Enum.FillDirection.Horizontal
		HolderLayout.Padding = UDim.new(0, 8)
		HolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
		HolderLayout.Parent = ColumnHolder

		-- FIXED WIDTH LEFT COLUMN (200px)
		local LeftColumn = Instance.new("Frame")
		LeftColumn.Name = "LeftColumn"
		LeftColumn.Size = UDim2.new(0, 200, 0, 0)
		LeftColumn.BackgroundTransparency = 1
		LeftColumn.Parent = ColumnHolder

		local LeftLayout = Instance.new("UIListLayout")
		LeftLayout.Padding = UDim.new(0, 8)
		LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
		LeftLayout.Parent = LeftColumn

		-- FIXED WIDTH RIGHT COLUMN (200px)
		local RightColumn = Instance.new("Frame")
		RightColumn.Name = "RightColumn"
		RightColumn.Size = UDim2.new(0, 200, 0, 0)
		RightColumn.BackgroundTransparency = 1
		RightColumn.Parent = ColumnHolder

		local RightLayout = Instance.new("UIListLayout")
		RightLayout.Padding = UDim.new(0, 8)
		RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
		RightLayout.Parent = RightColumn

		-- Update scroll canvas vertically and dynamically recalculate bounds
		local function UpdateCanvas()
			local leftH = LeftLayout.AbsoluteContentSize.Y
			local rightH = RightLayout.AbsoluteContentSize.Y
			local maxH = math.max(leftH, rightH)
			MainScroll.CanvasSize = UDim2.new(0, 0, 0, maxH + 10)

			if Window.ActiveTab == Tab then
				local contentW = LeftColumn.Size.X.Offset + RightColumn.Size.X.Offset + HolderLayout.Padding.Offset
				AdjustWindowBounds(contentW, maxH)
			end
		end

		LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
		RightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

		local BaseComponents = CreateComponents(MainScroll)
		for k, v in pairs(BaseComponents) do
			Tab[k] = v
		end

		local subCount = 0
		function Tab:CreateSubSection(subName, forceColumn)
			subCount = subCount + 1
			local targetCol = LeftColumn
			if forceColumn == "Right" or (not forceColumn and subCount % 2 == 0) then
				targetCol = RightColumn
			end

			local CardFrame = Instance.new("Frame")
			CardFrame.Name = subName .. "Card"
			CardFrame.Size = UDim2.new(1, 0, 0, 36)
			RegisterTheme(CardFrame, "BackgroundColor3", "Background")
			CardFrame.BorderSizePixel = 0
			CardFrame.Parent = targetCol

			local CardCorner = Instance.new("UICorner")
			CardCorner.CornerRadius = UDim.new(0, 6)
			CardCorner.Parent = CardFrame

			local CardPadding = Instance.new("UIPadding")
			CardPadding.PaddingTop = UDim.new(0, 8)
			CardPadding.PaddingBottom = UDim.new(0, 8)
			CardPadding.PaddingLeft = UDim.new(0, 8)
			CardPadding.PaddingRight = UDim.new(0, 8)
			CardPadding.Parent = CardFrame

			local TitleLabel = Instance.new("TextLabel")
			TitleLabel.Name = "CardTitle"
			TitleLabel.Size = UDim2.new(1, 0, 0, 20)
			TitleLabel.BackgroundTransparency = 1
			TitleLabel.Text = subName
			RegisterTheme(TitleLabel, "TextColor3", "Text")
			TitleLabel.TextSize = 13
			TitleLabel.Font = Enum.Font.SourceSansBold
			TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
			TitleLabel.Parent = CardFrame

			local ElementsHolder = Instance.new("Frame")
			ElementsHolder.Name = "ElementsHolder"
			ElementsHolder.Size = UDim2.new(1, 0, 0, 0)
			ElementsHolder.Position = UDim2.new(0, 0, 0, 24)
			ElementsHolder.BackgroundTransparency = 1
			ElementsHolder.Parent = CardFrame

			local ElementsLayout = Instance.new("UIListLayout")
			ElementsLayout.Padding = UDim.new(0, 6)
			ElementsLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ElementsLayout.Parent = ElementsHolder

			ElementsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				local newContentHeight = ElementsLayout.AbsoluteContentSize.Y
				ElementsHolder.Size = UDim2.new(1, 0, 0, newContentHeight)
				CardFrame.Size = UDim2.new(1, 0, 0, newContentHeight + 40)
			end)

			local SubSection = CreateComponents(ElementsHolder)
			SubSection.Container = CardFrame

			return SubSection
		end

		local function SelectTab()
			for _, t in pairs(Window.Tabs) do
				t.PageFrame.Visible = false
				TweenService:Create(t.Button, TweenInfo.new(0.2), {
					TextColor3 = Library.Theme.MutedText
				}):Play()
			end

			PageFrame.Visible = true
			
			TweenService:Create(TabButton, TweenInfo.new(0.2), {
				TextColor3 = Library.Theme.Text
			}):Play()

			Window.ActiveTab = Tab
			UpdateActiveLine()
			UpdateCanvas()
		end

		TabButton.MouseButton1Click:Connect(SelectTab)

		Tab.Button = TabButton
		Tab.PageFrame = PageFrame
		table.insert(Window.Tabs, Tab)

		if #Window.Tabs == 1 then
			task.spawn(function()
				task.wait()
				SelectTab()
			end)
		end

		return Tab
	end
	return Window
end

return Library
