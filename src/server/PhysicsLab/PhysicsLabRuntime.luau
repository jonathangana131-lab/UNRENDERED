--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local FidelityManager = require(Shared.Physics.FidelityManager)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local WorldEntity = require(Shared.Reality.WorldEntity)

local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

local PhysicsLabRuntime = {}

PhysicsLabRuntime.MAX_ENTITY_COUNT = 128

type FidelityLevel = FidelityManager.FidelityLevel
type PolicyConfig = FidelityManager.PolicyConfig
type PolicyInputs = FidelityManager.PolicyInputs
type Recipe = PhysicsLabRecipe.Recipe
type Registry = WorldEntity.Registry
type PlainData = WorldEntity.PlainData

export type DiagnosticRow = {
	key: string,
	entityId: string,
	fidelity: FidelityLevel,
	stateRevision: number,
	representationRevision: number,
	realized: boolean,
}

export type Runtime = {
	recipe: Recipe,
	parent: Instance,
	registry: Registry,
	fidelity: FidelityManager.Manager,
	initialFidelityById: { [string]: FidelityLevel },
	representations: { [string]: Instance },
	root: Folder?,
	clock: number,
}

local activeRuntime: Runtime? = nil

local function runtimeConfig(entityCount: number): PolicyConfig
	assert(entityCount >= 1 and entityCount <= PhysicsLabRuntime.MAX_ENTITY_COUNT, "Physics Lab entity count exceeds runtime cap")
	local default = FidelityManager.defaultConfig()
	return {
		maxRegisteredEntities = entityCount,
		structuralDistanceStuds = default.structuralDistanceStuds,
		renderDistanceStuds = default.renderDistanceStuds,
		interactiveDistanceStuds = default.interactiveDistanceStuds,
		heroDistanceStuds = default.heroDistanceStuds,
		distanceHysteresisStuds = default.distanceHysteresisStuds,
		interactionGraceSeconds = default.interactionGraceSeconds,
		significanceKeepaliveThreshold = default.significanceKeepaliveThreshold,
		activeRelevanceThreshold = default.activeRelevanceThreshold,
		heroRelevanceThreshold = default.heroRelevanceThreshold,
		-- Lab teardown/rebuild is an explicit development lifecycle operation. It
		-- still uses the production FidelityManager transition hook, but does not
		-- wait on gameplay-facing temporal hysteresis.
		promotionHoldSeconds = 0,
		demotionHoldSeconds = 0,
		transitionCooldownSeconds = 0,
	}
end

local function inputsForTarget(target: FidelityLevel, config: PolicyConfig): PolicyInputs
	local distanceStuds: number
	local directlyObserved = false

	if target == "F0" then
		distanceStuds = config.structuralDistanceStuds + config.distanceHysteresisStuds + 1
	elseif target == "F1" then
		distanceStuds = (config.renderDistanceStuds + config.structuralDistanceStuds) * 0.5
	elseif target == "F2" then
		distanceStuds = (config.interactiveDistanceStuds + config.renderDistanceStuds) * 0.5
	elseif target == "F3" then
		distanceStuds = (config.heroDistanceStuds + config.interactiveDistanceStuds) * 0.5
	else
		distanceStuds = 0
		directlyObserved = true
	end

	return {
		distanceStuds = distanceStuds,
		visible = false,
		directlyObserved = directlyObserved,
		secondsSinceInteraction = math.huge,
		significance = 0,
		networkRelevance = 0,
		entityRelevance = 0,
	}
end

local function nextClock(runtime: Runtime): number
	runtime.clock += 1
	return runtime.clock
end

local function transitionTo(
	runtime: Runtime,
	entityId: string,
	target: FidelityLevel,
	capturedState: PlainData?
): ()
	local current = runtime.registry.get(entityId)
	assert(current ~= nil, `Physics Lab runtime missing WorldEntity: {entityId}`)
	if current.fidelity == target then
		assert(
			runtime.fidelity:getObservedLevel(entityId) == target,
			`Physics Lab fidelity mirror drifted for {entityId}`
		)
		return
	end

	local currentRank = WorldEntity.fidelityRank(current.fidelity)
	local targetRank = WorldEntity.fidelityRank(target)
	local stateForTransition: PlainData? = nil
	if targetRank < currentRank then
		stateForTransition = capturedState or current.persistentState
	end

	local result = runtime.fidelity:step(
		entityId,
		current.fidelity,
		inputsForTarget(target, runtime.fidelity.config),
		nextClock(runtime),
		function(hookEntityId, fromLevel, toLevel)
			assert(hookEntityId == entityId, "Physics Lab transition hook entity mismatch")
			assert(fromLevel == current.fidelity, "Physics Lab transition hook source fidelity mismatch")
			assert(toLevel == target, "Physics Lab transition hook target fidelity mismatch")
			runtime.registry.transitionRegistered(hookEntityId, toLevel, stateForTransition)
		end
	)
	assert(result.transitioned and result.currentLevel == target, `Physics Lab transition to {target} was blocked`)

	local updated = runtime.registry.get(entityId)
	assert(updated ~= nil and updated.fidelity == target, `Physics Lab WorldEntity transition failed for {entityId}`)
	assert(
		runtime.fidelity:getObservedLevel(entityId) == target,
		`Physics Lab FidelityManager transition failed for {entityId}`
	)
end

local function updateRepresentationDiagnostics(runtime: Runtime): ()
	for _, element in runtime.recipe.elements do
		local record = runtime.registry.get(element.entity.id)
		assert(record ~= nil, `Physics Lab runtime missing WorldEntity: {element.entity.id}`)
		local representation = runtime.representations[element.entity.id]
		assert(representation ~= nil, `Physics Lab runtime missing representation: {element.entity.id}`)
		representation:SetAttribute("Fidelity", record.fidelity)
		representation:SetAttribute("StateRevision", record.stateRevision)
		representation:SetAttribute("RepresentationRevision", record.representationRevision)
	end
end

local function realize(runtime: Runtime): ()
	local ok, rootOrError, representations = pcall(PhysicsLabRealizer.realize, runtime.recipe, runtime.parent)
	if not ok then
		PhysicsLabRealizer.destroy(runtime.parent)
		error(rootOrError, 2)
	end

	runtime.root = rootOrError :: Folder
	runtime.representations = representations :: { [string]: Instance }
	updateRepresentationDiagnostics(runtime)
end

local function demoteForTeardown(runtime: Runtime): ()
	for _, element in runtime.recipe.elements do
		local record = runtime.registry.get(element.entity.id)
		assert(record ~= nil, `Physics Lab runtime missing WorldEntity: {element.entity.id}`)
		transitionTo(runtime, element.entity.id, "F0", record.persistentState)
	end
end

local function promoteToRecipeFidelity(runtime: Runtime): ()
	for _, element in runtime.recipe.elements do
		local target = runtime.initialFidelityById[element.entity.id]
		assert(target ~= nil, `Physics Lab runtime missing initial fidelity: {element.entity.id}`)
		transitionTo(runtime, element.entity.id, target, nil)
	end
end

local function unregisterAll(runtime: Runtime): ()
	for _, element in runtime.recipe.elements do
		local entityId = element.entity.id
		if runtime.registry.get(entityId) ~= nil then
			runtime.fidelity:unregister(entityId)
			runtime.registry.unregister(entityId)
		end
	end
end

function PhysicsLabRuntime.destroyRepresentation(runtime: Runtime): ()
	if runtime.root == nil then
		return
	end

	demoteForTeardown(runtime)
	PhysicsLabRealizer.destroy(runtime.parent)
	runtime.root = nil
	runtime.representations = {}
end

function PhysicsLabRuntime.realizeRepresentation(runtime: Runtime): Folder
	assert(runtime.root == nil, "Physics Lab representation already exists")
	promoteToRecipeFidelity(runtime)

	local ok, message = pcall(function()
		realize(runtime)
	end)
	if not ok then
		demoteForTeardown(runtime)
		error(message, 2)
	end

	return runtime.root :: Folder
end

function PhysicsLabRuntime.rebuild(runtime: Runtime): Folder
	PhysicsLabRuntime.destroyRepresentation(runtime)
	return PhysicsLabRuntime.realizeRepresentation(runtime)
end

function PhysicsLabRuntime.snapshot(runtime: Runtime): { DiagnosticRow }
	local rows: { DiagnosticRow } = {}
	for _, element in runtime.recipe.elements do
		local record = runtime.registry.get(element.entity.id)
		assert(record ~= nil, `Physics Lab runtime missing WorldEntity: {element.entity.id}`)
		table.insert(rows, {
			key = element.key,
			entityId = record.id,
			fidelity = record.fidelity,
			stateRevision = record.stateRevision,
			representationRevision = record.representationRevision,
			realized = runtime.representations[record.id] ~= nil,
		})
	end
	return rows
end

function PhysicsLabRuntime.shutdown(runtime: Runtime): ()
	PhysicsLabRuntime.destroyRepresentation(runtime)
	unregisterAll(runtime)
	if activeRuntime == runtime then
		activeRuntime = nil
	end
end

function PhysicsLabRuntime.start(recipe: Recipe, parent: Instance): Runtime
	PhysicsLabRecipe.validate(recipe)
	assert(#recipe.elements <= PhysicsLabRuntime.MAX_ENTITY_COUNT, "Physics Lab recipe exceeds runtime entity cap")

	if activeRuntime ~= nil then
		if activeRuntime.recipe.recipeId == recipe.recipeId and activeRuntime.parent == parent then
			PhysicsLabRuntime.rebuild(activeRuntime)
			return activeRuntime
		end
		PhysicsLabRuntime.shutdown(activeRuntime)
	end

	local registry = WorldEntity.createRegistry(#recipe.elements)
	local fidelity = FidelityManager.new(runtimeConfig(#recipe.elements))
	local initialFidelityById: { [string]: FidelityLevel } = {}
	local runtime: Runtime = {
		recipe = recipe,
		parent = parent,
		registry = registry,
		fidelity = fidelity,
		initialFidelityById = initialFidelityById,
		representations = {},
		root = nil,
		clock = 0,
	}

	for _, element in recipe.elements do
		local registered = registry.register(element.entity)
		assert(registered, `Physics Lab runtime duplicate WorldEntityId: {element.entity.id}`)
		fidelity:register(element.entity.id, element.entity.fidelity)
		initialFidelityById[element.entity.id] = element.entity.fidelity
	end
	assert(registry.count() == #recipe.elements, "Physics Lab runtime registry count mismatch")
	assert(fidelity:getMetrics().registered == #recipe.elements, "Physics Lab fidelity registration count mismatch")

	local ok, message = pcall(function()
		realize(runtime)
	end)
	if not ok then
		unregisterAll(runtime)
		error(message, 2)
	end

	activeRuntime = runtime
	return runtime
end

function PhysicsLabRuntime.getActive(): Runtime?
	return activeRuntime
end

function PhysicsLabRuntime.rebuildActive(): Folder
	assert(activeRuntime ~= nil, "Physics Lab runtime is not active")
	return PhysicsLabRuntime.rebuild(activeRuntime)
end

function PhysicsLabRuntime.snapshotActive(): { DiagnosticRow }
	assert(activeRuntime ~= nil, "Physics Lab runtime is not active")
	return PhysicsLabRuntime.snapshot(activeRuntime)
end

return table.freeze(PhysicsLabRuntime)
