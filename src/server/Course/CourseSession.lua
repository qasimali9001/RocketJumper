-- Per player: targets cleared, finish gate, timer, and full reset. Does not move geometry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))
local MapLoader = require(script.Parent.Parent.Map.MapLoader)

local CourseSession = {}
CourseSession.__index = CourseSession

function CourseSession.new(map, config, respawnRemote, courseRemote, targetHitRemote, resetRemote, helloRemote)
	local self = Class.instance(CourseSession)
	self._map = map
	self._config = config
	self._respawn = respawnRemote
	self._course = courseRemote
	self._targetHit = targetHitRemote
	self._reset = resetRemote
	self._hello = helloRemote
	self._state = {}
	self._targetParts = {}
	self._targetLook = {}
	self._lock = {}
	self._connections = {}
	self._mapName = ""
	self._mapId = ""
	self._times = nil
	self._total = #map.targets
	for _, target in map.targets do
		self._targetParts[target.id] = target.part
		self._targetLook[target.id] = self:_capture(target.part)
	end
	return self
end

function CourseSession:setMapName(name)
	self._mapName = name
end

function CourseSession:setMapId(mapId)
	self._mapId = mapId
end

function CourseSession:setTimes(times)
	self._times = times
end

function CourseSession:setPaused(player, paused)
	local state = self._state[player]
	if state == nil or state.finished or paused == state.paused then
		return
	end
	state.paused = paused
	if paused then
		if state.timerStart then
			state.elapsed = workspace:GetServerTimeNow() - state.timerStart
			state.timerStart = nil
		end
	elseif state.timerStarted then
		state.timerStart = workspace:GetServerTimeNow() - state.elapsed
	end
	self._course:FireClient(player, self:_payload(player, "timer"))
end

function CourseSession:announce(kind)
	for _, player in Players:GetPlayers() do
		if self._state[player] then
			self._course:FireClient(player, self:_payload(player, kind))
		end
	end
end

function CourseSession:start()
	Players.RespawnTime = 0
	self:_applyGate(false)
	self:_restoreTargets()

	self:_bind(self._map.kills, function(player)
		self:_resetPlayer(player)
	end)
	self:_bind(self._map.finishes, function(player)
		self:_onFinish(player)
	end)

	table.insert(self._connections, self._targetHit.OnServerEvent:Connect(function(player, id)
		self:_onTargetHit(player, id)
	end))
	table.insert(self._connections, self._reset.OnServerEvent:Connect(function(player)
		self:_resetPlayer(player)
	end))
	table.insert(self._connections, self._hello.OnServerEvent:Connect(function(player)
		self:_onHello(player)
	end))
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_hookPlayer(player)
	end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self._state[player] = nil
		self._lock[player] = nil
	end))
	table.insert(self._connections, RunService.Heartbeat:Connect(function()
		self:_watchStarts()
	end))

	for _, player in Players:GetPlayers() do
		self:_hookPlayer(player)
	end
end

function CourseSession:destroy()
	self:_restoreTargets()
	self:_applyGate(false)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._state)
	table.clear(self._lock)
end

function CourseSession:_hookPlayer(player)
	table.insert(self._connections, player.CharacterAdded:Connect(function()
		self:_beginRun(player)
	end))
	if player.Character then
		self:_beginRun(player)
	end
end

function CourseSession:_onHello(player)
	if self._state[player] == nil then
		self:_beginRun(player)
		return
	end
	self:_spawn(player)
	self._course:FireClient(player, self:_payload(player, "sync"))
end

function CourseSession:_beginRun(player)
	self._state[player] = self:_fresh()
	self:_restoreTargets()
	self:_applyGate(false)
	self:_spawn(player)
	self._course:FireClient(player, self:_payload(player, "reset"))
	self:_publishBoard(player)
end

function CourseSession:_fresh()
	return {
		cleared = {},
		clearedCount = 0,
		timerStarted = false,
		timerStart = nil,
		armed = false,
		finished = false,
		elapsed = 0,
		paused = false,
	}
end

function CourseSession:_payload(player, kind, record)
	local state = self._state[player]
	local ids = {}
	if state then
		for id in state.cleared do
			table.insert(ids, id)
		end
	end
	return {
		kind = kind,
		cleared = state and state.clearedCount or 0,
		total = self._total,
		timerStart = state and state.timerStart or nil,
		finishOpen = state ~= nil and self._total > 0 and state.clearedCount >= self._total,
		finished = state ~= nil and state.finished or false,
		elapsed = state and state.elapsed or 0,
		clearedIds = ids,
		mapName = self._mapName,
		personalBest = record and record.personalSeconds or nil,
		improved = record ~= nil and record.improved == true,
		board = record and record.board or nil,
	}
end

function CourseSession:_publishBoard(player)
	local times = self._times
	local mapId = self._mapId
	if times == nil or mapId == "" then
		return
	end
	task.spawn(function()
		local record = times:read(player, mapId)
		if player.Parent ~= nil then
			self._course:FireClient(player, self:_payload(player, "board", record))
		end
	end)
end

function CourseSession:_bind(parts, handler)
	for _, part in parts do
		table.insert(self._connections, part.Touched:Connect(function(hit)
			local player = self:_playerFromHit(hit)
			if player then
				handler(player, part)
			end
		end))
	end
end

function CourseSession:_playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

function CourseSession:_onTargetHit(player, id)
	if typeof(id) ~= "string" then
		return
	end
	local state = self._state[player]
	if state == nil or state.finished or state.paused then
		return
	end
	if self._targetParts[id] == nil or state.cleared[id] then
		return
	end
	state.cleared[id] = true
	state.clearedCount += 1
	self:_showTarget(id, true)
	if state.clearedCount >= self._total then
		self:_applyGate(true)
		self:_finishOverlaps()
	end
	self._course:FireClient(player, self:_payload(player, "target"))
end

function CourseSession:_finishOverlaps()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and self:_insideFinish(root.Position) then
			self:_onFinish(player)
		end
	end
end

function CourseSession:_insideFinish(worldPosition)
	for _, part in self._map.finishes do
		if MapLoader.contains(part, worldPosition) then
			return true
		end
	end
	return false
end

function CourseSession:_onFinish(player)
	local state = self._state[player]
	if state == nil or state.finished or state.paused then
		return
	end
	if self._total == 0 or state.clearedCount < self._total then
		return
	end
	state.finished = true
	state.elapsed = 0
	if state.timerStart then
		state.elapsed = workspace:GetServerTimeNow() - state.timerStart
	end
	local record = nil
	if self._times and self._mapId ~= "" then
		record = self._times:submit(player, self._mapId, state.elapsed)
	end
	self._course:FireClient(player, self:_payload(player, "finish", record))
end

function CourseSession:_resetPlayer(player)
	local now = os.clock()
	local lockedUntil = self._lock[player]
	if lockedUntil and now < lockedUntil then
		return
	end
	self._lock[player] = now + self._config.RespawnDebounce
	if player.Character == nil then
		return
	end
	self:_beginRun(player)
end

function CourseSession:_spawn(player)
	local pad = self._map.startPart
	if pad == nil then
		return
	end
	local cframe = MapLoader.spawnCFrame(pad, self._config.SpawnLift)
	self._respawn:FireClient(player, cframe)
end

function CourseSession:_watchStarts()
	local startPart = self._map.startPart
	if startPart == nil then
		return
	end
	for player, state in self._state do
		if state.timerStarted or state.finished or state.paused then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			continue
		end
		if MapLoader.contains(startPart, root.Position) then
			state.armed = true
		elseif state.armed then
			state.timerStarted = true
			state.timerStart = workspace:GetServerTimeNow()
			self._course:FireClient(player, self:_payload(player, "timer"))
		end
	end
end

function CourseSession:_host(part)
	local parent = part.Parent
	if parent and parent:IsA("Model") and parent ~= self._map.model then
		return parent
	end
	return part
end

function CourseSession:_capture(part)
	local host = self:_host(part)
	local pieces = {}
	local function keep(piece)
		table.insert(pieces, {
			part = piece,
			transparency = piece.Transparency,
			canQuery = piece.CanQuery,
		})
	end
	if host:IsA("BasePart") then
		keep(host)
	end
	if host:IsA("Model") then
		for _, descendant in host:GetDescendants() do
			if descendant:IsA("BasePart") then
				keep(descendant)
			end
		end
	end
	return pieces
end

function CourseSession:_showTarget(id, cleared)
	local look = self._targetLook[id]
	if look == nil then
		return
	end
	for _, saved in look do
		local piece = saved.part
		if piece.Parent ~= nil then
			if cleared then
				piece.Transparency = 1
				piece.CanQuery = false
			else
				piece.Transparency = saved.transparency
				piece.CanQuery = saved.canQuery
			end
		end
	end
end

function CourseSession:_restoreTargets()
	for id in self._targetParts do
		self:_showTarget(id, false)
	end
end

function CourseSession:_applyGate(open)
	local style = open and self._config.FinishOpen or self._config.FinishClosed
	for _, part in self._map.finishes do
		part.CanCollide = not open
		part.CanQuery = not open
		part.CanTouch = true
		part.Color = style.Color
		part.Transparency = style.Transparency
		part.Material = style.Material
	end
end

return CourseSession
