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
local LeaderboardConfig = require(Config:WaitForChild("LeaderboardConfig"))
local MapRegistry = require(Config:WaitForChild("MapRegistry"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))
local MapCycle = require(script.Parent.Map.MapCycle)
local BestTimes = require(script.Parent.Course.BestTimes)
local RigGuard = require(script.Parent.Player.RigGuard)

RigGuard.start()

local respawn, course, targetHit, reset, hello, cycle, selectMap, pause = CourseRemotes.ensure()
local times = BestTimes.new(LeaderboardConfig)
local maps = MapCycle.new(MapRegistry, CourseConfig, respawn, course, targetHit, reset, hello, cycle, times, selectMap, pause)
maps:start()
