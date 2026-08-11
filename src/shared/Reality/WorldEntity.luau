--!strict

local WorldEntity = {}

export type WorldEntityId = string
export type Fidelity = "F0" | "F1" | "F2" | "F3" | "F4"
export type PlainData = { [string]: unknown }

export type GenerationOrigin = {
	worldId: string,
	regionId: string?,
	generator: string,
	generatorVersion: number,
	recipeKey: string,
}

export type WorldEntityRecord = {
	id: WorldEntityId,
	kind: string,
	origin: GenerationOrigin,
	fidelity: Fidelity,
	persistentState: PlainData,
	stateRevision: number,
	representationRevision: number,
}

export type NewWorldEntity = {
	id: WorldEntityId,
	kind: string,
	origin: GenerationOrigin,
	fidelity: Fidelity?,
	persistentState: PlainData?,
}

export type DuplicateIdentityDiagnostic = {
	entityId: WorldEntityId,
	existingKind: string,
	incomingKind: string,
	existingRecipeKey: string,
	incomingRecipeKey: string,
}

export type Registry = {
	register: (WorldEntityRecord) -> (boolean, DuplicateIdentityDiagnostic?),
	get: (WorldEntityId) -> WorldEntityRecord?,
	captureRegistered: (WorldEntityId, PlainData) -> WorldEntityRecord,
	transitionRegistered: (WorldEntityId, Fidelity, PlainData?) -> WorldEntityRecord,
	unregister: (WorldEntityId) -> WorldEntityRecord?,
	count: () -> number,
	duplicateDiagnostics: () -> { DuplicateIdentityDiagnostic },
}

WorldEntity.Fidelity = table.freeze({
	F0 = "F0",
	F1 = "F1",
	F2 = "F2",
	F3 = "F3",
	F4 = "F4",
})

WorldEntity.DEFAULT_DUPLICATE_DIAGNOSTIC_CAPACITY = 64

local FIDELITY_RANK: { [string]: number } = table.freeze({
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
})

local NEW_ENTITY_KEYS: { [string]: boolean } = table.freeze({
	id = true,
	kind = true,
	origin = true,
	fidelity = true,
	persistentState = true,
})

local RECORD_KEYS: { [string]: boolean } = table.freeze({
	id = true,
	kind = true,
	origin = true,
	fidelity = true,
	persistentState = true,
	stateRevision = true,
	representationRevision = true,
})

local ORIGIN_KEYS: { [string]: boolean } = table.freeze({
	worldId = true,
	regionId = true,
	generator = true,
	generatorVersion = true,
	recipeKey = true,
})

local function assertNonEmpty(name: string, value: string): ()
	assert(value ~= "", `{name} must not be empty`)
	assert(string.find(value, "%c") == nil, `{name} must not contain control characters`)
end

local function checkedNonEmpty(name: string, value: unknown): string
	assert(type(value) == "string", `{name} must be a string`)
	local stringValue = value :: string
	assertNonEmpty(name, stringValue)
	return stringValue
end

local function assertFiniteNumber(path: string, value: number): ()
	assert(value == value and value > -math.huge and value < math.huge, `{path} must be finite`)
end

local function checkedFiniteNumber(path: string, value: unknown): number
	assert(type(value) == "number", `{path} must be a number`)
	local numericValue = value :: number
	assertFiniteNumber(path, numericValue)
	return numericValue
end

local function assertNonNegativeInteger(path: string, value: unknown): number
	assert(type(value) == "number", `{path} must be a number`)
	local numericValue = value :: number
	assertFiniteNumber(path, numericValue)
	assert(
		numericValue >= 0 and numericValue == math.floor(numericValue),
		`{path} must be a non-negative integer`
	)
	return numericValue
end

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

local function clonePlainValue(value: unknown, path: string, seen: { [any]: boolean }): unknown
	local valueType = type(value)
	if valueType == "nil" or valueType == "boolean" or valueType == "string" then
		return value
	elseif valueType == "number" then
		assertFiniteNumber(path, value :: number)
		return value
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
		elseif keyType == "number" then
			hasNumericKeys = true
			local numericKey = key :: number
			assertFiniteNumber(`${path} key`, numericKey)
			assert(
				numericKey >= 1 and numericKey == math.floor(numericKey),
				`{path} numeric keys must be positive integers`
			)
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

local function cloneState(state: PlainData?): PlainData
	local source: any = state
	if source == nil then
		source = {}
	end
	assert(type(source) == "table", "persistentState must be a table")
	assert(getmetatable(source) == nil, "persistentState must not contain metatables")
	for key in pairs(source) do
		assert(
			type(key) == "string" and key ~= "",
			"persistentState top-level keys must be non-empty strings"
		)
	end
	return clonePlainValue(source, "persistentState", {}) :: PlainData
end

local function cloneOrigin(origin: GenerationOrigin): GenerationOrigin
	local source = assertExactRecordShape(origin, ORIGIN_KEYS, "origin")
	local worldId = checkedNonEmpty("origin.worldId", source.worldId)
	local regionId: string? = nil
	if source.regionId ~= nil then
		regionId = checkedNonEmpty("origin.regionId", source.regionId)
	end
	local generator = checkedNonEmpty("origin.generator", source.generator)
	local generatorVersion = checkedFiniteNumber("origin.generatorVersion", source.generatorVersion)
	assert(
		generatorVersion >= 1 and generatorVersion == math.floor(generatorVersion),
		"origin.generatorVersion must be a positive integer"
	)
	local recipeKey = checkedNonEmpty("origin.recipeKey", source.recipeKey)

	return table.freeze({
		worldId = worldId,
		regionId = regionId,
		generator = generator,
		generatorVersion = generatorVersion,
		recipeKey = recipeKey,
	})
end

local function cloneRecord(
	record: WorldEntityRecord,
	fidelity: Fidelity,
	persistentState: PlainData,
	stateRevision: number,
	representationRevision: number
): WorldEntityRecord
	return table.freeze({
		id = record.id,
		kind = record.kind,
		origin = record.origin,
		fidelity = fidelity,
		persistentState = persistentState,
		stateRevision = stateRevision,
		representationRevision = representationRevision,
	})
end

function WorldEntity.isId(value: unknown): boolean
	return type(value) == "string" and value ~= "" and #value <= 256 and string.find(value, "%c") == nil
end

function WorldEntity.isFidelity(value: unknown): boolean
	return type(value) == "string" and FIDELITY_RANK[value] ~= nil
end

function WorldEntity.fidelityRank(fidelity: Fidelity): number
	local rank = FIDELITY_RANK[fidelity]
	assert(rank ~= nil, `invalid fidelity {tostring(fidelity)}`)
	return rank
end

local function ownRecord(record: WorldEntityRecord): WorldEntityRecord
	local source = assertExactRecordShape(record, RECORD_KEYS, "WorldEntityRecord")
	assert(
		WorldEntity.isId(source.id),
		"WorldEntityRecord.id must be a non-empty stable identifier without control characters"
	)
	local kind = checkedNonEmpty("WorldEntityRecord.kind", source.kind)
	assert(type(source.origin) == "table", "WorldEntityRecord.origin must be a table")
	assert(WorldEntity.isFidelity(source.fidelity), `invalid fidelity {tostring(source.fidelity)}`)
	assert(type(source.persistentState) == "table", "WorldEntityRecord.persistentState must be a table")

	local stateRevision = assertNonNegativeInteger("WorldEntityRecord.stateRevision", source.stateRevision)
	local representationRevision =
		assertNonNegativeInteger("WorldEntityRecord.representationRevision", source.representationRevision)

	return table.freeze({
		id = source.id,
		kind = kind,
		origin = cloneOrigin(source.origin :: GenerationOrigin),
		fidelity = source.fidelity :: Fidelity,
		persistentState = cloneState(source.persistentState :: PlainData),
		stateRevision = stateRevision,
		representationRevision = representationRevision,
	})
end

function WorldEntity.new(spec: NewWorldEntity): WorldEntityRecord
	local source = assertExactRecordShape(spec, NEW_ENTITY_KEYS, "NewWorldEntity")
	assert(
		WorldEntity.isId(source.id),
		"WorldEntity.id must be a non-empty stable identifier without control characters"
	)
	local kind = checkedNonEmpty("WorldEntity.kind", source.kind)
	assert(type(source.origin) == "table", "WorldEntity.origin must be a table")
	local origin = cloneOrigin(source.origin :: GenerationOrigin)

	local fidelity: Fidelity
	if source.fidelity == nil then
		fidelity = "F0"
	else
		assert(WorldEntity.isFidelity(source.fidelity), `invalid fidelity {tostring(source.fidelity)}`)
		fidelity = source.fidelity :: Fidelity
	end

	local persistentState: PlainData? = nil
	if source.persistentState ~= nil then
		assert(type(source.persistentState) == "table", "WorldEntity.persistentState must be a table")
		persistentState = source.persistentState :: PlainData
	end

	return table.freeze({
		id = source.id,
		kind = kind,
		origin = origin,
		fidelity = fidelity,
		persistentState = cloneState(persistentState),
		stateRevision = 0,
		representationRevision = 0,
	})
end

function WorldEntity.captureState(record: WorldEntityRecord, capturedState: PlainData): WorldEntityRecord
	local ownedRecord = ownRecord(record)
	return cloneRecord(
		ownedRecord,
		ownedRecord.fidelity,
		cloneState(capturedState),
		ownedRecord.stateRevision + 1,
		ownedRecord.representationRevision
	)
end

function WorldEntity.transition(
	record: WorldEntityRecord,
	target: Fidelity,
	capturedState: PlainData?
): WorldEntityRecord
	local ownedRecord = ownRecord(record)
	assert(WorldEntity.isFidelity(target), `invalid fidelity {tostring(target)}`)
	if target == ownedRecord.fidelity then
		if capturedState == nil then
			return ownedRecord
		end
		return WorldEntity.captureState(ownedRecord, capturedState)
	end

	local currentRank = WorldEntity.fidelityRank(ownedRecord.fidelity)
	local targetRank = WorldEntity.fidelityRank(target)
	local nextState = ownedRecord.persistentState
	local nextStateRevision = ownedRecord.stateRevision

	if targetRank < currentRank then
		assert(
			capturedState ~= nil,
			"demotion requires captured persistent state before representation teardown"
		)
		nextState = cloneState(capturedState)
		nextStateRevision += 1
	else
		assert(
			capturedState == nil,
			"promotion consumes the already-captured persistent state; do not pass capturedState"
		)
	end

	return cloneRecord(
		ownedRecord,
		target,
		nextState,
		nextStateRevision,
		ownedRecord.representationRevision + 1
	)
end

function WorldEntity.createRegistry(duplicateDiagnosticCapacity: number?): Registry
	local capacity = duplicateDiagnosticCapacity or WorldEntity.DEFAULT_DUPLICATE_DIAGNOSTIC_CAPACITY
	assertFiniteNumber("duplicateDiagnosticCapacity", capacity)
	assert(
		capacity >= 0 and capacity == math.floor(capacity),
		"duplicateDiagnosticCapacity must be a non-negative integer"
	)

	local records: { [WorldEntityId]: WorldEntityRecord } = {}
	local duplicates: { DuplicateIdentityDiagnostic } = {}

	local function getRegistered(entityId: WorldEntityId): WorldEntityRecord
		local record = records[entityId]
		assert(record ~= nil, `unknown WorldEntityId: {entityId}`)
		return record
	end

	local function register(record: WorldEntityRecord): (boolean, DuplicateIdentityDiagnostic?)
		local ownedRecord = ownRecord(record)
		local existing = records[ownedRecord.id]
		if existing ~= nil then
			local diagnostic = table.freeze({
				entityId = ownedRecord.id,
				existingKind = existing.kind,
				incomingKind = ownedRecord.kind,
				existingRecipeKey = existing.origin.recipeKey,
				incomingRecipeKey = ownedRecord.origin.recipeKey,
			})
			if capacity > 0 then
				if #duplicates >= capacity then
					table.remove(duplicates, 1)
				end
				table.insert(duplicates, diagnostic)
			end
			return false, diagnostic
		end

		records[ownedRecord.id] = ownedRecord
		return true, nil
	end

	local function get(entityId: WorldEntityId): WorldEntityRecord?
		return records[entityId]
	end

	local function captureRegistered(entityId: WorldEntityId, capturedState: PlainData): WorldEntityRecord
		local nextRecord = WorldEntity.captureState(getRegistered(entityId), capturedState)
		records[entityId] = nextRecord
		return nextRecord
	end

	local function transitionRegistered(
		entityId: WorldEntityId,
		target: Fidelity,
		capturedState: PlainData?
	): WorldEntityRecord
		local nextRecord = WorldEntity.transition(getRegistered(entityId), target, capturedState)
		records[entityId] = nextRecord
		return nextRecord
	end

	local function unregister(entityId: WorldEntityId): WorldEntityRecord?
		local existing = records[entityId]
		records[entityId] = nil
		return existing
	end

	local function count(): number
		local total = 0
		for _ in pairs(records) do
			total += 1
		end
		return total
	end

	local function duplicateDiagnostics(): { DuplicateIdentityDiagnostic }
		return table.clone(duplicates)
	end

	return table.freeze({
		register = register,
		get = get,
		captureRegistered = captureRegistered,
		transitionRegistered = transitionRegistered,
		unregister = unregister,
		count = count,
		duplicateDiagnostics = duplicateDiagnostics,
	})
end

function WorldEntity.register(
	registry: Registry,
	record: WorldEntityRecord
): (boolean, DuplicateIdentityDiagnostic?)
	return registry.register(record)
end

function WorldEntity.get(registry: Registry, entityId: WorldEntityId): WorldEntityRecord?
	return registry.get(entityId)
end

function WorldEntity.captureRegistered(
	registry: Registry,
	entityId: WorldEntityId,
	capturedState: PlainData
): WorldEntityRecord
	return registry.captureRegistered(entityId, capturedState)
end

function WorldEntity.transitionRegistered(
	registry: Registry,
	entityId: WorldEntityId,
	target: Fidelity,
	capturedState: PlainData?
): WorldEntityRecord
	return registry.transitionRegistered(entityId, target, capturedState)
end

function WorldEntity.unregister(registry: Registry, entityId: WorldEntityId): WorldEntityRecord?
	return registry.unregister(entityId)
end

function WorldEntity.count(registry: Registry): number
	return registry.count()
end

function WorldEntity.duplicateDiagnostics(registry: Registry): { DuplicateIdentityDiagnostic }
	return registry.duplicateDiagnostics()
end

return table.freeze(WorldEntity)
