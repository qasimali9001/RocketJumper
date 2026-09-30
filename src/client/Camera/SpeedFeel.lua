-- Maps horizontal speed to the 0-1 widen used by field of view and the side streaks.
-- Curve above 1 stays flat, then bends up near the top speed.

local SpeedFeel = {}

function SpeedFeel.alpha(fov, speed)
	if fov.SpeedForMax <= 0 then
		return 0
	end
	local t = math.clamp(speed / fov.SpeedForMax, 0, 1)
	local curve = fov.Curve
	if typeof(curve) ~= "number" or curve <= 0 then
		curve = 1
	end
	return t ^ curve
end

return SpeedFeel
