-- Fastest times for the current map. Does not submit a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local LeaderboardHud = {}
LeaderboardHud.__index = LeaderboardHud

local function formatTime(seconds)
	return string.format("%.2f", math.max(0, seconds))
end

function LeaderboardHud.new(config)
	local self = Class.instance(LeaderboardHud)
	self._config = config
	self._gui = nil
	self._title = nil
	self._empty = nil
	self._rows = nil
	self._connection = nil
	return self
end

function LeaderboardHud:start()
	if self._gui then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 13

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = config.AnchorPoint
	panel.Position = config.Position
	panel.Size = UDim2.fromOffset(config.Width, config.TitleSize + config.Padding * 2 + config.RowHeight)
	panel.BackgroundColor3 = config.Background
	panel.BackgroundTransparency = config.BackgroundTransparency
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(config.Padding, config.Padding)
	title.Size = UDim2.new(1, -config.Padding * 2, 0, config.TitleSize)
	title.Font = config.Font
	title.TextSize = config.TitleSize
	title.TextColor3 = config.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Times"
	title.Parent = panel

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.BackgroundTransparency = 1
	empty.Position = UDim2.fromOffset(config.Padding, config.Padding + config.TitleSize + 4)
	empty.Size = UDim2.new(1, -config.Padding * 2, 0, config.RowHeight)
	empty.Font = config.BodyFont
	empty.TextSize = config.RowSize
	empty.TextColor3 = config.Muted
	empty.TextXAlignment = Enum.TextXAlignment.Left
	empty.Text = "No times yet"
	empty.Parent = panel

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(config.Padding, config.Padding + config.TitleSize + 4)
	rows.Size = UDim2.new(1, -config.Padding * 2, 1, -(config.Padding * 2 + config.TitleSize + 4))
	rows.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui
	self._panel = panel
	self._title = title
	self._empty = empty
	self._rows = rows
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end)
end

function LeaderboardHud:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

function LeaderboardHud:_onCourse(payload)
	if typeof(payload) ~= "table" or self._title == nil then
		return
	end
	if payload.kind ~= "board" and payload.kind ~= "finish" and payload.kind ~= "map" then
		return
	end
	if typeof(payload.mapName) == "string" and payload.mapName ~= "" then
		self._title.Text = payload.mapName
	end
	if typeof(payload.board) ~= "table" then
		return
	end
	self:_show(payload.board)
end

function LeaderboardHud:_show(board)
	local config = self._config
	local rows = self._rows
	for _, child in rows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local localId = Players.LocalPlayer.UserId
	local count = math.min(#board, config.MaxRows)
	self._empty.Visible = count == 0
	for index = 1, count do
		local entry = board[index]
		local label = Instance.new("TextLabel")
		label.Name = "Row"
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, config.RowHeight)
		label.Font = config.BodyFont
		label.TextSize = config.RowSize
		label.TextXAlignment = Enum.TextXAlignment.Left
		local name = typeof(entry.name) == "string" and entry.name or "Player"
		local seconds = typeof(entry.seconds) == "number" and entry.seconds or 0
		local mine = entry.userId == localId
		label.TextColor3 = mine and config.You or config.Text
		label.Text = string.format("%d  %s  %s", index, name, formatTime(seconds))
		label.Parent = rows
	end
	local height = config.Padding * 2 + config.TitleSize + 4
	if count == 0 then
		height += config.RowHeight
	else
		height += count * config.RowHeight + math.max(0, count - 1) * 2
	end
	self._panel.Size = UDim2.fromOffset(config.Width, height)
end

return LeaderboardHud
