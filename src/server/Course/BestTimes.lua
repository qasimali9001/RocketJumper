-- Per-map fastest times. The value is milliseconds, lowest first.
-- A failed run never calls this. If the store is closed, times last for this server only.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Class = require(game:GetService("ReplicatedStorage"):WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local BestTimes = {}
BestTimes.__index = BestTimes

function BestTimes.new(config)
	local self = Class.instance(BestTimes)
	self._config = config
	self._stores = {}
	self._closed = {}
	self._memory = {}
	self._known = {}
	self._names = {}
	self._boards = {}
	self._warned = false
	return self
end

function BestTimes:personalSeconds(player, mapId)
	local ms = self:_get(player.UserId, mapId)
	if ms == nil then
		return nil
	end
	return ms / 1000
end

function BestTimes:read(player, mapId)
	local ms = self:_get(player.UserId, mapId)
	return {
		personalSeconds = ms and (ms / 1000) or nil,
		improved = false,
		board = self:_board(mapId),
	}
end

function BestTimes:submit(player, mapId, seconds)
	if typeof(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds > 3600 then
		return self:read(player, mapId)
	end
	local ms = math.floor(seconds * 1000 + 0.5)
	if ms < 1 then
		ms = 1
	end
	local previous = self:_get(player.UserId, mapId)
	local improved = previous == nil or ms < previous
	if improved then
		self:_set(player.UserId, mapId, ms)
		self._names[player.UserId] = player.Name
		self._boards[mapId] = nil
	end
	local personal = previous
	if improved or personal == nil then
		personal = ms
	end
	local board = self:_board(mapId)
	self:_place(board, {
		userId = player.UserId,
		name = player.Name,
		seconds = personal / 1000,
	})
	return {
		personalSeconds = personal / 1000,
		improved = improved,
		board = board,
	}
end

function BestTimes:_store(mapId)
	if self._closed[mapId] then
		return nil
	end
	local existing = self._stores[mapId]
	if existing then
		return existing
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(self._config.StorePrefix .. mapId)
	end)
	if not ok or store == nil then
		self._closed[mapId] = true
		if not self._warned then
			self._warned = true
			warn("RocketJumper: time store unavailable, keeping times for this server only")
		end
		return nil
	end
	self._stores[mapId] = store
	return store
end

function BestTimes:_bucket(mapId)
	local bucket = self._memory[mapId]
	if bucket == nil then
		bucket = {}
		self._memory[mapId] = bucket
	end
	return bucket
end

function BestTimes:_remember(mapId, userId, ms)
	local known = self._known[mapId]
	if known == nil then
		known = {}
		self._known[mapId] = known
	end
	known[userId] = ms
end

function BestTimes:_get(userId, mapId)
	local known = self._known[mapId]
	if known and known[userId] ~= nil then
		local value = known[userId]
		if value == false then
			return nil
		end
		return value
	end
	local store = self:_store(mapId)
	if store == nil then
		return self:_bucket(mapId)[userId]
	end
	local ok, value = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	if ok and typeof(value) == "number" then
		self:_remember(mapId, userId, value)
		return value
	end
	if ok then
		self:_remember(mapId, userId, false)
	end
	return self:_bucket(mapId)[userId]
end

function BestTimes:_set(userId, mapId, ms)
	self:_bucket(mapId)[userId] = ms
	self:_remember(mapId, userId, ms)
	local store = self:_store(mapId)
	if store == nil then
		return
	end
	pcall(function()
		store:SetAsync(tostring(userId), ms)
	end)
end

function BestTimes:_board(mapId)
	local cached = self._boards[mapId]
	if cached and os.clock() - cached.at < 20 then
		return cached.rows
	end
	local board = {}
	local store = self:_store(mapId)
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(true, self._config.BoardSize)
		end)
		if ok and pages then
			local pageOk, page = pcall(function()
				return pages:GetCurrentPage()
			end)
			if pageOk and typeof(page) == "table" then
				for _, entry in page do
					local userId = tonumber(entry.key)
					if userId then
						table.insert(board, {
							userId = userId,
							name = self:_name(userId),
							seconds = entry.value / 1000,
						})
					end
				end
			end
		end
	else
		for userId, ms in self:_bucket(mapId) do
			table.insert(board, {
				userId = userId,
				name = self:_name(userId),
				seconds = ms / 1000,
			})
		end
		table.sort(board, function(a, b)
			return a.seconds < b.seconds
		end)
		while #board > self._config.BoardSize do
			table.remove(board)
		end
	end
	self._boards[mapId] = { at = os.clock(), rows = board }
	return board
end

function BestTimes:_place(board, entry)
	local found = false
	for index, row in board do
		if row.userId == entry.userId then
			if entry.seconds < row.seconds then
				board[index] = entry
			end
			found = true
			break
		end
	end
	if not found then
		table.insert(board, entry)
	end
	table.sort(board, function(a, b)
		return a.seconds < b.seconds
	end)
	while #board > self._config.BoardSize do
		table.remove(board)
	end
end

function BestTimes:_name(userId)
	local cached = self._names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self._names[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" and name ~= "" then
		self._names[userId] = name
		return name
	end
	return "Player"
end

return BestTimes
