-- Downward ray that reports whether the rig is standing on walkable ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local GroundProbe = {}
GroundProbe.__index = GroundProbe

function GroundProbe.new(config)
	local self = Class.instance(GroundProbe)
	self._skin = config.GroundSkin
	self._minNormalY = config.MinGroundNormalY
	self._params = RaycastParams.new()
	self._params.FilterType = Enum.RaycastFilterType.Exclude
	return self
end

function GroundProbe:setCharacter(character)
	self._params.FilterDescendantsInstances = { character }
end

function GroundProbe:probe(root, humanoid)
	local reach = humanoid.HipHeight + root.Size.Y * 0.5 + self._skin
	local result = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), self._params)
	if result == nil or result.Normal.Y < self._minNormalY then
		return false, nil
	end
	return true, result.Position.Y
end

return GroundProbe
