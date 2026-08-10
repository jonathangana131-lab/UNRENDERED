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
	_records: { [WorldEntityId]: WorldEntityRecord },
	_duplicates: { DuplicateIdentityDiagnostic },
	_duplicateCapacity: number,
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

local function assertNonEmpty(name: string, value: string): ()
	assert(value ~= "", `{name} must not be empty`)
	assert(string.find(value, "%c") == nil, `{name} must not contain control characters`)
end

local function assertFiniteNumber(path: string, value: number): ()
	assert(value == value and value > -math.huge and value < math.huge, `{path} must be finite`)
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
	local stringKeyCount = 0
	local numericKeyCount = 0
	local maxNumericKey = 0

	for key, nested in pairs(source) do
		local keyType = type(key)
		if keyType == "string" then
			assert(key ~= "", `{path} contains an empty string key`)
			stringKeyCount += 1
		elseif keyType == "number" then
			local numericKey = key :: number
			assertFiniteNumber(`${path} key`, numericKey)
			assert(
				numericKey >= 1 and numericKey == math.floor(numericKey),
				`{path} numeric keys must be positive integers`
			)
			numericKeyCount += 1
			maxNumericKey = math.max(maxNumericKey, numericKey)
		else
			error(`{path} keys must be strings or positive integers, got {keyType}`)
		end
		copy[key] = clonePlainValue(nested, `{path}.{tostring(key)}`, seen)
	end

	assert(stringKeyCount == 0 or numericKeyCount == 0, `{path} tables cannot mix map and array keys`)
	if numericKeyCount > 0 then
		assert(numericKeyCount == maxNumericKey, `{path} arrays must use contiguous indices starting at 1`)
	end

	seen[source] = nil
	return table.freeze(copy)
end

local function cloneState(state: PlainData?): PlainData
	local source = state or {}
	for key in pairs(source) do
		assert(
			type(key) == "string" and key ~= "",
			"persistentState top-level keys must be non-empty strings"
		)
	end
	return clonePlainValue(source, "persistentState", {}) :: PlainData
end

local function cloneOrigin(origin: GenerationOrigin): GenerationOrigin
	assertNonEmpty("origin.worldId", origin.worldId)
	if origin.regionId ~= nil then
		assertNonEmpty("origin.regionId", origin.regionId)
	end
	assertNonEmpty("origin.generator", origin.generator)
	assertFiniteNumber("origin.generatorVersion", origin.generatorVersion)
	assert(
		origin.generatorVersion >= 1 and origin.generatorVersion == math.floor(origin.generatorVersion),
		"origin.generatorVersion must be a positive integer"
	)
	assertNonEmpty("origin.recipeKey", origin.recipeKey)

	return table.freeze({
		worldId = origin.worldId,
		regionId = origin.regionId,
		generator = origin.generator,
		generatorVersion = origin.generatorVersion,
		recipeKey = origin.recipeKey,
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

function WorldEntity.new(spec: NewWorldEntity): WorldEntityRecord
	assert(
		WorldEntity.isId(spec.id),
		"WorldEntity.id must be a non-empty stable identifier without control characters"
	)
	assertNonEmpty("WorldEntity.kind", spec.kind)
	local fidelity: Fidelity
	if spec.fidelity == nil then
		fidelity = "F0"
	else
		fidelity = spec.fidelity
	end
	assert(WorldEntity.isFidelity(fidelity), `invalid fidelity {tostring(fidelity)}`)

	return table.freeze({
		id = spec.id,
		kind = spec.kind,
		origin = cloneOrigin(spec.origin),
		fidelity = fidelity,
		persistentState = cloneState(spec.persistentState),
		stateRevision = 0,
		representationRevision = 0,
	})
end

function WorldEntity.captureState(record: WorldEntityRecord, capturedState: PlainData): WorldEntityRecord
	return cloneRecord(
		record,
		record.fidelity,
		cloneState(capturedState),
		record.stateRevision + 1,
		record.representationRevision
	)
end

function WorldEntity.transition(
	record: WorldEntityRecord,
	target: Fidelity,
	capturedState: PlainData?
): WorldEntityRecord
	assert(WorldEntity.isFidelity(target), `invalid fidelity {tostring(target)}`)
	if target == record.fidelity then
		if capturedState == nil then
			return record
		end
		return WorldEntity.captureState(record, capturedState)
	end

	local currentRank = WorldEntity.fidelityRank(record.fidelity)
	local targetRank = WorldEntity.fidelityRank(target)
	local nextState = record.persistentState
	local nextStateRevision = record.stateRevision

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

	return cloneRecord(record, target, nextState, nextStateRevision, record.representationRevision + 1)
end

function WorldEntity.createRegistry(duplicateDiagnosticCapacity: number?): Registry
	local capacity = duplicateDiagnosticCapacity or WorldEntity.DEFAULT_DUPLICATE_DIAGNOSTIC_CAPACITY
	assertFiniteNumber("duplicateDiagnosticCapacity", capacity)
	assert(
		capacity >= 0 and capacity == math.floor(capacity),
		"duplicateDiagnosticCapacity must be a non-negative integer"
	)

	return table.freeze({
		_records = {},
		_duplicates = {},
		_duplicateCapacity = capacity,
	}) :: Registry
end

function WorldEntity.register(
	registry: Registry,
	record: WorldEntityRecord
): (boolean, DuplicateIdentityDiagnostic?)
	local existing = registry._records[record.id]
	if existing ~= nil then
		local diagnostic = table.freeze({
			entityId = record.id,
			existingKind = existing.kind,
			incomingKind = record.kind,
			existingRecipeKey = existing.origin.recipeKey,
			incomingRecipeKey = record.origin.recipeKey,
		})
		if registry._duplicateCapacity > 0 then
			if #registry._duplicates >= registry._duplicateCapacity then
				table.remove(registry._duplicates, 1)
			end
			table.insert(registry._duplicates, diagnostic)
		end
		return false, diagnostic
	end

	registry._records[record.id] = record
	return true, nil
end

function WorldEntity.get(registry: Registry, entityId: WorldEntityId): WorldEntityRecord?
	return registry._records[entityId]
end

function WorldEntity.unregister(registry: Registry, entityId: WorldEntityId): WorldEntityRecord?
	local existing = registry._records[entityId]
	registry._records[entityId] = nil
	return existing
end

function WorldEntity.count(registry: Registry): number
	local count = 0
	for _ in pairs(registry._records) do
		count += 1
	end
	return count
end

function WorldEntity.duplicateDiagnostics(registry: Registry): { DuplicateIdentityDiagnostic }
	return table.clone(registry._duplicates)
end

return table.freeze(WorldEntity)
