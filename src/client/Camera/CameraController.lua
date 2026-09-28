-- First person, mouse lock, and local head visibility. Does not write velocity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new(config, player)
	local self = Class.instance(CameraController)
	self._config = config
	self._player = player
	self._character = nil
	self._added = nil
	self._render = nil
	self._mouseLocked = true
	self._started = false
	return self
end

function CameraController:start()
	if self._started then
		return
	end
	self._started = true
	self:_applyMode()
	self._render = RunService.RenderStepped:Connect(function()
		self:_applyMode()
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

function CameraController:destroy()
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
