-- Picks the next map that is already in Workspace and reloads the session.
-- Does not change course rules. CourseSession still owns the run.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local MapLoader = require(script.Parent.MapLoader)
local CourseSession = require(script.Parent.Parent.Course.CourseSession)

local MapCycle = {}
MapCycle.__index = MapCycle

function MapCycle.new(registry, config, respawnRemote, courseRemote, targetHitRemote, resetRemote, helloRemote, cycleRemote)
	local self = Class.instance(MapCycle)
	self._registry = registry
	self._config = config
	self._respawn = respawnRemote
	self._course = courseRemote
	self._targetHit = targetHitRemote
	self._reset = resetRemote
	self._hello = helloRemote
	self._cycle = cycleRemote
	self._rows = {}
	self._index = 1
	self._session = nil
	self._connection = nil
	return self
end

function MapCycle:start()
	self._rows = self:_present()
	if #self._rows == 0 then
		warn("RocketJumper: no map model in Workspace")
		return
	end
	self:_open()
	self._connection = self._cycle.OnServerEvent:Connect(function()
		self:_advance()
	end)
end

function MapCycle:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._session then
		self._session:destroy()
		self._session = nil
	end
end

function MapCycle:_present()
	local rows = {}
	local startIndex = 1
	for _, row in self._registry do
		if Workspace:FindFirstChild(row.modelName) then
			table.insert(rows, row)
			if row.active then
				startIndex = #rows
			end
		end
	end
	self._index = startIndex
	return rows
end

function MapCycle:_advance()
	if #self._rows < 2 then
		return
	end
	self._index = self._index % #self._rows + 1
	self:_open()
end

function MapCycle:_open()
	local row = self._rows[self._index]
	local model = Workspace:FindFirstChild(row.modelName)
	if model == nil then
		warn("RocketJumper: map model missing: " .. row.modelName)
		return
	end
	if self._session then
		self._session:destroy()
		self._session = nil
	end
	local map = MapLoader.read(model, self._config.Tags)
	local session = CourseSession.new(map, self._config, self._respawn, self._course, self._targetHit, self._reset, self._hello)
	session:setMapName(row.displayName)
	session:start()
	session:announce("map")
	self._session = session
end

return MapCycle
