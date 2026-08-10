--!strict

export type Generator = {
	state: number,
	nextU32: (self: Generator) -> number,
	nextNumber: (self: Generator) -> number,
	nextInteger: (self: Generator, minimum: number, maximum: number) -> number,
	chance: (self: Generator, probability: number) -> boolean,
}

local DeterministicRng = {}

local Generator = {}
Generator.__index = Generator

function DeterministicRng.new(seed: number): Generator
	local normalized = bit32.band(seed, 0xffffffff)
	if normalized == 0 then
		normalized = 0x6d2b79f5
	end
	return setmetatable({ state = normalized }, Generator) :: any
end

function Generator:nextU32(): number
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

function Generator:nextNumber(): number
	return self:nextU32() / 4294967296
end

function Generator:nextInteger(minimum: number, maximum: number): number
	assert(minimum <= maximum, "minimum must be <= maximum")
	local width = maximum - minimum + 1
	return minimum + math.floor(self:nextNumber() * width)
end

function Generator:chance(probability: number): boolean
	assert(probability >= 0 and probability <= 1, "probability must be in [0, 1]")
	return self:nextNumber() < probability
end

return table.freeze(DeterministicRng)
