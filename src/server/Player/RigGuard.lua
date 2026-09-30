-- Keeps a respawn from ragdolling. The client still owns velocity.

local Players = game:GetService("Players")

local RigGuard = {}

local BLOCKED = {
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Physics,
}

function RigGuard._releaseRagdoll(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BallSocketConstraint") then
			descendant:Destroy()
		end
	end
end

function RigGuard._claim(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid == nil or character.Parent == nil then
		return
	end
	humanoid.BreakJointsOnDeath = false
	for _, state in BLOCKED do
		humanoid:SetStateEnabled(state, false)
	end
	RigGuard._releaseRagdoll(character)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	task.defer(function()
		if character.Parent == nil or humanoid.Parent == nil then
			return
		end
		RigGuard._releaseRagdoll(character)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)
end

function RigGuard._hook(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(RigGuard._claim, character)
	end)
	if player.Character then
		task.spawn(RigGuard._claim, player.Character)
	end
end

function RigGuard.start()
	Players.PlayerAdded:Connect(RigGuard._hook)
	for _, player in Players:GetPlayers() do
		RigGuard._hook(player)
	end
end

return RigGuard
