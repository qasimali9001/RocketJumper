-- Reads configured keys into move axes and a short jump buffer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local InputController = {}
InputController.__index = InputController

function InputController.new(config)
	local self = Class.instance(InputController)
	self._config = config
	self._down = {}
	self._jumpQueuedAt = nil
	self._tuneQueued = false
	self._fireQueuedAt = nil
	self._connections = {}
	self._started = false
	return self
end

function InputController:start()
	if self._started then
		return
	end
	self._started = true

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		self:_onBegan(input, processed)
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		self:_onEnded(input)
	end))
	table.insert(self._connections, UserInputService.WindowFocusReleased:Connect(function()
		table.clear(self._down)
		self._jumpQueuedAt = nil
		self._tuneQueued = false
		self._fireQueuedAt = nil
	end))
end

function InputController:getMoveAxes()
	local x = 0
	local z = 0
	if self:_anyDown(self._config.Right) then
		x += 1
	end
	if self:_anyDown(self._config.Left) then
		x -= 1
	end
	if self:_anyDown(self._config.Forward) then
		z += 1
	end
	if self:_anyDown(self._config.Back) then
		z -= 1
	end
	return x, z
end

function InputController:hasJumpBuffered()
	if self._jumpQueuedAt == nil then
		return false
	end
	if os.clock() - self._jumpQueuedAt > self._config.JumpBuffer then
		self._jumpQueuedAt = nil
		return false
	end
	return true
end

function InputController:consumeJump()
	self._jumpQueuedAt = nil
end

function InputController:consumeTune()
	if not self._tuneQueued then
		return false
	end
	self._tuneQueued = false
	return true
end

function InputController:hasFire(maxAge)
	if self._fireQueuedAt == nil then
		return false
	end
	if os.clock() - self._fireQueuedAt > maxAge then
		self._fireQueuedAt = nil
		return false
	end
	return true
end

function InputController:consumeFire()
	self._fireQueuedAt = nil
end

function InputController:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._down)
	self._jumpQueuedAt = nil
	self._tuneQueued = false
	self._fireQueuedAt = nil
	self._started = false
end

function InputController:_onBegan(input, _processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			return
		end
		self._fireQueuedAt = os.clock()
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	self._down[input.KeyCode] = true
	if self:_isListed(self._config.Jump, input.KeyCode) then
		self._jumpQueuedAt = os.clock()
	end
	if self._config.Tune and self:_isListed(self._config.Tune, input.KeyCode) then
		self._tuneQueued = true
	end
end

function InputController:_onEnded(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	self._down[input.KeyCode] = nil
end

function InputController:_anyDown(keyList)
	for _, keyCode in keyList do
		if self._down[keyCode] then
			return true
		end
	end
	return false
end

function InputController:_isListed(keyList, keyCode)
	for _, listed in keyList do
		if listed == keyCode then
			return true
		end
	end
	return false
end

return InputController
