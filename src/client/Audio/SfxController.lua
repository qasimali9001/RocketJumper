-- One-shot cues. Does not write velocity.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local SfxController = {}
SfxController.__index = SfxController

function SfxController.new(config)
	local self = Class.instance(SfxController)
	self._config = config
	self._scale = 1
	self._connection = nil
	return self
end

function SfxController:start()
	if self._connection then
		return
	end
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end)
end

function SfxController:getScale()
	return self._scale
end

function SfxController:setScale(scale)
	if typeof(scale) ~= "number" then
		return
	end
	self._scale = math.clamp(scale, 0, 1)
end

function SfxController:play(name)
	local cue = self._config[name]
	local volume = cue and (cue.Volume or 0) * self._scale or 0
	if cue == nil or volume <= 0 then
		return
	end
	if cue.SoundId == nil or cue.SoundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = cue.SoundId
	sound.Volume = volume
	sound.PlaybackSpeed = cue.PlaybackSpeed or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 8)
end

function SfxController:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function SfxController:_onCourse(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.kind == "target" then
		self:play("Target")
	elseif payload.kind == "finish" then
		self:play("Finish")
	end
end

return SfxController
