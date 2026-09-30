-- Run clock. Starts when the server says you left the pad. Layout comes from HudConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local TimerHud = {}
TimerHud.__index = TimerHud

local function formatTime(seconds)
	return string.format("%.2f", math.max(0, seconds))
end

function TimerHud.new(config)
	local self = Class.instance(TimerHud)
	self._config = config
	self._label = nil
	self._timerStart = nil
	self._connections = {}
	return self
end

function TimerHud:start()
	if self._label then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "TimerHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12

	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = config.Position
	label.Size = UDim2.fromOffset(220, config.TextSize + 8)
	label.BackgroundTransparency = 1
	label.Font = config.Font
	label.TextSize = config.TextSize
	label.TextColor3 = config.Color
	label.Text = formatTime(0)
	label.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._label = label

	table.insert(self._connections, CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end))
	table.insert(self._connections, RunService.RenderStepped:Connect(function()
		self:_tick()
	end))
end

function TimerHud:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._label then
		self._label.Parent:Destroy()
		self._label = nil
	end
	self._timerStart = nil
end

function TimerHud:_onCourse(payload)
	if typeof(payload) ~= "table" or self._label == nil then
		return
	end
	if payload.kind == "timer" or payload.kind == "sync" then
		self._timerStart = payload.timerStart
		if self._timerStart == nil then
			self._label.Text = formatTime(0)
		end
	elseif payload.kind == "reset" then
		self._timerStart = nil
		self._label.Text = formatTime(0)
	elseif payload.kind == "finish" then
		self._timerStart = nil
		self._label.Text = formatTime(payload.elapsed or 0)
	end
end

function TimerHud:_tick()
	if self._label == nil or self._timerStart == nil then
		return
	end
	self._label.Text = formatTime(workspace:GetServerTimeNow() - self._timerStart)
end

return TimerHud
