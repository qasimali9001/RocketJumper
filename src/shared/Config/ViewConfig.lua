-- First-person launcher placement. Does not affect the shot or the blast.
-- Offset is camera space: +X right, +Y up, -Z forward.

return {
	LauncherEnabled = true,
	HoldOffset = Vector3.new(0.5, -0.36, -0.9),
	BodyColor = Color3.fromRGB(41, 43, 48),
	AccentColor = Color3.fromRGB(255, 107, 20),
	GripColor = Color3.fromRGB(18, 18, 20),
}
