--!strict

local StableId = require(script.Parent.Parent.Core.StableId)
local RealityVersions = require(script.Parent.RealityVersions)

export type GeneratorVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

export type RecipeDraft = {
	worldId: string,
	worldSeedRef: string,
	regionId: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type ResolvedRegionRecipe = {
	schemaVersion: number,
	recipeId: string,
	worldId: string,
	worldSeedRef: string,
	regionId: string,
	regionAddress: string,
	generatorVersions: GeneratorVersions,
	semanticIntentKey: string,
	topologyAnchorKeys: { string },
	canonicalContentKeys: { string },
}

export type DeltaBaseReference = {
	recipeId: string,
	recipeSchemaVersion: number,
}

export type ValidationResult = {
	ok: boolean,
	error: string?,
}

export type MigrationHook = (fromVersion: number, toVersion: number, serialized: any) -> any

local ResolvedRegionRecipe = {}

ResolvedRegionRecipe.SCHEMA_VERSION = 1
ResolvedRegionRecipe.RECIPE_NAMESPACE = "resolved-region-recipe"
ResolvedRegionRecipe.KEY_SET_NAMESPACE = "resolved-region-key-set"
ResolvedRegionRecipe.MAX_TEXT_BYTES = 512
ResolvedRegionRecipe.MAX_GENERATOR_VERSION = 2147483647

local DRAFT_FIELDS: { [string]: boolean } = table.freeze({
	worldId = true,
	worldSeedRef = true,
	regionId = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
})

local RECIPE_FIELDS: { [string]: boolean } = table.freeze({
	schemaVersion = true,
	recipeId = true,
	worldId = true,
	worldSeedRef = true,
	regionId = true,
	regionAddress = true,
	generatorVersions = true,
	semanticIntentKey = true,
	topologyAnchorKeys = true,
	canonicalContentKeys = true,
})

local VERSION_FIELDS: { [string]: boolean } = table.freeze({
	reality = true,
	topology = true,
	material = true,
	object = true,
	entity = true,
})

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function checkedVersion(path: string, value: any): number
	assert(
		isFinite(value)
			and value % 1 == 0
			and value >= 1
			and value <= ResolvedRegionRecipe.MAX_GENERATOR_VERSION,
		`{path} must be an integer in [1, {ResolvedRegionRecipe.MAX_GENERATOR_VERSION}]`
	)
	return value
end

local function checkedSchemaVersion(path: string, value: any): number
	assert(
		isFinite(value)
			and value % 1 == 0
			and value >= 0
			and value <= ResolvedRegionRecipe.MAX_GENERATOR_VERSION,
		`{path} must be a non-negative integer <= {ResolvedRegionRecipe.MAX_GENERATOR_VERSION}`
	)
	return value
end

local function checkedText(path: string, value: any): string
	assert(type(value) == "string", `{path} must be a string`)
	local text = value :: string
	assert(text ~= "", `{path} must not be empty`)
	assert(#text <= ResolvedRegionRecipe.MAX_TEXT_BYTES, `{path} exceeds byte limit`)
	assert(string.find(text, "%c") == nil, `{path} must not contain control characters`)
	return text
end

local function assertPlainRecord(path: string, value: any, fields: { [string]: boolean }): ()
	assert(type(value) == "table", `{path} must be a plain table`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)
	for key in pairs(value) do
		assert(type(key) == "string" and fields[key] == true, `{path} contains an unknown field`)
	end
end

local function copyVersions(value: any): GeneratorVersions
	assertPlainRecord("generatorVersions", value, VERSION_FIELDS)
	return table.freeze({
		reality = checkedVersion("generatorVersions.reality", value.reality),
		topology = checkedVersion("generatorVersions.topology", value.topology),
		material = checkedVersion("generatorVersions.material", value.material),
		object = checkedVersion("generatorVersions.object", value.object),
		entity = checkedVersion("generatorVersions.entity", value.entity),
	})
end

local function copyCanonicalKeySet(path: string, value: any): { string }
	assert(type(value) == "table", `{path} must be a dense 1-based array`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)

	local count = 0
	local maximum = 0
	for key in pairs(value) do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1, `{path} must use positive integer keys`)
		count += 1
		maximum = math.max(maximum, key)
	end
	assert(count == maximum, `{path} must be a dense 1-based array`)

	local result: { string } = table.create(count)
	local seen: { [string]: boolean } = {}
	for index = 1, count do
		local item = checkedText(`{path}[{index}]`, value[index])
		assert(not seen[item], `{path} must not contain duplicate keys`)
		seen[item] = true
		table.insert(result, item)
	end
	table.sort(result)
	return table.freeze(result)
end

local function foldKeySet(label: string, values: { string }): string
	local signature = StableId.fromParts(ResolvedRegionRecipe.KEY_SET_NAMESPACE, {
		label,
		tostring(#values),
	})
	for _, value in ipairs(values) do
		signature = StableId.fromParts(ResolvedRegionRecipe.KEY_SET_NAMESPACE, {
			signature,
			value,
		})
	end
	return signature
end

local function recipeIdFor(draft: RecipeDraft): string
	return StableId.fromParts(ResolvedRegionRecipe.RECIPE_NAMESPACE, {
		tostring(ResolvedRegionRecipe.SCHEMA_VERSION),
		draft.worldId,
		draft.worldSeedRef,
		draft.regionId,
		draft.regionAddress,
		tostring(draft.generatorVersions.reality),
		tostring(draft.generatorVersions.topology),
		tostring(draft.generatorVersions.material),
		tostring(draft.generatorVersions.object),
		tostring(draft.generatorVersions.entity),
		draft.semanticIntentKey,
		foldKeySet("topology-anchors", draft.topologyAnchorKeys),
		foldKeySet("canonical-content", draft.canonicalContentKeys),
	})
end

local function canonicalDraft(value: any): RecipeDraft
	assertPlainRecord("draft", value, DRAFT_FIELDS)
	return {
		worldId = checkedText("worldId", value.worldId),
		worldSeedRef = checkedText("worldSeedRef", value.worldSeedRef),
		regionId = checkedText("regionId", value.regionId),
		regionAddress = checkedText("regionAddress", value.regionAddress),
		generatorVersions = copyVersions(value.generatorVersions),
		semanticIntentKey = checkedText("semanticIntentKey", value.semanticIntentKey),
		topologyAnchorKeys = copyCanonicalKeySet("topologyAnchorKeys", value.topologyAnchorKeys),
		canonicalContentKeys = copyCanonicalKeySet("canonicalContentKeys", value.canonicalContentKeys),
	}
end

local function canonicalRecipe(value: any): ResolvedRegionRecipe
	assertPlainRecord("recipe", value, RECIPE_FIELDS)
	local schemaVersion = checkedSchemaVersion("schemaVersion", value.schemaVersion)
	assert(
		schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION,
		`unsupported ResolvedRegionRecipe schema version {schemaVersion}`
	)

	local draft = canonicalDraft({
		worldId = value.worldId,
		worldSeedRef = value.worldSeedRef,
		regionId = value.regionId,
		regionAddress = value.regionAddress,
		generatorVersions = value.generatorVersions,
		semanticIntentKey = value.semanticIntentKey,
		topologyAnchorKeys = value.topologyAnchorKeys,
		canonicalContentKeys = value.canonicalContentKeys,
	})
	local recipeId = checkedText("recipeId", value.recipeId)
	assert(
		StableId.is(recipeId, ResolvedRegionRecipe.RECIPE_NAMESPACE),
		"recipeId must use the resolved-region-recipe StableId namespace"
	)
	assert(recipeId == recipeIdFor(draft), "recipeId does not match immutable recipe content")

	return table.freeze({
		schemaVersion = schemaVersion,
		recipeId = recipeId,
		worldId = draft.worldId,
		worldSeedRef = draft.worldSeedRef,
		regionId = draft.regionId,
		regionAddress = draft.regionAddress,
		generatorVersions = draft.generatorVersions,
		semanticIntentKey = draft.semanticIntentKey,
		topologyAnchorKeys = draft.topologyAnchorKeys,
		canonicalContentKeys = draft.canonicalContentKeys,
	})
end

local function clonePlainData(value: any, path: string, seen: { [any]: boolean }): any
	local valueType = type(value)
	if valueType == "nil" or valueType == "string" or valueType == "boolean" then
		return value
	elseif valueType == "number" then
		assert(isFinite(value), `{path} contains a non-finite number`)
		return value
	elseif valueType ~= "table" then
		error(`{path} contains non-plain data of type {valueType}`)
	end

	assert(getmetatable(value) == nil, `{path} must not have a metatable`)
	assert(not seen[value], `{path} must not contain cycles`)
	seen[value] = true
	local copy = {}
	for key, child in pairs(value) do
		local keyType = type(key)
		assert(keyType == "string" or keyType == "number", `{path} contains a non-plain table key`)
		if keyType == "number" then
			assert(isFinite(key), `{path} contains a non-finite numeric key`)
		end
		copy[key] = clonePlainData(child, `{path}.{tostring(key)}`, seen)
	end
	seen[value] = nil
	return copy
end

function ResolvedRegionRecipe.currentGeneratorVersions(): GeneratorVersions
	local current = RealityVersions.current()
	return copyVersions(current)
end

function ResolvedRegionRecipe.lock(draftValue: RecipeDraft): ResolvedRegionRecipe
	local draft = canonicalDraft(draftValue)
	return table.freeze({
		schemaVersion = ResolvedRegionRecipe.SCHEMA_VERSION,
		recipeId = recipeIdFor(draft),
		worldId = draft.worldId,
		worldSeedRef = draft.worldSeedRef,
		regionId = draft.regionId,
		regionAddress = draft.regionAddress,
		generatorVersions = draft.generatorVersions,
		semanticIntentKey = draft.semanticIntentKey,
		topologyAnchorKeys = draft.topologyAnchorKeys,
		canonicalContentKeys = draft.canonicalContentKeys,
	})
end

function ResolvedRegionRecipe.resolve(
	existingRecipe: ResolvedRegionRecipe?,
	draftValue: RecipeDraft
): (ResolvedRegionRecipe, boolean)
	if existingRecipe ~= nil then
		return canonicalRecipe(existingRecipe), false
	end
	return ResolvedRegionRecipe.lock(draftValue), true
end

function ResolvedRegionRecipe.serialize(recipeValue: ResolvedRegionRecipe): any
	local recipe = canonicalRecipe(recipeValue)
	return {
		schemaVersion = recipe.schemaVersion,
		recipeId = recipe.recipeId,
		worldId = recipe.worldId,
		worldSeedRef = recipe.worldSeedRef,
		regionId = recipe.regionId,
		regionAddress = recipe.regionAddress,
		generatorVersions = {
			reality = recipe.generatorVersions.reality,
			topology = recipe.generatorVersions.topology,
			material = recipe.generatorVersions.material,
			object = recipe.generatorVersions.object,
			entity = recipe.generatorVersions.entity,
		},
		semanticIntentKey = recipe.semanticIntentKey,
		topologyAnchorKeys = table.clone(recipe.topologyAnchorKeys),
		canonicalContentKeys = table.clone(recipe.canonicalContentKeys),
	}
end

function ResolvedRegionRecipe.reconstruct(
	serializedValue: any,
	migrationHook: MigrationHook?
): ResolvedRegionRecipe
	assert(type(serializedValue) == "table", "serialized recipe must be a plain table")
	assert(getmetatable(serializedValue) == nil, "serialized recipe must not have a metatable")
	local sourceVersion = checkedSchemaVersion("schemaVersion", rawget(serializedValue, "schemaVersion"))
	local candidate = serializedValue

	if sourceVersion ~= ResolvedRegionRecipe.SCHEMA_VERSION then
		assert(
			migrationHook ~= nil,
			`unsupported ResolvedRegionRecipe schema version {sourceVersion}; migration required`
		)
		local plainSource = clonePlainData(serializedValue, "serializedRecipe", {})
		candidate = (migrationHook :: MigrationHook)(
			sourceVersion,
			ResolvedRegionRecipe.SCHEMA_VERSION,
			plainSource
		)
	end

	return canonicalRecipe(candidate)
end

function ResolvedRegionRecipe.fingerprint(recipeValue: ResolvedRegionRecipe): string
	return canonicalRecipe(recipeValue).recipeId
end

function ResolvedRegionRecipe.equals(left: ResolvedRegionRecipe, right: ResolvedRegionRecipe): boolean
	return ResolvedRegionRecipe.fingerprint(left) == ResolvedRegionRecipe.fingerprint(right)
end

function ResolvedRegionRecipe.deltaBaseReference(recipeValue: ResolvedRegionRecipe): DeltaBaseReference
	local recipe = canonicalRecipe(recipeValue)
	return table.freeze({
		recipeId = recipe.recipeId,
		recipeSchemaVersion = recipe.schemaVersion,
	})
end

function ResolvedRegionRecipe.inspect(value: any): ValidationResult
	local ok, problem = pcall(function()
		canonicalRecipe(value)
	end)
	if ok then
		return table.freeze({ ok = true })
	end
	return table.freeze({
		ok = false,
		error = tostring(problem),
	})
end

return table.freeze(ResolvedRegionRecipe)
