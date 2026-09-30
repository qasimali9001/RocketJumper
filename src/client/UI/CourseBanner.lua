-- Shows the finish line for a few seconds. Does not move the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local CourseRemotes = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("CourseRemotes"))

local CourseBanner = {}
CourseBanner.__index = CourseBanner

function CourseBanner.new(config)
	local self = Class.instance(CourseBanner)
	self._config = config
	self._label = nil
	self._connection = nil
	self._token = 0
	return self
end

function CourseBanner:start()
	if self._label then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "CourseBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = config.Position
	label.Size = UDim2.fromOffset(360, config.TextSize + 8)
	label.BackgroundTransparency = 1
	label.Font = config.Font
	label.TextSize = config.TextSize
	label.TextColor3 = config.Color
	label.Text = config.Text
	label.Visible = false
	label.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._label = label
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "finish" then
			self:_show(string.format("%.2f", math.max(0, tonumber(payload.elapsed) or 0)))
		elseif payload.kind == "map" and typeof(payload.mapName) == "string" then
			self:_show(payload.mapName)
		end
	end)
end

function CourseBanner:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._label then
		self._label.Parent:Destroy()
		self._label = nil
	end
end

function CourseBanner:_show(text)
	local label = self._label
	if label == nil then
		return
	end
	self._token += 1
	local token = self._token
	label.Text = text
	label.Visible = true
	task.delay(self._config.Seconds, function()
		if self._token == token and self._label then
			self._label.Visible = false
		end
	end)
end

return CourseBanner
