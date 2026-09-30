-- Feel only. 0 or Enabled false turns that cue off.
-- Nothing here writes velocity or changes the blast shove.

return {
	Fov = {
		Base = 70,
		MaxBonus = 40,
		SpeedForMax = 140,
		-- 1 is a straight ramp. Higher holds the widen back, then bends it up near SpeedForMax.
		Curve = 2.6,
		Ease = 8,
		Kick = 7,
		KickTime = 0.14,
	},
	SpeedLines = {
		Enabled = true,
		Count = 18,
		Length = 52,
		Thickness = 2,
		-- Pixels. The line sits this far inside the screen edge, then slides out by Travel.
		EdgeInset = 10,
		Travel = 28,
		Scroll = 1.4,
		Color = Color3.fromRGB(255, 255, 255),
		PeakTransparency = 0.12,
	},
	Shake = {
		MaxOffset = 0.55,
		Duration = 0.14,
	},
	Burst = {
		Enabled = true,
		CoreTime = 0.16,
		RingTime = 0.32,
		SparkTime = 0.24,
		SparkCount = 8,
		CoreColor = Color3.fromRGB(255, 244, 220),
		RingColor = Color3.fromRGB(255, 148, 48),
		SparkColor = Color3.fromRGB(255, 196, 90),
	},
	Trail = {
		Enabled = true,
		Lifetime = 0.25,
		Color = Color3.fromRGB(255, 170, 54),
		TailColor = Color3.fromRGB(255, 78, 18),
	},
	TargetFlash = {
		Enabled = true,
		Time = 0.14,
		Grow = 1.55,
		Color = Color3.fromRGB(255, 244, 214),
	},
	Muzzle = {
		Enabled = true,
		Time = 0.07,
		Size = 0.55,
		Color = Color3.fromRGB(255, 220, 160),
	},
}
