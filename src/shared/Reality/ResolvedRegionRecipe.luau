--!strict

local requireAny = require :: any
local scriptValue = script :: any
local StableId = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.StableId)
	else requireAny("../Core/StableId")
local DeterminismContract = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Core.DeterminismContract)
	else requireAny("../Core/DeterminismContract")
local RegionAddress = if scriptValue ~= nil
	then requireAny(scriptValue.Parent.Parent.Spatial.RegionAddress)
	else requireAny("../Spatial/RegionAddress")

local SCHEMA_VERSION = 1
local MAX_VERSION = 2147483647
local MAX_WORLD_SEED_REF_BYTES = 512
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

export type RegionAddressValue = {
	x: number,
	z: number,
	layer: number,
}

export type PotentialRegionRecipe = {
	worldId: string,
	worldSeedRef: string,
	regionAddress: RegionAddressValue,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionBaseRecipe = {
	schemaVersion: number,
	id: string,
	worldId: string,
	worldSeedRef: string,
	regionAddress: RegionAddressValue,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionRecipe = ResolvedRegionBaseRecipe
export type LockDisposition = "locked" | "existing-match" | "existing-conflict"

export type MigrationPlan = {
	source: ResolvedRegionRecipe,
	sourceFingerprint: string,
	sourceVersions: GeneratorVersions,
	targetVersions: GeneratorVersions,
}

export type MigrationResult = {
	sourceFingerprint: string,
	sourceVersions: GeneratorVersions,
	target: ResolvedRegionRecipe,
}

export type Migrator = (ResolvedRegionRecipe, GeneratorVersions) -> PotentialRegionRecipe

local ResolvedRegionRecipe = {
	SchemaVersion = SCHEMA_VERSION,
	FingerprintVersion = 1,
}

local POTENTIAL_KEYS = {
	worldId = true,
	worldSeedRef = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
}

local TOP_LEVEL_KEYS = {
	schemaVersion = true,
	id = true,
	worldId = true,
	worldSeedRef = true,
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

local function versionsEqual(left: GeneratorVersions, right: GeneratorVersions): boolean
	return left.reality == right.reality
		and left.topology == right.topology
		and left.material == right.material
		and left.object == right.object
		and left.entity == right.entity
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

local function derivedRegionId(worldId: string, address: RegionAddressValue): string
	return StableId.fromParts("region", { worldId, RegionAddress.key(address) })
end

local function candidateIdentity(input: any): (string, string, RegionAddressValue)
	assertPlainTable(input, "potentialRegionRecipe")
	local worldId = rawget(input, "worldId")
	local worldSeedRef = rawget(input, "worldSeedRef")
	local regionAddress = rawget(input, "regionAddress")
	assert(StableId.is(worldId, "world"), "worldId must be a StableId in the world namespace")
	assertBoundedText(worldSeedRef, "worldSeedRef", MAX_WORLD_SEED_REF_BYTES)
	return worldId, worldSeedRef, RegionAddress.fromPlainData(regionAddress)
end

local function freezeRecipe(input: PotentialRegionRecipe): ResolvedRegionRecipe
	assertExactKeys(input, POTENTIAL_KEYS, "potentialRegionRecipe")
	local worldId, worldSeedRef, address = candidateIdentity(input)
	assertSemanticKey(input.semanticIntentKey, "semanticIntentKey")

	local versions = normalizeVersions(input.generatorVersions)
	local anchors = normalizeKeyArray(input.topologyAnchorKeys, "topologyAnchorKeys", MAX_ANCHORS)
	local content = normalizeKeyArray(input.canonicalContentKeys, "canonicalContentKeys", MAX_CONTENT_KEYS)
	local id = derivedRegionId(worldId, address)

	return table.freeze({
		schemaVersion = SCHEMA_VERSION,
		id = id,
		worldId = worldId,
		worldSeedRef = worldSeedRef,
		regionAddress = address,
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
		recipe.worldSeedRef,
		RegionAddress.key(recipe.regionAddress),
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

function ResolvedRegionRecipe.regionId(worldId: string, address: RegionAddressValue): string
	assert(StableId.is(worldId, "world"), "worldId must be a StableId in the world namespace")
	local canonicalAddress = RegionAddress.fromPlainData(address)
	return derivedRegionId(worldId, canonicalAddress)
end

function ResolvedRegionRecipe.new(input: PotentialRegionRecipe): ResolvedRegionRecipe
	return freezeRecipe(input)
end

function ResolvedRegionRecipe.fromPlainData(value: any): ResolvedRegionRecipe
	assertExactKeys(value, TOP_LEVEL_KEYS, "resolvedRegionRecipe")
	assert(
		value.schemaVersion == SCHEMA_VERSION,
		`resolvedRegionRecipe.schemaVersion must be {SCHEMA_VERSION}`
	)
	assert(type(value.id) == "string", "resolvedRegionRecipe.id must be a string")

	local recipe = freezeRecipe({
		worldId = value.worldId,
		worldSeedRef = value.worldSeedRef,
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
		worldSeedRef = canonical.worldSeedRef,
		regionAddress = RegionAddress.toPlainData(canonical.regionAddress),
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
): (ResolvedRegionRecipe, LockDisposition)
	if existing == nil then
		return ResolvedRegionRecipe.new(candidate), "locked"
	end

	local locked = ResolvedRegionRecipe.fromPlainData(existing)
	local candidateWorldId, candidateWorldSeedRef, candidateAddress = candidateIdentity(candidate)
	assert(locked.worldId == candidateWorldId, "existing lock and candidate worldId must match")
	assert(
		locked.worldSeedRef == candidateWorldSeedRef,
		"existing lock and candidate worldSeedRef must match"
	)
	assert(
		RegionAddress.equal(locked.regionAddress, candidateAddress),
		"existing lock and candidate regionAddress must match"
	)

	local ok, canonicalCandidate = pcall(ResolvedRegionRecipe.new, candidate)
	if ok and ResolvedRegionRecipe.equivalent(locked, canonicalCandidate :: ResolvedRegionRecipe) then
		return locked, "existing-match"
	end
	return locked, "existing-conflict"
end

function ResolvedRegionRecipe.needsMigration(
	recipe: ResolvedRegionRecipe,
	targetVersions: GeneratorVersions
): boolean
	local canonical = ResolvedRegionRecipe.fromPlainData(recipe)
	local target = normalizeVersions(targetVersions)
	return not versionsEqual(canonical.generatorVersions, target)
end

function ResolvedRegionRecipe.planMigration(
	recipe: ResolvedRegionRecipe,
	targetVersions: GeneratorVersions
): MigrationPlan?
	local source = ResolvedRegionRecipe.fromPlainData(recipe)
	local target = normalizeVersions(targetVersions)
	if versionsEqual(source.generatorVersions, target) then
		return nil
	end
	return table.freeze({
		source = source,
		sourceFingerprint = ResolvedRegionRecipe.fingerprint(source),
		sourceVersions = normalizeVersions(source.generatorVersions),
		targetVersions = target,
	})
end

function ResolvedRegionRecipe.runMigration(plan: MigrationPlan, migrator: Migrator): MigrationResult
	assert(type(plan) == "table", "migration plan must be a table")
	assert(type(migrator) == "function", "migrator must be a function")

	local source = ResolvedRegionRecipe.fromPlainData(plan.source)
	local sourceFingerprint = ResolvedRegionRecipe.fingerprint(source)
	assert(
		plan.sourceFingerprint == sourceFingerprint,
		"migration plan source fingerprint does not match source recipe"
	)
	local sourceVersions = normalizeVersions(plan.sourceVersions)
	assert(
		versionsEqual(source.generatorVersions, sourceVersions),
		"migration plan source versions do not match source recipe"
	)
	local targetVersions = normalizeVersions(plan.targetVersions)
	assert(
		not versionsEqual(sourceVersions, targetVersions),
		"migration plan target versions must differ from source"
	)

	local migrated = ResolvedRegionRecipe.new(migrator(source, targetVersions))
	assert(migrated.worldId == source.worldId, "migration must preserve worldId")
	assert(migrated.worldSeedRef == source.worldSeedRef, "migration must preserve worldSeedRef")
	assert(
		RegionAddress.equal(migrated.regionAddress, source.regionAddress),
		"migration must preserve regionAddress"
	)
	assert(
		versionsEqual(migrated.generatorVersions, targetVersions),
		"migration output must use target generator versions"
	)

	return table.freeze({
		sourceFingerprint = sourceFingerprint,
		sourceVersions = sourceVersions,
		target = migrated,
	})
end

return table.freeze(ResolvedRegionRecipe)
