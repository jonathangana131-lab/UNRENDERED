--!strict

local DeterminismContract = require(script.Parent.DeterminismContract)

local UINT32 = 4294967296
local MAX_SAFE_INTEGER = 9007199254740991

local Generator = {}
Generator.__index = Generator

export type Generator = typeof(setmetatable({} :: { state: number }, Generator))

local DeterministicRng = {
	ContractVersion = DeterminismContract.RngVersion,
}

local function isSafeInteger(value: number): boolean
	if value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	return value % 1 == 0 and math.abs(value) <= MAX_SAFE_INTEGER
end

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
	assert(isSafeInteger(minimum) and isSafeInteger(maximum), "minimum and maximum must be safe integers")
	assert(minimum <= maximum, "minimum must be <= maximum")
	local width = maximum - minimum + 1
	assert(width <= UINT32, "integer range width must be <= 2^32")

	local acceptanceLimit = UINT32 - (UINT32 % width)
	local sample = Generator.nextU32(self)
	while sample >= acceptanceLimit do
		sample = Generator.nextU32(self)
	end

	return minimum + (sample % width)
end

function Generator.chance(self: Generator, probability: number): boolean
	assert(probability >= 0 and probability <= 1, "probability must be in [0, 1]")
	return Generator.nextNumber(self) < probability
end

return table.freeze(DeterministicRng)
