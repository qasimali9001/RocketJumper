-- Music and one-shot cues. Volume 0 turns that cue off.
-- None of this writes velocity.
-- TimeAttack1.mp3 lives in audio/ and is copied into the Studio
-- content/sounds folder so rbxasset can play it. Cloud upload is still blocked.

return {
	Music = {
		Enabled = true,
		Volume = 0.4,
		Looped = true,
		SoundId = "rbxasset://sounds/TimeAttack1.mp3",
	},
	Fire = {
		Volume = 0.55,
		PlaybackSpeed = 1.15,
		SoundId = "rbxasset://sounds/action_jump_land.mp3",
	},
	Explosion = {
		Volume = 0.85,
		PlaybackSpeed = 1,
		SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
	},
	Target = {
		Volume = 0.55,
		PlaybackSpeed = 1.25,
		SoundId = "rbxasset://sounds/volume_slider.ogg",
	},
	Finish = {
		Volume = 0.7,
		PlaybackSpeed = 0.9,
		SoundId = "rbxasset://sounds/volume_slider.ogg",
	},
}
