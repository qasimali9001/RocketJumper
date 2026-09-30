-- One-shot. Paste into the Studio command bar while the game is not playing.
-- Builds the pyramid from parts, so nothing is uploaded as a mesh.
-- The model is shifted south of Serpentine so the two courses do not overlap.

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SCALE = 0.75
local PITCH = math.rad(45)
local RUN = 70 * SCALE
local LEDGE = 36 * SCALE
local HEIGHT = RUN * math.tan(PITCH)
local THICK = 8 * SCALE
local APRON_HALF = 476 * SCALE
local FOOT_HALF = 420 * SCALE
local ALCOVE_WIDTH = 34 * SCALE
local ALCOVE_ALONG = 26 * SCALE
local ALCOVE_DEPTH = 28 * SCALE
local TARGET_INSET = 7 * SCALE
local SHIFT = Vector3.new(0, 20, 4000)

local BLUE = Color3.fromRGB(45, 110, 220)
local YELLOW = Color3.fromRGB(235, 185, 40)

local FACES = {
	East = Vector3.xAxis,
	West = -Vector3.xAxis,
	South = Vector3.zAxis,
	North = -Vector3.zAxis,
}

local PLAN = {
	{ tier = 1, face = "South", id = "1" },
	{ tier = 1, face = "East", id = "2" },
	{ tier = 2, face = "West", id = "3" },
	{ tier = 2, face = "North", id = "4" },
	{ tier = 3, face = "East", id = "5" },
	{ tier = 3, face = "South", id = "6" },
	{ tier = 4, face = "North", id = "7" },
	{ tier = 4, face = "West", id = "8" },
}

local OVERLAP = 0.25 * SCALE
local tiers = {}
local radius = FOOT_HALF
local yCursor = -OVERLAP
for index = 1, 4 do
	local topRadius = radius - RUN
	local y0 = yCursor
	local y1 = y0 + HEIGHT
	table.insert(tiers, {
		r0 = radius,
		r1 = topRadius,
		y0 = y0,
		y1 = y1,
	})
	radius = topRadius - LEDGE
	yCursor = y1 + THICK - OVERLAP
end

local function slopeNormal(faceDir)
	return (faceDir * math.sin(PITCH) + Vector3.yAxis * math.cos(PITCH)).Unit
end

local function axes(zAxis)
	local xAxis = Vector3.yAxis:Cross(zAxis)
	if xAxis.Magnitude < 0.05 then
		xAxis = Vector3.xAxis:Cross(zAxis)
	end
	xAxis = xAxis.Unit
	local yAxis = zAxis:Cross(xAxis).Unit
	return xAxis, yAxis
end

local scratch = Instance.new("Folder")
scratch.Name = "_PyramidBuild"
scratch.Parent = workspace

local function subtract(source, cutter, fidelity)
	cutter.Parent = scratch
	local result = source:SubtractAsync({ cutter }, fidelity, Enum.RenderFidelity.Automatic)
	cutter:Destroy()
	source:Destroy()
	result.Anchored = true
	result.Parent = scratch
	return result
end

local function planeCutter(point, normal)
	-- A part bigger than 2048 is clamped, and the old 4000 cutter then sat
	-- entirely outside the block, so the slope cut removed nothing.
	local length = 1600
	local xAxis, yAxis = axes(normal)
	local cutter = Instance.new("Part")
	cutter.Name = "Cutter"
	cutter.Anchored = true
	cutter.CanCollide = false
	cutter.Size = Vector3.new(length, length, length)
	cutter.CFrame = CFrame.fromMatrix(point + normal * (length * 0.5), xAxis, yAxis, normal)
	return cutter
end

local function paint(piece, name, color)
	piece.Name = name
	if piece:IsA("PartOperation") then
		piece.UsePartColor = true
	end
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = true
	piece.CanQuery = true
	piece.CanTouch = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	return piece
end

local function slab(parent, name, half, topY)
	local piece = Instance.new("Part")
	piece.Size = Vector3.new(half * 2, THICK, half * 2)
	piece.CFrame = CFrame.new(0, topY - THICK * 0.5, 0)
	paint(piece, name, BLUE)
	piece.Parent = parent
	return piece
end

local function frustum(tier)
	local height = tier.y1 - tier.y0
	local block = Instance.new("Part")
	block.Size = Vector3.new(tier.r0 * 2, height, tier.r0 * 2)
	block.CFrame = CFrame.new(0, (tier.y0 + tier.y1) * 0.5, 0)
	block.Anchored = true
	block.Parent = scratch

	local solid = block
	for _, faceDir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local normal = slopeNormal(faceDir)
		local point = faceDir * tier.r0 + Vector3.yAxis * tier.y0
		solid = subtract(solid, planeCutter(point, normal), Enum.CollisionFidelity.Hull)
	end
	return solid
end

local function facePoint(tier, faceDir)
	local mid = 0.5
	local radiusAt = tier.r0 + (tier.r1 - tier.r0) * mid
	local yAt = tier.y0 + (tier.y1 - tier.y0) * mid
	local normal = slopeNormal(faceDir)
	local surface = faceDir * radiusAt + Vector3.yAxis * yAt
	return surface, normal
end

local function trimToSlope(piece, tier)
	local name = piece.Name
	local parent = piece.Parent
	local solid = piece
	for _, faceDir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local normal = slopeNormal(faceDir)
		local point = faceDir * tier.r0 + Vector3.yAxis * tier.y0 - normal * 0.2
		solid = subtract(solid, planeCutter(point, normal), Enum.CollisionFidelity.Hull)
	end
	paint(solid, name, BLUE)
	solid.Parent = parent
	return solid
end

local function alcoveCutter(tier, faceDir)
	local surface, normal = facePoint(tier, faceDir)
	local inward = -normal
	local across = faceDir:Cross(Vector3.yAxis).Unit
	local upSlope = inward:Cross(across).Unit
	if upSlope.Y < 0 then
		across = -across
		upSlope = inward:Cross(across).Unit
	end
	local cutter = Instance.new("Part")
	cutter.Name = "Alcove"
	cutter.Anchored = true
	cutter.CanCollide = false
	cutter.Size = Vector3.new(ALCOVE_WIDTH, ALCOVE_ALONG, ALCOVE_DEPTH)
	cutter.CFrame = CFrame.fromMatrix(surface + inward * (ALCOVE_DEPTH * 0.35), across, upSlope, inward)
	return cutter
end

ChangeHistoryService:SetWaypoint("Before pyramid build")

local previous = workspace:FindFirstChild("Pyramid")
if previous then
	if previous:GetAttribute("RJ_Source") == "parts" then
		previous:Destroy()
	else
		local parked = "PyramidOld"
		local n = 2
		while workspace:FindFirstChild(parked) do
			parked = "PyramidOld" .. n
			n += 1
		end
		previous.Name = parked
	end
end

local model = Instance.new("Model")
model.Name = "Pyramid"
model:SetAttribute("RJ_Source", "parts")
model.Parent = workspace

local apron = slab(model, "Apron", APRON_HALF, 0)
do
	local limit = APRON_HALF + FOOT_HALF
	local solid = apron
	for _, sign in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local normal = Vector3.new(sign[1], 0, sign[2]).Unit
		local point = normal * (limit * 0.5)
		solid = subtract(solid, planeCutter(point, normal), Enum.CollisionFidelity.Hull)
	end
	paint(solid, "Apron", BLUE)
	solid.Parent = model
end

local byTier = {}
for _, spot in PLAN do
	byTier[spot.tier] = byTier[spot.tier] or {}
	table.insert(byTier[spot.tier], spot)
end

for index, tier in tiers do
	local solid = frustum(tier)
	for _, spot in byTier[index] do
		solid = subtract(solid, alcoveCutter(tier, FACES[spot.face]), Enum.CollisionFidelity.PreciseConvexDecomposition)
	end
	paint(solid, "Slope_" .. index, YELLOW)
	solid.Parent = model
	if index < 4 then
		local flat = slab(model, "Flat_" .. index, tier.r1, tier.y1 + THICK - OVERLAP)
		trimToSlope(flat, tier)
	end
end
local top = slab(model, "Top", tiers[4].r1, tiers[4].y1 + THICK - OVERLAP)
trimToSlope(top, tiers[4])

local function part(parent, name, size, cf, color)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

-- On the apron, outside the slope footprint, facing the pyramid.
-- South edge, clear of the chamfered corners.
local startPos = Vector3.new(-180 * SCALE, 6 * SCALE, APRON_HALF - 20 * SCALE)
local startPart = part(model, "RJ_Start", Vector3.new(26, 12, 26) * SCALE, CFrame.lookAt(startPos, Vector3.new(0, startPos.Y, 0)), BLUE)
startPart.Transparency = 1
startPart.CanCollide = false
startPart.CanQuery = false
startPart.CanTouch = false
CollectionService:AddTag(startPart, "RJ_Start")

local templateFolder = game:GetService("ServerStorage"):FindFirstChild("Templates")
local targetTemplate = templateFolder and templateFolder:FindFirstChild("Target")

for _, spot in PLAN do
	local tier = tiers[spot.tier]
	local faceDir = FACES[spot.face]
	local surface, normal = facePoint(tier, faceDir)
	local placeAt = surface - normal * TARGET_INSET
	if targetTemplate then
		local clone = targetTemplate:Clone()
		clone.Name = "Target_" .. spot.id
		clone:PivotTo(CFrame.lookAt(placeAt, placeAt + normal))
		clone.Parent = model
		clone:ScaleTo(SCALE)
		local hit = clone:FindFirstChild("RJ_Target", true)
		if hit then
			hit:SetAttribute("Id", spot.id)
		end
	else
		local target = part(model, "RJ_Target_" .. spot.id, Vector3.new(18, 18, 18) * SCALE, CFrame.new(placeAt), Color3.fromRGB(60, 220, 90))
		target.Shape = Enum.PartType.Ball
		target.Material = Enum.Material.Neon
		target.CanCollide = false
		target.CanQuery = true
		target.CanTouch = false
		target:SetAttribute("Id", spot.id)
		CollectionService:AddTag(target, "RJ_Target")
	end
end

local topY = tiers[4].y1 + THICK - OVERLAP
local finish = part(model, "RJ_Finish", Vector3.new(22, 6, 22) * SCALE, CFrame.new(0, topY + 3 * SCALE, 0), Color3.fromRGB(220, 50, 50))
finish.Material = Enum.Material.Neon
finish.CanCollide = true
finish.CanQuery = true
finish.CanTouch = true
CollectionService:AddTag(finish, "RJ_Finish")

local kill = part(model, "RJ_Kill", Vector3.new(2048, 32 * SCALE, 2048), CFrame.new(0, -28 * SCALE, 0), Color3.fromRGB(180, 30, 30))
kill.Transparency = 1
kill.CanCollide = false
kill.CanQuery = false
kill.CanTouch = true
CollectionService:AddTag(kill, "RJ_Kill")

model:PivotTo(model:GetPivot() + SHIFT)
model.WorldPivot = startPart.CFrame
scratch:Destroy()

ChangeHistoryService:SetWaypoint("Build pyramid")
return string.format("Pyramid built, 8 targets, base shifted by %.0f, %.0f, %.0f", SHIFT.X, SHIFT.Y, SHIFT.Z)
