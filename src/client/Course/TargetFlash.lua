-- A short flash where a target clears. Does not change the clear or the hide.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("RocketJumper"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("Class"))
local CourseConfig = require(Shared:WaitForChild("Config"):WaitForChild("CourseConfig"))
local CourseRemotes = require(Shared:WaitForChild("Net"):WaitForChild("CourseRemotes"))

local TargetFlash = {}
TargetFlash.__index = TargetFlash

function TargetFlash.new(config)
	local self = Class.instance(TargetFlash)
	self._config = config
	self._seen = {}
	self._connection = nil
	return self
end

function TargetFlash:start()
	if self._connection or not self._config.Enabled then
		return
	end
	self._connection = CourseRemotes.course().OnClientEvent:Connect(function(payload)
		self:_onCourse(payload)
	end)
end

function TargetFlash:destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	table.clear(self._seen)
end

function TargetFlash:_onCourse(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.kind == "reset" or payload.kind == "map" then
		table.clear(self._seen)
		return
	end
	if payload.kind ~= "target" or typeof(payload.clearedIds) ~= "table" then
		return
	end
	for _, id in payload.clearedIds do
		if not self._seen[id] then
			self._seen[id] = true
			self:_flash(id)
		end
	end
end

function TargetFlash:_flash(id)
	local config = self._config
	if config.Time <= 0 then
		return
	end
	local part = self:_find(id)
	if part == nil then
		return
	end
	local flash = Instance.new("Part")
	flash.Name = "TargetFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = part.Size
	flash.CFrame = part.CFrame
	flash.Color = config.Color
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.15
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Parent = workspace
	local grow = config.Grow
	if grow < 1 then
		grow = 1
	end
	local tween = TweenService:Create(flash, TweenInfo.new(config.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = part.Size * grow,
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(flash, config.Time + 0.05)
end

function TargetFlash:_find(id)
	for _, part in CollectionService:GetTagged(CourseConfig.Tags.Target) do
		if part:GetAttribute("Id") == id and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

return TargetFlash
