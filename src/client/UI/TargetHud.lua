-- Cleared and total targets. Layout comes from HudConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local TargetHud = {}
TargetHud.__index = TargetHud

function TargetHud.new(config)
	local self = Class.instance(TargetHud)
	self._config = config
	self._label = nil
	self._hint = nil
	self._connection = nil
	return self
end

function TargetHud:start()
	if self._label then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "TargetHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12

	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = config.Position
	label.Size = UDim2.fromOffset(220, config.TextSize + 6)
	label.BackgroundTransparency = 1
	label.Font = config.Font
	label.TextSize = config.TextSize
	label.TextColor3 = config.Color
	label.Text = "0 / 0"
	label.Parent = gui

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = config.Position + UDim2.fromOffset(0, config.TextSize + 2)
	hint.Size = UDim2.fromOffset(220, config.HintSize + 4)
	hint.BackgroundTransparency = 1
	hint.Font = config.Font
	hint.TextSize = config.HintSize
	hint.TextColor3 = config.HintColor
	hint.Text = config.Hint
	hint.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._label = label
	self._hint = hint
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end)
end

function TargetHud:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._label then
		self._label.Parent:Destroy()
		self._label = nil
	end
	self._hint = nil
end

function TargetHud:_onCourse(payload)
	if typeof(payload) ~= "table" or self._label == nil then
		return
	end
	if payload.cleared == nil or payload.total == nil then
		return
	end
	self._label.Text = string.format("%d / %d", payload.cleared, payload.total)
	if payload.finishOpen then
		self._label.TextColor3 = self._config.OpenColor
	else
		self._label.TextColor3 = self._config.Color
	end
end

return TargetHud
