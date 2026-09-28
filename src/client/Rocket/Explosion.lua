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

	local direction = Vector3.yAxis
	if distance > 0.05 then
		direction = offset.Unit
	end

	local falloff = 1 - (distance / config.ExplosionRadius)
	local strength = config.ExplosionForce * config.SelfForceMultiplier * falloff
	return direction * strength
end

function Explosion.burst(config, position)
	local ball = Instance.new("Part")
	ball.Name = "RocketBurst"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.Neon
	ball.Color = config.BurstColor
	ball.Size = Vector3.new(1, 1, 1)
	ball.CFrame = CFrame.new(position)
	ball.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = config.ExplosionSoundId
	sound.Volume = 0.7
	sound.RollOffMaxDistance = 180
	sound.Parent = ball
	sound:Play()

	local diameter = config.ExplosionRadius * 0.85
	local tween = TweenService:Create(ball, TweenInfo.new(config.BurstTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(diameter, diameter, diameter),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ball, config.BurstTime + 0.05)
end

return Explosion
