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

local InputController = require(script.Parent.Input.InputController)
local CameraController = require(script.Parent.Camera.CameraController)
local MovementController = require(script.Parent.Movement.MovementController)
local SpeedHud = require(script.Parent.UI.SpeedHud)
local AirControlPanel = require(script.Parent.UI.AirControlPanel)
local RocketController = require(script.Parent.Rocket.RocketController)

local player = Players.LocalPlayer

local input = InputController.new(InputConfig)
local camera = CameraController.new(CameraConfig, player)
local hud = SpeedHud.new(HudConfig)
local airTune = AirControlPanel.new({ HudConfig.AirTune, HudConfig.RocketTune }, {
	movement = MovementConfig,
	rocket = RocketConfig,
}, input, camera)

input:start()
camera:start()
hud:start()
airTune:start()

local movement = nil
local rocket = nil

local function onCharacter(character)
	if rocket then
		rocket:destroy()
		rocket = nil
	end
	if movement then
		movement:destroy()
		movement = nil
	end
	camera:setCharacter(character)
	movement = MovementController.new(MovementConfig, character, input)
	movement:start(function(sample)
		hud:setSpeed(sample)
	end)
	rocket = RocketController.new(RocketConfig, input, movement, character)
	rocket:start()
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
