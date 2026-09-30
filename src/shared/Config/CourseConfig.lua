-- Course rules and the tag names MapLoader looks for. Geometry does not live here.

return {
	RespawnDebounce = 0.35,
	SpawnLift = 5,
	Tags = {
		Start = "RJ_Start",
		Target = "RJ_Target",
		Kill = "RJ_Kill",
		Finish = "RJ_Finish",
	},
	FinishClosed = {
		Color = Color3.fromRGB(186, 48, 58),
		Transparency = 0.12,
		Material = Enum.Material.Neon,
	},
	FinishOpen = {
		Color = Color3.fromRGB(96, 255, 156),
		Transparency = 0.55,
		Material = Enum.Material.Neon,
	},
	TargetCleared = {
		Color = Color3.fromRGB(70, 74, 82),
		Transparency = 0.45,
		Material = Enum.Material.SmoothPlastic,
	},
}
