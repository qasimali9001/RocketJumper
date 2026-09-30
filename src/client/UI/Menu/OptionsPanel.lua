-- Music, effects, and mouse sensitivity. Does not write velocity.

local UserInputService = game:GetService("UserInputService")

local OptionsPanel = {}
OptionsPanel.__index = OptionsPanel

function OptionsPanel.new(config, bindings)
	local self = setmetatable({}, OptionsPanel)
	self._config = config
	self._bindings = bindings
	self._frame = nil
	self._rows = {}
	self._drag = nil
	self._connections = {}
	return self
end

function OptionsPanel:mount(parent)
	local config = self._config
	local frame = Instance.new("Frame")
	frame.Name = "Options"
	frame.LayoutOrder = 20
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(config.ButtonWidth, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, config.Gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	self._frame = frame
	self:_row(config.Music, self._bindings.music, 1, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)
	self:_row(config.Effects, self._bindings.effects, 2, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)
	self:_row(config.Sensitivity, self._bindings.sensitivity, 3, function(value)
		return string.format("%.2f", value)
	end)

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if self._drag and input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_apply(self._drag, input.Position.X)
		end
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._drag = nil
		end
	end))
	self:refresh()
	return frame
end

function OptionsPanel:refresh()
	for _, row in self._rows do
		self:_show(row, row.binding.get())
	end
end

function OptionsPanel:setVisible(visible)
	if self._frame then
		self._frame.Visible = visible
	end
end

function OptionsPanel:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

function OptionsPanel:_row(spec, binding, order, format)
	local config = self._config
	local row = Instance.new("Frame")
	row.Name = spec.Label
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(config.ButtonWidth, config.ButtonHeight + 22)
	row.Parent = self._frame

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.6, 0, 0, 18)
	name.Font = config.BodyFont
	name.TextSize = 16
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = config.Muted
	name.Text = spec.Label
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.new(0.4, 0, 0, 18)
	value.Font = config.Font
	value.TextSize = 16
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = config.Text
	value.Text = ""
	value.Parent = row

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 22)
	track.Size = UDim2.new(1, 0, 0, config.ButtonHeight - 16)
	track.BackgroundColor3 = config.Track
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.Corner)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = config.Fill
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, config.Corner)
	fillCorner.Parent = fill

	local entry = {
		spec = spec,
		binding = binding,
		format = format,
		track = track,
		fill = fill,
		value = value,
	}
	table.insert(self._rows, entry)
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._drag = entry
			self:_apply(entry, input.Position.X)
		end
	end)
end

function OptionsPanel:_apply(row, mouseX)
	local spec = row.spec
	local width = row.track.AbsoluteSize.X
	local alpha = 0
	if width > 0 then
		alpha = math.clamp((mouseX - row.track.AbsolutePosition.X) / width, 0, 1)
	end
	local raw = spec.Min + (spec.Max - spec.Min) * alpha
	local steps = math.floor((raw - spec.Min) / spec.Step + 0.5)
	local value = math.clamp(spec.Min + steps * spec.Step, spec.Min, spec.Max)
	row.binding.set(value)
	self:_show(row, value)
end

function OptionsPanel:_show(row, value)
	local spec = row.spec
	local span = spec.Max - spec.Min
	local alpha = 0
	if span > 0 and typeof(value) == "number" then
		alpha = math.clamp((value - spec.Min) / span, 0, 1)
	end
	row.fill.Size = UDim2.fromScale(alpha, 1)
	row.value.Text = row.format(typeof(value) == "number" and value or spec.Min)
end

return OptionsPanel
