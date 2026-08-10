--!strict

local DeterminismContract = require(script.Parent.Parent.Core.DeterminismContract)
local RegionAddress = require(script.Parent.Parent.Spatial.RegionAddress)

local LegacyResolvedRegionRecipeV1 = {
	SCHEMA_VERSION = 1,
	FINGERPRINT_VERSION = 1,
	MAX_REFERENCE_COUNT = 4096,
	MAX_KEY_BYTES = 256,
	MAX_WORLD_SEED_REF_BYTES = 512,
}

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type RegionAddressData = {
	x: number,
	z: number,
	layer: number,
}

export type Recipe = {
	schemaVersion: number,
	regionId: string,
	worldSeedRef: string,
	regionAddress: RegionAddressData,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
	recipeFingerprint: string,
}

type CanonicalCandidate = {
	worldSeedRef: string,
	regionAddress: RegionAddressData,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
}

local MAX_SAFE_INTEGER = 9007199254740991
local MAX_GENERATOR_VERSION = 2147483647
local FINGERPRINT_SEEDS = table.freeze({
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
})

local RECIPE_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	regionId = true,
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
	recipeFingerprint = true,
})

local ADDRESS_KEYS: { [string]: boolean } = table.freeze({
	x = true,
	z = true,
	layer = true,
})

local VERSION_KEYS: { [string]: boolean } = table.freeze({
	reality = true,
	topology = true,
	material = true,
	object = true,
	entity = true,
})

local function assertPlainRecord(value: unknown, path: string): any
	assert(type(value) == "table", `{path} must be a table`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	return source
end

local function assertExactRecordShape(value: unknown, allowedKeys: { [string]: boolean }, path: string): any
	local source = assertPlainRecord(value, path)
	for key in pairs(source) do
		assert(
			type(key) == "string" and allowedKeys[key] == true,
			`{path} contains unknown schema key {tostring(key)}`
		)
	end
	return source
end

local function checkedOpaqueKey(path: string, value: unknown, maximumBytes: number): string
	assert(type(value) == "string", `{path} must be a string`)
	local text = value :: string
	assert(text ~= "", `{path} must not be empty`)
	assert(#text <= maximumBytes, `{path} must be <= {maximumBytes} bytes`)
	assert(string.find(text, "%c") == nil, `{path} must not contain control characters`)
	return text
end

local function checkedSafeInteger(path: string, value: unknown): number
	assert(type(value) == "number", `{path} must be a number`)
	local numberValue = value :: number
	assert(
		numberValue == numberValue and numberValue > -math.huge and numberValue < math.huge,
		`{path} must be finite`
	)
	assert(numberValue == math.floor(numberValue), `{path} must be an integer`)
	assert(math.abs(numberValue) <= MAX_SAFE_INTEGER, `{path} must be a safe integer`)
	return numberValue
end

local function checkedGeneratorVersion(path: string, value: unknown): number
	local version = checkedSafeInteger(path, value)
	assert(
		version >= 1 and version <= MAX_GENERATOR_VERSION,
		`{path} must be in [1, {MAX_GENERATOR_VERSION}]`
	)
	return version
end

local function cloneAddress(value: unknown): RegionAddressData
	local source = assertExactRecordShape(value, ADDRESS_KEYS, "regionAddress")
	return table.freeze({
		x = checkedSafeInteger("regionAddress.x", source.x),
		z = checkedSafeInteger("regionAddress.z", source.z),
		layer = checkedSafeInteger("regionAddress.layer", source.layer),
	})
end

local function cloneVersions(value: unknown): GeneratorVersions
	local source = assertExactRecordShape(value, VERSION_KEYS, "generatorVersions")
	return table.freeze({
		reality = checkedGeneratorVersion("generatorVersions.reality", source.reality),
		topology = checkedGeneratorVersion("generatorVersions.topology", source.topology),
		material = checkedGeneratorVersion("generatorVersions.material", source.material),
		object = checkedGeneratorVersion("generatorVersions.object", source.object),
		entity = checkedGeneratorVersion("generatorVersions.entity", source.entity),
	})
end

local function cloneCanonicalKeySet(value: unknown, path: string): { string }
	assert(type(value) == "table", `{path} must be an array`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	local length = #source
	assert(length <= LegacyResolvedRegionRecipeV1.MAX_REFERENCE_COUNT, `{path} exceeds reference-count limit`)

	for key in pairs(source) do
		assert(
			type(key) == "number" and key == math.floor(key) and key >= 1 and key <= length,
			`{path} must be a dense 1-based array`
		)
	end

	local copy: { string } = {}
	for index = 1, length do
		copy[index] = checkedOpaqueKey(`{path}[{index}]`, source[index], LegacyResolvedRegionRecipeV1.MAX_KEY_BYTES)
	end
	table.sort(copy)
	for index = 2, #copy do
		assert(copy[index] ~= copy[index - 1], `{path} must not contain duplicate key {copy[index]}`)
	end
	return table.freeze(copy)
end

local function addressKey(address: RegionAddressData): string
	return RegionAddress.key(address)
end

local function recipeAsCandidate(source: any): CanonicalCandidate
	return table.freeze({
		worldSeedRef = checkedOpaqueKey(
			"worldSeedRef",
			source.worldSeedRef,
			LegacyResolvedRegionRecipeV1.MAX_WORLD_SEED_REF_BYTES
		),
		regionAddress = cloneAddress(source.regionAddress),
		generatorVersions = cloneVersions(source.generatorVersions),
		semanticIntentKey = checkedOpaqueKey(
			"semanticIntentKey",
			source.semanticIntentKey,
			LegacyResolvedRegionRecipeV1.MAX_KEY_BYTES
		),
		topologyAnchors = cloneCanonicalKeySet(source.topologyAnchors, "topologyAnchors"),
		canonicalContentKeys = cloneCanonicalKeySet(source.canonicalContentKeys, "canonicalContentKeys"),
	})
end

local function canonicalPayload(candidate: CanonicalCandidate): string
	return DeterminismContract.encodeParts({
		"resolved-region-recipe",
		tostring(LegacyResolvedRegionRecipeV1.SCHEMA_VERSION),
		candidate.worldSeedRef,
		addressKey(candidate.regionAddress),
		tostring(candidate.generatorVersions.reality),
		tostring(candidate.generatorVersions.topology),
		tostring(candidate.generatorVersions.material),
		tostring(candidate.generatorVersions.object),
		tostring(candidate.generatorVersions.entity),
		candidate.semanticIntentKey,
		DeterminismContract.encodeParts(candidate.topologyAnchors),
		DeterminismContract.encodeParts(candidate.canonicalContentKeys),
	})
end

local function fingerprintFor(candidate: CanonicalCandidate): string
	local payload = canonicalPayload(candidate)
	local digest: { string } = {}
	for _, seed in FINGERPRINT_SEEDS do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hash32(payload, seed)))
	end
	return string.format(
		"resolved-region:v%d:%s",
		LegacyResolvedRegionRecipeV1.FINGERPRINT_VERSION,
		table.concat(digest)
	)
end

local function regionIdFor(candidate: CanonicalCandidate): string
	return DeterminismContract.stableId("region", {
		candidate.worldSeedRef,
		addressKey(candidate.regionAddress),
	})
end

local function ownRecipe(value: unknown): Recipe
	local source = assertExactRecordShape(value, RECIPE_KEYS, "LegacyResolvedRegionRecipeV1")
	local schemaVersion = checkedSafeInteger("schemaVersion", source.schemaVersion)
	assert(
		schemaVersion == LegacyResolvedRegionRecipeV1.SCHEMA_VERSION,
		`unsupported legacy ResolvedRegionRecipe schema version {schemaVersion}`
	)
	local regionId = checkedOpaqueKey("regionId", source.regionId, LegacyResolvedRegionRecipeV1.MAX_KEY_BYTES)
	assert(DeterminismContract.isStableId(regionId, "region"), "regionId must be a region StableId")
	local storedFingerprint = checkedOpaqueKey(
		"recipeFingerprint",
		source.recipeFingerprint,
		LegacyResolvedRegionRecipeV1.MAX_KEY_BYTES
	)
	local candidate = recipeAsCandidate(source)
	local expectedRegionId = regionIdFor(candidate)
	local expectedFingerprint = fingerprintFor(candidate)
	assert(regionId == expectedRegionId, "legacy v1 regionId does not match worldSeedRef + regionAddress identity")
	assert(
		storedFingerprint == expectedFingerprint,
		"legacy v1 recipeFingerprint does not match canonical resolved recipe content"
	)
	return table.freeze({
		schemaVersion = schemaVersion,
		regionId = regionId,
		worldSeedRef = candidate.worldSeedRef,
		regionAddress = candidate.regionAddress,
		generatorVersions = candidate.generatorVersions,
		semanticIntentKey = candidate.semanticIntentKey,
		topologyAnchors = candidate.topologyAnchors,
		canonicalContentKeys = candidate.canonicalContentKeys,
		recipeFingerprint = storedFingerprint,
	})
end

function LegacyResolvedRegionRecipeV1.deserialize(data: unknown): Recipe
	return ownRecipe(data)
end

function LegacyResolvedRegionRecipeV1.serialize(recipe: Recipe): { [string]: any }
	local owned = ownRecipe(recipe)
	return {
		schemaVersion = owned.schemaVersion,
		regionId = owned.regionId,
		worldSeedRef = owned.worldSeedRef,
		regionAddress = {
			x = owned.regionAddress.x,
			z = owned.regionAddress.z,
			layer = owned.regionAddress.layer,
		},
		generatorVersions = {
			reality = owned.generatorVersions.reality,
			topology = owned.generatorVersions.topology,
			material = owned.generatorVersions.material,
			object = owned.generatorVersions.object,
			entity = owned.generatorVersions.entity,
		},
		semanticIntentKey = owned.semanticIntentKey,
		topologyAnchors = table.clone(owned.topologyAnchors),
		canonicalContentKeys = table.clone(owned.canonicalContentKeys),
		recipeFingerprint = owned.recipeFingerprint,
	}
end

function LegacyResolvedRegionRecipeV1.equal(left: Recipe, right: Recipe): boolean
	local ownedLeft = ownRecipe(left)
	local ownedRight = ownRecipe(right)
	return ownedLeft.regionId == ownedRight.regionId
		and canonicalPayload(recipeAsCandidate(ownedLeft)) == canonicalPayload(recipeAsCandidate(ownedRight))
end

function LegacyResolvedRegionRecipeV1.fingerprint(recipe: Recipe): string
	return ownRecipe(recipe).recipeFingerprint
end

return table.freeze(LegacyResolvedRegionRecipeV1)
