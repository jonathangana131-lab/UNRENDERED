--!strict

local StableId = require(script.Parent.Parent.Core.StableId)

local SCHEMA_VERSION = 1
local DELTA_STREAM_SCHEMA_VERSION = 1
local MAX_GENERATOR_VERSION = 2147483647
local MAX_REGION_ADDRESS_BYTES = 256
local MAX_SEMANTIC_BYTES = 160
local MAX_WORLD_SEED_BYTES = 512
local MAX_DELTA_PAYLOAD_REF_BYTES = 512
local MAX_CANONICAL_ITEMS = 64

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type Candidate = {
	worldSeed: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionRecipe = {
	schemaVersion: number,
	regionId: string,
	regionAddress: string,
	worldSeedRef: string,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
	recipeFingerprint: string,
}

export type MigrationDraft = {
	semanticIntent: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string },
}

export type MigrationHook = (ResolvedRegionRecipe, GeneratorVersions) -> MigrationDraft

export type RegionDeltaRecord = {
	sequence: number,
	deltaKey: string,
	payloadRef: string,
}

export type RegionDeltaStream = {
	schemaVersion: number,
	regionId: string,
	baseRecipeFingerprint: string,
	nextSequence: number,
	entries: { RegionDeltaRecord },
}

export type ValidationIssue = {
	code: string,
	path: string,
	message: string,
}

export type ValidationResult = {
	ok: boolean,
	issues: { ValidationIssue },
}

local ResolvedRegionRecipe = {
	SchemaVersion = SCHEMA_VERSION,
	DeltaStreamSchemaVersion = DELTA_STREAM_SCHEMA_VERSION,
}

local CANDIDATE_KEYS: { [string]: boolean } = table.freeze({
	worldSeed = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntent = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
})

local RECIPE_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	regionId = true,
	regionAddress = true,
	worldSeedRef = true,
	generatorVersions = true,
	semanticIntent = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
	recipeFingerprint = true,
})

local VERSION_KEYS: { [string]: boolean } = table.freeze({
	reality = true,
	topology = true,
	material = true,
	object = true,
	entity = true,
})

local MIGRATION_DRAFT_KEYS: { [string]: boolean } = table.freeze({
	semanticIntent = true,
	topologyAnchors = true,
	canonicalContentKeys = true,
})

local DELTA_STREAM_KEYS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	regionId = true,
	baseRecipeFingerprint = true,
	nextSequence = true,
	entries = true,
})

local DELTA_RECORD_KEYS: { [string]: boolean } = table.freeze({
	sequence = true,
	deltaKey = true,
	payloadRef = true,
})

local function isIntegerInRange(value: unknown, minimum: number, maximum: number): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
		and value >= minimum
		and value <= maximum
end

local function hasControlCharacters(value: string): boolean
	return string.find(value, "%c") ~= nil
end

local function isBoundedString(value: unknown, maximumBytes: number): boolean
	return type(value) == "string" and value ~= "" and #value <= maximumBytes and not hasControlCharacters(value)
end

local function hasOnlyKeys(value: { [any]: any }, allowed: { [string]: boolean }): boolean
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			return false
		end
	end
	return true
end

local function isPlainTable(value: unknown): boolean
	return type(value) == "table" and getmetatable(value :: any) == nil
end

local function denseArrayLength(value: unknown): number?
	if not isPlainTable(value) then
		return nil
	end
	local array = value :: { [any]: any }
	local length = #array
	for key in pairs(array) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then
			return nil
		end
	end
	for index = 1, length do
		if array[index] == nil then
			return nil
		end
	end
	return length
end

local function addIssue(issues: { ValidationIssue }, code: string, path: string, message: string): ()
	table.insert(issues, {
		code = code,
		path = path,
		message = message,
	})
end

local function reportResult(issues: { ValidationIssue }): ValidationResult
	return {
		ok = #issues == 0,
		issues = issues,
	}
end

local function assertExactShape(value: unknown, allowed: { [string]: boolean }, label: string): { [any]: any }
	assert(isPlainTable(value), `{label} must be a plain table without a metatable`)
	local raw = value :: { [any]: any }
	assert(hasOnlyKeys(raw, allowed), `{label} contains unknown or non-string fields`)
	for key in pairs(allowed) do
		assert(raw[key] ~= nil, `{label}.{key} is required`)
	end
	return raw
end

local function copyVersions(value: GeneratorVersions): GeneratorVersions
	return {
		reality = value.reality,
		topology = value.topology,
		material = value.material,
		object = value.object,
		entity = value.entity,
	}
end

local function freezeVersions(value: GeneratorVersions): GeneratorVersions
	return table.freeze(copyVersions(value))
end

local function normalizeVersions(value: unknown, label: string): GeneratorVersions
	local raw = assertExactShape(value, VERSION_KEYS, label)
	for key in pairs(VERSION_KEYS) do
		assert(
			isIntegerInRange(raw[key], 1, MAX_GENERATOR_VERSION),
			`{label}.{key} must be an integer in [1, {MAX_GENERATOR_VERSION}]`
		)
	end
	return {
		reality = raw.reality,
		topology = raw.topology,
		material = raw.material,
		object = raw.object,
		entity = raw.entity,
	}
end

local function versionsEqual(left: GeneratorVersions, right: GeneratorVersions): boolean
	return left.reality == right.reality
		and left.topology == right.topology
		and left.material == right.material
		and left.object == right.object
		and left.entity == right.entity
end

local function normalizeStringSet(value: unknown, label: string): { string }
	local length = denseArrayLength(value)
	assert(length ~= nil, `{label} must be a dense plain-data array`)
	assert(length <= MAX_CANONICAL_ITEMS, `{label} must contain at most {MAX_CANONICAL_ITEMS} entries`)
	local raw = value :: { any }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for index = 1, length do
		local item = raw[index]
		assert(
			isBoundedString(item, MAX_SEMANTIC_BYTES),
			`{label}[{index}] must be a non-empty semantic string <= {MAX_SEMANTIC_BYTES} bytes without controls`
		)
		assert(not seen[item], `{label}[{index}] duplicates semantic key {item}`)
		seen[item] = true
		table.insert(result, item)
	end
	table.sort(result)
	return result
end

local function freezeStringArray(value: { string }): { string }
	local result: { string } = {}
	for index, item in ipairs(value) do
		result[index] = item
	end
	return table.freeze(result)
end

local function encodeInteger(value: number): string
	assert(isIntegerInRange(value, 0, MAX_GENERATOR_VERSION), "integer encoding input out of range")
	if value == 0 then
		return "0"
	end
	local digits: { string } = {}
	local remaining = value
	while remaining > 0 do
		local digit = remaining % 10
		table.insert(digits, 1, string.char(48 + digit))
		remaining = (remaining - digit) / 10
	end
	return table.concat(digits)
end

local function foldFingerprint(signature: string, label: string, payload: string): string
	return StableId.fromParts("resolved-region-fold", { signature, label, payload })
end

local function recipeFingerprint(
	regionId: string,
	regionAddress: string,
	worldSeedRef: string,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string }
): string
	local signature = StableId.fromParts("resolved-region-fold", { "schema", encodeInteger(SCHEMA_VERSION) })
	signature = foldFingerprint(signature, "region-id", regionId)
	signature = foldFingerprint(signature, "region-address", regionAddress)
	signature = foldFingerprint(signature, "world-seed-ref", worldSeedRef)
	signature = foldFingerprint(signature, "version-reality", encodeInteger(generatorVersions.reality))
	signature = foldFingerprint(signature, "version-topology", encodeInteger(generatorVersions.topology))
	signature = foldFingerprint(signature, "version-material", encodeInteger(generatorVersions.material))
	signature = foldFingerprint(signature, "version-object", encodeInteger(generatorVersions.object))
	signature = foldFingerprint(signature, "version-entity", encodeInteger(generatorVersions.entity))
	signature = foldFingerprint(signature, "semantic-intent", semanticIntent)
	signature = foldFingerprint(signature, "topology-anchor-count", encodeInteger(#topologyAnchors))
	for index, key in ipairs(topologyAnchors) do
		signature = foldFingerprint(signature, `topology-anchor-{encodeInteger(index)}`, key)
	end
	signature = foldFingerprint(signature, "content-key-count", encodeInteger(#canonicalContentKeys))
	for index, key in ipairs(canonicalContentKeys) do
		signature = foldFingerprint(signature, `content-key-{encodeInteger(index)}`, key)
	end
	return StableId.fromParts("resolved-region-recipe", { signature })
end

local function sealFromReference(
	worldSeedRef: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntent: string,
	topologyAnchors: { string },
	canonicalContentKeys: { string }
): ResolvedRegionRecipe
	local frozenVersions = freezeVersions(generatorVersions)
	local frozenAnchors = freezeStringArray(topologyAnchors)
	local frozenContentKeys = freezeStringArray(canonicalContentKeys)
	local regionId = StableId.fromParts("world-region", { worldSeedRef, regionAddress })
	local fingerprint = recipeFingerprint(
		regionId,
		regionAddress,
		worldSeedRef,
		frozenVersions,
		semanticIntent,
		frozenAnchors,
		frozenContentKeys
	)
	return table.freeze({
		schemaVersion = SCHEMA_VERSION,
		regionId = regionId,
		regionAddress = regionAddress,
		worldSeedRef = worldSeedRef,
		generatorVersions = frozenVersions,
		semanticIntent = semanticIntent,
		topologyAnchors = frozenAnchors,
		canonicalContentKeys = frozenContentKeys,
		recipeFingerprint = fingerprint,
	})
end

local function normalizedCandidate(value: Candidate): (string, string, GeneratorVersions, string, { string }, { string })
	local raw = assertExactShape(value, CANDIDATE_KEYS, "candidate")
	assert(
		isBoundedString(raw.worldSeed, MAX_WORLD_SEED_BYTES),
		`candidate.worldSeed must be non-empty, <= {MAX_WORLD_SEED_BYTES} bytes, and contain no controls`
	)
	assert(
		isBoundedString(raw.regionAddress, MAX_REGION_ADDRESS_BYTES),
		`candidate.regionAddress must be non-empty, <= {MAX_REGION_ADDRESS_BYTES} bytes, and contain no controls`
	)
	assert(
		isBoundedString(raw.semanticIntent, MAX_SEMANTIC_BYTES),
		`candidate.semanticIntent must be non-empty, <= {MAX_SEMANTIC_BYTES} bytes, and contain no controls`
	)
	local versions = normalizeVersions(raw.generatorVersions, "candidate.generatorVersions")
	local anchors = normalizeStringSet(raw.topologyAnchors, "candidate.topologyAnchors")
	local contentKeys = normalizeStringSet(raw.canonicalContentKeys, "candidate.canonicalContentKeys")
	return raw.worldSeed, raw.regionAddress, versions, raw.semanticIntent, anchors, contentKeys
end

function ResolvedRegionRecipe.lock(candidate: Candidate): ResolvedRegionRecipe
	local worldSeed, regionAddress, versions, semanticIntent, anchors, contentKeys = normalizedCandidate(candidate)
	local worldSeedRef = StableId.fromParts("world-seed", { worldSeed })
	return sealFromReference(worldSeedRef, regionAddress, versions, semanticIntent, anchors, contentKeys)
end

local function inspectCanonicalStringSet(
	issues: { ValidationIssue },
	value: unknown,
	path: string
): boolean
	local length = denseArrayLength(value)
	if length == nil then
		addIssue(issues, "array.shape", path, "must be a dense plain-data array")
		return false
	end
	if length > MAX_CANONICAL_ITEMS then
		addIssue(issues, "array.count", path, `must contain at most {MAX_CANONICAL_ITEMS} entries`)
		return false
	end
	local raw = value :: { any }
	local previous: string? = nil
	local valid = true
	for index = 1, length do
		local item = raw[index]
		if not isBoundedString(item, MAX_SEMANTIC_BYTES) then
			addIssue(
				issues,
				"array.semantic_key",
				`{path}[{index}]`,
				`must be a non-empty semantic string <= {MAX_SEMANTIC_BYTES} bytes without controls`
			)
			valid = false
		elseif previous ~= nil and item <= previous then
			addIssue(issues, "array.canonical_order", path, "entries must be unique and strictly sorted")
			valid = false
		end
		if type(item) == "string" then
			previous = item
		end
	end
	return valid
end

local function inspectVersions(issues: { ValidationIssue }, value: unknown, path: string): boolean
	if not isPlainTable(value) then
		addIssue(issues, "versions.shape", path, "generator versions must be a plain table")
		return false
	end
	local raw = value :: { [any]: any }
	if not hasOnlyKeys(raw, VERSION_KEYS) then
		addIssue(issues, "versions.fields", path, "generator versions contain unknown fields")
		return false
	end
	local valid = true
	for key in pairs(VERSION_KEYS) do
		if not isIntegerInRange(raw[key], 1, MAX_GENERATOR_VERSION) then
			addIssue(
				issues,
				"versions.value",
				path .. "." .. key,
				`must be an integer in [1, {MAX_GENERATOR_VERSION}]`
			)
			valid = false
		end
	end
	return valid
end

function ResolvedRegionRecipe.inspect(value: unknown): ValidationResult
	local issues: { ValidationIssue } = {}
	if not isPlainTable(value) then
		addIssue(issues, "recipe.shape", "recipe", "recipe must be a plain table without a metatable")
		return reportResult(issues)
	end
	local raw = value :: { [any]: any }
	if not hasOnlyKeys(raw, RECIPE_KEYS) then
		addIssue(issues, "recipe.fields", "recipe", "recipe contains unknown or non-string fields")
	end
	for key in pairs(RECIPE_KEYS) do
		if raw[key] == nil then
			addIssue(issues, "recipe.required", key, "required recipe field missing")
		end
	end
	if raw.schemaVersion ~= SCHEMA_VERSION then
		addIssue(issues, "recipe.schema_version", "schemaVersion", `schemaVersion must equal {SCHEMA_VERSION}`)
	end
	if not StableId.is(raw.regionId, "world-region") then
		addIssue(issues, "recipe.region_id", "regionId", "regionId must be a project world-region StableId")
	end
	if not isBoundedString(raw.regionAddress, MAX_REGION_ADDRESS_BYTES) then
		addIssue(issues, "recipe.region_address", "regionAddress", "invalid regionAddress")
	end
	if not StableId.is(raw.worldSeedRef, "world-seed") then
		addIssue(issues, "recipe.world_seed_ref", "worldSeedRef", "worldSeedRef must be a project world-seed StableId")
	end
	local versionsValid = inspectVersions(issues, raw.generatorVersions, "generatorVersions")
	if not isBoundedString(raw.semanticIntent, MAX_SEMANTIC_BYTES) then
		addIssue(issues, "recipe.semantic_intent", "semanticIntent", "invalid semantic intent")
	end
	local anchorsValid = inspectCanonicalStringSet(issues, raw.topologyAnchors, "topologyAnchors")
	local contentValid = inspectCanonicalStringSet(issues, raw.canonicalContentKeys, "canonicalContentKeys")
	if not StableId.is(raw.recipeFingerprint, "resolved-region-recipe") then
		addIssue(
			issues,
			"recipe.fingerprint",
			"recipeFingerprint",
			"recipeFingerprint must be a resolved-region-recipe StableId"
		)
	end

	if
		StableId.is(raw.worldSeedRef, "world-seed")
		and isBoundedString(raw.regionAddress, MAX_REGION_ADDRESS_BYTES)
		and StableId.is(raw.regionId, "world-region")
	then
		local expectedRegionId = StableId.fromParts("world-region", { raw.worldSeedRef, raw.regionAddress })
		if raw.regionId ~= expectedRegionId then
			addIssue(issues, "recipe.region_identity", "regionId", "regionId does not match worldSeedRef + regionAddress")
		end
	end

	if
		#issues == 0
		and versionsValid
		and anchorsValid
		and contentValid
	then
		local expectedFingerprint = recipeFingerprint(
			raw.regionId,
			raw.regionAddress,
			raw.worldSeedRef,
			raw.generatorVersions,
			raw.semanticIntent,
			raw.topologyAnchors,
			raw.canonicalContentKeys
		)
		if raw.recipeFingerprint ~= expectedFingerprint then
			addIssue(
				issues,
				"recipe.fingerprint_mismatch",
				"recipeFingerprint",
				"recipe content does not match its canonical fingerprint"
			)
		end
	end
	return reportResult(issues)
end

local function assertValidRecipe(value: unknown): { [any]: any }
	local report = ResolvedRegionRecipe.inspect(value)
	if not report.ok then
		local first = report.issues[1]
		error(`invalid resolved region recipe: {first.code} at {first.path}: {first.message}`, 3)
	end
	return value :: { [any]: any }
end

function ResolvedRegionRecipe.toPlainData(recipe: ResolvedRegionRecipe): { [string]: unknown }
	local raw = assertValidRecipe(recipe)
	local anchors: { string } = {}
	for index, key in ipairs(raw.topologyAnchors) do
		anchors[index] = key
	end
	local contentKeys: { string } = {}
	for index, key in ipairs(raw.canonicalContentKeys) do
		contentKeys[index] = key
	end
	return {
		schemaVersion = raw.schemaVersion,
		regionId = raw.regionId,
		regionAddress = raw.regionAddress,
		worldSeedRef = raw.worldSeedRef,
		generatorVersions = copyVersions(raw.generatorVersions),
		semanticIntent = raw.semanticIntent,
		topologyAnchors = anchors,
		canonicalContentKeys = contentKeys,
		recipeFingerprint = raw.recipeFingerprint,
	}
end

function ResolvedRegionRecipe.fromPlainData(value: unknown): ResolvedRegionRecipe
	local raw = assertValidRecipe(value)
	return sealFromReference(
		raw.worldSeedRef,
		raw.regionAddress,
		raw.generatorVersions,
		raw.semanticIntent,
		raw.topologyAnchors,
		raw.canonicalContentKeys
	)
end

function ResolvedRegionRecipe.resolveFirstObservation(
	existingRecipe: ResolvedRegionRecipe?,
	candidate: Candidate
): (ResolvedRegionRecipe, boolean)
	local worldSeed, regionAddress, versions, semanticIntent, anchors, contentKeys = normalizedCandidate(candidate)
	local worldSeedRef = StableId.fromParts("world-seed", { worldSeed })
	local incomingRegionId = StableId.fromParts("world-region", { worldSeedRef, regionAddress })
	if existingRecipe ~= nil then
		local locked = ResolvedRegionRecipe.fromPlainData(existingRecipe)
		assert(
			locked.regionId == incomingRegionId,
			"existing locked recipe identity does not match candidate world seed reference + region address"
		)
		return locked, false
	end
	return sealFromReference(worldSeedRef, regionAddress, versions, semanticIntent, anchors, contentKeys), true
end

function ResolvedRegionRecipe.migrate(
	recipe: ResolvedRegionRecipe,
	targetGeneratorVersions: GeneratorVersions,
	hook: MigrationHook
): ResolvedRegionRecipe
	local locked = ResolvedRegionRecipe.fromPlainData(recipe)
	local targetVersions = normalizeVersions(targetGeneratorVersions, "targetGeneratorVersions")
	if versionsEqual(locked.generatorVersions, targetVersions) then
		return locked
	end
	assert(type(hook) == "function", "an explicit migration hook is required for generator-version changes")
	local frozenTarget = freezeVersions(targetVersions)
	local draftValue = hook(locked, frozenTarget)
	local draft = assertExactShape(draftValue, MIGRATION_DRAFT_KEYS, "migration draft")
	assert(
		isBoundedString(draft.semanticIntent, MAX_SEMANTIC_BYTES),
		"migration draft semanticIntent is invalid"
	)
	local anchors = normalizeStringSet(draft.topologyAnchors, "migration draft.topologyAnchors")
	local contentKeys = normalizeStringSet(draft.canonicalContentKeys, "migration draft.canonicalContentKeys")
	return sealFromReference(
		locked.worldSeedRef,
		locked.regionAddress,
		targetVersions,
		draft.semanticIntent,
		anchors,
		contentKeys
	)
end

function ResolvedRegionRecipe.newDeltaStream(recipe: ResolvedRegionRecipe): RegionDeltaStream
	local locked = ResolvedRegionRecipe.fromPlainData(recipe)
	return {
		schemaVersion = DELTA_STREAM_SCHEMA_VERSION,
		regionId = locked.regionId,
		baseRecipeFingerprint = locked.recipeFingerprint,
		nextSequence = 1,
		entries = {},
	}
end

function ResolvedRegionRecipe.inspectDeltaStream(
	stream: unknown,
	recipe: ResolvedRegionRecipe
): ValidationResult
	local issues: { ValidationIssue } = {}
	local recipeRaw = assertValidRecipe(recipe)
	if not isPlainTable(stream) then
		addIssue(issues, "delta.shape", "deltaStream", "delta stream must be a mutable plain table")
		return reportResult(issues)
	end
	local raw = stream :: { [any]: any }
	if not hasOnlyKeys(raw, DELTA_STREAM_KEYS) then
		addIssue(issues, "delta.fields", "deltaStream", "delta stream contains unknown fields")
	end
	for key in pairs(DELTA_STREAM_KEYS) do
		if raw[key] == nil then
			addIssue(issues, "delta.required", key, "required delta stream field missing")
		end
	end
	if raw.schemaVersion ~= DELTA_STREAM_SCHEMA_VERSION then
		addIssue(issues, "delta.schema_version", "schemaVersion", "delta stream schema mismatch")
	end
	if raw.regionId ~= recipeRaw.regionId then
		addIssue(issues, "delta.region_id", "regionId", "delta stream is bound to a different region")
	end
	if raw.baseRecipeFingerprint ~= recipeRaw.recipeFingerprint then
		addIssue(
			issues,
			"delta.base_fingerprint",
			"baseRecipeFingerprint",
			"delta stream is bound to a different immutable base recipe"
		)
	end
	local length = denseArrayLength(raw.entries)
	if length == nil then
		addIssue(issues, "delta.entries_shape", "entries", "delta entries must be a dense plain-data array")
		return reportResult(issues)
	end
	if not isIntegerInRange(raw.nextSequence, 1, MAX_GENERATOR_VERSION) or raw.nextSequence ~= length + 1 then
		addIssue(issues, "delta.next_sequence", "nextSequence", "nextSequence must equal #entries + 1")
	end
	for index = 1, length do
		local entry = raw.entries[index]
		if not isPlainTable(entry) then
			addIssue(issues, "delta.entry_shape", `entries[{index}]`, "delta entry must be a plain table")
			continue
		end
		local entryRaw = entry :: { [any]: any }
		if not hasOnlyKeys(entryRaw, DELTA_RECORD_KEYS) then
			addIssue(issues, "delta.entry_fields", `entries[{index}]`, "delta entry contains unknown fields")
		end
		if entryRaw.sequence ~= index then
			addIssue(issues, "delta.sequence", `entries[{index}].sequence`, "delta sequence must be contiguous")
		end
		if not isBoundedString(entryRaw.deltaKey, MAX_SEMANTIC_BYTES) then
			addIssue(issues, "delta.key", `entries[{index}].deltaKey`, "invalid delta key")
		end
		if not isBoundedString(entryRaw.payloadRef, MAX_DELTA_PAYLOAD_REF_BYTES) then
			addIssue(issues, "delta.payload_ref", `entries[{index}].payloadRef`, "invalid delta payload reference")
		end
	end
	return reportResult(issues)
end

function ResolvedRegionRecipe.appendDelta(
	stream: RegionDeltaStream,
	recipe: ResolvedRegionRecipe,
	deltaKey: string,
	payloadRef: string
): RegionDeltaRecord
	local report = ResolvedRegionRecipe.inspectDeltaStream(stream, recipe)
	assert(report.ok, "delta stream must be valid and bound to the immutable base recipe before append")
	assert(
		isBoundedString(deltaKey, MAX_SEMANTIC_BYTES),
		`deltaKey must be non-empty, <= {MAX_SEMANTIC_BYTES} bytes, and contain no controls`
	)
	assert(
		isBoundedString(payloadRef, MAX_DELTA_PAYLOAD_REF_BYTES),
		`payloadRef must be non-empty, <= {MAX_DELTA_PAYLOAD_REF_BYTES} bytes, and contain no controls`
	)
	assert(stream.nextSequence <= MAX_GENERATOR_VERSION, "delta sequence capacity exhausted")
	local record = table.freeze({
		sequence = stream.nextSequence,
		deltaKey = deltaKey,
		payloadRef = payloadRef,
	})
	table.insert(stream.entries, record)
	stream.nextSequence += 1
	return record
end

return table.freeze(ResolvedRegionRecipe)
