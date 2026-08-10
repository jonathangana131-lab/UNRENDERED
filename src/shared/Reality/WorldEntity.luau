--!strict

local WorldEntity = {}

export type WorldEntityId = string
export type Fidelity = "F0" | "F1" | "F2" | "F3" | "F4"

export type GenerationOrigin = {
	worldId: string,
	regionId: string?,
	generator: string,
	generatorVersion: number,
	localKey: string?,
}

export type PersistentState = { [string]: any }

export type WorldEntityRecord = {
	id: WorldEntityId,
	kind: string,
	origin: GenerationOrigin,
	fidelity: Fidelity,
	persistentState: PersistentState,
	lifecycleRevision: number,
}

export type WorldEntitySpec = {
	id: WorldEntityId,
	kind: string,
	origin: GenerationOrigin,
	fidelity: Fidelity?,
	persistentState: PersistentState?,
}

export type Registry = {
	entities: { [WorldEntityId]: WorldEntityRecord },
}

WorldEntity.Fidelity = table.freeze({
	F0 = "F0" :: Fidelity,
	F1 = "F1" :: Fidelity,
	F2 = "F2" :: Fidelity,
	F3 = "F3" :: Fidelity,
	F4 = "F4" :: Fidelity,
})

local FIDELITY_RANK: { [Fidelity]: number } = {
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
}

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function clonePlain(value: any, seen: { [any]: boolean }): any
	local valueType = typeof(value)
	if valueType == "nil" or valueType == "boolean" or valueType == "string" then
		return value
	end
	if valueType == "number" then
		assert(isFiniteNumber(value), "persistent state numbers must be finite")
		return value
	end
	assert(valueType == "table", `persistent state must be plain data, got {valueType}`)
	assert(getmetatable(value) == nil, "persistent state tables must not have metatables")
	assert(not seen[value], "persistent state must not contain cycles")
	seen[value] = true

	local copy = {}
	local stringKeyCount = 0
	local numericKeyCount = 0
	local maxNumericKey = 0

	for key, child in pairs(value) do
		local keyType = typeof(key)
		if keyType == "string" then
			stringKeyCount += 1
		elseif keyType == "number" then
			assert(isFiniteNumber(key), "persistent state numeric keys must be finite")
			assert(key >= 1 and key % 1 == 0, "persistent state numeric keys must be positive integers")
			numericKeyCount += 1
			maxNumericKey = math.max(maxNumericKey, key)
		else
			error(`persistent state keys must be strings or array indices, got {keyType}`)
		end
		copy[key] = clonePlain(child, seen)
	end

	assert(stringKeyCount == 0 or numericKeyCount == 0, "persistent state tables cannot mix map and array keys")
	if numericKeyCount > 0 then
		assert(numericKeyCount == maxNumericKey, "persistent state arrays must be contiguous")
	end

	seen[value] = nil
	return copy
end

local function freezePlain(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	for _, child in pairs(value) do
		if typeof(child) == "table" then
			freezePlain(child)
		end
	end

	return table.freeze(value)
end

local function cloneMutableState(state: PersistentState): PersistentState
	return clonePlain(state, {}) :: PersistentState
end

local function cloneState(state: PersistentState): PersistentState
	return freezePlain(cloneMutableState(state)) :: PersistentState
end

local function cloneOrigin(origin: GenerationOrigin): GenerationOrigin
	return {
		worldId = origin.worldId,
		regionId = origin.regionId,
		generator = origin.generator,
		generatorVersion = origin.generatorVersion,
		localKey = origin.localKey,
	}
end

local function validateOrigin(origin: GenerationOrigin)
	assert(origin.worldId ~= "", "origin.worldId must not be empty")
	assert(origin.generator ~= "", "origin.generator must not be empty")
	assert(
		origin.generatorVersion >= 1 and origin.generatorVersion % 1 == 0,
		"origin.generatorVersion must be a positive integer"
	)
	if origin.regionId ~= nil then
		assert(origin.regionId ~= "", "origin.regionId must not be empty when provided")
	end
	if origin.localKey ~= nil then
		assert(origin.localKey ~= "", "origin.localKey must not be empty when provided")
	end
end

function WorldEntity.isFidelity(value: unknown): boolean
	return type(value) == "string" and FIDELITY_RANK[value :: Fidelity] ~= nil
end

function WorldEntity.fidelityRank(fidelity: Fidelity): number
	local rank = FIDELITY_RANK[fidelity]
	assert(rank ~= nil, `invalid fidelity {fidelity}`)
	return rank
end

function WorldEntity.isDemotion(from: Fidelity, to: Fidelity): boolean
	return WorldEntity.fidelityRank(to) < WorldEntity.fidelityRank(from)
end

function WorldEntity.validatePersistentState(state: PersistentState): boolean
	local ok = pcall(function()
		cloneMutableState(state)
	end)
	return ok
end

function WorldEntity.new(spec: WorldEntitySpec): WorldEntityRecord
	assert(spec.id ~= "", "WorldEntityId must not be empty")
	assert(spec.kind ~= "", "entity kind must not be empty")
	validateOrigin(spec.origin)

	local fidelity = spec.fidelity or "F0"
	assert(WorldEntity.isFidelity(fidelity), `invalid fidelity {fidelity}`)
	local persistentState = cloneState(spec.persistentState or {})

	return table.freeze({
		id = spec.id,
		kind = spec.kind,
		origin = table.freeze(cloneOrigin(spec.origin)),
		fidelity = fidelity :: Fidelity,
		persistentState = persistentState,
		lifecycleRevision = 0,
	})
end

local function mergeState(base: PersistentState, patch: PersistentState?): PersistentState
	local merged = cloneMutableState(base)
	if patch ~= nil then
		local cleanPatch = cloneMutableState(patch)
		for key, value in pairs(cleanPatch) do
			merged[key] = value
		end
	end
	return freezePlain(merged) :: PersistentState
end

function WorldEntity.transition(
	entity: WorldEntityRecord,
	target: Fidelity,
	capturedState: PersistentState?
): WorldEntityRecord
	assert(WorldEntity.isFidelity(target), `invalid fidelity {target}`)
	if target == entity.fidelity then
		return entity
	end

	if WorldEntity.isDemotion(entity.fidelity, target) then
		assert(capturedState ~= nil, "demotion requires an explicit persistent-state capture, even when empty")
	end

	return table.freeze({
		id = entity.id,
		kind = entity.kind,
		origin = entity.origin,
		fidelity = target,
		persistentState = mergeState(entity.persistentState, capturedState),
		lifecycleRevision = entity.lifecycleRevision + 1,
	})
end

function WorldEntity.newRegistry(): Registry
	return {
		entities = {},
	}
end

function WorldEntity.register(registry: Registry, entity: WorldEntityRecord)
	assert(registry.entities[entity.id] == nil, `duplicate WorldEntityId: {entity.id}`)
	registry.entities[entity.id] = entity
end

function WorldEntity.get(registry: Registry, id: WorldEntityId): WorldEntityRecord?
	return registry.entities[id]
end

function WorldEntity.unregister(registry: Registry, id: WorldEntityId): WorldEntityRecord?
	local existing = registry.entities[id]
	registry.entities[id] = nil
	return existing
end

function WorldEntity.transitionRegistered(
	registry: Registry,
	id: WorldEntityId,
	target: Fidelity,
	capturedState: PersistentState?
): WorldEntityRecord
	local existing = registry.entities[id]
	assert(existing ~= nil, `unknown WorldEntityId: {id}`)
	local nextEntity = WorldEntity.transition(existing, target, capturedState)
	registry.entities[id] = nextEntity
	return nextEntity
end

return table.freeze(WorldEntity)
