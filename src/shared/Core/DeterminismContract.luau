--!strict

local UINT32 = 4294967296
local MAX_SAFE_INTEGER = 9007199254740991
local RNG_ZERO_FALLBACK = 0x6d2b79f5
local SEED_STREAM_ROOT = 0x9e3779b9
local MAX_SEMANTIC_PARTS = 32
local MAX_SEMANTIC_PART_BYTES = 512
local MAX_WORLD_SEED_BYTES = 512
local STABLE_ID_HASH_SEEDS = {
	0x243f6a88,
	0x85a308d3,
	0x13198a2e,
	0x03707344,
}

local DeterminismContract = {
	EncodingVersion = 1,
	Hash32Version = 1,
	StableIdVersion = 1,
	RngVersion = 1,
	SeedStreamVersion = 1,
}

local function isSafeInteger(value: number): boolean
	if value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	return value % 1 == 0 and math.abs(value) <= MAX_SAFE_INTEGER
end

local function assertU32(value: number, label: string)
	assert(
		isSafeInteger(value) and value >= 0 and value < UINT32,
		`{label} must be an unsigned 32-bit integer`
	)
end

local function u32(value: number): number
	return value % UINT32
end

local function validateStringArray(parts: { string }, label: string, allowEmptyStrings: boolean): number
	assert(type(parts) == "table", `{label} must be an array`)
	local length = #parts

	for key, value in pairs(parts) do
		assert(
			type(key) == "number" and isSafeInteger(key) and key >= 1 and key <= length,
			`{label} must be a dense 1-based array`
		)
		assert(type(value) == "string", `{label}[{key}] must be a string`)
	end

	for index = 1, length do
		local value = parts[index]
		assert(type(value) == "string", `{label} must be a dense 1-based array`)
		if not allowEmptyStrings then
			assert(value ~= "", `{label}[{index}] must not be empty`)
		end
	end

	return length
end

local function isNamespace(namespace: string): boolean
	return #namespace >= 1 and #namespace <= 64 and string.match(namespace, "^[a-z][a-z0-9_.-]*$") ~= nil
end

local function isSubsystemSalt(subsystemSalt: string): boolean
	if #subsystemSalt < 3 or #subsystemSalt > 128 then
		return false
	end
	if string.sub(subsystemSalt, 1, 1) == "." or string.sub(subsystemSalt, -1) == "." then
		return false
	end
	if string.find(subsystemSalt, "..", 1, true) ~= nil then
		return false
	end

	local componentCount = 0
	for component in string.gmatch(subsystemSalt, "[^.]+") do
		if string.match(component, "^[a-z][a-z0-9_-]*$") == nil then
			return false
		end
		componentCount += 1
	end

	return componentCount >= 2
end

function DeterminismContract.encodeParts(parts: { string }): string
	local length = validateStringArray(parts, "parts", true)
	local chunks = { `u{DeterminismContract.EncodingVersion};{length};` }

	for index = 1, length do
		local value = parts[index]
		table.insert(chunks, `{#value}:`)
		table.insert(chunks, value)
	end

	return table.concat(chunks)
end

function DeterminismContract.hash32(text: string, seed: number): number
	assert(type(text) == "string", "text must be a string")
	assert(type(seed) == "number", "seed must be an unsigned 32-bit integer")
	assertU32(seed, "seed")
	local hash = seed

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

function DeterminismContract.hashParts(seed: number, parts: { string }): number
	assertU32(seed, "seed")
	return DeterminismContract.hash32(DeterminismContract.encodeParts(parts), seed)
end

function DeterminismContract.hex32(value: number): string
	assertU32(value, "value")
	return string.format("%08x", value)
end

function DeterminismContract.stableId(namespace: string, parts: { string }): string
	assert(
		type(namespace) == "string" and isNamespace(namespace),
		"namespace must match [a-z][a-z0-9_.-]* and be <= 64 bytes"
	)
	local length = validateStringArray(parts, "parts", false)
	assert(length > 0, "parts must contain at least one semantic part")
	assert(length <= MAX_SEMANTIC_PARTS, `parts must contain at most {MAX_SEMANTIC_PARTS} semantic parts`)
	for index = 1, length do
		assert(#parts[index] <= MAX_SEMANTIC_PART_BYTES, `parts[{index}] exceeds semantic-part byte limit`)
	end

	local payload = {
		"stable-id",
		tostring(DeterminismContract.StableIdVersion),
		namespace,
	}
	for index = 1, length do
		table.insert(payload, parts[index])
	end

	local digest = {}
	for _, seed in STABLE_ID_HASH_SEEDS do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hashParts(seed, payload)))
	end

	return string.format("%s:v%d:%s", namespace, DeterminismContract.StableIdVersion, table.concat(digest))
end

function DeterminismContract.isStableId(value: unknown, namespace: string?): boolean
	if type(value) ~= "string" then
		return false
	end
	if namespace ~= nil and (type(namespace) ~= "string" or not isNamespace(namespace)) then
		return false
	end

	local parsedNamespace, version, digest = string.match(value, "^([a-z][a-z0-9_.-]*):v(%d+):([0-9a-f]+)$")
	if parsedNamespace == nil or version == nil or digest == nil then
		return false
	end
	if #parsedNamespace > 64 or tonumber(version) ~= DeterminismContract.StableIdVersion or #digest ~= 32 then
		return false
	end
	if namespace ~= nil and parsedNamespace ~= namespace then
		return false
	end
	return true
end

function DeterminismContract.normalizeRngSeed(seed: number): number
	assertU32(seed, "seed")
	if seed == 0 then
		return RNG_ZERO_FALLBACK
	end
	return seed
end

function DeterminismContract.nextRngState(state: number): number
	local x = DeterminismContract.normalizeRngSeed(state)
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	x = bit32.band(x, 0xffffffff)
	if x == 0 then
		x = RNG_ZERO_FALLBACK
	end
	return x
end

function DeterminismContract.nextIntegerState(
	state: number,
	minimum: number,
	maximum: number
): (number, number)
	assert(isSafeInteger(minimum) and isSafeInteger(maximum), "minimum and maximum must be safe integers")
	assert(minimum <= maximum, "minimum must be <= maximum")
	local width = maximum - minimum + 1
	assert(width <= UINT32, "integer range width must be <= 2^32")

	local acceptanceLimit = UINT32 - (UINT32 % width)
	local nextState = DeterminismContract.nextRngState(state)
	while nextState >= acceptanceLimit do
		nextState = DeterminismContract.nextRngState(nextState)
	end

	return nextState, minimum + (nextState % width)
end

function DeterminismContract.seedFor(
	worldSeed: string,
	generationVersion: number,
	subsystemSalt: string,
	scopes: { string }
): number
	assert(type(worldSeed) == "string" and worldSeed ~= "", "worldSeed must not be empty")
	assert(#worldSeed <= MAX_WORLD_SEED_BYTES, `worldSeed must be <= {MAX_WORLD_SEED_BYTES} bytes`)
	assert(
		isSafeInteger(generationVersion) and generationVersion >= 1 and generationVersion <= 2147483647,
		"generationVersion must be an integer in [1, 2147483647]"
	)
	assert(
		type(subsystemSalt) == "string" and isSubsystemSalt(subsystemSalt),
		"subsystemSalt must use lowercase dotted components"
	)
	local scopeCount = validateStringArray(scopes, "scopes", false)
	assert(scopeCount > 0, "scopes must contain at least one semantic scope")
	assert(
		scopeCount <= MAX_SEMANTIC_PARTS,
		`scopes must contain at most {MAX_SEMANTIC_PARTS} semantic scopes`
	)
	for index = 1, scopeCount do
		assert(#scopes[index] <= MAX_SEMANTIC_PART_BYTES, `scopes[{index}] exceeds semantic-scope byte limit`)
	end

	local payload = {
		"seed-stream",
		tostring(DeterminismContract.SeedStreamVersion),
		worldSeed,
		tostring(generationVersion),
		subsystemSalt,
	}
	for index = 1, scopeCount do
		table.insert(payload, scopes[index])
	end

	return DeterminismContract.hashParts(SEED_STREAM_ROOT, payload)
end

return table.freeze(DeterminismContract)
