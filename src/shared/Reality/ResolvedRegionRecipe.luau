--!strict

local requireAny = require :: any
local scriptValue = script :: any
local StableId = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.StableId)
	else requireAny("../Core/StableId")
local DeterminismContract = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.DeterminismContract)
	else requireAny("../Core/DeterminismContract")

local SCHEMA_VERSION = 1
local MAX_VERSION = 2147483647
local MAX_WORLD_SEED_BYTES = 512
local MAX_ADDRESS_BYTES = 512
local MAX_KEY_BYTES = 160
local MAX_ANCHORS = 256
local MAX_CONTENT_KEYS = 4096
local FINGERPRINT_SEED = 0x6a09e667

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type PotentialRegionRecipe = {
	worldId: string,
	worldSeed: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionRecipe = {
	schemaVersion: number,
	id: string,
	worldId: string,
	worldSeed: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

local ResolvedRegionRecipe = {
	SchemaVersion = SCHEMA_VERSION,
	FingerprintVersion = 1,
}

local TOP_LEVEL_KEYS = {
	schemaVersion = true,
	id = true,
	worldId = true,
	worldSeed = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
}

local VERSION_KEYS = {
	reality = true,
	topology = true,
	material = true,
	object = true,
	entity = true,
}

local function isIntegerInRange(value: any, minimum: number, maximum: number): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
		and value >= minimum
		and value <= maximum
end

local function assertPlainTable(value: any, label: string)
	assert(type(value) == "table", `{label} must be a table`)
	assert(getmetatable(value) == nil, `{label} must not have a metatable`)
end

local function assertExactKeys(value: any, expected: { [string]: boolean }, label: string)
	assertPlainTable(value, label)
	for key in pairs(value) do
		assert(
			type(key) == "string" and expected[key] == true,
			`{label} contains unsupported key {tostring(key)}`
		)
	end
	for key in pairs(expected) do
		assert(value[key] ~= nil, `{label}.{key} is required`)
	end
end

local function assertBoundedText(value: any, label: string, maximumBytes: number)
	assert(type(value) == "string" and #value > 0, `{label} must be a non-empty string`)
	assert(#value <= maximumBytes, `{label} exceeds {maximumBytes} bytes`)
	assert(string.find(value, "[%z\1-\31\127]") == nil, `{label} must not contain control bytes`)
end

local function assertSemanticKey(value: any, label: string)
	assertBoundedText(value, label, MAX_KEY_BYTES)
	assert(
		string.match(value, "^[A-Za-z0-9][A-Za-z0-9._/-]*$") ~= nil,
		`{label} contains unsupported characters`
	)
	assert(string.sub(value, -1) ~= "/", `{label} must not end with /`)
	assert(string.find(value, "//", 1, true) == nil, `{label} must not contain //`)
end

local function normalizeVersions(value: any): GeneratorVersions
	assertExactKeys(value, VERSION_KEYS, "generatorVersions")
	for key in pairs(VERSION_KEYS) do
		assert(
			isIntegerInRange(value[key], 1, MAX_VERSION),
			`generatorVersions.{key} must be an integer in 1..{MAX_VERSION}`
		)
	end
	return table.freeze({
		reality = value.reality,
		topology = value.topology,
		material = value.material,
		object = value.object,
		entity = value.entity,
	})
end

local function normalizeKeyArray(value: any, label: string, maximumCount: number): { string }
	assertPlainTable(value, label)
	local count = #value
	assert(count <= maximumCount, `{label} exceeds {maximumCount} entries`)
	local seen: { [string]: boolean } = {}
	local normalized = table.create(count)

	for key in pairs(value) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
			`{label} must be a dense 1-based array`
		)
	end
	for index = 1, count do
		local item = value[index]
		assertSemanticKey(item, `{label}[{index}]`)
		assert(not seen[item], `{label} contains duplicate key {item}`)
		seen[item] = true
		table.insert(normalized, item)
	end

	table.sort(normalized)
	return table.freeze(normalized)
end

local function derivedRegionId(worldId: string, regionAddress: string): string
	return StableId.fromParts("region", { worldId, regionAddress })
end

local function freezeRecipe(input: PotentialRegionRecipe): ResolvedRegionRecipe
	assert(StableId.is(input.worldId, "world"), "worldId must be a StableId in the world namespace")
	assertBoundedText(input.worldSeed, "worldSeed", MAX_WORLD_SEED_BYTES)
	assertBoundedText(input.regionAddress, "regionAddress", MAX_ADDRESS_BYTES)
	assertSemanticKey(input.semanticIntentKey, "semanticIntentKey")

	local versions = normalizeVersions(input.generatorVersions)
	local anchors = normalizeKeyArray(input.topologyAnchorKeys, "topologyAnchorKeys", MAX_ANCHORS)
	local content = normalizeKeyArray(input.canonicalContentKeys, "canonicalContentKeys", MAX_CONTENT_KEYS)
	local id = derivedRegionId(input.worldId, input.regionAddress)

	return table.freeze({
		schemaVersion = SCHEMA_VERSION,
		id = id,
		worldId = input.worldId,
		worldSeed = input.worldSeed,
		regionAddress = input.regionAddress,
		generatorVersions = versions,
		semanticIntentKey = input.semanticIntentKey,
		topologyAnchorKeys = anchors,
		canonicalContentKeys = content,
	})
end

local function canonicalParts(recipe: ResolvedRegionRecipe): { string }
	local parts = {
		"resolved-region-recipe",
		tostring(SCHEMA_VERSION),
		recipe.id,
		recipe.worldId,
		recipe.worldSeed,
		recipe.regionAddress,
		tostring(recipe.generatorVersions.reality),
		tostring(recipe.generatorVersions.topology),
		tostring(recipe.generatorVersions.material),
		tostring(recipe.generatorVersions.object),
		tostring(recipe.generatorVersions.entity),
		recipe.semanticIntentKey,
		"topology-anchors",
		tostring(#recipe.topologyAnchorKeys),
	}
	for _, key in ipairs(recipe.topologyAnchorKeys) do
		table.insert(parts, key)
	end
	table.insert(parts, "canonical-content")
	table.insert(parts, tostring(#recipe.canonicalContentKeys))
	for _, key in ipairs(recipe.canonicalContentKeys) do
		table.insert(parts, key)
	end
	return parts
end

function ResolvedRegionRecipe.regionId(worldId: string, regionAddress: string): string
	assert(StableId.is(worldId, "world"), "worldId must be a StableId in the world namespace")
	assertBoundedText(regionAddress, "regionAddress", MAX_ADDRESS_BYTES)
	return derivedRegionId(worldId, regionAddress)
end

function ResolvedRegionRecipe.new(input: PotentialRegionRecipe): ResolvedRegionRecipe
	assert(type(input) == "table", "input must be a table")
	return freezeRecipe(input)
end

function ResolvedRegionRecipe.fromPlainData(value: any): ResolvedRegionRecipe
	assertExactKeys(value, TOP_LEVEL_KEYS, "resolvedRegionRecipe")
	assert(
		value.schemaVersion == SCHEMA_VERSION,
		`resolvedRegionRecipe.schemaVersion must be {SCHEMA_VERSION}`
	)
	assert(
		StableId.is(value.worldId, "world"),
		"resolvedRegionRecipe.worldId must be a StableId in the world namespace"
	)
	assertBoundedText(value.worldSeed, "resolvedRegionRecipe.worldSeed", MAX_WORLD_SEED_BYTES)
	assertBoundedText(value.regionAddress, "resolvedRegionRecipe.regionAddress", MAX_ADDRESS_BYTES)
	assertSemanticKey(value.semanticIntentKey, "resolvedRegionRecipe.semanticIntentKey")
	assert(type(value.id) == "string", "resolvedRegionRecipe.id must be a string")

	local recipe = freezeRecipe({
		worldId = value.worldId,
		worldSeed = value.worldSeed,
		regionAddress = value.regionAddress,
		generatorVersions = value.generatorVersions,
		semanticIntentKey = value.semanticIntentKey,
		topologyAnchorKeys = value.topologyAnchorKeys,
		canonicalContentKeys = value.canonicalContentKeys,
	})
	assert(value.id == recipe.id, "resolvedRegionRecipe.id does not match worldId + regionAddress")
	return recipe
end

function ResolvedRegionRecipe.toPlainData(recipe: ResolvedRegionRecipe): any
	local canonical = ResolvedRegionRecipe.fromPlainData(recipe)
	return {
		schemaVersion = canonical.schemaVersion,
		id = canonical.id,
		worldId = canonical.worldId,
		worldSeed = canonical.worldSeed,
		regionAddress = canonical.regionAddress,
		generatorVersions = {
			reality = canonical.generatorVersions.reality,
			topology = canonical.generatorVersions.topology,
			material = canonical.generatorVersions.material,
			object = canonical.generatorVersions.object,
			entity = canonical.generatorVersions.entity,
		},
		semanticIntentKey = canonical.semanticIntentKey,
		topologyAnchorKeys = table.clone(canonical.topologyAnchorKeys),
		canonicalContentKeys = table.clone(canonical.canonicalContentKeys),
	}
end

function ResolvedRegionRecipe.canonicalEncoding(recipe: ResolvedRegionRecipe): string
	local canonical = ResolvedRegionRecipe.fromPlainData(recipe)
	return DeterminismContract.encodeParts(canonicalParts(canonical))
end

function ResolvedRegionRecipe.fingerprint(recipe: ResolvedRegionRecipe): string
	local encoding = ResolvedRegionRecipe.canonicalEncoding(recipe)
	return `rr1:{DeterminismContract.hex32(DeterminismContract.hash32(encoding, FINGERPRINT_SEED))}`
end

function ResolvedRegionRecipe.equivalent(left: ResolvedRegionRecipe, right: ResolvedRegionRecipe): boolean
	return ResolvedRegionRecipe.canonicalEncoding(left) == ResolvedRegionRecipe.canonicalEncoding(right)
end

function ResolvedRegionRecipe.lock(
	existing: ResolvedRegionRecipe?,
	candidate: PotentialRegionRecipe
): (ResolvedRegionRecipe, boolean)
	if existing ~= nil then
		local locked = ResolvedRegionRecipe.fromPlainData(existing)
		return locked, false
	end
	return ResolvedRegionRecipe.new(candidate), true
end

function ResolvedRegionRecipe.needsMigration(
	recipe: ResolvedRegionRecipe,
	targetVersions: GeneratorVersions
): boolean
	local canonical = ResolvedRegionRecipe.fromPlainData(recipe)
	local target = normalizeVersions(targetVersions)
	return canonical.generatorVersions.reality ~= target.reality
		or canonical.generatorVersions.topology ~= target.topology
		or canonical.generatorVersions.material ~= target.material
		or canonical.generatorVersions.object ~= target.object
		or canonical.generatorVersions.entity ~= target.entity
end

return table.freeze(ResolvedRegionRecipe)
