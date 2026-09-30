-- One row per map. The active row is the course that plays.
-- A model in Workspace is edited in place. A model only in ServerStorage/Maps is cloned at run start.
-- A card is one row: summary is the line under the name, featured is the large card,
-- preview is the card image, shot from that level's spawn.
-- Files live in images/ and are copied into the Studio content/textures/RocketJumper folder.
-- Cloud upload is still blocked. Empty preview falls back to a live photograph.

return {
	{
		id = "serpentine",
		displayName = "Serpentine",
		modelName = "Serpentine",
		summary = "An enclosed S. Five targets along the bends.",
		featured = true,
		preview = "rbxasset://textures/RocketJumper/Serpentine.png",
		active = true,
	},
	{
		id = "straightaway",
		displayName = "Straightaway",
		modelName = "Straightaway",
		summary = "A straight time trial.",
		featured = false,
		preview = "",
		active = false,
	},
	{
		id = "flat_yard",
		displayName = "Flat Yard",
		modelName = "FlatYard",
		summary = "A flat yard for movement.",
		featured = false,
		preview = "",
		active = false,
	},
	{
		id = "pyramid",
		displayName = "Pyramid",
		modelName = "Pyramid",
		summary = "Four slopes. Eight targets on the way up.",
		featured = false,
		preview = "rbxasset://textures/RocketJumper/Pyramid.png",
		active = false,
	},
}
