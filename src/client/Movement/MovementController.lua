-- Owns ground move, air strafe, jump, and gravity. Writes root velocity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local GroundProbe = require(script.Parent.GroundProbe)

local MovementController = {}
MovementController.__index = MovementController

function MovementController.new(config, character, input)
	local self = Class.instance(MovementController)
	self._config = config
	self._character = character
	self._input = input
	self._groundProbe = GroundProbe.new(config)
	self._velocity = Vector3.zero
	self._onSpeed = nil
	self._root = nil
	self._humanoid = nil
	self._preSim = nil
	self._wallParams = nil
	self._died = nil
	self._destroyed = false
	self._blastLift = false
	return self
end

function MovementController:start(onSpeed)
	self._onSpeed = onSpeed
	self._root = self._character:WaitForChild("HumanoidRootPart")
	self._humanoid = self._character:WaitForChild("Humanoid")
	self._groundProbe:setCharacter(self._character)
	self:_claimRig()
	workspace.Gravity = 0

	self._wallParams = RaycastParams.new()
	self._wallParams.FilterType = Enum.RaycastFilterType.Exclude
	self._wallParams.FilterDescendantsInstances = { self._character }

	self._preSim = RunService.PreSimulation:Connect(function(dt)
		self:_step(math.min(dt, self._config.DtCap))
	end)
	self._died = self._humanoid.Died:Connect(function()
		self:destroy()
	end)
end

function MovementController:addImpulse(impulse)
	if self._destroyed then
		return
	end
	self._velocity += impulse
	if impulse.Y > 0 then
		self._blastLift = true
	end
end

function MovementController:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._preSim then
		self._preSim:Disconnect()
	end
	if self._died then
		self._died:Disconnect()
	end
end

function MovementController:_claimRig()
	local humanoid = self._humanoid
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.UseJumpPower = true
	pcall(function()
		humanoid.EvaluateStateMachine = false
	end)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	self:_disableDefaultControls()
end

function MovementController:_disableDefaultControls()
	local player = Players.LocalPlayer
	local playerScripts = player:FindFirstChild("PlayerScripts")
	if playerScripts == nil then
		return
	end
	local moduleScript = playerScripts:FindFirstChild("PlayerModule")
	if moduleScript == nil then
		return
	end
	local ok, playerModule = pcall(require, moduleScript)
	if ok and playerModule.GetControls then
		playerModule:GetControls():Disable()
	end
end

function MovementController:_step(dt)
	local root = self._root
	local humanoid = self._humanoid
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local config = self._config
	local onFloor, floorY = self._groundProbe:probe(root, humanoid)
	local axisX, axisZ = self._input:getMoveAxes()
	local wishDir = self:_wishDirection(axisX, axisZ)

	local horizontal = Vector3.new(self._velocity.X, 0, self._velocity.Z)
	local vertical = self._velocity.Y
	local launched = false

	-- A rising rig is airborne even if the ground ray still reaches the floor.
	-- A blast that has not left the floor yet still takes the buffered jump, so both pushes count.
	local blastLift = self._blastLift
	self._blastLift = false
	if onFloor and self._input:hasJumpBuffered() and (vertical <= 0 or blastLift) then
		self._input:consumeJump()
		vertical = math.max(vertical, 0) + config.JumpSpeed
		launched = true
	end

	local grounded = onFloor and not launched and vertical <= 0
	if grounded then
		horizontal = self:_applyFriction(horizontal, dt)
		if wishDir then
			horizontal = self:_accelerate(horizontal, wishDir, config.GroundMaxSpeed, config.GroundAccel, dt)
		end
		vertical = 0
	else
		if wishDir then
			horizontal = self:_airAccelerate(horizontal, wishDir, dt)
		end
		if not launched then
			vertical -= config.Gravity * dt
		end
		vertical = math.max(vertical, -config.MaxFallSpeed)
	end

	horizontal = self:_slideOnWalls(horizontal, dt)
	self._velocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
	self:_placeRig(floorY, grounded)
	root.AssemblyAngularVelocity = Vector3.zero
	root.AssemblyLinearVelocity = self._velocity

	if self._onSpeed then
		self._onSpeed({
			horizontal = horizontal.Magnitude,
			vertical = vertical,
			grounded = grounded,
		})
	end
end

function MovementController:_placeRig(floorY, snapToFloor)
	local root = self._root
	local humanoid = self._humanoid
	local position = root.Position
	local y = position.Y
	if snapToFloor and floorY ~= nil then
		y = floorY + root.Size.Y * 0.5 + humanoid.HipHeight
	end

	local look = self:_flatLook()
	local origin = Vector3.new(position.X, y, position.Z)
	root.CFrame = CFrame.lookAt(origin, origin + look)
end

function MovementController:_slideOnWalls(horizontal, dt)
	local speed = horizontal.Magnitude
	if speed < 1 or self._wallParams == nil then
		return horizontal
	end
	local reach = self._root.Size.X * 0.5 + speed * dt + self._config.GroundSkin
	local result = workspace:Raycast(self._root.Position, horizontal.Unit * reach, self._wallParams)
	if result == nil or result.Normal.Y >= self._config.MinGroundNormalY then
		return horizontal
	end
	local intoWall = horizontal:Dot(result.Normal)
	if intoWall < 0 then
		return horizontal - result.Normal * intoWall
	end
	return horizontal
end

function MovementController:_wishDirection(axisX, axisZ)
	if axisX == 0 and axisZ == 0 then
		return nil
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if forward.Magnitude < 0.001 or right.Magnitude < 0.001 then
		return nil
	end
	local wish = forward.Unit * axisZ + right.Unit * axisX
	if wish.Magnitude < 0.001 then
		return nil
	end
	return wish.Unit
end

function MovementController:_flatLook()
	local camera = workspace.CurrentCamera
	local forward = Vector3.new(0, 0, -1)
	if camera ~= nil then
		forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	end
	if forward.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

function MovementController:_applyFriction(horizontal, dt)
	local speed = horizontal.Magnitude
	if speed < 0.1 then
		return Vector3.zero
	end
	local config = self._config
	local control = math.max(speed, config.StopSpeed)
	local drop = control * config.GroundFriction * dt
	local newSpeed = math.max(speed - drop, 0)
	return horizontal * (newSpeed / speed)
end

function MovementController:_airAccelerate(horizontal, wishDir, dt)
	local config = self._config
	local wishSpeed = config.AirWishSpeed
	local cappedWish = math.min(wishSpeed, config.AirSpeedCap)
	local currentSpeed = horizontal:Dot(wishDir)
	local addSpeed = cappedWish - currentSpeed
	if addSpeed <= 0 then
		return horizontal
	end
	local accelSpeed = config.AirAccelerate * wishSpeed * dt
	if accelSpeed > addSpeed then
		accelSpeed = addSpeed
	end
	local add = wishDir * accelSpeed
	local speed = horizontal.Magnitude
	if speed > 0.1 then
		local along = horizontal / speed
		local alongAdd = add:Dot(along)
		if alongAdd < 0 then
			add = add - along * alongAdd * (1 - config.AirBrake)
		end
	end
	return horizontal + add
end

function MovementController:_accelerate(horizontal, wishDir, wishSpeed, accel, dt)
	local currentSpeed = horizontal:Dot(wishDir)
	local addSpeed = wishSpeed - currentSpeed
	if addSpeed <= 0 then
		return horizontal
	end
	local accelSpeed = math.min(accel * wishSpeed * dt, addSpeed)
	return horizontal + wishDir * accelSpeed
end

return MovementController
