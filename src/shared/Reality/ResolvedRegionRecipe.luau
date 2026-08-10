--!strict

local requireAny = require :: any
local scriptValue = script :: any
local StableId = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.StableId)
	else requireAny("../Core/StableId")
local RegionAddress = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Spatial.RegionAddress)
	else requireAny("../Spatial/RegionAddress")

local ResolvedRegionRecipe = {}

ResolvedRegionRecipe.SchemaVersion = 1
ResolvedRegionRecipe.MaxKeyBytes = 256
ResolvedRegionRecipe.MaxSeedRefBytes = 512
ResolvedRegionRecipe.MaxTopologyAnchors = 256
ResolvedRegionRecipe.MaxCanonicalContentKeys = 1024
ResolvedRegionRecipe.MaxDeltaPayloadDepth = 16
ResolvedRegionRecipe.MaxDeltaPayloadNodes = 4096
ResolvedRegionRecipe.MaxDeltaStringBytes = 4096

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type RegionAddress = {
	x: number,
	z: number,
	layer: number,
}

export type LockInput = {
	worldId: string,
	worldSeedRef: string,
	regionAddress: RegionAddress,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionRecipe = {
	schemaVersion: number,
	regionId: string,
	fingerprint: string,
	worldId: string,
	worldSeedRef: string,
	regionAddress: RegionAddress,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type PlainData = { [string]: unknown }

export type SerializedRecipe = {
	schemaVersion: number,
	regionId: string,
	fingerprint: string,
	worldId: string,
	worldSeedRef: string,
	regionAddress: RegionAddress,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type RegionDelta = {
	baseSchemaVersion: number,
	baseRegionId: string,
	baseFingerprint: string,
	sequence: number,
	kind: string,
	targetKey: string?,
	payload: PlainData,
}

export type MigrationPlan = {
	regionId: string,
	fromFingerprint: string,
	fromVersions: GeneratorVersions,
	toVersions: GeneratorVersions,
	changedGenerators: { string },
}

local LOCK_INPUT_KEYS: { [string]: boolean } = table.freeze({
	worldId = true,
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntent = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
})

local RECIPE_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	regionId = true,
	fingerprint = true,
	worldId = true,
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntent = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
})

local REGION_ADDRESS_KEYS: { [string]: boolean } = table.freeze({
	x = true,
	z = true,
	layer = true,
})

local GENERATOR_VERSION_KEYS: { [string]: boolean } = table.freeze({
	reality = true,
	topology = true,
	material = true,
	object = true,
	entity = true,
})

local GENERATOR_VERSION_ORDER = table.freeze({ "reality", "topology", "material", "object", "entity" })

local MAX_SAFE_INTEGER = 9007199254740991
local MAX_GENERATOR_VERSION = 2147483647

local function assertExactShape(value: unknown, allowedKeys: { [string]: boolean }, path: string): any
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
	assert(#stringValue <= maximumBytes, `{path} must be <= {maximumBytes} bytes`)
	assert(string.find(stringValue, "%c") == nil, `{path} must not contain control characters`)
	return stringValue
end

local function checkedSafeInteger(path: string, value: unknown): number
	assert(type(value) == "number", `{path} must be a number`)
	local numericValue = value :: number
	assert(
		numericValue == numericValue
			and numericValue ~= math.huge
			and numericValue ~= -math.huge
			and numericValue == math.floor(numericValue)
			and math.abs(numericValue) <= MAX_SAFE_INTEGER,
		`{path} must be a safe integer`
	)
	return numericValue
end

local function checkedPositiveInteger(path: string, value: unknown, maximum: number): number
	local numericValue = checkedSafeInteger(path, value)
	assert(numericValue >= 1 and numericValue <= maximum, `{path} must be in [1, {maximum}]`)
	return numericValue
end

local function cloneRegionAddress(value: unknown): RegionAddress
	local source = assertExactShape(value, REGION_ADDRESS_KEYS, "regionAddress")
	local x = checkedSafeInteger("regionAddress.x", source.x)
	local z = checkedSafeInteger("regionAddress.z", source.z)
	local layer = checkedSafeInteger("regionAddress.layer", source.layer)
	return RegionAddress.new(x, z, layer)
end

local function cloneGeneratorVersions(value: unknown): GeneratorVersions
	local source = assertExactShape(value, GENERATOR_VERSION_KEYS, "generatorVersions")
	return table.freeze({
		reality = checkedPositiveInteger("generatorVersions.reality", source.reality, MAX_GENERATOR_VERSION),
		topology = checkedPositiveInteger(
			"generatorVersions.topology",
			source.topology,
			MAX_GENERATOR_VERSION
		),
		material = checkedPositiveInteger(
			"generatorVersions.material",
			source.material,
			MAX_GENERATOR_VERSION
		),
		object = checkedPositiveInteger("generatorVersions.object", source.object, MAX_GENERATOR_VERSION),
		entity = checkedPositiveInteger("generatorVersions.entity", source.entity, MAX_GENERATOR_VERSION),
	})
end

local function cloneCanonicalKeyArray(path: string, value: unknown, maximumCount: number): { string }
	assert(type(value) == "table", `{path} must be a table`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	local length = #source
	assert(length <= maximumCount, `{path} must contain at most {maximumCount} entries`)

	for key in pairs(source) do
		assert(
			type(key) == "number" and key == math.floor(key) and key >= 1 and key <= length,
			`{path} must be a dense 1-based array`
		)
	end

	local copy: { string } = {}
	for index = 1, length do
		copy[index] = checkedString(`{path}[{index}]`, source[index], ResolvedRegionRecipe.MaxKeyBytes)
	end
	table.sort(copy)
	for index = 2, #copy do
		assert(copy[index] ~= copy[index - 1], `{path} must not contain duplicate keys`)
	end
	return table.freeze(copy)
end

local function foldKeys(label: string, values: { string }): string
	local accumulator = StableId.fromParts("resolved-region-fold", {
		tostring(ResolvedRegionRecipe.SchemaVersion),
		label,
		tostring(#values),
	})
	for index, value in ipairs(values) do
		accumulator = StableId.fromParts("resolved-region-fold", {
			accumulator,
			tostring(index),
			value,
		})
	end
	return accumulator
end

local function computeRegionId(worldId: string, address: RegionAddress): string
	return StableId.fromParts("region", {
		worldId,
		RegionAddress.key(address),
	})
end

local function computeFingerprint(
	worldId: string,
	worldSeedRef: string,
	address: RegionAddress,
	versions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string }
): string
	local anchorFold = foldKeys("topology", topologyAnchorKeys)
	local contentFold = foldKeys("content", canonicalContentKeys)
	return StableId.fromParts("resolved-region-recipe", {
		tostring(ResolvedRegionRecipe.SchemaVersion),
		worldId,
		worldSeedRef,
		RegionAddress.key(address),
		tostring(versions.reality),
		tostring(versions.topology),
		tostring(versions.material),
		tostring(versions.object),
		tostring(versions.entity),
		semanticIntent,
		anchorFold,
		contentFold,
	})
end

local function canonicalizeLockInput(value: unknown): LockInput
	local source = assertExactShape(value, LOCK_INPUT_KEYS, "lockInput")
	local worldId = checkedString("lockInput.worldId", source.worldId, ResolvedRegionRecipe.MaxKeyBytes)
	assert(StableId.is(worldId, "world"), "lockInput.worldId must be a canonical world StableId")
	local worldSeedRef =
		checkedString("lockInput.worldSeedRef", source.worldSeedRef, ResolvedRegionRecipe.MaxSeedRefBytes)
	local address = cloneRegionAddress(source.regionAddress)
	local versions = cloneGeneratorVersions(source.generatorVersions)
	local semanticIntent =
		checkedString("lockInput.semanticIntent", source.semanticIntent, ResolvedRegionRecipe.MaxKeyBytes)
	local topologyAnchorKeys = cloneCanonicalKeyArray(
		"lockInput.topologyAnchorKeys",
		source.topologyAnchorKeys,
		ResolvedRegionRecipe.MaxTopologyAnchors
	)
	local canonicalContentKeys = cloneCanonicalKeyArray(
		"lockInput.canonicalContentKeys",
		source.canonicalContentKeys,
		ResolvedRegionRecipe.MaxCanonicalContentKeys
	)

	return table.freeze({
		worldId = worldId,
		worldSeedRef = worldSeedRef,
		regionAddress = address,
		generatorVersions = versions,
		semanticIntent = semanticIntent,
		topologyAnchorKeys = topologyAnchorKeys,
		canonicalContentKeys = canonicalContentKeys,
	})
end

local function observationIdentity(value: unknown): (string, string, RegionAddress)
	assert(type(value) == "table", "lockInput must be a table")
	local source = value :: any
	assert(getmetatable(source) == nil, "lockInput must not have a metatable")
	local worldId = checkedString("lockInput.worldId", source.worldId, ResolvedRegionRecipe.MaxKeyBytes)
	assert(StableId.is(worldId, "world"), "lockInput.worldId must be a canonical world StableId")
	local worldSeedRef =
		checkedString("lockInput.worldSeedRef", source.worldSeedRef, ResolvedRegionRecipe.MaxSeedRefBytes)
	return worldId, worldSeedRef, cloneRegionAddress(source.regionAddress)
end

local function buildRecipe(input: LockInput): ResolvedRegionRecipe
	local regionId = computeRegionId(input.worldId, input.regionAddress)
	local fingerprint = computeFingerprint(
		input.worldId,
		input.worldSeedRef,
		input.regionAddress,
		input.generatorVersions,
		input.semanticIntent,
		input.topologyAnchorKeys,
		input.canonicalContentKeys
	)
	return table.freeze({
		schemaVersion = ResolvedRegionRecipe.SchemaVersion,
		regionId = regionId,
		fingerprint = fingerprint,
		worldId = input.worldId,
		worldSeedRef = input.worldSeedRef,
		regionAddress = input.regionAddress,
		generatorVersions = input.generatorVersions,
		semanticIntent = input.semanticIntent,
		topologyAnchorKeys = input.topologyAnchorKeys,
		canonicalContentKeys = input.canonicalContentKeys,
	})
end

local function recipeAsLockInput(recipe: ResolvedRegionRecipe): LockInput
	return table.freeze({
		worldId = recipe.worldId,
		worldSeedRef = recipe.worldSeedRef,
		regionAddress = recipe.regionAddress,
		generatorVersions = recipe.generatorVersions,
		semanticIntent = recipe.semanticIntent,
		topologyAnchorKeys = recipe.topologyAnchorKeys,
		canonicalContentKeys = recipe.canonicalContentKeys,
	})
end

local function clonePlainValue(
	value: unknown,
	path: string,
	seen: { [any]: boolean },
	depth: number,
	nodeBudget: { count: number }
): unknown
	assert(depth <= ResolvedRegionRecipe.MaxDeltaPayloadDepth, `{path} exceeds maximum nesting depth`)
	nodeBudget.count += 1
	assert(
		nodeBudget.count <= ResolvedRegionRecipe.MaxDeltaPayloadNodes,
		`{path} exceeds payload node budget`
	)

	local valueType = type(value)
	if valueType == "nil" or valueType == "boolean" then
		return value
	elseif valueType == "string" then
		local stringValue = value :: string
		assert(
			#stringValue <= ResolvedRegionRecipe.MaxDeltaStringBytes,
			`{path} string value exceeds {ResolvedRegionRecipe.MaxDeltaStringBytes} bytes`
		)
		return stringValue
	elseif valueType == "number" then
		local numericValue = value :: number
		assert(
			numericValue == numericValue and numericValue ~= math.huge and numericValue ~= -math.huge,
			`{path} must contain only finite numbers`
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
			assert(key ~= "", `{path} contains an empty string key`)
			assert(#key <= ResolvedRegionRecipe.MaxKeyBytes, `{path} contains an oversized string key`)
			assert(string.find(key, "%c") == nil, `{path} contains a control character in a key`)
		elseif keyType == "number" then
			hasNumericKeys = true
			local numericKey = checkedSafeInteger(`${path} key`, key)
			assert(numericKey >= 1, `{path} numeric keys must be positive integers`)
			numericKeyCount += 1
			maximumNumericKey = math.max(maximumNumericKey, numericKey)
		else
			error(`{path} keys must be strings or positive integers, got {keyType}`)
		end
		copy[key] = clonePlainValue(nested, `{path}.{tostring(key)}`, seen, depth + 1, nodeBudget)
	end

	assert(not (hasStringKeys and hasNumericKeys), `{path} must not mix string and numeric keys`)
	if hasNumericKeys then
		assert(numericKeyCount == maximumNumericKey, `{path} numeric keys must form a dense 1-based array`)
	end

	seen[source] = nil
	return table.freeze(copy)
end

local function clonePlainMap(value: unknown, path: string): PlainData
	assert(type(value) == "table", `{path} must be a table`)
	local source = value :: any
	assert(getmetatable(source) == nil, `{path} must not have a metatable`)
	for key in pairs(source) do
		assert(type(key) == "string" and key ~= "", `{path} top-level keys must be non-empty strings`)
	end
	return clonePlainValue(source, path, {}, 0, { count = 0 }) :: PlainData
end

function ResolvedRegionRecipe.lockFirstObservation(value: LockInput): ResolvedRegionRecipe
	return buildRecipe(canonicalizeLockInput(value))
end

function ResolvedRegionRecipe.resolveFirstObservation(
	existing: ResolvedRegionRecipe?,
	value: LockInput
): ResolvedRegionRecipe
	if existing == nil then
		return buildRecipe(canonicalizeLockInput(value))
	end

	local canonicalExisting = ResolvedRegionRecipe.deserialize(existing :: any)
	local incomingWorldId, incomingWorldSeedRef, incomingAddress = observationIdentity(value)
	assert(canonicalExisting.worldId == incomingWorldId, "existing truth belongs to a different world")
	assert(
		canonicalExisting.worldSeedRef == incomingWorldSeedRef,
		"existing truth belongs to a different world seed"
	)
	assert(
		canonicalExisting.regionId == computeRegionId(incomingWorldId, incomingAddress),
		"existing truth belongs to a different region"
	)
	return canonicalExisting
end

function ResolvedRegionRecipe.serialize(recipe: ResolvedRegionRecipe): SerializedRecipe
	local canonical = ResolvedRegionRecipe.deserialize(recipe :: any)
	return table.freeze({
		schemaVersion = canonical.schemaVersion,
		regionId = canonical.regionId,
		fingerprint = canonical.fingerprint,
		worldId = canonical.worldId,
		worldSeedRef = canonical.worldSeedRef,
		regionAddress = canonical.regionAddress,
		generatorVersions = canonical.generatorVersions,
		semanticIntent = canonical.semanticIntent,
		topologyAnchorKeys = canonical.topologyAnchorKeys,
		canonicalContentKeys = canonical.canonicalContentKeys,
	})
end

function ResolvedRegionRecipe.deserialize(value: unknown): ResolvedRegionRecipe
	local source = assertExactShape(value, RECIPE_KEYS, "resolvedRegionRecipe")
	assert(
		checkedPositiveInteger(
			"resolvedRegionRecipe.schemaVersion",
			source.schemaVersion,
			MAX_GENERATOR_VERSION
		) == ResolvedRegionRecipe.SchemaVersion,
		`resolvedRegionRecipe.schemaVersion must equal {ResolvedRegionRecipe.SchemaVersion}`
	)
	local expectedRegionId =
		checkedString("resolvedRegionRecipe.regionId", source.regionId, ResolvedRegionRecipe.MaxKeyBytes)
	local expectedFingerprint = checkedString(
		"resolvedRegionRecipe.fingerprint",
		source.fingerprint,
		ResolvedRegionRecipe.MaxKeyBytes
	)
	assert(
		StableId.is(expectedRegionId, "region"),
		"resolvedRegionRecipe.regionId must be a canonical region StableId"
	)
	assert(
		StableId.is(expectedFingerprint, "resolved-region-recipe"),
		"resolvedRegionRecipe.fingerprint must be a canonical resolved-region-recipe StableId"
	)

	local canonicalInput = canonicalizeLockInput({
		worldId = source.worldId,
		worldSeedRef = source.worldSeedRef,
		regionAddress = source.regionAddress,
		generatorVersions = source.generatorVersions,
		semanticIntent = source.semanticIntent,
		topologyAnchorKeys = source.topologyAnchorKeys,
		canonicalContentKeys = source.canonicalContentKeys,
	})
	local canonical = buildRecipe(canonicalInput)
	assert(
		canonical.regionId == expectedRegionId,
		"resolvedRegionRecipe.regionId does not match canonical identity"
	)
	assert(
		canonical.fingerprint == expectedFingerprint,
		"resolvedRegionRecipe.fingerprint does not match canonical recipe content"
	)
	return canonical
end

function ResolvedRegionRecipe.equals(left: ResolvedRegionRecipe, right: ResolvedRegionRecipe): boolean
	local canonicalLeft = ResolvedRegionRecipe.deserialize(left :: any)
	local canonicalRight = ResolvedRegionRecipe.deserialize(right :: any)
	return canonicalLeft.regionId == canonicalRight.regionId
		and canonicalLeft.fingerprint == canonicalRight.fingerprint
end

function ResolvedRegionRecipe.migrationPlan(
	recipe: ResolvedRegionRecipe,
	targetVersions: GeneratorVersions
): MigrationPlan?
	local canonicalRecipe = ResolvedRegionRecipe.deserialize(recipe :: any)
	local canonicalTarget = cloneGeneratorVersions(targetVersions)
	local changed: { string } = {}
	for _, key in ipairs(GENERATOR_VERSION_ORDER) do
		if (canonicalRecipe.generatorVersions :: any)[key] ~= (canonicalTarget :: any)[key] then
			table.insert(changed, key)
		end
	end
	if #changed == 0 then
		return nil
	end
	return table.freeze({
		regionId = canonicalRecipe.regionId,
		fromFingerprint = canonicalRecipe.fingerprint,
		fromVersions = canonicalRecipe.generatorVersions,
		toVersions = canonicalTarget,
		changedGenerators = table.freeze(changed),
	})
end

function ResolvedRegionRecipe.newDelta(
	recipe: ResolvedRegionRecipe,
	sequence: number,
	kind: string,
	targetKey: string?,
	payload: PlainData?
): RegionDelta
	local canonicalRecipe = ResolvedRegionRecipe.deserialize(recipe :: any)
	local canonicalSequence = checkedPositiveInteger("delta.sequence", sequence, MAX_SAFE_INTEGER)
	local canonicalKind = checkedString("delta.kind", kind, ResolvedRegionRecipe.MaxKeyBytes)
	local canonicalTarget: string? = nil
	if targetKey ~= nil then
		canonicalTarget = checkedString("delta.targetKey", targetKey, ResolvedRegionRecipe.MaxKeyBytes)
	end
	local payloadValue: unknown = payload
	if payloadValue == nil then
		payloadValue = {}
	end
	local canonicalPayload = clonePlainMap(payloadValue, "delta.payload")
	return table.freeze({
		baseSchemaVersion = canonicalRecipe.schemaVersion,
		baseRegionId = canonicalRecipe.regionId,
		baseFingerprint = canonicalRecipe.fingerprint,
		sequence = canonicalSequence,
		kind = canonicalKind,
		targetKey = canonicalTarget,
		payload = canonicalPayload,
	})
end

function ResolvedRegionRecipe.assertDeltaMatchesBase(recipe: ResolvedRegionRecipe, delta: RegionDelta): ()
	local canonicalRecipe = ResolvedRegionRecipe.deserialize(recipe :: any)
	assert(type(delta) == "table", "delta must be a table")
	assert(getmetatable(delta :: any) == nil, "delta must not have a metatable")
	assert(delta.baseSchemaVersion == canonicalRecipe.schemaVersion, "delta base schema version mismatch")
	assert(delta.baseRegionId == canonicalRecipe.regionId, "delta base region mismatch")
	assert(delta.baseFingerprint == canonicalRecipe.fingerprint, "delta base fingerprint mismatch")
end

function ResolvedRegionRecipe.lockInput(recipe: ResolvedRegionRecipe): LockInput
	return recipeAsLockInput(ResolvedRegionRecipe.deserialize(recipe :: any))
end

return table.freeze(ResolvedRegionRecipe)
