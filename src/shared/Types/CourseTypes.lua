--!strict
-- Shapes the course passes around. No behavior.

export type MapDescriptor = {
	id: string,
	displayName: string,
	modelName: string,
}

export type Target = {
	id: string,
}

export type RunResult = {
	elapsed: number,
	cleared: number,
	total: number,
}

return {}
