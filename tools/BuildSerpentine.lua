-- One-shot. Paste into the Studio command bar while the game is not playing.
-- Builds the S as parts, so nothing is uploaded as a mesh.

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local INNER_W = 96
local INNER_H = 72
local THICK = 12
local STEP = 5
local OVERLAP = 2
local WALL_COLOR = Color3.fromRGB(48, 56, 72)
local CENTER_Y = 56

local controls = {
	Vector3.new(4.27, CENTER_Y, 23.61),
	Vector3.new(107.92, CENTER_Y, 0.02),
	Vector3.new(213.13, CENTER_Y, -14.88),
	Vector3.new(319.32, CENTER_Y, -19.17),
	Vector3.new(424.59, CENTER_Y, -6.3),
	Vector3.new(522.47, CENTER_Y, 33.55),
	Vector3.new(597.76, CENTER_Y, 107.42),
	Vector3.new(626.79, CENTER_Y, 208.52),
	Vector3.new(580.05, CENTER_Y, 300.37),
	Vector3.new(488.83, CENTER_Y, 352.32),
	Vector3.new(384.64, CENTER_Y, 373.24),
	Vector3.new(279.99, CENTER_Y, 390.96),
	Vector3.new(181.14, CENTER_Y, 429.3),
	Vector3.new(99.88, CENTER_Y, 497.11),
	Vector3.new(50.84, CENTER_Y, 590.6),
	Vector3.new(58.03, CENTER_Y, 694.1),
	Vector3.new(121.66, CENTER_Y, 778.04),
	Vector3.new(214.59, CENTER_Y, 829.09),
	Vector3.new(316.4, CENTER_Y, 858.86),
	Vector3.new(422.32, CENTER_Y, 864.64),
	Vector3.new(527.29, CENTER_Y, 848.97),
	Vector3.new(628.25, CENTER_Y, 815.97),
	Vector3.new(723.5, CENTER_Y, 768.97),
	Vector3.new(812.33, CENTER_Y, 710.6),
}

local function tj(ti, a, b)
	local d = (b - a).Magnitude
	if d < 1e-4 then
		d = 1e-4
	end
	return ti + math.sqrt(d)
end

local function mix(a, b, ta, tb, tt)
	if math.abs(tb - ta) < 1e-6 then
		return a
	end
	return a:Lerp(b, (tt - ta) / (tb - ta))
end

local function catmull(p0, p1, p2, p3, t)
	local t0 = 0
	local t1 = tj(t0, p0, p1)
	local t2 = tj(t1, p1, p2)
	local t3 = tj(t2, p2, p3)
	local tt = t1 + (t2 - t1) * t
	local a1 = mix(p0, p1, t0, t1, tt)
	local a2 = mix(p1, p2, t1, t2, tt)
	local a3 = mix(p2, p3, t2, t3, tt)
	local b1 = mix(a1, a2, t0, t2, tt)
	local b2 = mix(a2, a3, t1, t3, tt)
	return mix(b1, b2, t1, t2, tt)
end

local ext = { controls[1] }
for _, point in controls do
	table.insert(ext, point)
end
table.insert(ext, controls[#controls])

local dense = {}
for i = 2, #ext - 2 do
	for s = 0, 15 do
		table.insert(dense, catmull(ext[i - 1], ext[i], ext[i + 1], ext[i + 2], s / 16))
	end
end
table.insert(dense, controls[#controls])

local dist = { 0 }
for i = 2, #dense do
	dist[i] = dist[i - 1] + (dense[i] - dense[i - 1]).Magnitude
end
local total = dist[#dist]

local points = {}
local cursor = 1
local walked = 0
while walked < total - 0.01 do
	while cursor < #dist - 1 and dist[cursor + 1] < walked do
		cursor += 1
	end
	local span = dist[cursor + 1] - dist[cursor]
	local alpha = if span < 1e-6 then 0 else (walked - dist[cursor]) / span
	table.insert(points, dense[cursor]:Lerp(dense[cursor + 1], math.clamp(alpha, 0, 1)))
	walked += STEP
end
table.insert(points, dense[#dense])

local function tangentAt(i)
	local a = if i == 1 then points[1] else points[i - 1]
	local b = if i == #points then points[#points] else points[i + 1]
	local delta = b - a
	if delta.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return delta.Unit
end

local prevRight = nil
local function frameAt(i)
	local forward = tangentAt(i)
	local right = forward:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		right = prevRight or Vector3.xAxis
	else
		right = right.Unit
	end
	if prevRight and right:Dot(prevRight) < 0 then
		right = -right
	end
	prevRight = right
	return forward, right
end

local function align(pos, forward, right)
	return CFrame.fromMatrix(pos, right, Vector3.yAxis, -forward)
end

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

ChangeHistoryService:SetWaypoint("Before serpentine rebuild")

local previous = workspace:FindFirstChild("Serpentine")
if previous then
	if previous:GetAttribute("RJ_Source") == "parts" then
		previous:Destroy()
	else
		local parked = "SerpentineOld"
		local n = 2
		while workspace:FindFirstChild(parked) do
			parked = "SerpentineOld" .. n
			n += 1
		end
		previous.Name = parked
	end
end

local model = Instance.new("Model")
model.Name = "Serpentine"
model:SetAttribute("RJ_Source", "parts")
model.Parent = workspace

local shell = Instance.new("Folder")
shell.Name = "Shell"
shell.Parent = model

local outerW = INNER_W + THICK * 2
local drop = INNER_H / 2 + THICK / 2
local side = INNER_W / 2 + THICK / 2
local count = 0

for i = 1, #points - 1 do
	local a = points[i]
	local b = points[i + 1]
	local span = b - a
	local length = span.Magnitude
	if length < 0.25 then
		continue
	end
	local forward = span.Unit
	local right = forward:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end
	if prevRight and right:Dot(prevRight) < 0 then
		right = -right
	end
	prevRight = right
	local mid = (a + b) / 2
	local cf = align(mid, forward, right)
	local long = length + OVERLAP
	part(shell, "Floor", Vector3.new(outerW, THICK, long), cf - Vector3.yAxis * drop, WALL_COLOR)
	part(shell, "Ceiling", Vector3.new(outerW, THICK, long), cf + Vector3.yAxis * drop, WALL_COLOR)
	part(shell, "Wall", Vector3.new(THICK, INNER_H, long), cf + right * side, WALL_COLOR)
	part(shell, "Wall", Vector3.new(THICK, INNER_H, long), cf - right * side, WALL_COLOR)
	count += 4
end

local function cap(index, sign)
	local forward, right = frameAt(index)
	local pos = points[index] + forward * sign * (THICK / 2)
	part(shell, "Cap", Vector3.new(outerW, INNER_H + THICK * 2, THICK), align(pos, forward, right), WALL_COLOR)
end
cap(1, -1)
cap(#points, 1)

prevRight = nil
local function sample(fraction)
	local index = math.clamp(math.round(fraction * (#points - 1)) + 1, 1, #points)
	local forward, right = frameAt(index)
	return points[index], forward, right
end

local startPos, startForward, startRight = sample(0.02)
local startPart = part(model, "RJ_Start", Vector3.new(70, 64, 22), align(startPos, startForward, startRight), WALL_COLOR)
startPart.Transparency = 1
startPart.CanCollide = false
startPart.CanQuery = false
startPart.CanTouch = false
CollectionService:AddTag(startPart, "RJ_Start")

local targetTemplate = nil
local templateFolder = game:GetService("ServerStorage"):FindFirstChild("Templates")
if templateFolder then
	targetTemplate = templateFolder:FindFirstChild("Target")
end

local targetOffsets = { 24, -24, 24, -24, 24 }
local targetFracs = { 0.16, 0.31, 0.50, 0.69, 0.84 }
for i, fraction in targetFracs do
	local pos, forward, right = sample(fraction)
	local placeAt = pos + right * targetOffsets[i] + Vector3.new(0, -18, 0)
	if targetTemplate then
		local clone = targetTemplate:Clone()
		clone.Name = "Target_" .. i
		local face = -math.sign(targetOffsets[i]) * right
		clone:PivotTo(CFrame.lookAt(placeAt, placeAt + face))
		local hit = clone:FindFirstChild("RJ_Target", true)
		if hit then
			hit:SetAttribute("Id", tostring(i))
		end
		clone.Parent = model
	else
		local target = part(
			model,
			"RJ_Target_" .. i,
			Vector3.new(18, 18, 18),
			CFrame.new(placeAt),
			Color3.fromRGB(60, 220, 90)
		)
		target.Shape = Enum.PartType.Ball
		target.Material = Enum.Material.Neon
		target.CanCollide = false
		target.CanQuery = true
		target.CanTouch = false
		target:SetAttribute("Id", tostring(i))
		CollectionService:AddTag(target, "RJ_Target")
	end
end

local finishPos, finishForward, finishRight = sample(0.95)
local finish = part(
	model,
	"RJ_Finish",
	Vector3.new(INNER_W, INNER_H, 6),
	align(finishPos, finishForward, finishRight),
	Color3.fromRGB(220, 50, 50)
)
finish.Material = Enum.Material.Neon
finish.CanCollide = true
finish.CanQuery = true
finish.CanTouch = true
CollectionService:AddTag(finish, "RJ_Finish")

local minX, maxX = math.huge, -math.huge
local minZ, maxZ = math.huge, -math.huge
for _, point in points do
	minX = math.min(minX, point.X)
	maxX = math.max(maxX, point.X)
	minZ = math.min(minZ, point.Z)
	maxZ = math.max(maxZ, point.Z)
end
local kill = part(
	model,
	"RJ_Kill",
	Vector3.new((maxX - minX) + 240, 80, (maxZ - minZ) + 240),
	CFrame.new((minX + maxX) / 2, -40, (minZ + maxZ) / 2),
	Color3.fromRGB(180, 30, 30)
)
kill.Transparency = 1
kill.CanCollide = false
kill.CanQuery = false
kill.CanTouch = true
CollectionService:AddTag(kill, "RJ_Kill")

model.WorldPivot = startPart.CFrame
ChangeHistoryService:SetWaypoint("Build serpentine")
print(string.format("Serpentine built, %d shell parts, path %.0f studs", count, total))
