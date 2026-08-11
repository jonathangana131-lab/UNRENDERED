local ProductionLoader = require("./support/ProductionLoader")
local runPhysicsLabDiagnosticsAtomicity = require("./physics_lab_diagnostics_atomicity")
local runPhysicsLabDiagnosticsBounds = require("./physics_lab_diagnostics_bounds")
local runPhysicsLabDiagnosticsEnabledIntegrity = require("./physics_lab_diagnostics_enabled_integrity")
local runPhysicsLabDiagnosticsFinalState = require("./physics_lab_diagnostics_final_state")
local runPhysicsLabDiagnosticsReadoutContract = require("./physics_lab_diagnostics_readout_contract")

local StableId = ProductionLoader.requireShared("Core/StableId")
local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")
local FidelityManager = ProductionLoader.requireShared("Physics/FidelityManager")
local WorldEntity = ProductionLoader.requireShared("Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL hero-contract {name}`)
		else
			print(`PASS hero-contract {name}`)
		end
	end

	local genome = Fixtures.officeTable
	local genomeReport = ObjectGenome.inspect(genome)
	expect("production fixture remains a valid ObjectGenome", genomeReport.ok)

	local allMaterialRefsValid = true
	for _, component in ipairs(genome.components) do
		local materialReport = MaterialDNA.validateReference({
			id = component.materialKey,
			recipeVersion = component.materialRecipeVersion,
		})
		if not materialReport.ok then
			allMaterialRefsValid = false
			break
		end
	end
	expect(
		"ObjectGenome component references satisfy exact MaterialDNA reference contract",
		allMaterialRefsValid
	)

	local objectState = ObjectGenome.defaultState(genome)
	expect("default ObjectState is valid for fixture", ObjectGenome.inspectState(genome, objectState).ok)

	local entityId = StableId.fromParts("world-entity", {
		"physics-lab",
		"hero-gate-contract-integration",
		"office-table",
	})
	expect("lab entity id is a canonical StableId", StableId.is(entityId, "world-entity"))
	expect("canonical StableId satisfies WorldEntity id boundary", WorldEntity.isId(entityId))

	local record = WorldEntity.new({
		id = entityId,
		kind = "object",
		origin = {
			worldId = "world.hero-gate-test",
			regionId = "region.physics-lab",
			generator = "physics-lab.contract-integration",
			generatorVersion = 1,
			recipeKey = ObjectGenome.identityKey(genome),
		},
		persistentState = objectState,
	})
	local registry = WorldEntity.createRegistry()
	local registered = WorldEntity.register(registry, record)
	expect("WorldEntity registry accepts StableId-backed object", registered)

	local config = table.clone(FidelityManager.defaultConfig())
	config.promotionHoldSeconds = 0
	config.demotionHoldSeconds = 0
	config.transitionCooldownSeconds = 0
	local manager = FidelityManager.new(config)
	manager:register(entityId, record.fidelity)

	local promotion = manager:step(
		entityId,
		"F0",
		{
			distanceStuds = 32,
			visible = true,
			directlyObserved = true,
			secondsSinceInteraction = 0,
			significance = 0,
			networkRelevance = 0,
			entityRelevance = 0,
		},
		0,
		function(id, _fromLevel, toLevel, _reason)
			WorldEntity.transitionRegistered(registry, id, toLevel, nil)
		end
	)
	local promotedRecord = WorldEntity.get(registry, entityId)
	expect(
		"FidelityManager promotes observed lab object through transition boundary",
		promotion.transitioned and promotion.currentLevel == "F3"
	)
	expect(
		"promotion keeps FidelityManager and WorldEntity in sync",
		manager:getObservedLevel(entityId) == "F3"
			and promotedRecord ~= nil
			and promotedRecord.fidelity == "F3"
	)
	expect(
		"promotion preserves canonical object state",
		promotedRecord ~= nil
			and promotedRecord.stateRevision == 0
			and ObjectGenome.inspectState(genome, promotedRecord.persistentState).ok
	)

	local demotion = manager:step(
		entityId,
		"F3",
		{
			distanceStuds = 10000,
			visible = false,
			directlyObserved = false,
			secondsSinceInteraction = 100,
			significance = 0,
			networkRelevance = 0,
			entityRelevance = 0,
		},
		1,
		function(id, _fromLevel, toLevel, _reason)
			local current = WorldEntity.get(registry, id)
			assert(current ~= nil, "registered entity must exist during fidelity transition")
			WorldEntity.transitionRegistered(registry, id, toLevel, current.persistentState)
		end
	)
	local demotedRecord = WorldEntity.get(registry, entityId)
	expect(
		"FidelityManager demotes inactive lab object through state-capture boundary",
		demotion.transitioned and demotion.currentLevel == "F0"
	)
	expect(
		"demotion keeps FidelityManager and WorldEntity in sync",
		manager:getObservedLevel(entityId) == "F0" and demotedRecord ~= nil and demotedRecord.fidelity == "F0"
	)
	expect(
		"demotion captures state before representation teardown",
		demotedRecord ~= nil
			and demotedRecord.stateRevision == 1
			and demotedRecord.representationRevision == 2
	)
	expect(
		"captured ObjectState survives F0-F3-F0 lifecycle",
		demotedRecord ~= nil
			and ObjectGenome.inspectState(genome, demotedRecord.persistentState).ok
			and demotedRecord.persistentState.genomeId == objectState.genomeId
	)

	local metrics = manager:getMetrics()
	expect(
		"integration path records one promotion and one demotion",
		metrics.transitions == 2 and metrics.promotions == 1 and metrics.demotions == 1
	)

	manager:unregister(entityId)
	WorldEntity.unregister(registry, entityId)
	expect(
		"integration cleanup releases both registries",
		manager:getMetrics().registered == 0 and WorldEntity.count(registry) == 0
	)

	failures += runPhysicsLabDiagnosticsAtomicity()
	failures += runPhysicsLabDiagnosticsBounds()
	failures += runPhysicsLabDiagnosticsEnabledIntegrity()
	failures += runPhysicsLabDiagnosticsFinalState()
	failures += runPhysicsLabDiagnosticsReadoutContract()
	return failures
end

return run
