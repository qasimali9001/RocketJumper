-- One row per map. The active row is the course that plays.
-- A model in Workspace is edited in place. A model only in ServerStorage/Maps is cloned at run start.

return {
	{
		id = "serpentine",
		displayName = "Serpentine",
		modelName = "Serpentine",
		active = true,
	},
	{
		id = "straightaway",
		displayName = "Straightaway",
		modelName = "Straightaway",
		active = false,
	},
	{
		id = "flat_yard",
		displayName = "Flat Yard",
		modelName = "FlatYard",
		active = false,
	},
	{
		id = "pyramid",
		displayName = "Pyramid",
		modelName = "Pyramid",
		active = false,
	},
}
