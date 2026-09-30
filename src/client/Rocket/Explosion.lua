-- Falloff impulse and the short burst at the impact point.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Explosion = {}

function Explosion.impulse(config, origin, targetPosition)
	local offset = targetPosition - origin
	local distance = offset.Magnitude
	if distance > config.ExplosionRadius then
		return Vector3.zero
	end

	-- Treat a nearby blast as this many studs lower than the impact. The rocket
	-- still lands on the crosshair. A shot around the torso lifts the same way
	-- while rising and while falling. 0 keeps the raw angle.
	local biased = offset + Vector3.yAxis * (config.SelfUpBias or 0)
	local direction = Vector3.yAxis
	if biased.Magnitude > 0.05 then
		direction = biased.Unit
	end

	local falloff = 1 - (distance / config.ExplosionRadius)
	local strength = config.ExplosionForce * config.SelfForceMultiplier * falloff
	return direction * strength
end

local function ghost(name, shape, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	return part
end

local function fade(part, time, goal)
	if time <= 0 then
		part:Destroy()
		return
	end
	local tween = TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
	Debris:AddItem(part, time + 0.05)
end

function Explosion.burst(config, burst, position)
	if burst == nil or not burst.Enabled then
		return
	end
	local radius = config.ExplosionRadius
	if burst.CoreTime > 0 then
		local core = ghost("RocketCore", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), CFrame.new(position), burst.CoreColor)
		local diameter = math.max(2, radius * 0.42)
		fade(core, burst.CoreTime, {
			Size = Vector3.new(diameter, diameter, diameter),
			Transparency = 1,
		})
	end
	if burst.RingTime > 0 then
		local ring = ghost(
			"RocketRing",
			Enum.PartType.Cylinder,
			Vector3.new(0.28, 1.6, 1.6),
			CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			burst.RingColor
		)
		ring.Transparency = 0.25
		local diameter = math.max(4, radius * 1.6)
		fade(ring, burst.RingTime, {
			Size = Vector3.new(0.16, diameter, diameter),
			Transparency = 1,
		})
	end
	local count = burst.SparkCount or 0
	if burst.SparkTime > 0 and count > 0 then
		local travel = math.max(4, radius * 0.55)
		for _ = 1, count do
			local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
			if direction.Magnitude < 0.05 then
				direction = Vector3.yAxis
			else
				direction = direction.Unit
			end
			local spark = ghost("RocketSpark", Enum.PartType.Ball, Vector3.new(0.45, 0.45, 0.45), CFrame.new(position), burst.SparkColor)
			fade(spark, burst.SparkTime, {
				Position = position + direction * travel,
				Size = Vector3.new(0.08, 0.08, 0.08),
				Transparency = 1,
			})
		end
	end
end

return Explosion
