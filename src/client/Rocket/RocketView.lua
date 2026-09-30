-- Parts stand-in for the rocket in export/Weapons.blend.
-- The nose points along -Z so lookAt aims it. This does not change the shot.

local RocketView = {}

local function cylinder(model, name, length, radius, center, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, radius * 2, radius * 2)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0)
	part.Parent = model
	return part
end

local function box(model, name, size, center, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(center)
	part.Parent = model
	return part
end

local function attachTrail(body, trail)
	if trail == nil or not trail.Enabled or trail.Lifetime <= 0 then
		return
	end
	local function point(name, offset)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = offset
		attachment.Parent = body
		return attachment
	end
	-- Body local -X is the nozzle. The two points sit across the flame so the ribbon has width.
	local back = point("Trail0", Vector3.new(-0.32, 0.22, 0))
	local front = point("Trail1", Vector3.new(-0.32, -0.22, 0))
	local ribbon = Instance.new("Trail")
	ribbon.Name = "Flame"
	ribbon.Attachment0 = back
	ribbon.Attachment1 = front
	ribbon.Lifetime = trail.Lifetime
	ribbon.MinLength = 0.05
	ribbon.FaceCamera = true
	ribbon.LightEmission = 0.75
	ribbon.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.Color = ColorSequence.new(trail.Color, trail.TailColor)
	ribbon.Parent = body
end

function RocketView.create(config, trail)
	local model = Instance.new("Model")
	model.Name = "Rocket"
	local bodyColor = config.RocketColor
	local metal = Color3.fromRGB(26, 28, 31)
	local nose = Color3.fromRGB(237, 237, 230)
	local body = cylinder(model, "Body", 0.48, 0.11, Vector3.new(0, 0, 0), bodyColor)
	attachTrail(body, trail)
	local tip = Instance.new("Part")
	tip.Name = "Nose"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.2, 0.2, 0.2)
	tip.Color = nose
	tip.Material = Enum.Material.SmoothPlastic
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.CastShadow = false
	tip.CFrame = CFrame.new(0, 0, -0.32)
	tip.Parent = model
	cylinder(model, "Nozzle", 0.1, 0.07, Vector3.new(0, 0, 0.29), metal)
	box(model, "FinX", Vector3.new(0.32, 0.02, 0.16), Vector3.new(0, 0, 0.16), metal)
	box(model, "FinY", Vector3.new(0.02, 0.32, 0.16), Vector3.new(0, 0, 0.16), metal)
	-- Nose and nozzle are laid out along -Z. The automatic pivot follows
	-- the body cylinder and would fly the rocket sideways.
	model.WorldPivot = CFrame.identity
	model.Parent = workspace
	return model
end

return RocketView
