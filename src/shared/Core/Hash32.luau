--!strict

local UINT32 = 4294967296

local Hash32 = {}

local function u32(value: number): number
	return value % UINT32
end

function Hash32.jenkins(text: string, seed: number?): number
	local hash = u32(seed or 0)

	for index = 1, #text do
		hash = u32(hash + string.byte(text, index))
		hash = u32(hash + bit32.lshift(hash, 10))
		hash = bit32.bxor(hash, bit32.rshift(hash, 6))
	end

	hash = u32(hash + bit32.lshift(hash, 3))
	hash = bit32.bxor(hash, bit32.rshift(hash, 11))
	hash = u32(hash + bit32.lshift(hash, 15))

	return hash
end

function Hash32.combine(seed: number, ...: string): number
	local hash = seed
	for _, value in { ... } do
		hash = Hash32.jenkins(value, hash)
		hash = Hash32.jenkins("\31", hash)
	end
	return hash
end

function Hash32.hex(value: number): string
	return string.format("%08x", value)
end

return table.freeze(Hash32)
