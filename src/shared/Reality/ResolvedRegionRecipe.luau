--!strict

local DeterminismContract = require(script.Parent.Parent.Core.DeterminismContract)
local RegionAddress = require(script.Parent.Parent.Spatial.RegionAddress)
local RealityVersions = require(script.Parent.RealityVersions)

local ResolvedRegionRecipe = {
	SCHEMA_VERSION = 2,
	FINGERPRINT_VERSION = 2,
	LEGACY_SCHEMA_VERSION = 1,
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
	worldId: string,
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
	worldId: string?,
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
	worldId: string,
	regionId: string,
	sourceFingerprint: string,
	targetFingerprint: string,
	sourceVersions: GeneratorVersions,
	targetVersions: GeneratorVersions,
}

export type LegacyUpgradeReceipt = {
	migrationKey: string,
	worldId: string,
	sourceRegionId: string,
	targetRegionId: string,
	sourceFingerprint: string,
	targetFingerprint: string,
	sourceSchemaVersion: number,
	targetSchemaVersion: number,
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
	worldId = true,
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
})

local RECIPE_V1_KEYS: { [string]: boolean } = table.freeze({
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

local RECIPE_V2_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	regionId = true,
	worldId = true,
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
	local sourceValue = value :: any
	assert(getmetatable(sourceValue) == nil, `{path} must not have a metatable`)
	return sourceValue
end

local function assertExactRecordShape(value: unknown, allowedKeys: { [string]: boolean }, path: string): any
	local sourceValue = assertPlainRecord(value, path)
	for key in pairs(sourceValue) do
		assert(
			type(key) == "string" and allowedKeys[key] == true,
			`{path} contains unknown schema key {tostring(key)}`
		)
	end
	return sourceValue
end

local function checkedOpaqueKey(path: string, value: unknown, maximumBytes: number): string
	assert(type(value) == "string", `{path} must be a string`)
	local text = value :: string
	assert(text ~= "", `{path} must not be empty`)
	assert(#text <= maximumBytes, `{path} must be <= {maximumBytes} bytes`)
	assert(string.find(text, "%c") == nil, `{path} must not contain control characters`)
	return text
end

local function checkedWorldId(value: unknown): string
	local worldId = checkedOpaqueKey("worldId", value, ResolvedRegionRecipe.MAX_KEY_BYTES)
	assert(DeterminismContract.isStableId(worldId, "world"), "worldId must be a world StableId")
	return worldId
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
	local sourceValue = assertExactRecordShape(value, ADDRESS_KEYS, "regionAddress")
	return table.freeze({
		x = checkedSafeInteger("regionAddress.x", sourceValue.x),
		z = checkedSafeInteger("regionAddress.z", sourceValue.z),
		layer = checkedSafeInteger("regionAddress.layer", sourceValue.layer),
	})
end

local function cloneVersions(value: unknown): GeneratorVersions
	local sourceValue = assertExactRecordShape(value, VERSION_KEYS, "generatorVersions")
	return table.freeze({
		reality = checkedGeneratorVersion("generatorVersions.reality", sourceValue.reality),
		topology = checkedGeneratorVersion("generatorVersions.topology", sourceValue.topology),
		material = checkedGeneratorVersion("generatorVersions.material", sourceValue.material),
		object = checkedGeneratorVersion("generatorVersions.object", sourceValue.object),
		entity = checkedGeneratorVersion("generatorVersions.entity", sourceValue.entity),
	})
end

local function cloneCanonicalKeySet(value: unknown, path: string): { string }
	assert(type(value) == "table", `{path} must be an array`)
	local sourceValue = value :: any
	assert(getmetatable(sourceValue) == nil, `{path} must not have a metatable`)
	local length = #sourceValue
	assert(length <= ResolvedRegionRecipe.MAX_REFERENCE_COUNT, `{path} exceeds reference-count limit`)

	for key in pairs(sourceValue) do
		assert(
			type(key) == "number" and key == math.floor(key) and key >= 1 and key <= length,
			`{path} must be a dense 1-based array`
		)
	end

	local copy: { string } = {}
	for index = 1, length do
		copy[index] = checkedOpaqueKey(`{path}[{index}]`, sourceValue[index], ResolvedRegionRecipe.MAX_KEY_BYTES)
	end
	table.sort(copy)
	for index = 2, #copy do
		assert(copy[index] ~= copy[index - 1], `{path} must not contain duplicate key {copy[index]}`)
	end
	return table.freeze(copy)
end

local function ownCandidate(value: Candidate): Candidate
	local sourceValue = assertExactRecordShape(value, CANDIDATE_KEYS, "ResolvedRegionCandidate")
	return table.freeze({
		worldId = checkedWorldId(sourceValue.worldId),
		worldSeedRef = checkedOpaqueKey(
			"worldSeedRef",
			sourceValue.worldSeedRef,
			ResolvedRegionRecipe.MAX_WORLD_SEED_REF_BYTES
		),
		regionAddress = cloneAddress(sourceValue.regionAddress),
		generatorVersions = cloneVersions(sourceValue.generatorVersions),
		semanticIntentKey = checkedOpaqueKey(
			"semanticIntentKey",
			sourceValue.semanticIntentKey,
			ResolvedRegionRecipe.MAX_KEY_BYTES
		),
		topologyAnchors = cloneCanonicalKeySet(sourceValue.topologyAnchors, "topologyAnchors"),
		canonicalContentKeys = cloneCanonicalKeySet(sourceValue.canonicalContentKeys, "canonicalContentKeys"),
	})
end

local function ownObservationIdentity(value: unknown): (string, string, RegionAddressData)
	local sourceValue = assertPlainRecord(value, "ResolvedRegionCandidate")
	local worldId = checkedWorldId(sourceValue.worldId)
	local worldSeedRef = checkedOpaqueKey(
		"worldSeedRef",
		sourceValue.worldSeedRef,
		ResolvedRegionRecipe.MAX_WORLD_SEED_REF_BYTES
	)
	return worldId, worldSeedRef, cloneAddress(sourceValue.regionAddress)
end

local function addressKey(address: RegionAddressData): string
	return RegionAddress.key(address)
end

local function canonicalPayloadV2(candidate: Candidate): string
	return DeterminismContract.encodeParts({
		"resolved-region-recipe",
		tostring(ResolvedRegionRecipe.SCHEMA_VERSION),
		candidate.worldId,
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

local function canonicalPayloadV1(sourceValue: any): string
	return DeterminismContract.encodeParts({
		"resolved-region-recipe",
		tostring(ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION),
		sourceValue.worldSeedRef,
		addressKey(sourceValue.regionAddress),
		tostring(sourceValue.generatorVersions.reality),
		tostring(sourceValue.generatorVersions.topology),
		tostring(sourceValue.generatorVersions.material),
		tostring(sourceValue.generatorVersions.object),
		tostring(sourceValue.generatorVersions.entity),
		sourceValue.semanticIntentKey,
		DeterminismContract.encodeParts(sourceValue.topologyAnchors),
		DeterminismContract.encodeParts(sourceValue.canonicalContentKeys),
	})
end

local function hashPayload(prefixVersion: number, payload: string): string
	local digest: { string } = {}
	for _, seed in FINGERPRINT_SEEDS do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hash32(payload, seed)))
	end
	return string.format("resolved-region:v%d:%s", prefixVersion, table.concat(digest))
end

local function fingerprintForV2(candidate: Candidate): string
	return hashPayload(ResolvedRegionRecipe.FINGERPRINT_VERSION, canonicalPayloadV2(candidate))
end

local function fingerprintForV1(sourceValue: any): string
	return hashPayload(ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION, canonicalPayloadV1(sourceValue))
end

local function regionIdForV2(candidate: Candidate): string
	return DeterminismContract.stableId("region", {
		candidate.worldId,
		addressKey(candidate.regionAddress),
	})
end

local function regionIdForV1(sourceValue: any): string
	return DeterminismContract.stableId("region", {
		sourceValue.worldSeedRef,
		addressKey(sourceValue.regionAddress),
	})
end

local function lockOwnedV2(candidate: Candidate): Recipe
	return table.freeze({
		schemaVersion = ResolvedRegionRecipe.SCHEMA_VERSION,
		regionId = regionIdForV2(candidate),
		worldId = candidate.worldId,
		worldSeedRef = candidate.worldSeedRef,
		regionAddress = candidate.regionAddress,
		generatorVersions = candidate.generatorVersions,
		semanticIntentKey = candidate.semanticIntentKey,
		topologyAnchors = candidate.topologyAnchors,
		canonicalContentKeys = candidate.canonicalContentKeys,
		recipeFingerprint = fingerprintForV2(candidate),
	})
end

local function recipeAsV2Candidate(sourceValue: any): Candidate
	return ownCandidate({
		worldId = sourceValue.worldId,
		worldSeedRef = sourceValue.worldSeedRef,
		regionAddress = sourceValue.regionAddress,
		generatorVersions = sourceValue.generatorVersions,
		semanticIntentKey = sourceValue.semanticIntentKey,
		topologyAnchors = sourceValue.topologyAnchors,
		canonicalContentKeys = sourceValue.canonicalContentKeys,
	})
end

local function ownRecipeV1(value: unknown): Recipe
	local sourceValue = assertExactRecordShape(value, RECIPE_V1_KEYS, "ResolvedRegionRecipeV1")
	local schemaVersion = checkedSafeInteger("schemaVersion", sourceValue.schemaVersion)
	assert(
		schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION,
		`unsupported legacy ResolvedRegionRecipe schema version {schemaVersion}`
	)

	local regionId = checkedOpaqueKey("regionId", sourceValue.regionId, ResolvedRegionRecipe.MAX_KEY_BYTES)
	assert(DeterminismContract.isStableId(regionId, "region"), "regionId must be a region StableId")
	local storedFingerprint = checkedOpaqueKey(
		"recipeFingerprint",
		sourceValue.recipeFingerprint,
		ResolvedRegionRecipe.MAX_KEY_BYTES
	)

	local owned = {
		schemaVersion = ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION,
		regionId = regionId,
		worldSeedRef = checkedOpaqueKey(
			"worldSeedRef",
			sourceValue.worldSeedRef,
			ResolvedRegionRecipe.MAX_WORLD_SEED_REF_BYTES
		),
		regionAddress = cloneAddress(sourceValue.regionAddress),
		generatorVersions = cloneVersions(sourceValue.generatorVersions),
		semanticIntentKey = checkedOpaqueKey(
			"semanticIntentKey",
			sourceValue.semanticIntentKey,
			ResolvedRegionRecipe.MAX_KEY_BYTES
		),
		topologyAnchors = cloneCanonicalKeySet(sourceValue.topologyAnchors, "topologyAnchors"),
		canonicalContentKeys = cloneCanonicalKeySet(sourceValue.canonicalContentKeys, "canonicalContentKeys"),
		recipeFingerprint = storedFingerprint,
	}

	assert(
		owned.regionId == regionIdForV1(owned),
		"legacy regionId does not match worldSeedRef + regionAddress identity"
	)
	assert(
		owned.recipeFingerprint == fingerprintForV1(owned),
		"legacy recipeFingerprint does not match canonical v1 content"
	)
	return table.freeze(owned) :: any
end

local function ownRecipeV2(value: unknown): Recipe
	local sourceValue = assertExactRecordShape(value, RECIPE_V2_KEYS, "ResolvedRegionRecipeV2")
	local schemaVersion = checkedSafeInteger("schemaVersion", sourceValue.schemaVersion)
	assert(
		schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION,
		`unsupported ResolvedRegionRecipe schema version {schemaVersion}`
	)

	local regionId = checkedOpaqueKey("regionId", sourceValue.regionId, ResolvedRegionRecipe.MAX_KEY_BYTES)
	assert(DeterminismContract.isStableId(regionId, "region"), "regionId must be a region StableId")
	local storedFingerprint = checkedOpaqueKey(
		"recipeFingerprint",
		sourceValue.recipeFingerprint,
		ResolvedRegionRecipe.MAX_KEY_BYTES
	)

	local candidate = recipeAsV2Candidate(sourceValue)
	local expectedRegionId = regionIdForV2(candidate)
	local expectedFingerprint = fingerprintForV2(candidate)
	assert(regionId == expectedRegionId, "regionId does not match worldId + regionAddress identity")
	assert(
		storedFingerprint == expectedFingerprint,
		"recipeFingerprint does not match canonical resolved recipe content"
	)
	return lockOwnedV2(candidate)
end

local function ownRecipe(value: unknown): Recipe
	local sourceValue = assertPlainRecord(value, "ResolvedRegionRecipe")
	local schemaVersion = checkedSafeInteger("schemaVersion", sourceValue.schemaVersion)
	if schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION then
		return ownRecipeV1(sourceValue)
	end
	if schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION then
		return ownRecipeV2(sourceValue)
	end
	error(`unsupported ResolvedRegionRecipe schema version {schemaVersion}`)
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
	return lockOwnedV2(ownCandidate(candidate))
end

function ResolvedRegionRecipe.resolveOnObservation(existing: Recipe?, candidate: Candidate): Recipe
	if existing == nil then
		return lockOwnedV2(ownCandidate(candidate))
	end

	local locked = ownRecipe(existing)
	local incomingWorldId, incomingWorldSeedRef, incomingAddress = ownObservationIdentity(candidate)
	if locked.schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION then
		assert(
			locked.worldSeedRef == incomingWorldSeedRef,
			"observation candidate worldSeedRef does not match locked legacy region"
		)
		assert(
			sameAddress(locked.regionAddress, incomingAddress),
			"observation candidate address does not match locked legacy region"
		)
		return locked
	end

	assert(locked.worldId == incomingWorldId, "observation candidate worldId does not match locked region")
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
	local serialized: { [string]: any } = {
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
	if owned.schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION then
		serialized.worldId = owned.worldId
	end
	return serialized
end

function ResolvedRegionRecipe.deserialize(data: unknown): Recipe
	local sourceValue = assertPlainRecord(data, "serialized ResolvedRegionRecipe")
	local schemaVersion = checkedSafeInteger("schemaVersion", sourceValue.schemaVersion)
	assert(
		schemaVersion ~= ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION,
		"schema-v1 recipes require explicit deserializeLegacyV1 compatibility loading"
	)
	return ownRecipeV2(sourceValue)
end

function ResolvedRegionRecipe.deserializeLegacyV1(data: unknown): Recipe
	return ownRecipeV1(data)
end

function ResolvedRegionRecipe.isLegacyV1(recipe: Recipe): boolean
	return ownRecipe(recipe).schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION
end

function ResolvedRegionRecipe.equal(left: Recipe, right: Recipe): boolean
	local ownedLeft = ownRecipe(left)
	local ownedRight = ownRecipe(right)
	if ownedLeft.schemaVersion ~= ownedRight.schemaVersion or ownedLeft.regionId ~= ownedRight.regionId then
		return false
	end
	if ownedLeft.schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION then
		return canonicalPayloadV1(ownedLeft) == canonicalPayloadV1(ownedRight)
	end
	local leftPayload = canonicalPayloadV2(recipeAsV2Candidate(ownedLeft))
	local rightPayload = canonicalPayloadV2(recipeAsV2Candidate(ownedRight))
	return leftPayload == rightPayload
end

function ResolvedRegionRecipe.fingerprint(recipe: Recipe): string
	return ownRecipe(recipe).recipeFingerprint
end

function ResolvedRegionRecipe.reproKey(recipe: Recipe): string
	local owned = ownRecipe(recipe)
	if owned.schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION then
		return string.format(
			"legacy-v1|%s|seed=%s|%s|reality=%d|%s",
			owned.regionId,
			owned.worldSeedRef,
			addressKey(owned.regionAddress),
			owned.generatorVersions.reality,
			owned.recipeFingerprint
		)
	end

	local ownedWorldId = owned.worldId
	assert(ownedWorldId ~= nil, "schema-v2 recipe must own worldId")
	return string.format(
		"%s|%s|seed=%s|%s|reality=%d|%s",
		ownedWorldId,
		owned.regionId,
		owned.worldSeedRef,
		addressKey(owned.regionAddress),
		owned.generatorVersions.reality,
		owned.recipeFingerprint
	)
end

function ResolvedRegionRecipe.requiresMigration(recipe: Recipe, targetVersions: GeneratorVersions?): boolean
	local owned = ownRecipe(recipe)
	if owned.schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION then
		return true
	end
	local target = if targetVersions == nil
		then ResolvedRegionRecipe.currentGeneratorVersions()
		else cloneVersions(targetVersions)
	return not sameVersions(owned.generatorVersions, target)
end

function ResolvedRegionRecipe.upgradeLegacyV1(
	recipe: Recipe,
	worldId: string
): (Recipe, LegacyUpgradeReceipt)
	local sourceRecipe = ownRecipe(recipe)
	assert(
		sourceRecipe.schemaVersion == ResolvedRegionRecipe.LEGACY_SCHEMA_VERSION,
		"upgradeLegacyV1 requires a schema-v1 recipe"
	)
	local targetWorldId = checkedWorldId(worldId)
	local upgraded = lockOwnedV2(ownCandidate({
		worldId = targetWorldId,
		worldSeedRef = sourceRecipe.worldSeedRef,
		regionAddress = sourceRecipe.regionAddress,
		generatorVersions = sourceRecipe.generatorVersions,
		semanticIntentKey = sourceRecipe.semanticIntentKey,
		topologyAnchors = sourceRecipe.topologyAnchors,
		canonicalContentKeys = sourceRecipe.canonicalContentKeys,
	}))

	local receipt: LegacyUpgradeReceipt = table.freeze({
		migrationKey = "resolved-region:v1-to-v2:explicit-world-id",
		worldId = targetWorldId,
		sourceRegionId = sourceRecipe.regionId,
		targetRegionId = upgraded.regionId,
		sourceFingerprint = sourceRecipe.recipeFingerprint,
		targetFingerprint = upgraded.recipeFingerprint,
		sourceSchemaVersion = sourceRecipe.schemaVersion,
		targetSchemaVersion = upgraded.schemaVersion,
	})
	return upgraded, receipt
end

function ResolvedRegionRecipe.migrate(
	recipe: Recipe,
	targetVersions: GeneratorVersions,
	migrationKey: string,
	builder: MigrationBuilder
): (Recipe, MigrationReceipt)
	local sourceRecipe = ownRecipe(recipe)
	assert(
		sourceRecipe.schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION,
		"schema-v1 recipes require upgradeLegacyV1 with an explicit WorldId before generator migration"
	)
	local sourceWorldId = sourceRecipe.worldId
	assert(sourceWorldId ~= nil, "schema-v2 recipe must own worldId")

	local target = cloneVersions(targetVersions)
	local ownedMigrationKey = checkedOpaqueKey(
		"migrationKey",
		migrationKey,
		ResolvedRegionRecipe.MAX_KEY_BYTES
	)
	assert(
		not sameVersions(sourceRecipe.generatorVersions, target),
		"migration target versions must differ from locked versions"
	)
	assert(type(builder) == "function", "migration builder must be a function")

	local migratedCandidate = ownCandidate(builder(sourceRecipe, target))
	assert(migratedCandidate.worldId == sourceWorldId, "migration must preserve worldId")
	assert(
		migratedCandidate.worldSeedRef == sourceRecipe.worldSeedRef,
		"migration must preserve worldSeedRef"
	)
	assert(
		sameAddress(migratedCandidate.regionAddress, sourceRecipe.regionAddress),
		"migration must preserve regionAddress"
	)
	assert(
		sameVersions(migratedCandidate.generatorVersions, target),
		"migration candidate must use exact target generator versions"
	)

	local migrated = lockOwnedV2(migratedCandidate)
	assert(migrated.regionId == sourceRecipe.regionId, "migration must preserve stable region identity")
	assert(
		migrated.recipeFingerprint ~= sourceRecipe.recipeFingerprint,
		"migration must change the recipe fingerprint"
	)

	local receipt: MigrationReceipt = table.freeze({
		migrationKey = ownedMigrationKey,
		worldId = sourceWorldId,
		regionId = sourceRecipe.regionId,
		sourceFingerprint = sourceRecipe.recipeFingerprint,
		targetFingerprint = migrated.recipeFingerprint,
		sourceVersions = copyVersions(sourceRecipe.generatorVersions),
		targetVersions = copyVersions(migrated.generatorVersions),
	})
	return migrated, receipt
end

return table.freeze(ResolvedRegionRecipe)
