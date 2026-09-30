-- One-shot. Paste into the Studio command bar while the game is not playing.
-- One sphere. The same archery face is painted on the front and the back.
-- White is the band around the middle. Replaces the saved template and placed copies.

local CollectionService = game:GetService("CollectionService")

local DIAMETER = 18
local RADIUS = DIAMETER / 2

-- How far each ring reaches across the circle you see, from the center out.
-- The same sizes are mirrored onto the back. White sits between the two faces.
local rings = {
	{ name = "Red", fraction = 0.24, color = Color3.fromRGB(220, 25, 35) },
	{ name = "Yellow", fraction = 0.50, color = Color3.fromRGB(255, 196, 30) },
	{ name = "Blue", fraction = 0.74, color = Color3.fromRGB(25, 95, 230) },
	{ name = "Black", fraction = 0.94, color = Color3.fromRGB(15, 15, 15) },
}
local WHITE = Color3.fromRGB(245, 245, 245)

local function planeZ(fraction)
	local s = math.clamp(fraction, 0, 0.999)
	return -RADIUS * math.sqrt(1 - s * s)
end

local function isTargetModel(model)
	if not model:IsA("Model") or model:FindFirstChild("RJ_Target", true) == nil then
		return false
	end
	local black = model:FindFirstChild("Black")
	if black and black:IsA("Part") and black.Shape == Enum.PartType.Cylinder then
		return true
	end
	for _, name in { "Red", "Yellow", "Blue", "Black", "White" } do
		if model:FindFirstChild(name) == nil then
			return false
		end
	end
	return true
end

local storage = game:GetService("ServerStorage")
local templates = storage:FindFirstChild("Templates")
if templates == nil then
	templates = Instance.new("Folder")
	templates.Name = "Templates"
	templates.Parent = storage
end

local placements = {}
local flat = {}
for _, inst in game:GetDescendants() do
	if isTargetModel(inst) then
		table.insert(flat, inst)
		if inst.Parent ~= templates then
			local hit = inst:FindFirstChild("RJ_Target", true)
			table.insert(placements, {
				parent = inst.Parent,
				name = inst.Name,
				pivot = inst:GetPivot(),
				id = if hit then hit:GetAttribute("Id") else "",
			})
		end
	end
end
for _, inst in flat do
	inst:Destroy()
end

local scratch = Instance.new("Folder")
scratch.Name = "_TargetBuild"
scratch.Parent = workspace

local function bandPart(name, color, z0, z1)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(DIAMETER, DIAMETER, DIAMETER)
	sphere.Color = color
	sphere.Material = Enum.Material.Neon
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Parent = scratch

	local block = Instance.new("Part")
	block.Size = Vector3.new(DIAMETER * 3, DIAMETER * 3, math.abs(z1 - z0))
	block.CFrame = CFrame.new(0, 0, (z0 + z1) / 2)
	block.Anchored = true
	block.CanCollide = false
	block.Parent = scratch

	local result = sphere:IntersectAsync({ block }, Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Precise)
	result.Name = name
	result.Color = color
	result.Material = Enum.Material.Neon
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	sphere:Destroy()
	block:Destroy()
	return result
end

local model = Instance.new("Model")
model.Name = "Target"

local zFront = -RADIUS - 0.05
for _, ring in rings do
	local z1 = planeZ(ring.fraction)
	local piece = bandPart(ring.name, ring.color, zFront, z1)
	piece.Parent = model
	zFront = z1
end

local backEdge = -zFront
local white = bandPart("White", WHITE, zFront, backEdge)
white.Parent = model

local zBack = backEdge
for index = #rings, 1, -1 do
	local towardPole = if index == 1 then RADIUS + 0.05 else -planeZ(rings[index - 1].fraction)
	local piece = bandPart(rings[index].name .. "Back", rings[index].color, zBack, towardPole)
	piece.Parent = model
	zBack = towardPole
end

local hit = Instance.new("Part")
hit.Name = "RJ_Target"
hit.Shape = Enum.PartType.Ball
hit.Size = Vector3.new(DIAMETER, DIAMETER, DIAMETER)
hit.Transparency = 1
hit.Anchored = true
hit.CanCollide = false
hit.CanQuery = true
hit.CanTouch = false
hit:SetAttribute("Id", "")
hit.Parent = model
CollectionService:AddTag(hit, "RJ_Target")

for _, piece in model:GetChildren() do
	if piece ~= hit and piece:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hit
		weld.Part1 = piece
		weld.Parent = piece
	end
end

model.PrimaryPart = hit
model.Parent = templates
scratch:Destroy()

for _, spot in placements do
	local clone = model:Clone()
	clone.Name = spot.name
	clone:PivotTo(spot.pivot)
	local cloneHit = clone:FindFirstChild("RJ_Target", true)
	if cloneHit and spot.id ~= nil then
		cloneHit:SetAttribute("Id", spot.id)
	end
	clone.Parent = spot.parent
end

print("Target is one painted sphere. Template: ServerStorage.Templates.Target")
