-- Server wiring only. Course rules live in CourseSession.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

require(Config:WaitForChild("MovementConfig"))
require(Config:WaitForChild("RocketConfig"))
require(Config:WaitForChild("InputConfig"))
require(Config:WaitForChild("CameraConfig"))
require(Config:WaitForChild("HudConfig"))

local CourseConfig = require(Config:WaitForChild("CourseConfig"))
local MapRegistry = require(Config:WaitForChild("MapRegistry"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))
local MapCycle = require(script.Parent.Map.MapCycle)
local RigGuard = require(script.Parent.Player.RigGuard)

RigGuard.start()

local respawn, course, targetHit, reset, hello, cycle = CourseRemotes.ensure()
local maps = MapCycle.new(MapRegistry, CourseConfig, respawn, course, targetHit, reset, hello, cycle)
maps:start()
