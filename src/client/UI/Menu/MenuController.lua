-- Start screen on load, pause during a run, level list, and options.
-- Escape stays the Roblox menu. M opens this one. Does not write velocity.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local InputConfig = require(Shared:WaitForChild("Config"):WaitForChild("InputConfig"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))
local MenuChrome = require(script.Parent.MenuChrome)
local LevelSelect = require(script.Parent.LevelSelect)
local OptionsPanel = require(script.Parent.OptionsPanel)

local MenuController = {}
MenuController.__index = MenuController

function MenuController.new(config, registry, deps)
	local self = Class.instance(MenuController)
	self._config = config
	self._input = deps.input
	self._camera = deps.camera
	self._music = deps.music
	self._sfx = deps.sfx
	self._movement = nil
	self._mode = "start"
	self._back = "start"
	self._robloxOpen = false
	self._serverHeld = false
	self._gui = nil
	self._shade = nil
	self._title = nil
	self._hint = nil
	self._actions = nil
	self._connections = {}
	self._levels = LevelSelect.new(config, registry, function(mapId)
		self:_play(mapId)
	end)
	self._options = OptionsPanel.new(config, {
		music = {
			get = function()
				return self._music:getVolume()
			end,
			set = function(value)
				self._music:setVolume(value)
			end,
		},
		effects = {
			get = function()
				return self._sfx:getScale()
			end,
			set = function(value)
				self._sfx:setScale(value)
			end,
		},
		sensitivity = {
			get = function()
				return self:_mouse()
			end,
			set = function(value)
				self:_setMouse(value)
			end,
		},
	})
	return self
end

function MenuController:start()
	if self._gui then
		return
	end
	local config = self._config
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = config.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = config.Background
	shade.BackgroundTransparency = config.BackgroundTransparency
	shade.BorderSizePixel = 0
	shade.Active = true
	shade.Parent = gui

	local title = MenuChrome.title(shade, config, config.Title)
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -28)
	hint.Size = UDim2.fromOffset(720, 24)
	hint.Font = config.BodyFont
	hint.TextSize = config.HintSize
	hint.TextColor3 = config.Muted
	hint.Text = config.Hint
	hint.Parent = shade

	local actions = MenuChrome.stack(shade, config, "Actions")
	MenuChrome.button(actions, config, "Resume", 30, function()
		self:_play(nil)
	end)
	MenuChrome.button(actions, config, "Level Select", 31, function()
		self._back = "pause"
		self._levels:refresh()
		self:_setMode("levels")
	end)
	MenuChrome.button(actions, config, "Options", 32, function()
		self._back = self._mode == "pause" and "pause" or "start"
		self._options:refresh()
		self:_setMode("options")
	end)
	MenuChrome.button(actions, config, "Back", 33, function()
		self:_setMode(self._back)
	end)
	self._options:mount(actions)
	self._levels:mount(shade)

	local headerOptions = self:_header(shade, "Options", function()
		self._back = "start"
		self._options:refresh()
		self:_setMode("options")
	end)
	local headerBack = self:_header(shade, "Back", function()
		self:_setMode(self._back)
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._gui = gui
	self._shade = shade
	self._title = title
	self._hint = hint
	self._actions = actions
	self._headerOptions = headerOptions
	self._headerBack = headerBack
	self._levels:refresh()

	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input)
		self:_onKey(input)
	end))
	table.insert(self._connections, GuiService.MenuOpened:Connect(function()
		self._robloxOpen = true
		self:_applyHold()
	end))
	table.insert(self._connections, GuiService.MenuClosed:Connect(function()
		self._robloxOpen = false
		self:_applyHold()
	end))
	table.insert(self._connections, CourseRemotes.course().OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.mapName) == "string" then
			self._levels:setCurrent(payload.mapName)
		end
		if self._mode ~= "play" or self._robloxOpen then
			CourseRemotes.pause():FireServer(true)
		end
	end))

	self:_setMode("start")
end

function MenuController:bindMovement(movement)
	self._movement = movement
	self:_applyHold()
end

function MenuController:isPlaying()
	return self._mode == "play" and not self._robloxOpen
end

function MenuController:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._options:destroy()
	self._levels:destroy()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

function MenuController:_play(mapId)
	self:_setMode("play")
	if typeof(mapId) == "string" and mapId ~= "" then
		CourseRemotes.select():FireServer(mapId)
	end
end

function MenuController:_setMode(mode)
	self._mode = mode
	local config = self._config
	self._shade.Visible = mode ~= "play"
	self._levels:setVisible(mode == "start" or mode == "levels")
	self._options:setVisible(mode == "options")
	self._actions.Visible = mode == "pause" or mode == "options"
	self._headerOptions.Visible = mode == "start"
	self._headerBack.Visible = mode == "levels"
	if mode == "start" then
		self._title.Text = config.Title
	elseif mode == "pause" then
		self._title.Text = config.PauseTitle
	elseif mode == "levels" then
		self._title.Text = config.LevelsTitle
	elseif mode == "options" then
		self._title.Text = config.OptionsTitle
	end
	self:_placeTitle(mode)
	self:_showActions(mode)
	self._hint.Visible = mode == "start"
	self:_applyHold()
end

function MenuController:_placeTitle(mode)
	local title = self._title
	local cards = self._config.Cards
	if mode == "start" or mode == "levels" then
		title.AnchorPoint = Vector2.new(0, 0)
		title.Position = UDim2.fromOffset(cards.Margin, 28)
		title.TextXAlignment = Enum.TextXAlignment.Left
	else
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.fromScale(0.5, 0.16)
		title.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function MenuController:_header(parent, text, activated)
	local config = self._config
	local button = Instance.new("TextButton")
	button.Name = "Header" .. text
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -config.Cards.Margin, 0, 28)
	button.Size = UDim2.fromOffset(140, 40)
	button.BackgroundColor3 = config.Button
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = config.Font
	button.TextSize = 18
	button.TextColor3 = config.Text
	button.Text = text
	button.Visible = false
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.Corner)
	corner.Parent = button
	button.Activated:Connect(activated)
	return button
end

function MenuController:_showActions(mode)
	for _, child in self._actions:GetChildren() do
		if child:IsA("TextButton") then
			local name = child.Name
			if name == "Resume" or name == "Level Select" then
				child.Visible = mode == "pause"
			elseif name == "Options" then
				child.Visible = mode == "pause"
			elseif name == "Back" then
				child.Visible = mode == "levels" or mode == "options"
			end
		end
	end
end

function MenuController:_applyHold()
	local held = self._mode ~= "play" or self._robloxOpen
	self._input:setBlocked(held)
	self._camera:setMouseLocked(not held)
	if self._movement then
		self._movement:setHeld(held)
	end
	self:_tellServer(held)
end

function MenuController:_tellServer(held)
	if held == self._serverHeld then
		return
	end
	self._serverHeld = held
	CourseRemotes.pause():FireServer(held)
end

function MenuController:_onKey(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if not self:_isMenuKey(input.KeyCode) then
		return
	end
	if self._mode == "play" then
		self:_setMode("pause")
	elseif self._mode == "pause" then
		self:_play(nil)
	elseif self._mode == "levels" or self._mode == "options" then
		self:_setMode(self._back)
	end
end

function MenuController:_isMenuKey(keyCode)
	for _, listed in InputConfig.Menu do
		if listed == keyCode then
			return true
		end
	end
	return false
end

function MenuController:_mouse()
	local ok, value = pcall(function()
		return UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	if ok and typeof(value) == "number" then
		return value
	end
	return self._config.Sensitivity.Min
end

function MenuController:_setMouse(value)
	pcall(function()
		UserSettings():GetService("UserGameSettings").MouseSensitivity = value
	end)
end

return MenuController
