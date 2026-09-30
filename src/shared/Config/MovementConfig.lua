-- Ground move, air strafe, jump, and gravity. Tune feel here only.
-- Workspace.Gravity is forced to 0 while a MovementController is running.
-- Gravity below is the acceleration the controller integrates itself (studs/s^2).

return {
	GroundMaxSpeed = 26,
	GroundAccel = 10,
	GroundFriction = 4,
	StopSpeed = 8,

	-- Source AirAccelerate (TF2, CS:S, CS:GO, CS2). Velocity you already have is kept.
	-- Keys only add speed along the wish direction, and only until that component
	-- reaches AirSpeedCap. Let go of W, hold A or D, and turn the mouse into the
	-- strafe. Holding forward while you are already faster than the cap does not steer.
	--
	-- AirAccelerate is sv_airaccelerate. CS2 and CS:GO use 12. TF2 and CS:S use 10.
	-- Higher changes direction faster in the air. Lower locks the arc. Past about 20
	-- it stops mattering, because AirSpeedCap is already filled in one frame.
	-- AirSpeedCap is Source's 30-unit air cap, in studs. Lower keeps more of the line.
	AirWishSpeed = 26,
	-- 7.5 is about 25% under the previous 10, so a strafe shoves the arc less.
	AirAccelerate = 7.5,
	AirSpeedCap = 7.5,
	-- Fraction of an air shove that is allowed to reduce speed you already have.
	-- Holding W and looking off your line shoves toward the look. 1 is the full
	-- shove. 0 keeps the speed and only keeps the part that does not fight it.
	AirBrake = 0.2,

	JumpSpeed = 64,
	Gravity = 180,
	MaxFallSpeed = 220,

	GroundSkin = 0.45,
	MinGroundNormalY = 0.7,
	-- Speed along a wall removed per second while the body is flush with it.
	-- Same units as GroundFriction. 0 leaves the slide. Higher kills a rocket
	-- shove along the face sooner. A brush that is not flush is unchanged.
	WallFriction = 8,
	DtCap = 1 / 20,
}
