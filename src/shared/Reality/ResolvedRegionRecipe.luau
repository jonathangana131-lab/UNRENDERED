--!strict

local requireAny = require :: any
local scriptValue = script :: any
local DeterminismContract = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.DeterminismContract)
	else requireAny("../Core/DeterminismContract")
local StableId = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.StableId)
	else requireAny("../Core/StableId")
local Versions = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.Versions)
	else requireAny("../Core/Versions")

local ResolvedRegionRecipe = {}

ResolvedRegionRecipe.SchemaVersion = 1
ResolvedRegionRecipe.MAX_KEYS_PER_SECTION = 256
ResolvedRegionRecipe.MAX_KEY_BYTES = 256
ResolvedRegionRecipe.MAX_WORLD_REFERENCE_BYTES = 512

local MAX_SAFE_INTEGER = 9007199254740991
local FINGERPRINT_HASH_SEEDS = table.freeze({
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
})

export type RegionAddress = {
	x: number,
	z: number,
	layer: number,
}

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type MigrationRecord = {
	key: string,
	fromFingerprint: string,
}

export type ResolvedRegionRecipe = {
	schemaVersion: number,
	id: string,
	worldId: string,
	worldSeedRef: string,
	address: RegionAddress,
	regionKey: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKeys: { string },
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
	firstObservationKey: string,
	baseFingerprint: string,
	fingerprint: string,
	migration: MigrationRecord?,
}

export type LockRequest = {
	worldId: string,
	worldSeedRef: string,
	address: RegionAddress,
	generatorVersions: GeneratorVersions,
	semanticIntentKeys: { string },
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
	firstObservationKey: string,
}

export type LockResult = {
	recipe: ResolvedRegionRecipe,
	lockedNow: boolean,
	candidateMatches: boolean,
}

export type MigrationRequest = {
	migrationKey: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKeys: { string },
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type PlainData = { [string]: unknown }

export type DeltaSpec = {
	kind: string,
	targetKey: string?,
	payload: PlainData,
}

export type RegionDelta = {
	baseFingerprint: string,
	sequence: number,
	kind: string,
	targetKey: string?,
	payload: PlainData,
}

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

local LOCK_REQUEST_KEYS: { [string]: boolean } = table.freeze({
	worldId = true,
	worldSeedRef = true,
	address = true,
	generatorVersions = true,
	semanticIntentKeys = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
	firstObservationKey = true,
})

local RECIPE_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	id = true,
	worldId = true,
	worldSeedRef = true,
	address = true,
	regionKey = true,
	generatorVersions = true,
	semanticIntentKeys = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
	firstObservationKey = true,
	baseFingerprint = true,
	fingerprint = true,
	migration = true,
})

local MIGRATION_KEYS: { [string]: boolean } = table.freeze({
	key = true,
	fromFingerprint = true,
})

local MIGRATION_REQUEST_KEYS: { [string]: boolean } = table.freeze({
	migrationKey = true,
	generatorVersions = true,
	semanticIntentKeys = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
})

local DELTA_SPEC_KEYS: { [string]: boolean } = table.freeze({
	kind = true,
	targetKey = true,
	payload = true,
})

local DELTA_KEYS: { [string]: boolean } = table.freeze({
	baseFingerprint = true,
	sequence = true,
	kind = true,
	targetKey = true,
	payload = true,
})

local function assertExactRecordShape(value: unknown, allowedKeys: { [string]: boolean }, path: string): any
	assert(type(value) == "table", `{path} must be a table`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	for key in pairs(source) do
		assert(
			type(key) == "string" and allowedKeys[key] == true,
			`{path} contains unknown schema key {tostring(key)}`
		)
	end
	return source
end

local function checkedString(path: string, value: unknown, maximumBytes: number): string
	assert(type(value) == "string", `{path} must be a string`)
	local stringValue = value :: string
	assert(stringValue ~= "", `{path} must not be empty`)
	assert(#stringValue <= maximumBytes, `{path} exceeds {maximumBytes} bytes`)
	assert(string.find(stringValue, "%c") == nil, `{path} must not contain control characters`)
	return stringValue
end

local function checkedSafeInteger(path: string, value: unknown): number
	assert(type(value) == "number", `{path} must be a number`)
	local numberValue = value :: number
	assert(numberValue == numberValue and numberValue > -math.huge and numberValue < math.huge, `{path} must be finite`)
	assert(numberValue == math.floor(numberValue), `{path} must be an integer`)
	assert(math.abs(numberValue) <= MAX_SAFE_INTEGER, `{path} must be a safe integer`)
	return numberValue
end

local function checkedPositiveVersion(path: string, value: unknown): number
	local version = checkedSafeInteger(path, value)
	assert(version >= 1 and version <= 2147483647, `{path} must be in [1, 2147483647]`)
	return version
end

local function cloneAddress(value: unknown): RegionAddress
	local source = assertExactRecordShape(value, ADDRESS_KEYS, "address")
	return table.freeze({
		x = checkedSafeInteger("address.x", source.x),
		z = checkedSafeInteger("address.z", source.z),
		layer = checkedSafeInteger("address.layer", source.layer),
	})
end

local function regionKey(address: RegionAddress): string
	return string.format("r:%d:%d:%d", address.x, address.z, address.layer)
end

local function cloneVersions(value: unknown): GeneratorVersions
	local source = assertExactRecordShape(value, VERSION_KEYS, "generatorVersions")
	return table.freeze({
		reality = checkedPositiveVersion("generatorVersions.reality", source.reality),
		topology = checkedPositiveVersion("generatorVersions.topology", source.topology),
		material = checkedPositiveVersion("generatorVersions.material", source.material),
		object = checkedPositiveVersion("generatorVersions.object", source.object),
		entity = checkedPositiveVersion("generatorVersions.entity", source.entity),
	})
end

local function cloneCanonicalKeyList(value: unknown, path: string, requireNonEmpty: boolean): { string }
	assert(type(value) == "table", `{path} must be an array`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	local length = #source
	assert(length <= ResolvedRegionRecipe.MAX_KEYS_PER_SECTION, `{path} exceeds key-count limit`)
	if requireNonEmpty then
		assert(length > 0, `{path} must contain at least one key`)
	end

	for key in pairs(source) do
		assert(
			type(key) == "number"
				and key == math.floor(key)
				and key >= 1
				and key <= length,
			`{path} must be a dense 1-based array`
		)
	end

	local copy: { string } = {}
	for index = 1, length do
		local key = checkedString(
			`{path}[{index}]`,
			source[index],
			ResolvedRegionRecipe.MAX_KEY_BYTES
		)
		table.insert(copy, key)
	end
	table.sort(copy)

	for index = 2, #copy do
		assert(copy[index] ~= copy[index - 1], `{path} contains duplicate key {copy[index]}`)
	end

	return table.freeze(copy)
end

local function appendKeySection(parts: { string }, label: string, keys: { string })
	table.insert(parts, label)
	table.insert(parts, tostring(#keys))
	for _, key in keys do
		table.insert(parts, key)
	end
end

local function fingerprint(namespace: string, parts: { string }): string
	local digest = {}
	for _, seed in FINGERPRINT_HASH_SEEDS do
		table.insert(
			digest,
			DeterminismContract.hex32(DeterminismContract.hashParts(seed, parts))
		)
	end
	return StableId.fromParts(namespace, {
		"resolved-region-fingerprint-v1",
		table.concat(digest),
	})
end

local function baseFingerprint(
	worldId: string,
	worldSeedRef: string,
	address: RegionAddress,
	versions: GeneratorVersions,
	semanticIntentKeys: { string },
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string }
): string
	local parts = {
		"resolved-region-base",
		tostring(ResolvedRegionRecipe.SchemaVersion),
		worldId,
		worldSeedRef,
		regionKey(address),
		"versions",
		tostring(versions.reality),
		tostring(versions.topology),
		tostring(versions.material),
		tostring(versions.object),
		tostring(versions.entity),
	}
	appendKeySection(parts, "semantic-intent", semanticIntentKeys)
	appendKeySection(parts, "topology-anchors", topologyAnchorKeys)
	appendKeySection(parts, "canonical-content", canonicalContentKeys)
	return fingerprint("regionbase", parts)
end

local function fullFingerprint(
	resolvedBaseFingerprint: string,
	firstObservationKey: string,
	migration: MigrationRecord?
): string
	local parts = {
		"resolved-region-record",
		tostring(ResolvedRegionRecipe.SchemaVersion),
		resolvedBaseFingerprint,
		firstObservationKey,
	}
	if migration == nil then
		table.insert(parts, "initial-lock")
	else
		table.insert(parts, "migration")
		table.insert(parts, migration.key)
		table.insert(parts, migration.fromFingerprint)
	end
	return fingerprint("regionrecipe", parts)
end

local function cloneMigration(value: unknown): MigrationRecord?
	if value == nil then
		return nil
	end
	local source = assertExactRecordShape(value, MIGRATION_KEYS, "migration")
	local key = checkedString("migration.key", source.key, ResolvedRegionRecipe.MAX_KEY_BYTES)
	local fromFingerprint = checkedString("migration.fromFingerprint", source.fromFingerprint, 256)
	assert(
		StableId.is(fromFingerprint, "regionrecipe"),
		"migration.fromFingerprint must be a regionrecipe StableId"
	)
	return table.freeze({
		key = key,
		fromFingerprint = fromFingerprint,
	})
end

local function ownLockRequest(value: unknown): LockRequest
	local source = assertExactRecordShape(value, LOCK_REQUEST_KEYS, "LockRequest")
	local worldId = checkedString("worldId", source.worldId, 256)
	local worldSeedRef = checkedString(
		"worldSeedRef",
		source.worldSeedRef,
		ResolvedRegionRecipe.MAX_WORLD_REFERENCE_BYTES
	)
	local firstObservationKey = checkedString(
		"firstObservationKey",
		source.firstObservationKey,
		ResolvedRegionRecipe.MAX_KEY_BYTES
	)

	return table.freeze({
		worldId = worldId,
		worldSeedRef = worldSeedRef,
		address = cloneAddress(source.address),
		generatorVersions = cloneVersions(source.generatorVersions),
		semanticIntentKeys = cloneCanonicalKeyList(source.semanticIntentKeys, "semanticIntentKeys", true),
		topologyAnchorKeys = cloneCanonicalKeyList(source.topologyAnchorKeys, "topologyAnchorKeys", true),
		canonicalContentKeys = cloneCanonicalKeyList(source.canonicalContentKeys, "canonicalContentKeys", true),
		firstObservationKey = firstObservationKey,
	})
end

local function buildRecipe(request: LockRequest, migration: MigrationRecord?): ResolvedRegionRecipe
	local address = request.address
	local key = regionKey(address)
	local id = StableId.fromParts("region", {
		request.worldId,
		key,
	})
	local resolvedBaseFingerprint = baseFingerprint(
		request.worldId,
		request.worldSeedRef,
		address,
		request.generatorVersions,
		request.semanticIntentKeys,
		request.topologyAnchorKeys,
		request.canonicalContentKeys
	)

	return table.freeze({
		schemaVersion = ResolvedRegionRecipe.SchemaVersion,
		id = id,
		worldId = request.worldId,
		worldSeedRef = request.worldSeedRef,
		address = address,
		regionKey = key,
		generatorVersions = request.generatorVersions,
		semanticIntentKeys = request.semanticIntentKeys,
		topologyAnchorKeys = request.topologyAnchorKeys,
		canonicalContentKeys = request.canonicalContentKeys,
		firstObservationKey = request.firstObservationKey,
		baseFingerprint = resolvedBaseFingerprint,
		fingerprint = fullFingerprint(resolvedBaseFingerprint, request.firstObservationKey, migration),
		migration = migration,
	})
end

local function snapshotStringList(source: { string }): { string }
	local copy = {}
	for _, value in source do
		table.insert(copy, value)
	end
	return copy
end

local function snapshotVersions(source: GeneratorVersions): { [string]: number }
	return {
		reality = source.reality,
		topology = source.topology,
		material = source.material,
		object = source.object,
		entity = source.entity,
	}
end

local function snapshotAddress(source: RegionAddress): { [string]: number }
	return {
		x = source.x,
		z = source.z,
		layer = source.layer,
	}
end

local function clonePlainValue(value: unknown, path: string, seen: { [any]: boolean }): unknown
	local valueType = type(value)
	if valueType == "nil" or valueType == "boolean" or valueType == "string" then
		return value
	elseif valueType == "number" then
		local numericValue = value :: number
		assert(
			numericValue == numericValue and numericValue > -math.huge and numericValue < math.huge,
			`{path} numbers must be finite`
		)
		return numericValue
	elseif valueType ~= "table" then
		error(`{path} must contain plain data, got {valueType}`)
	end

	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not contain metatables`)
	assert(not seen[source], `{path} must not contain cycles`)
	seen[source] = true

	local copy: { [any]: any } = {}
	local hasStringKeys = false
	local hasNumericKeys = false
	local numericKeyCount = 0
	local maximumNumericKey = 0

	for key, nested in pairs(source) do
		local keyType = type(key)
		if keyType == "string" then
			hasStringKeys = true
			checkedString(`${path} key`, key, ResolvedRegionRecipe.MAX_KEY_BYTES)
		elseif keyType == "number" then
			hasNumericKeys = true
			local numericKey = checkedSafeInteger(`${path} key`, key)
			assert(numericKey >= 1, `{path} numeric keys must be positive integers`)
			numericKeyCount += 1
			maximumNumericKey = math.max(maximumNumericKey, numericKey)
		else
			error(`{path} keys must be strings or positive integers, got {keyType}`)
		end
		copy[key] = clonePlainValue(nested, `{path}.{tostring(key)}`, seen)
	end

	assert(not (hasStringKeys and hasNumericKeys), `{path} must not mix string and numeric keys`)
	if hasNumericKeys then
		assert(numericKeyCount == maximumNumericKey, `{path} numeric keys must form a dense 1-based array`)
	end

	seen[source] = nil
	return table.freeze(copy)
end

local function clonePayload(value: unknown): PlainData
	assert(type(value) == "table", "payload must be a table")
	local source = value :: any
	assert(getmetatable(source) == nil, "payload must not have a metatable")
	for key in pairs(source) do
		assert(type(key) == "string", "payload top-level keys must be strings")
		checkedString("payload key", key, ResolvedRegionRecipe.MAX_KEY_BYTES)
	end
	return clonePlainValue(source, "payload", {}) :: PlainData
end

function ResolvedRegionRecipe.currentGeneratorVersions(): GeneratorVersions
	return cloneVersions({
		reality = Versions.Reality,
		topology = Versions.Topology,
		material = Versions.Material,
		object = Versions.Object,
		entity = Versions.Entity,
	})
end

function ResolvedRegionRecipe.reconstruct(value: unknown): ResolvedRegionRecipe
	local source = assertExactRecordShape(value, RECIPE_KEYS, "ResolvedRegionRecipe")
	local schemaVersion = checkedSafeInteger("schemaVersion", source.schemaVersion)
	assert(
		schemaVersion == ResolvedRegionRecipe.SchemaVersion,
		`unsupported ResolvedRegionRecipe schema version {schemaVersion}`
	)

	local migration = cloneMigration(source.migration)
	local request = ownLockRequest({
		worldId = source.worldId,
		worldSeedRef = source.worldSeedRef,
		address = source.address,
		generatorVersions = source.generatorVersions,
		semanticIntentKeys = source.semanticIntentKeys,
		topologyAnchorKeys = source.topologyAnchorKeys,
		canonicalContentKeys = source.canonicalContentKeys,
		firstObservationKey = source.firstObservationKey,
	})
	local expected = buildRecipe(request, migration)

	assert(source.id == expected.id, "ResolvedRegionRecipe.id does not match canonical region identity")
	assert(source.regionKey == expected.regionKey, "ResolvedRegionRecipe.regionKey does not match address")
	assert(
		source.baseFingerprint == expected.baseFingerprint,
		"ResolvedRegionRecipe.baseFingerprint does not match canonical base"
	)
	assert(source.fingerprint == expected.fingerprint, "ResolvedRegionRecipe.fingerprint does not match record")

	return expected
end

function ResolvedRegionRecipe.snapshot(recipe: ResolvedRegionRecipe): { [string]: any }
	local owned = ResolvedRegionRecipe.reconstruct(recipe)
	local migration = nil
	if owned.migration ~= nil then
		migration = {
			key = owned.migration.key,
			fromFingerprint = owned.migration.fromFingerprint,
		}
	end
	return {
		schemaVersion = owned.schemaVersion,
		id = owned.id,
		worldId = owned.worldId,
		worldSeedRef = owned.worldSeedRef,
		address = snapshotAddress(owned.address),
		regionKey = owned.regionKey,
		generatorVersions = snapshotVersions(owned.generatorVersions),
		semanticIntentKeys = snapshotStringList(owned.semanticIntentKeys),
		topologyAnchorKeys = snapshotStringList(owned.topologyAnchorKeys),
		canonicalContentKeys = snapshotStringList(owned.canonicalContentKeys),
		firstObservationKey = owned.firstObservationKey,
		baseFingerprint = owned.baseFingerprint,
		fingerprint = owned.fingerprint,
		migration = migration,
	}
end

function ResolvedRegionRecipe.lock(
	existing: ResolvedRegionRecipe?,
	request: LockRequest
): LockResult
	local ownedRequest = ownLockRequest(request)
	local candidate = buildRecipe(ownedRequest, nil)
	if existing == nil then
		return table.freeze({
			recipe = candidate,
			lockedNow = true,
			candidateMatches = true,
		})
	end

	local current = ResolvedRegionRecipe.reconstruct(existing)
	assert(
		current.id == candidate.id,
		"first-observation lock cannot replace a different region identity"
	)
	return table.freeze({
		recipe = current,
		lockedNow = false,
		candidateMatches = current.baseFingerprint == candidate.baseFingerprint,
	})
end

function ResolvedRegionRecipe.migrate(
	existing: ResolvedRegionRecipe,
	request: MigrationRequest
): ResolvedRegionRecipe
	local current = ResolvedRegionRecipe.reconstruct(existing)
	local source = assertExactRecordShape(request, MIGRATION_REQUEST_KEYS, "MigrationRequest")
	local migrationKey = checkedString(
		"migrationKey",
		source.migrationKey,
		ResolvedRegionRecipe.MAX_KEY_BYTES
	)
	local migratedRequest = ownLockRequest({
		worldId = current.worldId,
		worldSeedRef = current.worldSeedRef,
		address = current.address,
		generatorVersions = source.generatorVersions,
		semanticIntentKeys = source.semanticIntentKeys,
		topologyAnchorKeys = source.topologyAnchorKeys,
		canonicalContentKeys = source.canonicalContentKeys,
		firstObservationKey = current.firstObservationKey,
	})
	return buildRecipe(
		migratedRequest,
		table.freeze({
			key = migrationKey,
			fromFingerprint = current.fingerprint,
		})
	)
end

function ResolvedRegionRecipe.equal(a: ResolvedRegionRecipe, b: ResolvedRegionRecipe): boolean
	return ResolvedRegionRecipe.reconstruct(a).fingerprint == ResolvedRegionRecipe.reconstruct(b).fingerprint
end

function ResolvedRegionRecipe.sameBase(a: ResolvedRegionRecipe, b: ResolvedRegionRecipe): boolean
	return ResolvedRegionRecipe.reconstruct(a).baseFingerprint
		== ResolvedRegionRecipe.reconstruct(b).baseFingerprint
end

function ResolvedRegionRecipe.createDelta(
	recipe: ResolvedRegionRecipe,
	sequence: number,
	spec: DeltaSpec
): RegionDelta
	local ownedRecipe = ResolvedRegionRecipe.reconstruct(recipe)
	local checkedSequence = checkedSafeInteger("sequence", sequence)
	assert(checkedSequence >= 1, "sequence must be a positive integer")
	local source = assertExactRecordShape(spec, DELTA_SPEC_KEYS, "DeltaSpec")
	local kind = checkedString("DeltaSpec.kind", source.kind, ResolvedRegionRecipe.MAX_KEY_BYTES)
	local targetKey = nil
	if source.targetKey ~= nil then
		targetKey = checkedString(
			"DeltaSpec.targetKey",
			source.targetKey,
			ResolvedRegionRecipe.MAX_KEY_BYTES
		)
	end
	local payload = clonePayload(source.payload)
	return table.freeze({
		baseFingerprint = ownedRecipe.baseFingerprint,
		sequence = checkedSequence,
		kind = kind,
		targetKey = targetKey,
		payload = payload,
	})
end

function ResolvedRegionRecipe.reconstructDelta(
	recipe: ResolvedRegionRecipe,
	value: unknown
): RegionDelta
	local ownedRecipe = ResolvedRegionRecipe.reconstruct(recipe)
	local source = assertExactRecordShape(value, DELTA_KEYS, "RegionDelta")
	local base = checkedString("RegionDelta.baseFingerprint", source.baseFingerprint, 256)
	assert(base == ownedRecipe.baseFingerprint, "RegionDelta belongs to a different generated base")
	local sequence = checkedSafeInteger("RegionDelta.sequence", source.sequence)
	assert(sequence >= 1, "RegionDelta.sequence must be a positive integer")
	local kind = checkedString("RegionDelta.kind", source.kind, ResolvedRegionRecipe.MAX_KEY_BYTES)
	local targetKey = nil
	if source.targetKey ~= nil then
		targetKey = checkedString(
			"RegionDelta.targetKey",
			source.targetKey,
			ResolvedRegionRecipe.MAX_KEY_BYTES
		)
	end
	return table.freeze({
		baseFingerprint = base,
		sequence = sequence,
		kind = kind,
		targetKey = targetKey,
		payload = clonePayload(source.payload),
	})
end

return table.freeze(ResolvedRegionRecipe)
