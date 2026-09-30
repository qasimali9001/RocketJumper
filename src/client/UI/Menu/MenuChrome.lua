-- Shared menu buttons and stacks. Does not decide which screen is open.

local MenuChrome = {}

function MenuChrome.stack(parent, config, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.56)
	frame.Size = UDim2.fromOffset(config.ButtonWidth, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, config.Gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

function MenuChrome.button(parent, config, text, layoutOrder, activated)
	local button = Instance.new("TextButton")
	button.Name = text
	button.LayoutOrder = layoutOrder
	button.Size = UDim2.fromOffset(config.ButtonWidth, config.ButtonHeight)
	button.BackgroundColor3 = config.Button
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = config.Font
	button.TextSize = config.ButtonSize
	button.TextColor3 = config.Text
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.Corner)
	corner.Parent = button

	button.Activated:Connect(activated)
	return button
end

function MenuChrome.title(parent, config, text)
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.16)
	label.Size = UDim2.fromOffset(640, config.TitleSize + 8)
	label.Font = config.Font
	label.TextSize = config.TitleSize
	label.TextColor3 = config.Text
	label.Text = text
	label.Parent = parent
	return label
end

return MenuChrome
