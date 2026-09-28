-- Server wiring only. Stage 1 movement runs on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

require(Config:WaitForChild("MovementConfig"))
require(Config:WaitForChild("RocketConfig"))
require(Config:WaitForChild("CourseConfig"))
require(Config:WaitForChild("InputConfig"))
require(Config:WaitForChild("CameraConfig"))
require(Config:WaitForChild("HudConfig"))
require(Config:WaitForChild("MapRegistry"))
