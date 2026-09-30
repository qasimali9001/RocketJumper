-- Reads a tagged map model. Does not build geometry.
-- A model already in Workspace is the one you edit between playtests.
-- A model that exists only under ServerStorage/Maps is cloned in for the run.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local MapLoader = {}

function MapLoader.spawnCFrame(part, lift)
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

function MapLoader.contains(part, worldPosition)
	if part == nil then
		return false
	end
	local localPos = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

function MapLoader.load(registry, tags, lift)
	local descriptor = nil
	for _, row in registry do
		if row.active then
			descriptor = row
			break
		end
	end
	if descriptor == nil then
		warn("RocketJumper: no active map in MapRegistry")
		return nil
	end

	local model = workspace:FindFirstChild(descriptor.modelName)
	if model == nil then
		local storage = ServerStorage:FindFirstChild("Maps")
		local source = storage and storage:FindFirstChild(descriptor.modelName)
		if source then
			model = source:Clone()
			model.Parent = workspace
		end
	end
	if model == nil then
		warn("RocketJumper: map model missing: " .. descriptor.modelName)
		return nil
	end

	return MapLoader.read(model, tags, lift)
end

function MapLoader.read(model, tags, _lift)
	local function tagged(tag)
		local found = {}
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(model) and instance:IsA("BasePart") then
				table.insert(found, instance)
			end
		end
		return found
	end

	local starts = tagged(tags.Start)
	local startPart = starts[1]
	if startPart == nil then
		warn("RocketJumper: map has no RJ_Start part")
	end

	local targets = {}
	local seen = {}
	for _, part in tagged(tags.Target) do
		local id = part:GetAttribute("Id")
		if typeof(id) ~= "string" or id == "" then
			warn("RocketJumper: target missing Id attribute: " .. part:GetFullName())
		elseif seen[id] then
			warn("RocketJumper: duplicate target Id " .. id)
		else
			seen[id] = true
			table.insert(targets, {
				id = id,
				part = part,
			})
		end
	end

	return {
		model = model,
		startPart = startPart,
		targets = targets,
		kills = tagged(tags.Kill),
		finishes = tagged(tags.Finish),
	}
end

return MapLoader
