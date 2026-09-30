-- Center dot. Does not change the shot.

local Players = game:GetService("Players")

local Class = require(game:GetService("ReplicatedStorage"):WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local Crosshair = {}
Crosshair.__index = Crosshair

function Crosshair.new(config)
	local self = Class.instance(Crosshair)
	self._config = config
	self._gui = nil
	return self
end

function Crosshair:start()
	if self._gui or not self._config.Enabled or self._config.Size <= 0 then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 25

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(config.Size, config.Size)
	dot.BackgroundColor3 = config.Color
	dot.BackgroundTransparency = config.Transparency
	dot.BorderSizePixel = 0
	dot.Active = false
	dot.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui
end

function Crosshair:destroy()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return Crosshair
