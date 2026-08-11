--!strict

local FidelityManager = require(script.Parent.FidelityManager)
local PhysicsLabRecipe = require(script.Parent.PhysicsLabRecipe)
local WorldEntity = require(script.Parent.Parent.Reality.WorldEntity)

local PhysicsLabRuntime = {}
PhysicsLabRuntime.__index = PhysicsLabRuntime

export type FidelityLevel = FidelityManager.FidelityLevel
export type PolicyInputs = FidelityManager.PolicyInputs
export type PolicyReason = FidelityManager.PolicyReason
export type StepResult = FidelityManager.StepResult
export type PlainData = WorldEntity.PlainData
export type WorldEntityRecord = WorldEntity.WorldEntityRecord

type Manager = FidelityManager.Manager
type Metrics = FidelityManager.Metrics
type Registry = WorldEntity.Registry
type Recipe = PhysicsLabRecipe.PhysicsLabRecipe

export type CaptureState = (WorldEntityRecord) -> PlainData
export type TransitionObserver = (WorldEntityRecord, WorldEntityRecord, PolicyReason) -> ()

export type Snapshot = {
	recipeKey: string,
	registered: number,
	fidelity: Metrics,
	duplicateIdentities: number,
}

type RuntimeImpl = {
	recipeKey: string,
}

export type Runtime = typeof(setmetatable({} :: RuntimeImpl, PhysicsLabRuntime))

type RuntimeState = {
	entityIds: { string },
	registry: Registry,
	fidelity: Manager,
	disposed: boolean,
	transitionInFlight: boolean,
}

local runtimeStates: { [Runtime]: RuntimeState } = {}
setmetatable(runtimeStates, { __mode = "k" })

local CANONICAL_RECIPE = PhysicsLabRecipe.build()
local CANONICAL_ENTITIES_BY_KEY: { [string]: PhysicsLabRecipe.EntityRecipe } = {}
for _, entityRecipe in ipairs(CANONICAL_RECIPE.entities) do
	CANONICAL_ENTITIES_BY_KEY[entityRecipe.key] = entityRecipe
end
table.freeze(CANONICAL_ENTITIES_BY_KEY)

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

local function stateFor(self: Runtime): RuntimeState
	local state = runtimeStates[self]
	assert(state ~= nil, "PhysicsLabRuntime state is unavailable")
	return state
end

local function assertActive(self: Runtime): RuntimeState
	local state = stateFor(self)
	assert(not state.disposed, "PhysicsLabRuntime is disposed")
	return state
end

local function assertEntityId(value: unknown): string
	assert(WorldEntity.isId(value), "entityId must satisfy the WorldEntityId value contract")
	return value :: string
end

local function assertMutationAllowed(state: RuntimeState): ()
	assert(
		not state.transitionInFlight,
		"PhysicsLabRuntime transition callback must not reenter runtime mutation"
	)
end

local function assertPlainTable(value: unknown, message: string): any
	assert(type(value) == "table", message)
	local tableValue = value :: any
	assert(getmetatable(tableValue) == nil, message)
	return tableValue
end

local function assertExactStringKeys(value: any, allowedKeys: { [string]: boolean }, message: string): ()
	for key in pairs(value) do
		assert(type(key) == "string", message)
		assert(allowedKeys[key] == true, message)
	end
end

local function plainValuesEqual(canonical: unknown, candidate: unknown, seen: { [any]: boolean }): boolean
	if type(canonical) ~= type(candidate) then
		return false
	end
	if type(canonical) ~= "table" then
		return canonical == candidate
	end

	local canonicalTable = canonical :: any
	local candidateTable = candidate :: any
	if getmetatable(candidateTable) ~= nil or seen[candidateTable] then
		return false
	end
	seen[candidateTable] = true

	local canonicalCount = 0
	for key, canonicalValue in pairs(canonicalTable) do
		canonicalCount += 1
		if not plainValuesEqual(canonicalValue, candidateTable[key], seen) then
			seen[candidateTable] = nil
			return false
		end
	end

	local candidateCount = 0
	for _ in pairs(candidateTable) do
		candidateCount += 1
		if candidateCount > canonicalCount then
			seen[candidateTable] = nil
			return false
		end
	end
	seen[candidateTable] = nil
	return candidateCount == canonicalCount
end

local function assertCanonicalRecipe(recipe: Recipe): ()
	local recipeTable = assertPlainTable(recipe, "Physics Lab runtime recipe must be a plain table")
	assert(
		recipeTable.schemaVersion == PhysicsLabRecipe.SCHEMA_VERSION,
		"unsupported Physics Lab recipe schema"
	)
	assert(recipeTable.recipeKey == PhysicsLabRecipe.RECIPE_KEY, "unexpected Physics Lab recipe key")
	assert(recipeTable.worldId == CANONICAL_RECIPE.worldId, "unexpected Physics Lab WorldId")
	assert(recipeTable.regionId == CANONICAL_RECIPE.regionId, "unexpected Physics Lab RegionId")

	local entities =
		assertPlainTable(recipeTable.entities, "Physics Lab runtime recipe entities must be a plain table")
	assert(
		#entities == #CANONICAL_RECIPE.entities,
		"Physics Lab runtime requires the complete canonical entity population"
	)

	local seenKeys: { [string]: boolean } = {}
	local seenCount = 0
	for _, rawEntityRecipe in ipairs(entities) do
		seenCount += 1
		local entityRecipe =
			assertPlainTable(rawEntityRecipe, "Physics Lab runtime entity recipe must be a plain table")
		local entityKey = entityRecipe.key
		assert(type(entityKey) == "string", "Physics Lab recipe entity key must be a string")

		local canonical = CANONICAL_ENTITIES_BY_KEY[entityKey]
		assert(canonical ~= nil, `unknown Physics Lab recipe entity key: {entityKey}`)
		assert(not seenKeys[entityKey], `duplicate Physics Lab recipe entity key: {entityKey}`)
		seenKeys[entityKey] = true

		local record = assertPlainTable(
			entityRecipe.entity,
			`Physics Lab recipe entity record must be a plain table: {entityKey}`
		)
		assertExactStringKeys(
			record,
			RECORD_KEYS,
			`Physics Lab recipe entity record has invalid schema: {entityKey}`
		)
		local origin = assertPlainTable(
			record.origin,
			`Physics Lab recipe entity origin must be a plain table: {entityKey}`
		)
		assertExactStringKeys(
			origin,
			ORIGIN_KEYS,
			`Physics Lab recipe entity origin has invalid schema: {entityKey}`
		)
		local canonicalRecord = canonical.entity
		assert(record.id == canonicalRecord.id, `Physics Lab recipe key/id mismatch: {entityKey}`)
		assert(record.kind == canonicalRecord.kind, `Physics Lab recipe entity kind mismatch: {entityKey}`)
		assert(
			record.fidelity == canonicalRecord.fidelity,
			`Physics Lab recipe initial fidelity mismatch: {entityKey}`
		)
		assert(
			record.stateRevision == canonicalRecord.stateRevision,
			`Physics Lab recipe state revision mismatch: {entityKey}`
		)
		assert(
			record.representationRevision == canonicalRecord.representationRevision,
			`Physics Lab recipe representation revision mismatch: {entityKey}`
		)
		assert(
			plainValuesEqual(canonicalRecord.persistentState, record.persistentState, {}),
			`Physics Lab recipe initial persistent state mismatch: {entityKey}`
		)
		assert(origin.worldId == recipeTable.worldId, `Physics Lab entity WorldId mismatch: {entityKey}`)
		assert(origin.regionId == recipeTable.regionId, `Physics Lab entity RegionId mismatch: {entityKey}`)
		assert(
			origin.generator == canonicalRecord.origin.generator,
			`Physics Lab entity generator mismatch: {entityKey}`
		)
		assert(
			origin.generatorVersion == canonicalRecord.origin.generatorVersion,
			`Physics Lab entity generator version mismatch: {entityKey}`
		)
		assert(
			origin.recipeKey == canonicalRecord.origin.recipeKey,
			`Physics Lab entity recipe provenance mismatch: {entityKey}`
		)
	end
	assert(
		seenCount == #CANONICAL_RECIPE.entities,
		"Physics Lab runtime requires a dense complete canonical entity population"
	)
end

local function boundedFidelityManager(entityCount: number): Manager
	local config = table.clone(FidelityManager.defaultConfig())
	config.maxRegisteredEntities = math.max(1, entityCount)
	return FidelityManager.new(config)
end

function PhysicsLabRuntime.new(recipe: Recipe): Runtime
	assertCanonicalRecipe(recipe)

	local registry = WorldEntity.createRegistry()
	local fidelity = boundedFidelityManager(#recipe.entities)
	local entityIds: { string } = {}

	for _, entityRecipe in ipairs(recipe.entities) do
		local record = entityRecipe.entity
		local registered, duplicate = registry.register(record)
		assert(
			registered,
			`duplicate Physics Lab WorldEntityId: {duplicate and duplicate.entityId or record.id}`
		)
		fidelity:register(record.id, record.fidelity)
		table.insert(entityIds, record.id)
	end

	local runtime = setmetatable(
		{
			recipeKey = recipe.recipeKey,
		} :: RuntimeImpl,
		PhysicsLabRuntime
	)
	runtimeStates[runtime] = {
		entityIds = entityIds,
		registry = registry,
		fidelity = fidelity,
		disposed = false,
		transitionInFlight = false,
	}
	return table.freeze(runtime)
end

function PhysicsLabRuntime.getRecord(self: Runtime, entityId: string): WorldEntityRecord
	local state = assertActive(self)
	local checkedEntityId = assertEntityId(entityId)
	local record = state.registry.get(checkedEntityId)
	assert(record ~= nil, `unknown Physics Lab WorldEntityId: {checkedEntityId}`)
	return record
end

function PhysicsLabRuntime.getFidelity(self: Runtime, entityId: string): FidelityLevel
	local state = assertActive(self)
	local record = PhysicsLabRuntime.getRecord(self, entityId)
	local observed = state.fidelity:getObservedLevel(entityId)
	assert(observed == record.fidelity, `Physics Lab fidelity authority diverged for {entityId}`)
	return observed
end

function PhysicsLabRuntime.step(
	self: Runtime,
	entityId: string,
	inputs: PolicyInputs,
	nowSeconds: number,
	captureState: CaptureState?,
	observeTransition: TransitionObserver?
): (StepResult, WorldEntityRecord)
	local state = assertActive(self)
	assertMutationAllowed(state)
	local current = PhysicsLabRuntime.getRecord(self, entityId)
	assert(
		state.fidelity:getObservedLevel(entityId) == current.fidelity,
		`Physics Lab fidelity authority diverged before step for {entityId}`
	)

	local transitionHook: FidelityManager.TransitionHook? = nil
	local observer = observeTransition
	if observer ~= nil then
		transitionHook = function(
			transitionEntityId: string,
			fromLevel: FidelityLevel,
			toLevel: FidelityLevel,
			reason: PolicyReason
		): ()
			assert(state.transitionInFlight, "PhysicsLabRuntime transition callback escaped step transaction")
			assert(
				transitionEntityId == entityId,
				"FidelityManager transitioned the wrong Physics Lab entity"
			)
			assert(fromLevel == current.fidelity, "Physics Lab transition source fidelity drifted")

			local capturedState: PlainData? = nil
			if WorldEntity.fidelityRank(toLevel) < WorldEntity.fidelityRank(fromLevel) then
				assert(captureState ~= nil, "Physics Lab demotion requires a state-capture adapter")
				capturedState = captureState(current)
			end

			-- Preview first so representation adapters can reject a transition before
			-- either authoritative store commits it. Demotion state has already been
			-- captured at this point; promotion receives the incumbent stored state.
			local preview = WorldEntity.transition(current, toLevel, capturedState)
			observer(current, preview, reason)

			-- WorldEntity.transition owns a frozen plain-data snapshot. Commit that exact
			-- snapshot rather than the adapter-owned capture table: an observer may share
			-- the adapter buffer and mutate it after inspecting the preview, which must not
			-- make the authoritative commit differ from the representation-approved state.
			local committedState: PlainData? = nil
			if capturedState ~= nil then
				committedState = preview.persistentState
			end

			local committed = state.registry.transitionRegistered(entityId, toLevel, committedState)
			assert(committed.fidelity == preview.fidelity, "Physics Lab transition commit fidelity mismatch")
			assert(
				committed.stateRevision == preview.stateRevision,
				"Physics Lab transition commit state mismatch"
			)
			assert(
				committed.representationRevision == preview.representationRevision,
				"Physics Lab transition commit representation mismatch"
			)
		end
	end

	-- Fence runtime mutation for the entire manager step, not just the eventual
	-- representation callback. Policy inputs and time are caller-owned values;
	-- hostile metatables/operators must not get a pre-hook window in which they
	-- can dispose or recursively step this runtime before FidelityManager rejects.
	state.transitionInFlight = true
	local stepSucceeded, resultOrError = pcall(function(): StepResult
		-- Preserve FidelityManager's production fail-closed contract: when no
		-- representation observer is supplied, pass no transition hook. Once hold
		-- and cooldown permit a transition, the manager returns
		-- blockedReason="transition-required" without committing either fidelity
		-- authority. Callers with intentionally no physical representation may pass
		-- an explicit no-op observer instead of silently advancing truth.
		return state.fidelity:step(entityId, current.fidelity, inputs, nowSeconds, transitionHook)
	end)
	state.transitionInFlight = false
	if not stepSucceeded then
		error(resultOrError, 0)
	end
	local result = resultOrError :: StepResult
	local nextRecord = PhysicsLabRuntime.getRecord(self, entityId)
	assert(
		state.fidelity:getObservedLevel(entityId) == nextRecord.fidelity,
		`Physics Lab fidelity authority diverged after step for {entityId}`
	)
	return result, nextRecord
end

function PhysicsLabRuntime.snapshot(self: Runtime): Snapshot
	local state = assertActive(self)
	local duplicates = state.registry.duplicateDiagnostics()
	return table.freeze({
		recipeKey = self.recipeKey,
		registered = state.registry.count(),
		fidelity = state.fidelity:getMetrics(),
		duplicateIdentities = #duplicates,
	})
end

function PhysicsLabRuntime.dispose(self: Runtime): ()
	local state = stateFor(self)
	if state.disposed then
		return
	end
	assertMutationAllowed(state)

	for _, entityId in ipairs(state.entityIds) do
		state.fidelity:unregister(entityId)
		state.registry.unregister(entityId)
	end
	state.disposed = true
end

return table.freeze(PhysicsLabRuntime)
