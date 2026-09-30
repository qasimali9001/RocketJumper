-- Loops the background track. Does not write velocity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Class = require(ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared"):WaitForChild("Class"))

local MusicController = {}
MusicController.__index = MusicController

function MusicController.new(config)
	local self = Class.instance(MusicController)
	self._config = config
	self._sound = nil
	return self
end

function MusicController:start()
	local config = self._config
	if not config.Enabled then
		return
	end
	if config.SoundId == nil or config.SoundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = config.SoundId
	sound.Volume = config.Volume
	sound.Looped = config.Looped
	sound.Parent = SoundService
	sound:Play()
	self._sound = sound
end

function MusicController:getVolume()
	return self._config.Volume
end

function MusicController:setVolume(volume)
	if typeof(volume) ~= "number" then
		return
	end
	self._config.Volume = math.clamp(volume, 0, 1)
	if self._sound then
		self._sound.Volume = self._config.Volume
	end
end

function MusicController:destroy()
	if self._sound then
		self._sound:Stop()
		self._sound:Destroy()
		self._sound = nil
	end
end

return MusicController
