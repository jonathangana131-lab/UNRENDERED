local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local PhysicsLabRuntime = ProductionLoader.requireShared("Physics/PhysicsLabRuntime")

local function findEntity(recipe, key)
	for _, entityRecipe in ipairs(recipe.entities) do
		if entityRecipe.key == key then
			return entityRecipe
		end
	end
	return nil
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local recipe = PhysicsLabRecipe.build()
	local runtime = PhysicsLabRuntime.new(recipe)
	local initial = runtime:snapshot()
	expect("runtime owns every lab WorldEntity", initial.registered == #recipe.entities)
	expect("runtime FidelityManager owns every lab WorldEntity", initial.fidelity.registered == #recipe.entities)
	expect("runtime starts without duplicate identities", initial.duplicateIdentities == 0)

	local interactive = findEntity(recipe, "cabinet-a")
	expect("runtime test fixture finds cabinet", interactive ~= nil)
	if interactive == nil then
		runtime:dispose()
		return failures
	end

	local entityId = interactive.entity.id
	local initialRecord = runtime:getRecord(entityId)
	expect("runtime record begins at authored F2 fidelity", runtime:getFidelity(entityId) == "F2")

	local noDemand = {
		distanceStuds = 10000,
		visible = false,
		directlyObserved = false,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
		entityRelevance = 0,
	}

	local captureCalls = 0
	local firstDemotion = runtime:step(entityId, noDemand, 0, function(record)
		captureCalls += 1
		return record.persistentState
	end)
	expect("default demotion hold blocks first low-demand sample", not firstDemotion.transitioned)

	local demotion, demoted = runtime:step(entityId, noDemand, 2, function(record)
		captureCalls += 1
		return record.persistentState
	end)
	expect("runtime demotes through production FidelityManager", demotion.transitioned and demoted.fidelity == "F0")
	expect("runtime demotion captures state exactly once", captureCalls == 1)
	expect("runtime demotion increments state revision", demoted.stateRevision == initialRecord.stateRevision + 1)
	expect(
		"runtime demotion increments representation revision",
		demoted.representationRevision == initialRecord.representationRevision + 1
	)
	expect("runtime keeps fidelity authorities synchronized after demotion", runtime:getFidelity(entityId) == "F0")

	local observed = {
		distanceStuds = 8,
		visible = true,
		directlyObserved = true,
		secondsSinceInteraction = 0,
		significance = 0,
		networkRelevance = 0,
		entityRelevance = 0,
	}

	local firstPromotion = runtime:step(entityId, observed, 3)
	expect("default promotion hold blocks first observed sample", not firstPromotion.transitioned)

	local promotion, promoted = runtime:step(entityId, observed, 3.2)
	expect("runtime promotes through production FidelityManager", promotion.transitioned and promoted.fidelity == "F4")
	expect("promotion does not recapture persistent state", promoted.stateRevision == demoted.stateRevision)
	expect("runtime keeps fidelity authorities synchronized after promotion", runtime:getFidelity(entityId) == "F4")

	local snapshot = runtime:snapshot()
	expect("runtime metrics record one promotion", snapshot.fidelity.promotions == 1)
	expect("runtime metrics record one demotion", snapshot.fidelity.demotions == 1)
	expect("runtime metrics remain bounded to recipe population", snapshot.registered == #recipe.entities)

	local atomicRuntime = PhysicsLabRuntime.new(recipe)
	local atomicEntity = findEntity(recipe, "chair-a")
	expect("atomic failure fixture finds chair", atomicEntity ~= nil)
	if atomicEntity ~= nil then
		local atomicId = atomicEntity.entity.id
		local before = atomicRuntime:getRecord(atomicId)
		atomicRuntime:step(atomicId, noDemand, 0, function(record)
			return record.persistentState
		end)
		local transitionOk = pcall(function()
			atomicRuntime:step(atomicId, noDemand, 2, function(record)
				return record.persistentState
			end, function()
				error("representation transition rejected")
			end)
		end)
		local after = atomicRuntime:getRecord(atomicId)
		expect("representation transition rejection propagates", not transitionOk)
		expect("rejected transition preserves WorldEntity fidelity", after.fidelity == before.fidelity)
		expect("rejected transition preserves state revision", after.stateRevision == before.stateRevision)
		expect(
			"rejected transition preserves representation revision",
			after.representationRevision == before.representationRevision
		)
		expect("rejected transition preserves FidelityManager authority", atomicRuntime:getFidelity(atomicId) == "F2")
	end
	atomicRuntime:dispose()

	runtime:dispose()
	local disposedSnapshotOk = pcall(function()
		runtime:snapshot()
	end)
	expect("disposed runtime rejects further authority reads", not disposedSnapshotOk)

	return failures
end

return run