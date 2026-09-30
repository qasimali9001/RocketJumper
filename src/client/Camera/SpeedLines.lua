-- Short streaks on the screen edge, each aimed at the center. Does not write velocity.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Class = require(game:GetService("ReplicatedStorage"):WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local SpeedLines = {}
SpeedLines.__index = SpeedLines

function SpeedLines.new(config, camera)
	local self = Class.instance(SpeedLines)
	self._config = config
	self._camera = camera
	self._gui = nil
	self._streaks = {}
	self._render = nil
	return self
end

function SpeedLines:start()
	if self._gui or not self._config.Enabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedLines"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui

	local count = math.max(1, self._config.Count)
	for index = 1, count do
		local frame = Instance.new("Frame")
		frame.Name = "Streak"
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.BackgroundColor3 = self._config.Color
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		table.insert(self._streaks, {
			frame = frame,
			angle = (index - 1) / count * math.pi * 2,
			phase = (index - 1) / count,
		})
	end

	self._render = RunService.RenderStepped:Connect(function()
		self:_draw()
	end)
end

function SpeedLines:destroy()
	if self._render then
		self._render:Disconnect()
		self._render = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	table.clear(self._streaks)
end

function SpeedLines:_draw()
	local config = self._config
	local alpha = 0
	if self._camera then
		alpha = self._camera:widenAlpha()
	end
	local size = self._gui.AbsoluteSize
	if size.X < 2 or size.Y < 2 then
		return
	end
	local cx = size.X * 0.5
	local cy = size.Y * 0.5
	local scroll = config.Scroll * (0.35 + alpha)
	local clock = os.clock()
	local length = config.Length * (0.75 + 0.25 * alpha)
	for _, streak in self._streaks do
		local travel = (streak.phase + clock * scroll) % 1
		local dirX = math.cos(streak.angle)
		local dirY = math.sin(streak.angle)
		local reach = math.huge
		if math.abs(dirX) > 0.0001 then
			reach = math.min(reach, cx / math.abs(dirX))
		end
		if math.abs(dirY) > 0.0001 then
			reach = math.min(reach, cy / math.abs(dirY))
		end
		local inset = config.EdgeInset + (1 - travel) * config.Travel
		local dist = math.max(0, reach - inset)
		local x = cx + dirX * dist
		local y = cy + dirY * dist
		streak.frame.Position = UDim2.fromOffset(x, y)
		streak.frame.Size = UDim2.fromOffset(length, config.Thickness)
		streak.frame.Rotation = math.deg(math.atan2(cy - y, cx - x))
		local shown = alpha * math.sin(travel * math.pi)
		streak.frame.BackgroundTransparency = 1 - shown * (1 - config.PeakTransparency)
	end
end

return SpeedLines
