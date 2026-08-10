--!strict

local Generator = {}
Generator.__index = Generator

export type Generator = typeof(setmetatable({} :: { state: number }, Generator))

local DeterministicRng = {}

function DeterministicRng.new(seed: number): Generator
	local normalized = bit32.band(seed, 0xffffffff)
	if normalized == 0 then
		normalized = 0x6d2b79f5
	end
	return setmetatable({ state = normalized }, Generator)
end

function Generator.nextU32(self: Generator): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	x = bit32.band(x, 0xffffffff)
	if x == 0 then
		x = 0x6d2b79f5
	end
	self.state = x
	return x
end

function Generator.nextNumber(self: Generator): number
	return Generator.nextU32(self) / 4294967296
end

function Generator.nextInteger(self: Generator, minimum: number, maximum: number): number
	assert(minimum <= maximum, "minimum must be <= maximum")
	local width = maximum - minimum + 1
	return minimum + math.floor(Generator.nextNumber(self) * width)
end

function Generator.chance(self: Generator, probability: number): boolean
	assert(probability >= 0 and probability <= 1, "probability must be in [0, 1]")
	return Generator.nextNumber(self) < probability
end

return table.freeze(DeterministicRng)
