-- Projectile, explosion, and rocket-jump timing. The movement controller never reads this.
-- Impulse is added to the velocity you already have. It does not replace it.

return {
	RocketSpeed = 160,
	SpawnForward = 2.5,
	MaxLifetime = 3,
	RocketSize = 0.55,
	RocketColor = Color3.fromRGB(255, 122, 26),

	ExplosionRadius = 23,
	ExplosionForce = 150,
	SelfForceMultiplier = 1.05,
	-- Studs. Added to the self-push only, so the blast is read as lower than
	-- the impact. 0 is the raw angle. The rocket still hits the crosshair.
	SelfUpBias = 3,
	BurstTime = 0.22,
	BurstColor = Color3.fromRGB(255, 196, 90),
	ExplosionSoundId = "rbxassetid://269146157",

	Cooldown = 0.7,
	FireBuffer = 0.12,
}
