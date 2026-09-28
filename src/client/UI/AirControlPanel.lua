-- Live sliders for air strafe, rocket blast, and look sensitivity. Writes config; does not move the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local AirControlPanel = {}
AirControlPanel.__index = AirControlPanel

function AirControlPanel.new(sections, configs, input, cameraController)
	local self = Class.instance(AirControlPanel)
	self._sections = sections
	self._configs = configs
	self._input = input
	self._camera = cameraController
	self._open = false
	self._dragId = nil
	self._rows = {}
	self._baseline = {}
	self._connections = {}
	self._gui = nil
	self._panels = {}
	self._chip = nil
	return self
end

function AirControlPanel:start()
	if self._gui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AirControlPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20

	for _, tune in self._sections do
		local panel = self:_buildPanel(tune)
		panel.Parent = gui
		table.insert(self._panels, panel)
		if tune.Chip and self._chip == nil then
			self._chip = self:_buildChip(tune, gui)
		end
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui

	table.insert(self._connections, self._chip.MouseButton1Click:Connect(function()
		self:_setOpen(true)
	end))
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		self:_onDrag(input)
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._dragId = nil
		end
	end))
	table.insert(self._connections, RunService.Heartbeat:Connect(function()
		if self._input:consumeTune() then
			self:_setOpen(not self._open)
		end
	end))
end

function AirControlPanel:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._camera:setMouseLocked(true)
end

function AirControlPanel:_setOpen(open)
	self._open = open
	for _, panel in self._panels do
		panel.Visible = open
	end
	self._chip.Visible = not open
	self._camera:setMouseLocked(not open)
	if not open then
		self._dragId = nil
	end
end

function AirControlPanel:_buildChip(tune, gui)
	local chip = Instance.new("TextButton")
	chip.Name = "Chip"
	chip.AnchorPoint = tune.AnchorPoint or Vector2.new(0, 0)
	chip.Position = tune.Position
	chip.Size = UDim2.fromOffset(tune.Width, 28)
	chip.BackgroundColor3 = tune.Background
	chip.BackgroundTransparency = tune.BackgroundTransparency
	chip.BorderSizePixel = 0
	chip.Font = tune.Font
	chip.TextSize = tune.HintSize
	chip.TextColor3 = tune.Text
	chip.Text = tune.Chip
	chip.AutoButtonColor = false
	chip.Parent = gui
	return chip
end

function AirControlPanel:_buildPanel(tune)
	local panel = Instance.new("Frame")
	panel.Name = tune.Title or "Panel"
	panel.AnchorPoint = tune.AnchorPoint or Vector2.new(0, 0)
	panel.Position = tune.Position
	panel.Size = UDim2.fromOffset(tune.Width, 10)
	panel.BackgroundColor3 = tune.Background
	panel.BackgroundTransparency = tune.BackgroundTransparency
	panel.BorderSizePixel = 0
	panel.Visible = false

	local title = self:_text(tune.TitleSize, tune.Font, tune.Text)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(tune.Padding, tune.Padding)
	title.Size = UDim2.new(1, -tune.Padding * 2, 0, tune.TitleSize + 2)
	title.Text = tune.Title or "Tune"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local hint = self:_text(tune.HintSize, tune.BodyFont, tune.Muted)
	hint.Name = "Hint"
	hint.Position = UDim2.fromOffset(tune.Padding, tune.Padding + tune.TitleSize + 4)
	hint.Size = UDim2.new(1, -tune.Padding * 2, 0, tune.HintSize + 4)
	hint.Text = tune.Hint or ""
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel

	local y = tune.Padding + tune.TitleSize + tune.HintSize + 16
	for _, spec in tune.Sliders do
		local value = self:_read(spec)
		self._baseline[spec.id] = value
		local row = self:_createRow(tune, spec, y)
		row.frame.Parent = panel
		self._rows[spec.id] = row
		self:_show(spec, value)
		y += tune.RowHeight
	end

	local reset = Instance.new("TextButton")
	reset.Name = "Reset"
	reset.Position = UDim2.fromOffset(tune.Padding, y)
	reset.Size = UDim2.new(1, -tune.Padding * 2, 0, 26)
	reset.BackgroundColor3 = tune.Track
	reset.BorderSizePixel = 0
	reset.Font = tune.Font
	reset.TextSize = tune.LabelSize
	reset.TextColor3 = tune.Text
	reset.Text = "Reset"
	reset.AutoButtonColor = true
	reset.Parent = panel
	y += 26 + tune.Padding
	panel.Size = UDim2.fromOffset(tune.Width, y)

	table.insert(self._connections, reset.MouseButton1Click:Connect(function()
		self:_reset(tune)
	end))

	return panel
end

function AirControlPanel:_createRow(tune, spec, y)
	local frame = Instance.new("Frame")
	frame.Name = spec.id
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(tune.Padding, y)
	frame.Size = UDim2.new(1, -tune.Padding * 2, 0, tune.RowHeight - 6)

	local label = self:_text(tune.LabelSize, tune.Font, tune.Text)
	label.Size = UDim2.new(0.72, 0, 0, tune.LabelSize + 2)
	label.Text = spec.label
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local value = self:_text(tune.ValueSize, tune.Font, tune.Fill)
	value.Size = UDim2.new(0.28, 0, 0, tune.ValueSize + 2)
	value.Position = UDim2.fromScale(0.72, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = frame

	local detail = self:_text(tune.HintSize, tune.BodyFont, tune.Muted)
	detail.Position = UDim2.fromOffset(0, tune.LabelSize + 2)
	detail.Size = UDim2.new(1, 0, 0, tune.HintSize + 2)
	detail.Text = spec.detail
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Parent = frame

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, tune.LabelSize + tune.HintSize + 8)
	track.Size = UDim2.new(1, 0, 0, 8)
	track.BackgroundColor3 = tune.Track
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = tune.Fill
	fill.BorderSizePixel = 0
	fill.Parent = track

	track.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		self._dragId = spec.id
		self:_setFromX(spec, input.Position.X)
	end)

	return {
		frame = frame,
		value = value,
		track = track,
		fill = fill,
		spec = spec,
	}
end

function AirControlPanel:_onDrag(input)
	if self._dragId == nil then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local row = self._rows[self._dragId]
	if row then
		self:_setFromX(row.spec, input.Position.X)
	end
end

function AirControlPanel:_setFromX(spec, mouseX)
	local row = self._rows[spec.id]
	local width = row.track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local alpha = (mouseX - row.track.AbsolutePosition.X) / width
	alpha = math.clamp(alpha, 0, 1)
	local raw = spec.min + (spec.max - spec.min) * alpha
	local steps = math.floor((raw - spec.min) / spec.step + 0.5)
	local value = math.clamp(spec.min + steps * spec.step, spec.min, spec.max)
	self:_write(spec, value)
	self:_show(spec, value)
end

function AirControlPanel:_show(spec, value)
	local row = self._rows[spec.id]
	local span = spec.max - spec.min
	local alpha = 0
	if span > 0 then
		alpha = math.clamp((value - spec.min) / span, 0, 1)
	end
	row.fill.Size = UDim2.fromScale(alpha, 1)
	row.value.Text = self:_format(spec, value)
end

function AirControlPanel:_reset(tune)
	for _, spec in tune.Sliders do
		local value = self._baseline[spec.id]
		self:_write(spec, value)
		self:_show(spec, value)
	end
end

function AirControlPanel:_read(spec)
	if spec.source == "mouse" then
		local ok, value = pcall(function()
			return UserSettings():GetService("UserGameSettings").MouseSensitivity
		end)
		if ok then
			return value
		end
		return spec.min
	end
	return self._configs[spec.source][spec.id]
end

function AirControlPanel:_write(spec, value)
	if spec.source == "mouse" then
		pcall(function()
			UserSettings():GetService("UserGameSettings").MouseSensitivity = value
		end)
		return
	end
	self._configs[spec.source][spec.id] = value
end

function AirControlPanel:_format(spec, value)
	local decimals = 0
	local step = spec.step
	while step < 1 and decimals < 3 do
		step *= 10
		decimals += 1
	end
	return string.format("%." .. decimals .. "f", value)
end

function AirControlPanel:_text(textSize, font, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = ""
	return label
end

return AirControlPanel
