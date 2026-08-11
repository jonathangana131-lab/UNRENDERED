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
	_entityIds: { string },
	_registry: Registry,
	_fidelity: Manager,
	_disposed: boolean,
	_transitioning: boolean,
}

export type Runtime = typeof(setmetatable({} :: RuntimeImpl, PhysicsLabRuntime))

local function assertActive(self: Runtime): ()
	assert(not self._disposed, "PhysicsLabRuntime is disposed")
end

local function assertMutationAllowed(self: Runtime): ()
	assert(
		not self._transitioning,
		"PhysicsLabRuntime mutation is blocked while a fidelity transition callback is active"
	)
end

local function runTransitionMutationFence(self: Runtime, callback: () -> ()): ()
	assert(not self._transitioning, "PhysicsLabRuntime transition callback re-entry is not allowed")
	self._transitioning = true
	local ok, failure = pcall(callback)
	self._transitioning = false
	if not ok then
		error(failure, 0)
	end
end

local function boundedFidelityManager(entityCount: number): Manager
	local config = table.clone(FidelityManager.defaultConfig())
	config.maxRegisteredEntities = math.max(1, entityCount)
	return FidelityManager.new(config)
end

function PhysicsLabRuntime.new(recipe: Recipe): Runtime
	assert(recipe.schemaVersion == PhysicsLabRecipe.SCHEMA_VERSION, "unsupported Physics Lab recipe schema")
	assert(recipe.recipeKey == PhysicsLabRecipe.RECIPE_KEY, "unexpected Physics Lab recipe key")
	assert(#recipe.entities > 0, "Physics Lab runtime requires at least one entity")

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

	return setmetatable({
		recipeKey = recipe.recipeKey,
		_entityIds = entityIds,
		_registry = registry,
		_fidelity = fidelity,
		_disposed = false,
		_transitioning = false,
	}, PhysicsLabRuntime)
end

function PhysicsLabRuntime.getRecord(self: Runtime, entityId: string): WorldEntityRecord
	assertActive(self)
	local record = self._registry.get(entityId)
	assert(record ~= nil, `unknown Physics Lab WorldEntityId: {entityId}`)
	return record
end

function PhysicsLabRuntime.getFidelity(self: Runtime, entityId: string): FidelityLevel
	assertActive(self)
	local record = PhysicsLabRuntime.getRecord(self, entityId)
	local observed = self._fidelity:getObservedLevel(entityId)
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
	assertActive(self)
	assertMutationAllowed(self)
	local current = PhysicsLabRuntime.getRecord(self, entityId)
	assert(
		self._fidelity:getObservedLevel(entityId) == current.fidelity,
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
			assert(
				transitionEntityId == entityId,
				"FidelityManager transitioned the wrong Physics Lab entity"
			)
			assert(fromLevel == current.fidelity, "Physics Lab transition source fidelity drifted")

			runTransitionMutationFence(self, function()
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

				local committed = self._registry.transitionRegistered(entityId, toLevel, committedState)
				assert(committed.fidelity == preview.fidelity, "Physics Lab transition commit fidelity mismatch")
				assert(
					committed.stateRevision == preview.stateRevision,
					"Physics Lab transition commit state mismatch"
				)
				assert(
					committed.representationRevision == preview.representationRevision,
					"Physics Lab transition commit representation mismatch"
				)
			end)
		end
	end

	-- Preserve FidelityManager's production fail-closed contract: when no
	-- representation observer is supplied, pass no transition hook. Once hold
	-- and cooldown permit a transition, the manager returns
	-- blockedReason="transition-required" without committing either fidelity
	-- authority. Callers with intentionally no physical representation may pass
	-- an explicit no-op observer instead of silently advancing truth.
	local result = self._fidelity:step(entityId, current.fidelity, inputs, nowSeconds, transitionHook)
	local nextRecord = PhysicsLabRuntime.getRecord(self, entityId)
	assert(
		self._fidelity:getObservedLevel(entityId) == nextRecord.fidelity,
		`Physics Lab fidelity authority diverged after step for {entityId}`
	)
	return result, nextRecord
end

function PhysicsLabRuntime.snapshot(self: Runtime): Snapshot
	assertActive(self)
	local duplicates = self._registry.duplicateDiagnostics()
	return table.freeze({
		recipeKey = self.recipeKey,
		registered = self._registry.count(),
		fidelity = self._fidelity:getMetrics(),
		duplicateIdentities = #duplicates,
	})
end

function PhysicsLabRuntime.dispose(self: Runtime): ()
	if self._disposed then
		return
	end
	assertMutationAllowed(self)

	for _, entityId in ipairs(self._entityIds) do
		self._fidelity:unregister(entityId)
		self._registry.unregister(entityId)
	end
	self._disposed = true
end

return table.freeze(PhysicsLabRuntime)
