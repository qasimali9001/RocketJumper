-- Card grid for maps already in Workspace. A new level is another registry row.
-- Does not start the run.

	local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local CourseConfig = require(Shared:WaitForChild("Config"):WaitForChild("CourseConfig"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))
local LevelPreview = require(script.Parent.LevelPreview)

local LevelSelect = {}
LevelSelect.__index = LevelSelect

local function pack(items, columns, featuredColumns, featuredRows)
	local grid = {}
	local function free(x, y, w, h)
		if x + w > columns then
			return false
		end
		for dy = 0, h - 1 do
			for dx = 0, w - 1 do
				local row = grid[y + dy]
				if row and row[x + dx] then
					return false
				end
			end
		end
		return true
	end
	local function take(x, y, w, h)
		for dy = 0, h - 1 do
			local row = grid[y + dy]
			if row == nil then
				row = {}
				grid[y + dy] = row
			end
			for dx = 0, w - 1 do
				row[x + dx] = true
			end
		end
	end
	local placed = {}
	local tallest = 0
	for _, item in items do
		local w = 1
		local h = 1
		if item.featured and featuredColumns <= columns then
			w = featuredColumns
			h = featuredRows
		end
		local found = false
		for y = 0, 32 do
			for x = 0, columns - w do
				if free(x, y, w, h) then
					take(x, y, w, h)
					table.insert(placed, { item = item, x = x, y = y, w = w, h = h })
					tallest = math.max(tallest, y + h)
					found = true
					break
				end
			end
			if found then
				break
			end
		end
	end
	return placed, tallest
end

function LevelSelect.new(config, registry, onPick)
	local self = setmetatable({}, LevelSelect)
	self._config = config
	self._registry = registry
	self._onPick = onPick
	self._current = ""
	self._bests = {}
	self._cards = {}
	self._frame = nil
	self._scroll = nil
	self._scrollY = 0
	self._contentHeight = 0
	self._visible = false
	self._connection = nil
	return self
end

function LevelSelect:mount(parent)
	local cards = self._config.Cards
	local frame = Instance.new("Frame")
	frame.Name = "Levels"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(cards.Margin, cards.Top)
	frame.Size = UDim2.new(1, -cards.Margin * 2, 1, -(cards.Top + cards.Bottom))
	frame.Visible = false
	frame.ClipsDescendants = true
	frame.Parent = parent

	local scroll = Instance.new("Frame")
	scroll.Name = "Grid"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Parent = frame

	self._frame = frame
	self._scroll = scroll
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	self._wheel = UserInputService.InputChanged:Connect(function(input)
		if not self._visible or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		self._scrollY -= input.Position.Z * 48
		self:_applyScroll()
	end)
end

function LevelSelect:setCurrent(displayName)
	if typeof(displayName) ~= "string" then
		return
	end
	self._current = displayName
	self:_mark()
end

function LevelSelect:refresh()
	local scroll = self._scroll
	if scroll == nil then
		return
	end
	for _, card in self._cards do
		card.button:Destroy()
	end
	table.clear(self._cards)

	local shown = {}
	local featuredSeen = false
	for _, row in self._registry do
		if Workspace:FindFirstChild(row.modelName) then
			table.insert(shown, row)
			if row.featured then
				featuredSeen = true
			end
		end
	end

	for index, row in shown do
		local featured = row.featured == true or (not featuredSeen and index == 1)
		local card = self:_card(row, featured)
		table.insert(self._cards, card)
	end
	self:_layout()
	self:_mark()
end

function LevelSelect:setVisible(visible)
	self._visible = visible
	if self._frame then
		self._frame.Visible = visible
	end
	if visible then
		task.defer(function()
			self:_layout()
			self:_kick()
		end)
	end
end

function LevelSelect:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._wheel then
		self._wheel:Disconnect()
		self._wheel = nil
	end
end

function LevelSelect:_card(row, featured)
	local config = self._config
	local cards = config.Cards
	local button = Instance.new("TextButton")
	button.Name = row.id
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.ClipsDescendants = true
	button.Parent = self._scroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cards.Corner)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = config.Accent
	stroke.Thickness = cards.Stroke
	stroke.Enabled = false
	stroke.Parent = button

	local preview = typeof(row.preview) == "string" and row.preview ~= ""
	if preview then
		local image = Instance.new("ImageLabel")
		image.Name = "Preview"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Crop
		image.Image = row.preview
		image.ZIndex = 1
		image.Parent = button
	else
		local model = Workspace:FindFirstChild(row.modelName)
		task.spawn(function()
			if button.Parent == nil then
				return
			end
			LevelPreview.attach(button, model, CourseConfig.Tags.Kill)
		end)
	end

	local titleSize = featured and cards.FeaturedTitle or cards.TitleSize
	local bestY = cards.Pad
	local summaryY = bestY + cards.BestSize + cards.TextGap
	local titleY = summaryY + cards.SummarySize + cards.TextGap
	local washHeight = titleY + titleSize + cards.Fade

	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.AnchorPoint = Vector2.new(0, 1)
	wash.Position = UDim2.fromScale(0, 1)
	wash.Size = UDim2.new(1, 0, 0, washHeight)
	wash.BackgroundColor3 = cards.WashColor
	wash.BorderSizePixel = 0
	wash.ZIndex = 2
	wash.Parent = button

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.62, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = wash

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0, cards.Pad, 1, -titleY)
	title.Size = UDim2.new(1, -cards.Pad * 2, 0, titleSize)
	title.Font = config.Font
	title.TextSize = titleSize
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Bottom
	title.TextColor3 = config.Text
	title.Text = row.displayName
	title.ZIndex = 3
	title.Parent = button

	local summary = Instance.new("TextLabel")
	summary.Name = "Summary"
	summary.BackgroundTransparency = 1
	summary.AnchorPoint = Vector2.new(0, 1)
	summary.Position = UDim2.new(0, cards.Pad, 1, -summaryY)
	summary.Size = UDim2.new(1, -cards.Pad * 2, 0, cards.SummarySize + 2)
	summary.Font = config.BodyFont
	summary.TextSize = cards.SummarySize
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Bottom
	summary.TextColor3 = config.Text
	summary.Text = typeof(row.summary) == "string" and row.summary or ""
	summary.ZIndex = 3
	summary.Parent = button

	local best = Instance.new("TextLabel")
	best.Name = "Best"
	best.BackgroundTransparency = 1
	best.AnchorPoint = Vector2.new(0, 1)
	best.Position = UDim2.new(0, cards.Pad, 1, -bestY)
	best.Size = UDim2.new(1, -cards.Pad * 2, 0, cards.BestSize + 2)
	best.Font = config.Font
	best.TextSize = cards.BestSize
	best.TextXAlignment = Enum.TextXAlignment.Left
	best.TextYAlignment = Enum.TextYAlignment.Bottom
	best.TextColor3 = config.Muted
	best.Text = "Best --"
	best.ZIndex = 3
	best.Parent = button

	local id = row.id
	button.Activated:Connect(function()
		self._onPick(id)
	end)

	local card = {
		button = button,
		stroke = stroke,
		best = best,
		id = id,
		displayName = row.displayName,
		featured = featured,
	}
	self:_showBest(card)
	return card
end

function LevelSelect:_layout()
	local scroll = self._scroll
	local cards = self._config.Cards
	if scroll == nil or scroll.AbsoluteSize.X < 10 then
		return
	end
	local width = scroll.AbsoluteSize.X
	local gap = cards.Gap
	local columns = cards.Columns
	local cellW = (width - gap * (columns - 1)) / columns
	local cellH = cellW * cards.Aspect
	local items = {}
	for _, card in self._cards do
		table.insert(items, card)
	end
	local placed, tallest = pack(items, columns, cards.FeaturedColumns, cards.FeaturedRows)
	for _, spot in placed do
		local card = spot.item
		local w = spot.w * cellW + (spot.w - 1) * gap
		local h = spot.h * cellH + (spot.h - 1) * gap
		card.button.Position = UDim2.fromOffset(spot.x * (cellW + gap), spot.y * (cellH + gap))
		card.button.Size = UDim2.fromOffset(w, h)
	end
	local height = 0
	if tallest > 0 then
		height = tallest * cellH + (tallest - 1) * gap
	end
	self._contentHeight = height
	self:_applyScroll()
end

function LevelSelect:_applyScroll()
	local frame = self._frame
	local scroll = self._scroll
	if frame == nil or scroll == nil then
		return
	end
	local maxScroll = math.max(0, self._contentHeight - frame.AbsoluteSize.Y)
	self._scrollY = math.clamp(self._scrollY, 0, maxScroll)
	scroll.Position = UDim2.fromOffset(0, -self._scrollY)
end

function LevelSelect:_kick()
	for _, card in self._cards do
		local viewport = card.button:FindFirstChild("Preview")
		local camera = viewport and viewport:IsA("ViewportFrame") and viewport.CurrentCamera
		if camera then
			local cf = camera.CFrame
			camera.CFrame = cf * CFrame.new(0, 0, -0.05)
			camera.CFrame = cf
		end
	end
end

function LevelSelect:_mark()
	for _, card in self._cards do
		card.stroke.Enabled = card.displayName == self._current and self._current ~= ""
	end
end

function LevelSelect:_onCourse(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.kind == "catalog" and typeof(payload.bests) == "table" then
		self._bests = {}
		for _, entry in payload.bests do
			if typeof(entry) == "table" and typeof(entry.id) == "string" then
				self._bests[entry.id] = entry.seconds
			end
		end
		for _, card in self._cards do
			self:_showBest(card)
		end
	end
	if typeof(payload.mapName) == "string" then
		self:setCurrent(payload.mapName)
	end
end

function LevelSelect:_showBest(card)
	local seconds = self._bests[card.id]
	if typeof(seconds) ~= "number" then
		card.best.Text = "Best --"
		card.best.TextColor3 = self._config.Muted
		return
	end
	card.best.Text = string.format("Best %.2f", math.max(0, seconds))
	card.best.TextColor3 = self._config.Accent
end

return LevelSelect
