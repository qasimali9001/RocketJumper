-- Photographs a map into a card. The clone's origin is that level's spawn,
-- the same point the player stands on. A viewport will not draw geometry
-- that stays hundreds of studs from the origin. Does not write velocity.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseConfig = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CourseConfig"))

local LevelPreview = {}

local function spawnCFrame(part, lift)
	local bottom = part.Position.Y - part.Size.Y * 0.5
	local position = Vector3.new(part.Position.X, bottom + lift, part.Position.Z)
	local look = part.CFrame.LookVector
	if math.abs(look.Y) > 0.99 then
		look = Vector3.new(0, 0, -1)
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

local function findStart(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (CollectionService:HasTag(descendant, CourseConfig.Tags.Start) or descendant.Name == "RJ_Start") then
			return descendant
		end
	end
	return nil
end

local function keep(part, killTag)
	if not part:IsA("BasePart") or part.Transparency >= 1 then
		return false
	end
	if CollectionService:HasTag(part, killTag) then
		return false
	end
	if math.max(part.Size.X, part.Size.Y, part.Size.Z) > 900 then
		return false
	end
	return true
end

function LevelPreview.attach(parent, model, killTag)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(94, 124, 158)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(180, 186, 196)
	viewport.LightColor = Color3.fromRGB(255, 248, 230)
	viewport.LightDirection = Vector3.new(-0.45, -1, -0.2)
	viewport.ZIndex = 1
	viewport.Parent = parent

	if model == nil then
		return viewport
	end
	task.wait()
	if viewport.Parent == nil then
		return viewport
	end

	local clone = model:Clone()
	local basis = nil
	local startPart = findStart(clone)
	if startPart then
		basis = spawnCFrame(startPart, CourseConfig.SpawnLift)
		startPart:Destroy()
	end
	local drop = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") and not keep(descendant, killTag) then
			table.insert(drop, descendant)
		end
	end
	for _, part in drop do
		part:Destroy()
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = viewport
	clone.Parent = world
	if basis then
		clone.WorldPivot = basis
		clone:PivotTo(CFrame.identity)
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	camera.CFrame = LevelPreview._aim(clone)
	return viewport
end

function LevelPreview._aim(model)
	local sum = Vector3.zero
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			sum += descendant.Position
			count += 1
		end
	end
	local eye = Vector3.new(0, 2.5, 0)
	local focus = Vector3.new(0, 1.5, -40)
	if count > 0 then
		local center = sum / count
		if (center - eye).Magnitude > 8 then
			focus = center
		end
	end
	return CFrame.lookAt(eye, focus)
end

return LevelPreview
