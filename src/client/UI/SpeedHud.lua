-- Horizontal speed, air or ground, and vertical speed. Layout comes from HudConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local SpeedHud = {}
SpeedHud.__index = SpeedHud

function SpeedHud.new(config)
	local self = Class.instance(SpeedHud)
	self._config = config
	self._gui = nil
	self._speedLabel = nil
	self._stateLabel = nil
	self._verticalLabel = nil
	return self
end

function SpeedHud:start()
	if self._gui then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local speed = self:_label(config.SpeedTextSize, config.Position)
	speed.Name = "Speed"
	speed.Parent = gui

	local state = self:_label(config.DetailTextSize, config.Position + UDim2.fromOffset(0, 36))
	state.Name = "State"
	state.Parent = gui

	local vertical = self:_label(config.DetailTextSize, config.Position + UDim2.fromOffset(0, 56))
	vertical.Name = "Vertical"
	vertical.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui
	self._speedLabel = speed
	self._stateLabel = state
	self._verticalLabel = vertical
	self:setSpeed({
		horizontal = 0,
		vertical = 0,
		grounded = true,
	})
end

function SpeedHud:setSpeed(sample)
	if self._speedLabel == nil then
		return
	end
	local config = self._config
	self._speedLabel.Text = string.format("%d", math.floor(sample.horizontal + 0.5))
	self._verticalLabel.Text = string.format("vy %d", math.floor(sample.vertical + 0.5))
	if sample.grounded then
		self._stateLabel.Text = "GROUND"
		self._stateLabel.TextColor3 = config.GroundColor
	else
		self._stateLabel.Text = "AIR"
		self._stateLabel.TextColor3 = config.AirColor
	end
end

function SpeedHud:destroy()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._speedLabel = nil
	self._stateLabel = nil
	self._verticalLabel = nil
end

function SpeedHud:_label(textSize, position)
	local config = self._config
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = UDim2.fromOffset(280, textSize + 8)
	label.BackgroundTransparency = 1
	label.Font = config.Font
	label.TextSize = textSize
	label.TextColor3 = config.Color
	label.TextStrokeTransparency = config.StrokeTransparency
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = ""
	return label
end

return SpeedHud
