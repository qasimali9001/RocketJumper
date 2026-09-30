-- Parts stand-in for export/Weapons.blend. Held on the camera. Does not write velocity.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local LauncherView = {}
LauncherView.__index = LauncherView

function LauncherView.new(config, muzzle)
	local self = Class.instance(LauncherView)
	self._config = config
	self._muzzle = muzzle
	self._model = nil
	self._render = nil
	return self
end

function LauncherView:start()
	if not self._config.LauncherEnabled then
		return
	end
	self._model = self:_build()
	self._render = RunService.RenderStepped:Connect(function()
		self:_place()
	end)
end

function LauncherView:flash()
	local muzzle = self._muzzle
	local barrel = self._model and self._model:FindFirstChild("Muzzle")
	if muzzle == nil or not muzzle.Enabled or muzzle.Time <= 0 or muzzle.Size <= 0 or barrel == nil then
		return
	end
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(muzzle.Size, muzzle.Size, muzzle.Size)
	flash.CFrame = barrel.CFrame
	flash.Color = muzzle.Color
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Parent = self._model
	local grow = muzzle.Size * 1.8
	local tween = TweenService:Create(flash, TweenInfo.new(muzzle.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(grow, grow, grow),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(flash, muzzle.Time + 0.05)
end

function LauncherView:destroy()
	if self._render then
		self._render:Disconnect()
		self._render = nil
	end
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
end

function LauncherView:_place()
	local camera = workspace.CurrentCamera
	if camera == nil or self._model == nil then
		return
	end
	if self._model.Parent ~= camera then
		self._model.Parent = camera
	end
	self._model:PivotTo(camera.CFrame * CFrame.new(self._config.HoldOffset))
end

function LauncherView:_cylinder(model, name, length, radius, center, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	-- Cylinder axis is local +X. Turn it to the camera's forward, -Z.
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0)
	part.Parent = model
	return part
end

function LauncherView:_box(model, name, size, center, color, pitch)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(center) * CFrame.Angles(pitch or 0, 0, 0)
	part.Parent = model
	return part
end

function LauncherView:_build()
	local config = self._config
	local model = Instance.new("Model")
	model.Name = "Launcher"
	local body = config.BodyColor
	local accent = config.AccentColor
	local grip = config.GripColor
	self:_cylinder(model, "Barrel", 1.45, 0.13, Vector3.new(0, 0.05, -0.42), body)
	self:_cylinder(model, "Muzzle", 0.12, 0.17, Vector3.new(0, 0.05, -1.12), accent)
	self:_cylinder(model, "Breach", 0.42, 0.18, Vector3.new(0, 0.05, 0.42), body)
	self:_cylinder(model, "Band", 0.07, 0.145, Vector3.new(0, 0.05, -0.85), accent)
	self:_box(model, "Sight", Vector3.new(0.06, 0.08, 0.14), Vector3.new(0, 0.22, -0.25), body)
	self:_box(model, "Grip", Vector3.new(0.11, 0.32, 0.1), Vector3.new(0, -0.22, 0.38), grip, math.rad(-18))
	self:_box(model, "Guard", Vector3.new(0.14, 0.04, 0.28), Vector3.new(0, -0.08, 0.22), body)
	-- Parts are laid out with the muzzle along -Z. The automatic pivot
	-- follows the cylinder rotation and would aim the barrel to the side.
	model.WorldPivot = CFrame.identity
	model.Parent = workspace.CurrentCamera
	return model
end

return LauncherView
