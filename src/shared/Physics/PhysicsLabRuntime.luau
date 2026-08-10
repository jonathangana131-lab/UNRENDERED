--!strict

local FidelityManager = require(script.Parent.FidelityManager)
local PhysicsLabRecipe = require(script.Parent.PhysicsLabRecipe)
local WorldEntity = require(script.Parent.Parent.Reality.WorldEntity)

local PhysicsLabRuntime = {}
PhysicsLabRuntime.__index = PhysicsLabRuntime

type FidelityLevel = FidelityManager.FidelityLevel
type Manager = FidelityManager.Manager
type Metrics = FidelityManager.Metrics
type PolicyInputs = FidelityManager.PolicyInputs
type PolicyReason = FidelityManager.PolicyReason
type StepResult = FidelityManager.StepResult
type PlainData = WorldEntity.PlainData
type Registry = WorldEntity.Registry
type WorldEntityRecord = WorldEntity.WorldEntityRecord
type Recipe = PhysicsLabRecipe.Recipe

export type CaptureState = (WorldEntityRecord) -> PlainData
export type TransitionObserver = (WorldEntityRecord, WorldEntityRecord, PolicyReason) -> ()

export type Snapshot = {
	recipeId: string,
	registered: number,
	fidelity: Metrics,
	duplicateIdentities: number,
}

type RuntimeImpl = {
	recipeId: string,
	_entityIds: { string },
	_registry: Registry,
	_fidelity: Manager,
	_disposed: boolean,
}

export type Runtime = typeof(setmetatable({} :: RuntimeImpl, PhysicsLabRuntime))

local function assertActive(self: Runtime): ()
	assert(not self._disposed, "PhysicsLabRuntime is disposed")
end

local function boundedFidelityManager(entityCount: number): Manager
	local config = table.clone(FidelityManager.defaultConfig())
	config.maxRegisteredEntities = math.max(1, entityCount)
	return FidelityManager.new(config)
end

function PhysicsLabRuntime.new(recipe: Recipe): Runtime
	PhysicsLabRecipe.validate(recipe)

	local registry = WorldEntity.createRegistry()
	local fidelity = boundedFidelityManager(#recipe.elements)
	local entityIds: { string } = {}

	for _, element in ipairs(recipe.elements) do
		local registered, duplicate = registry.register(element.entity)
		assert(registered, `duplicate Physics Lab WorldEntityId: {duplicate and duplicate.entityId or element.entity.id}`)
		fidelity:register(element.entity.id, element.entity.fidelity)
		table.insert(entityIds, element.entity.id)
	end

	return setmetatable({
		recipeId = recipe.recipeId,
		_entityIds = entityIds,
		_registry = registry,
		_fidelity = fidelity,
		_disposed = false,
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
	local current = PhysicsLabRuntime.getRecord(self, entityId)
	assert(
		self._fidelity:getObservedLevel(entityId) == current.fidelity,
		`Physics Lab fidelity authority diverged before step for {entityId}`
	)

	local function applyTransition(
		transitionEntityId: string,
		fromLevel: FidelityLevel,
		toLevel: FidelityLevel,
		reason: PolicyReason
	): ()
		assert(transitionEntityId == entityId, "FidelityManager transitioned the wrong Physics Lab entity")
		assert(fromLevel == current.fidelity, "Physics Lab transition source fidelity drifted")

		local capturedState: PlainData? = nil
		if WorldEntity.fidelityRank(toLevel) < WorldEntity.fidelityRank(fromLevel) then
			assert(captureState ~= nil, "Physics Lab demotion requires a state-capture adapter")
			capturedState = captureState(current)
		end

		-- Preview the exact production transition before mutating either authority.
		-- If representation work rejects the transition, both registries remain unchanged.
		local preview = WorldEntity.transition(current, toLevel, capturedState)
		if observeTransition ~= nil then
			observeTransition(current, preview, reason)
		end

		local committed = self._registry.transitionRegistered(entityId, toLevel, capturedState)
		assert(committed.fidelity == preview.fidelity, "Physics Lab transition commit fidelity mismatch")
		assert(committed.stateRevision == preview.stateRevision, "Physics Lab transition commit state mismatch")
		assert(
			committed.representationRevision == preview.representationRevision,
			"Physics Lab transition commit representation mismatch"
		)
	end

	local result = self._fidelity:step(entityId, current.fidelity, inputs, nowSeconds, applyTransition)
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
		recipeId = self.recipeId,
		registered = self._registry.count(),
		fidelity = self._fidelity:getMetrics(),
		duplicateIdentities = #duplicates,
	})
end

function PhysicsLabRuntime.dispose(self: Runtime): ()
	if self._disposed then
		return
	end

	for _, entityId in ipairs(self._entityIds) do
		self._fidelity:unregister(entityId)
		self._registry.unregister(entityId)
	end
	self._disposed = true
end

return table.freeze(PhysicsLabRuntime)
