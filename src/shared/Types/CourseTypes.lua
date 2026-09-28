--!strict
-- Shapes the course and practice tools will pass around. No behavior.

export type MapDescriptor = {
	id: string,
	displayName: string,
	modelName: string,
}

export type Checkpoint = {
	order: number,
	cframe: CFrame,
}

export type SaveState = {
	position: Vector3,
	velocity: Vector3,
	yaw: number,
	checkpointOrder: number,
}

return {}
