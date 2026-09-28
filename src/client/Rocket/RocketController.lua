-- Fires a local projectile and asks the movement controller to add the blast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local Explosion = require(script.Parent.Explosion)

local RocketController = {}
RocketController.__index = RocketController

function RocketController.new(config, input, movement, character)
	local self = Class.instance(RocketController)
	self._config = config
	self._input = input
	self._movement = movement
	self._character = character
	self._rockets = {}
	self._nextFireAt = 0
	self._heartbeat = nil
	self._params = RaycastParams.new()
	self._params.FilterType = Enum.RaycastFilterType.Exclude
	self._params.FilterDescendantsInstances = { character }
	return self
end

function RocketController:start()
	if self._heartbeat then
		return
	end
	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function RocketController:destroy()
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
	for _, rocket in self._rockets do
		if rocket.part then
			rocket.part:Destroy()
		end
	end
	table.clear(self._rockets)
	self._movement = nil
end

function RocketController:_step(dt)
	if self._movement == nil then
		return
	end
	self:_tryFire()

	for index = #self._rockets, 1, -1 do
		local rocket = self._rockets[index]
		local displacement = rocket.velocity * dt
		local hit = workspace:Raycast(rocket.position, displacement, self._params)
		if hit then
			self:_detonate(hit.Position)
			rocket.part:Destroy()
			table.remove(self._rockets, index)
		else
			rocket.position += displacement
			rocket.age += dt
			rocket.part.CFrame = CFrame.lookAt(rocket.position, rocket.position + rocket.velocity)
			if rocket.age >= self._config.MaxLifetime then
				rocket.part:Destroy()
				table.remove(self._rockets, index)
			end
		end
	end
end

function RocketController:_tryFire()
	local config = self._config
	if os.clock() < self._nextFireAt then
		return
	end
	if not self._input:hasFire(config.FireBuffer) then
		return
	end
	self._input:consumeFire()
	self._nextFireAt = os.clock() + config.Cooldown
	self:_launch()
end

function RocketController:_launch()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local config = self._config
	local look = camera.CFrame.LookVector
	local origin = camera.CFrame.Position + look * config.SpawnForward

	local part = Instance.new("Part")
	part.Name = "Rocket"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(config.RocketSize, config.RocketSize, config.RocketSize)
	part.Color = config.RocketColor
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.lookAt(origin, origin + look)
	part.Parent = workspace

	table.insert(self._rockets, {
		part = part,
		position = origin,
		velocity = look * config.RocketSpeed,
		age = 0,
	})
end

function RocketController:_detonate(position)
	local root = self._character and self._character:FindFirstChild("HumanoidRootPart")
	if root and self._movement then
		local impulse = Explosion.impulse(self._config, position, root.Position)
		self._movement:addImpulse(impulse)
	end
	Explosion.burst(self._config, position)
end

return RocketController
