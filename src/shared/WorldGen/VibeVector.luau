--!strict

export type VibeVector = {
	normality: number,
	familiarity: number,
	nostalgia: number,
	comfort: number,
	loneliness: number,
	dreamness: number,
	oppression: number,
	beauty: number,
	sterility: number,
	decay: number,
	humidity: number,
	warmth: number,
	darkness: number,
	vastness: number,
	claustrophobia: number,
	temporalWrongness: number,
	visualInstability: number,
	acousticEmptiness: number,
	humanTrace: number,
	biologicalWrongness: number,
	electricalInstability: number,
}

local VibeVector = {}

function VibeVector.neutral(): VibeVector
	return table.freeze({
		normality = 1,
		familiarity = 0.7,
		nostalgia = 0.3,
		comfort = 0.25,
		loneliness = 0.8,
		dreamness = 0.1,
		oppression = 0.2,
		beauty = 0.1,
		sterility = 0.4,
		decay = 0.15,
		humidity = 0.2,
		warmth = 0.5,
		darkness = 0.15,
		vastness = 0.25,
		claustrophobia = 0.2,
		temporalWrongness = 0,
		visualInstability = 0,
		acousticEmptiness = 0.5,
		humanTrace = 0.05,
		biologicalWrongness = 0,
		electricalInstability = 0.05,
	})
end

return table.freeze(VibeVector)
