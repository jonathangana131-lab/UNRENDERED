--!strict

local DeterminismContract = require(script.Parent.DeterminismContract)

local UINT32 = 4294967296

local Generator = {}
Generator.__index = Generator

export type Generator = typeof(setmetatable({} :: { state: number }, Generator))

local DeterministicRng = {
	ContractVersion = DeterminismContract.RngVersion,
}

function DeterministicRng.new(seed: number): Generator
	return setmetatable({ state = DeterminismContract.normalizeRngSeed(seed) }, Generator)
end

function Generator.nextU32(self: Generator): number
	local nextState = DeterminismContract.nextRngState(self.state)
	self.state = nextState
	return nextState
end

function Generator.nextNumber(self: Generator): number
	return Generator.nextU32(self) / UINT32
end

function Generator.nextInteger(self: Generator, minimum: number, maximum: number): number
	local nextState, value = DeterminismContract.nextIntegerState(self.state, minimum, maximum)
	self.state = nextState
	return value
end

function Generator.chance(self: Generator, probability: number): boolean
	assert(probability >= 0 and probability <= 1, "probability must be in [0, 1]")
	return Generator.nextNumber(self) < probability
end

return table.freeze(DeterministicRng)
