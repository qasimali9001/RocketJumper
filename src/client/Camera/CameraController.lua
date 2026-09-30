-- First person, mouse lock, local head visibility, speed field of view, and blast shake.
-- Does not write velocity.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local SpeedFeel = require(script.Parent.SpeedFeel)

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new(config, polish, player)
	local self = Class.instance(CameraController)
	self._config = config
	self._polish = polish
	self._player = player
	self._character = nil
	self._added = nil
	self._render = nil
	self._mouseLocked = true
	self._started = false
	self._speed = 0
	self._fov = polish.Fov.Base
	self._kick = 0
	self._shake = 0
	self._shakeStrength = 0
	return self
end

function CameraController:start()
	if self._started then
		return
	end
	self._started = true
	self:_applyMode()
	self._render = RunService.RenderStepped:Connect(function(dt)
		self:_applyMode()
		self:_applyFeel(dt)
	end)
	GuiService.MenuOpened:Connect(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
	if self._player.Character then
		self:setCharacter(self._player.Character)
	end
end

function CameraController:setCharacter(character)
	self._character = character
	self:_hideLocalHead()
	if self._added then
		self._added:Disconnect()
	end
	self._added = character.DescendantAdded:Connect(function()
		self:_hideLocalHead()
	end)
end

function CameraController:setMouseLocked(locked)
	self._mouseLocked = locked
	self:_applyMode()
end

function CameraController:widenAlpha()
	local fov = self._polish.Fov
	if fov.MaxBonus <= 0 then
		return 0
	end
	return math.clamp((self._fov - fov.Base) / fov.MaxBonus, 0, 1)
end

function CameraController:setSpeed(horizontal)
	if typeof(horizontal) == "number" then
		self._speed = horizontal
	end
end

function CameraController:kick()
	local fov = self._polish.Fov
	if fov.Kick <= 0 or fov.KickTime <= 0 then
		return
	end
	self._kick = fov.KickTime
end

function CameraController:shake(strength)
	local shake = self._polish.Shake
	if shake.MaxOffset <= 0 or shake.Duration <= 0 then
		return
	end
	if typeof(strength) ~= "number" then
		return
	end
	self._shake = shake.Duration
	self._shakeStrength = math.clamp(strength, 0, 1)
end

function CameraController:destroy()
	self:_clearShake()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = self._polish.Fov.Base
	end
	if self._render then
		self._render:Disconnect()
		self._render = nil
	end
	if self._added then
		self._added:Disconnect()
		self._added = nil
	end
	self._started = false
end

function CameraController:_applyMode()
	if GuiService.MenuIsOpen then
		return
	end
	local config = self._config
	local player = self._player
	if config.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	end
	if config.LockMouse and self._mouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	elseif not self._mouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function CameraController:_applyFeel(dt)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local fov = self._polish.Fov
	local bonus = 0
	if fov.MaxBonus > 0 then
		bonus = fov.MaxBonus * SpeedFeel.alpha(fov, self._speed)
	end
	local target = fov.Base + bonus
	if fov.Ease <= 0 then
		self._fov = target
	else
		local alpha = 1 - math.exp(-fov.Ease * dt)
		self._fov += (target - self._fov) * alpha
	end
	local kick = 0
	if self._kick > 0 and fov.KickTime > 0 and fov.Kick > 0 then
		kick = fov.Kick * (self._kick / fov.KickTime)
		self._kick = math.max(0, self._kick - dt)
	end
	camera.FieldOfView = self._fov + kick
	self:_applyShake(dt)
end

function CameraController:_applyShake(dt)
	local humanoid = self._character and self._character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local shake = self._polish.Shake
	if self._shake <= 0 or shake.MaxOffset <= 0 or shake.Duration <= 0 then
		if humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
		end
		return
	end
	local falloff = self._shake / shake.Duration
	self._shake = math.max(0, self._shake - dt)
	local amp = shake.MaxOffset * self._shakeStrength * falloff
	humanoid.CameraOffset = Vector3.new(
		(math.random() - 0.5) * 2 * amp,
		(math.random() - 0.5) * 2 * amp,
		0
	)
end

function CameraController:_clearShake()
	local humanoid = self._character and self._character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
	self._shake = 0
end

function CameraController:_hideLocalHead()
	local character = self._character
	if character == nil or not self._config.HideLocalHead then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "Head" or descendant:FindFirstAncestorOfClass("Accessory") ~= nil or descendant:FindFirstAncestorOfClass("Accoutrement") ~= nil) then
			descendant.LocalTransparencyModifier = 1
		end
	end
end

return CameraController
