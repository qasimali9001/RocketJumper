-- Picks the next map that is already in Workspace and reloads the session.
-- Does not change course rules. CourseSession still owns the run.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local MapLoader = require(script.Parent.MapLoader)
local CourseSession = require(script.Parent.Parent.Course.CourseSession)

local MapCycle = {}
MapCycle.__index = MapCycle

function MapCycle.new(registry, config, respawnRemote, courseRemote, targetHitRemote, resetRemote, helloRemote, cycleRemote, times, selectRemote, pauseRemote)
	local self = Class.instance(MapCycle)
	self._registry = registry
	self._config = config
	self._respawn = respawnRemote
	self._course = courseRemote
	self._targetHit = targetHitRemote
	self._reset = resetRemote
	self._hello = helloRemote
	self._cycle = cycleRemote
	self._times = times
	self._select = selectRemote
	self._pause = pauseRemote
	self._rows = {}
	self._index = 1
	self._session = nil
	self._connection = nil
	self._selectConnection = nil
	self._pauseConnection = nil
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
	self._selectConnection = self._select.OnServerEvent:Connect(function(_player, mapId)
		self:_selectMap(mapId)
	end)
	self._pauseConnection = self._pause.OnServerEvent:Connect(function(player, paused)
		if self._session then
			self._session:setPaused(player, paused == true)
		end
		if paused == true then
			self:_sendCatalog(player)
		end
	end)
end

function MapCycle:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._selectConnection then
		self._selectConnection:Disconnect()
		self._selectConnection = nil
	end
	if self._pauseConnection then
		self._pauseConnection:Disconnect()
		self._pauseConnection = nil
	end
	if self._session then
		self._session:destroy()
		self._session = nil
	end
end

function MapCycle:_sendCatalog(player)
	local times = self._times
	if times == nil or player.Parent == nil then
		return
	end
	task.spawn(function()
		local bests = {}
		for _, row in self._rows do
			table.insert(bests, {
				id = row.id,
				seconds = times:personalSeconds(player, row.id),
			})
		end
		if player.Parent ~= nil then
			self._course:FireClient(player, {
				kind = "catalog",
				bests = bests,
			})
		end
	end)
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

function MapCycle:_selectMap(mapId)
	if typeof(mapId) ~= "string" then
		return
	end
	for index, row in self._rows do
		if row.id == mapId and Workspace:FindFirstChild(row.modelName) then
			self._index = index
			self:_open()
			return
		end
	end
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
	session:setMapId(row.id)
	session:setTimes(self._times)
	session:start()
	session:announce("map")
	self._session = session
end

return MapCycle
