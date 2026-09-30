-- Reports rocket impacts, applies a server reset, and sends the reset key.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseConfig = require(Shared:WaitForChild("Config"):WaitForChild("CourseConfig"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local CourseController = {}
CourseController.__index = CourseController

function CourseController.new(input)
	local self = Class.instance(CourseController)
	self._input = input
	self._movement = nil
	self._pending = nil
	self._connections = {}
	return self
end

function CourseController:start()
	if self._connections[1] then
		return
	end
	table.insert(self._connections, CourseRemotes.respawn().OnClientEvent:Connect(function(cframe)
		self:_apply(cframe)
	end))
	table.insert(self._connections, RunService.Heartbeat:Connect(function()
		if self._input:consumeReset() then
			CourseRemotes.reset():FireServer()
		end
		if self._input:consumeCycle() then
			CourseRemotes.cycle():FireServer()
		end
	end))
	CourseRemotes.hello():FireServer()
end

function CourseController:reportImpact(instance)
	local id = self:_targetId(instance)
	if id then
		CourseRemotes.targetHit():FireServer(id)
	end
end

function CourseController:setMovement(movement)
	self._movement = movement
	if movement and self._pending then
		local cframe = self._pending
		self._pending = nil
		movement:placeAt(cframe)
	end
end

function CourseController:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._movement = nil
	self._pending = nil
end

function CourseController:_apply(cframe)
	if typeof(cframe) ~= "CFrame" then
		return
	end
	if self._movement and self._movement:isActive() then
		self._movement:placeAt(cframe)
	else
		self._pending = cframe
	end
end

function CourseController:_targetId(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("BasePart") and CollectionService:HasTag(current, CourseConfig.Tags.Target) then
			local id = current:GetAttribute("Id")
			if typeof(id) == "string" and id ~= "" then
				return id
			end
		end
		current = current.Parent
	end
	return nil
end

return CourseController
