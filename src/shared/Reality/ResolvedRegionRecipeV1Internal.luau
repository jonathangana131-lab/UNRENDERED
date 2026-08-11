--!strict

local DeterminismContract = require(script.Parent.Parent.Core.DeterminismContract)
local RegionAddress = require(script.Parent.Parent.Spatial.RegionAddress)
local RealityVersions = require(script.Parent.RealityVersions)

local ResolvedRegionRecipe = {
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

export type Candidate = {
	worldSeedRef: string,
	regionAddress: RegionAddressData,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
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

export type MigrationReceipt = {
	migrationKey: string,
	regionId: string,
	sourceFingerprint: string,
	targetFingerprint: string,
	sourceVersions: GeneratorVersions,
	targetVersions: GeneratorVersions,
}

export type MigrationBuilder = (Recipe, GeneratorVersions) -> Candidate

local MAX_SAFE_INTEGER = 9007199254740991
local MAX_GENERATOR_VERSION = 2147483647
local FINGERPRINT_SEEDS = table.freeze({
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
})

local CANDIDATE_KEYS: { [string]: boolean } = table.freeze({
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
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
		assert(type(key) == "string", `{path} contains a non-string schema key`)
		assert(allowedKeys[key] == true, `{path} contains unknown schema key {key}`)
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
	assert(length <= ResolvedRegionRecipe.MAX_REFERENCE_COUNT, `{path} exceeds reference-count limit`)

	for key in pairs(source) do
		assert(
			type(key) == "number" and key == math.floor(key) and key >= 1 and key <= length,
			`{path} must be a dense 1-based array`
		)
	end

	local copy: { string } = {}
	for index = 1, length do
		copy[index] = checkedOpaqueKey(`{path}[{index}]`, source[index], ResolvedRegionRecipe.MAX_KEY_BYTES)
	end
	table.sort(copy)
	for index = 2, #copy do
		assert(copy[index] ~= copy[index - 1], `{path} must not contain duplicate key {copy[index]}`)
	end
	return table.freeze(copy)
end

local function ownCandidate(value: Candidate): Candidate
	local source = assertExactRecordShape(value, CANDIDATE_KEYS, "ResolvedRegionCandidate")
	return table.freeze({
		worldSeedRef = checkedOpaqueKey(
			"worldSeedRef",
			source.worldSeedRef,
			ResolvedRegionRecipe.MAX_WORLD_SEED_REF_BYTES
		),
		regionAddress = cloneAddress(source.regionAddress),
		generatorVersions = cloneVersions(source.generatorVersions),
		semanticIntentKey = checkedOpaqueKey(
			"semanticIntentKey",
			source.semanticIntentKey,
			ResolvedRegionRecipe.MAX_KEY_BYTES
		),
		topologyAnchors = cloneCanonicalKeySet(source.topologyAnchors, "topologyAnchors"),
		canonicalContentKeys = cloneCanonicalKeySet(source.canonicalContentKeys, "canonicalContentKeys"),
	})
end

local function ownObservationIdentity(value: unknown): (string, RegionAddressData)
	local source = assertPlainRecord(value, "ResolvedRegionCandidate")
	local worldSeedRef =
		checkedOpaqueKey("worldSeedRef", source.worldSeedRef, ResolvedRegionRecipe.MAX_WORLD_SEED_REF_BYTES)
	return worldSeedRef, cloneAddress(source.regionAddress)
end

local function addressKey(address: RegionAddressData): string
	return RegionAddress.key(address)
end

local function canonicalPayload(candidate: Candidate): string
	return DeterminismContract.encodeParts({
		"resolved-region-recipe",
		tostring(ResolvedRegionRecipe.SCHEMA_VERSION),
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

local function fingerprintFor(candidate: Candidate): string
	local payload = canonicalPayload(candidate)
	local digest: { string } = {}
	for _, seed in FINGERPRINT_SEEDS do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hash32(payload, seed)))
	end
	return string.format(
		"resolved-region:v%d:%s",
		ResolvedRegionRecipe.FINGERPRINT_VERSION,
		table.concat(digest)
	)
end

local function regionIdFor(candidate: Candidate): string
	return DeterminismContract.stableId("region", {
		candidate.worldSeedRef,
		addressKey(candidate.regionAddress),
	})
end

local function lockOwned(candidate: Candidate): Recipe
	return table.freeze({
		schemaVersion = ResolvedRegionRecipe.SCHEMA_VERSION,
		regionId = regionIdFor(candidate),
		worldSeedRef = candidate.worldSeedRef,
		regionAddress = candidate.regionAddress,
		generatorVersions = candidate.generatorVersions,
		semanticIntentKey = candidate.semanticIntentKey,
		topologyAnchors = candidate.topologyAnchors,
		canonicalContentKeys = candidate.canonicalContentKeys,
		recipeFingerprint = fingerprintFor(candidate),
	})
end

local function recipeAsCandidate(source: any): Candidate
	return ownCandidate({
		worldSeedRef = source.worldSeedRef,
		regionAddress = source.regionAddress,
		generatorVersions = source.generatorVersions,
		semanticIntentKey = source.semanticIntentKey,
		topologyAnchors = source.topologyAnchors,
		canonicalContentKeys = source.canonicalContentKeys,
	})
end

local function ownRecipe(value: Recipe): Recipe
	local source = assertExactRecordShape(value, RECIPE_KEYS, "ResolvedRegionRecipe")
	local schemaVersion = checkedSafeInteger("schemaVersion", source.schemaVersion)
	assert(
		schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION,
		`unsupported ResolvedRegionRecipe schema version {schemaVersion}`
	)
	local regionId = checkedOpaqueKey("regionId", source.regionId, ResolvedRegionRecipe.MAX_KEY_BYTES)
	assert(DeterminismContract.isStableId(regionId, "region"), "regionId must be a region StableId")
	local storedFingerprint =
		checkedOpaqueKey("recipeFingerprint", source.recipeFingerprint, ResolvedRegionRecipe.MAX_KEY_BYTES)

	local candidate = recipeAsCandidate(source)
	local expectedRegionId = regionIdFor(candidate)
	local expectedFingerprint = fingerprintFor(candidate)
	assert(regionId == expectedRegionId, "regionId does not match worldSeedRef + regionAddress identity")
	assert(
		storedFingerprint == expectedFingerprint,
		"recipeFingerprint does not match canonical resolved recipe content"
	)
	return lockOwned(candidate)
end

local function sameAddress(left: RegionAddressData, right: RegionAddressData): boolean
	return left.x == right.x and left.z == right.z and left.layer == right.layer
end

local function sameVersions(left: GeneratorVersions, right: GeneratorVersions): boolean
	return left.reality == right.reality
		and left.topology == right.topology
		and left.material == right.material
		and left.object == right.object
		and left.entity == right.entity
end

local function copyVersions(versions: GeneratorVersions): GeneratorVersions
	return table.freeze({
		reality = versions.reality,
		topology = versions.topology,
		material = versions.material,
		object = versions.object,
		entity = versions.entity,
	})
end

function ResolvedRegionRecipe.currentGeneratorVersions(): GeneratorVersions
	return cloneVersions(RealityVersions.current())
end

function ResolvedRegionRecipe.lock(candidate: Candidate): Recipe
	return lockOwned(ownCandidate(candidate))
end

function ResolvedRegionRecipe.resolveOnObservation(existing: Recipe?, candidate: Candidate): Recipe
	if existing == nil then
		return lockOwned(ownCandidate(candidate))
	end

	local locked = ownRecipe(existing)
	local incomingWorldSeedRef, incomingAddress = ownObservationIdentity(candidate)
	assert(
		locked.worldSeedRef == incomingWorldSeedRef,
		"observation candidate worldSeedRef does not match locked region"
	)
	assert(
		sameAddress(locked.regionAddress, incomingAddress),
		"observation candidate address does not match locked region"
	)
	return locked
end

function ResolvedRegionRecipe.serialize(recipe: Recipe): { [string]: any }
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

function ResolvedRegionRecipe.deserialize(data: unknown): Recipe
	assert(type(data) == "table", "serialized ResolvedRegionRecipe must be a table")
	return ownRecipe(data :: any)
end

function ResolvedRegionRecipe.equal(left: Recipe, right: Recipe): boolean
	local ownedLeft = ownRecipe(left)
	local ownedRight = ownRecipe(right)
	if ownedLeft.regionId ~= ownedRight.regionId then
		return false
	end
	return canonicalPayload(recipeAsCandidate(ownedLeft)) == canonicalPayload(recipeAsCandidate(ownedRight))
end

function ResolvedRegionRecipe.fingerprint(recipe: Recipe): string
	return ownRecipe(recipe).recipeFingerprint
end

function ResolvedRegionRecipe.reproKey(recipe: Recipe): string
	local owned = ownRecipe(recipe)
	return string.format(
		"%s|%s|reality=%d|%s",
		owned.regionId,
		addressKey(owned.regionAddress),
		owned.generatorVersions.reality,
		owned.recipeFingerprint
	)
end

function ResolvedRegionRecipe.requiresMigration(recipe: Recipe, targetVersions: GeneratorVersions?): boolean
	local owned = ownRecipe(recipe)
	local target = if targetVersions == nil
		then ResolvedRegionRecipe.currentGeneratorVersions()
		else cloneVersions(targetVersions)
	return not sameVersions(owned.generatorVersions, target)
end

function ResolvedRegionRecipe.migrate(
	recipe: Recipe,
	targetVersions: GeneratorVersions,
	migrationKey: string,
	builder: MigrationBuilder
): (Recipe, MigrationReceipt)
	local source = ownRecipe(recipe)
	local target = cloneVersions(targetVersions)
	local ownedMigrationKey =
		checkedOpaqueKey("migrationKey", migrationKey, ResolvedRegionRecipe.MAX_KEY_BYTES)
	assert(
		not sameVersions(source.generatorVersions, target),
		"migration target versions must differ from locked versions"
	)
	assert(type(builder) == "function", "migration builder must be a function")

	local migratedCandidate = ownCandidate(builder(source, target))
	assert(migratedCandidate.worldSeedRef == source.worldSeedRef, "migration must preserve worldSeedRef")
	assert(
		sameAddress(migratedCandidate.regionAddress, source.regionAddress),
		"migration must preserve regionAddress"
	)
	assert(
		sameVersions(migratedCandidate.generatorVersions, target),
		"migration candidate must use exact target generator versions"
	)

	local migrated = lockOwned(migratedCandidate)
	assert(migrated.regionId == source.regionId, "migration must preserve stable region identity")
	assert(
		migrated.recipeFingerprint ~= source.recipeFingerprint,
		"migration must change the recipe fingerprint"
	)

	local receipt: MigrationReceipt = table.freeze({
		migrationKey = ownedMigrationKey,
		regionId = source.regionId,
		sourceFingerprint = source.recipeFingerprint,
		targetFingerprint = migrated.recipeFingerprint,
		sourceVersions = copyVersions(source.generatorVersions),
		targetVersions = copyVersions(migrated.generatorVersions),
	})
	return migrated, receipt
end

local LegacyReplayCore = {
	SCHEMA_VERSION = ResolvedRegionRecipe.SCHEMA_VERSION,
	FINGERPRINT_VERSION = ResolvedRegionRecipe.FINGERPRINT_VERSION,
	deserialize = ResolvedRegionRecipe.deserialize,
	serialize = ResolvedRegionRecipe.serialize,
	equal = ResolvedRegionRecipe.equal,
	fingerprint = ResolvedRegionRecipe.fingerprint,
	reproKey = ResolvedRegionRecipe.reproKey,
}

return table.freeze(LegacyReplayCore)