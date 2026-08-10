local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local PhysicsLabRuntime = ProductionLoader.requireShared("Physics/PhysicsLabRuntime")

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
	local entityId = recipe.entities[1].entity.id
	local before = runtime:getRecord(entityId)
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

	-- Establish the default demotion hold without committing a transition.
	local held = runtime:step(entityId, noDemand, 0, function(record)
		captureCalls += 1
		return record.persistentState
	end)
	expect("missing observer may establish demotion hold without committing", held.blockedReason == "hold")

	local blocked, after = runtime:step(entityId, noDemand, 2, function(record)
		captureCalls += 1
		return record.persistentState
	end)

	expect("missing observer blocks committed fidelity transition", not blocked.transitioned)
	expect(
		"missing observer uses FidelityManager transition-required contract",
		blocked.blockedReason == "transition-required"
	)
	expect("missing observer is rejected before demotion capture side effects", captureCalls == 0)
	expect("missing observer preserves WorldEntity fidelity", after.fidelity == before.fidelity)
	expect(
		"missing observer preserves WorldEntity state revision",
		after.stateRevision == before.stateRevision
	)
	expect(
		"missing observer preserves WorldEntity representation revision",
		after.representationRevision == before.representationRevision
	)
	expect(
		"missing observer preserves FidelityManager observed fidelity",
		runtime:getFidelity(entityId) == before.fidelity
	)
	expect(
		"missing observer is observable in bounded runtime diagnostics",
		runtime:snapshot().fidelity.blockedByMissingTransition == 1
	)

	local observerCalls = 0
	local retried, demoted = runtime:step(entityId, noDemand, 2, function(record)
		captureCalls += 1
		return record.persistentState
	end, function(_current, _preview, _reason)
		observerCalls += 1
	end)
	expect("supplying observer can retry the blocked transition", retried.transitioned)
	expect("retry captures demotion state exactly once", captureCalls == 1)
	expect("retry observes representation transition exactly once", observerCalls == 1)
	expect("retry commits WorldEntity fidelity", demoted.fidelity == "F0")
	expect("retry keeps both fidelity authorities synchronized", runtime:getFidelity(entityId) == "F0")

	runtime:dispose()
	return failures
end

return run
