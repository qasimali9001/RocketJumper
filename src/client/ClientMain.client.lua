-- Client wiring only. Domain rules live in the controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local MovementConfig = require(Config:WaitForChild("MovementConfig"))
local RocketConfig = require(Config:WaitForChild("RocketConfig"))
local InputConfig = require(Config:WaitForChild("InputConfig"))
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local HudConfig = require(Config:WaitForChild("HudConfig"))
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local ViewConfig = require(Config:WaitForChild("ViewConfig"))
local PolishConfig = require(Config:WaitForChild("PolishConfig"))
local MenuConfig = require(Config:WaitForChild("MenuConfig"))
local MapRegistry = require(Config:WaitForChild("MapRegistry"))

local InputController = require(script.Parent.Input.InputController)
local CameraController = require(script.Parent.Camera.CameraController)
local SpeedLines = require(script.Parent.Camera.SpeedLines)
local MovementController = require(script.Parent.Movement.MovementController)
local SpeedHud = require(script.Parent.UI.SpeedHud)
local AirControlPanel = require(script.Parent.UI.AirControlPanel)
local RocketController = require(script.Parent.Rocket.RocketController)
local CourseController = require(script.Parent.Course.CourseController)
local TargetFlash = require(script.Parent.Course.TargetFlash)
local CourseBanner = require(script.Parent.UI.CourseBanner)
local TimerHud = require(script.Parent.UI.TimerHud)
local TargetHud = require(script.Parent.UI.TargetHud)
local Crosshair = require(script.Parent.UI.Crosshair)
local LeaderboardHud = require(script.Parent.UI.LeaderboardHud)
local MenuController = require(script.Parent.UI.Menu.MenuController)
local MusicController = require(script.Parent.Audio.MusicController)
local SfxController = require(script.Parent.Audio.SfxController)
local LauncherView = require(script.Parent.View.LauncherView)

local player = Players.LocalPlayer

local input = InputController.new(InputConfig)
local camera = CameraController.new(CameraConfig, PolishConfig, player)
local speedLines = SpeedLines.new(PolishConfig.SpeedLines, camera)
local hud = SpeedHud.new(HudConfig)
local airTune = AirControlPanel.new({ HudConfig.AirTune, HudConfig.RocketTune }, {
	movement = MovementConfig,
	rocket = RocketConfig,
}, input, camera)

local course = CourseController.new(input)
local banner = CourseBanner.new(HudConfig.CourseBanner)
local timerHud = TimerHud.new(HudConfig.Timer)
local targetHud = TargetHud.new(HudConfig.TargetCount)
local crosshair = Crosshair.new(HudConfig.Crosshair)
local leaderboard = LeaderboardHud.new(HudConfig.Leaderboard)
local music = MusicController.new(AudioConfig.Music)
local sfx = SfxController.new(AudioConfig)
local launcher = LauncherView.new(ViewConfig, PolishConfig.Muzzle)
local menu = MenuController.new(MenuConfig, MapRegistry, {
	input = input,
	camera = camera,
	music = music,
	sfx = sfx,
})
local targetFlash = TargetFlash.new(PolishConfig.TargetFlash)

input:start()
camera:start()
speedLines:start()
hud:start()
airTune:start()
course:start()
banner:start()
timerHud:start()
targetHud:start()
crosshair:start()
leaderboard:start()
music:start()
sfx:start()
launcher:start()
targetFlash:start()
menu:start()

local movement = nil
local rocket = nil
local spawnToken = 0

local function onCharacter(character)
	spawnToken += 1
	local token = spawnToken
	if rocket then
		rocket:destroy()
		rocket = nil
	end
	if movement then
		movement:destroy()
		movement = nil
	end
	course:setMovement(nil)
	camera:setCharacter(character)
	local nextMovement = MovementController.new(MovementConfig, character, input)
	nextMovement:start(function(sample)
		hud:setSpeed(sample)
		camera:setSpeed(sample.horizontal)
	end)
	if token ~= spawnToken or character.Parent == nil then
		nextMovement:destroy()
		return
	end
	movement = nextMovement
	menu:bindMovement(movement)
	course:setMovement(movement)
	rocket = RocketController.new(RocketConfig, input, movement, character, function(instance)
		course:reportImpact(instance)
	end, {
		sfx = sfx,
		camera = camera,
		launcher = launcher,
		burst = PolishConfig.Burst,
		trail = PolishConfig.Trail,
	})
	rocket:start()
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
