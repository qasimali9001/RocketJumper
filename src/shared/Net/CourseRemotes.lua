-- Server creates the course events. The client only waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseRemotes = {}

function CourseRemotes.ensure()
	local root = ReplicatedStorage:WaitForChild("RocketJumper")
	local net = root:FindFirstChild("Net")
	if net == nil then
		net = Instance.new("Folder")
		net.Name = "Net"
		net.Parent = root
	end
	return CourseRemotes._event(net, "Respawn"),
		CourseRemotes._event(net, "Course"),
		CourseRemotes._event(net, "TargetHit"),
		CourseRemotes._event(net, "Reset"),
		CourseRemotes._event(net, "Hello"),
		CourseRemotes._event(net, "Cycle"),
		CourseRemotes._event(net, "Select"),
		CourseRemotes._event(net, "Pause")
end

function CourseRemotes._event(net, name)
	local remote = net:FindFirstChild(name)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = net
	end
	return remote
end

function CourseRemotes._wait(name)
	local root = ReplicatedStorage:WaitForChild("RocketJumper")
	local net = root:WaitForChild("Net")
	return net:WaitForChild(name)
end

function CourseRemotes.respawn()
	return CourseRemotes._wait("Respawn")
end

function CourseRemotes.course()
	return CourseRemotes._wait("Course")
end

function CourseRemotes.targetHit()
	return CourseRemotes._wait("TargetHit")
end

function CourseRemotes.reset()
	return CourseRemotes._wait("Reset")
end

function CourseRemotes.hello()
	return CourseRemotes._wait("Hello")
end

function CourseRemotes.cycle()
	return CourseRemotes._wait("Cycle")
end

function CourseRemotes.select()
	return CourseRemotes._wait("Select")
end

function CourseRemotes.pause()
	return CourseRemotes._wait("Pause")
end

return CourseRemotes
