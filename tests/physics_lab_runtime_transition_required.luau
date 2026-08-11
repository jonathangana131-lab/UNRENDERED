local ProductionLoader = require("./support/ProductionLoader")
local runSynthesis = require("./physics_lab_runtime_synthesis")

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

	local malformedRuntime = PhysicsLabRuntime.new(recipe)
	local malformedId = recipe.entities[1].entity.id
	local malformedBefore = malformedRuntime:getRecord(malformedId)
	local malformedCaptureCalls = 0
	local malformedObserverCalls = 0
	malformedRuntime:step(malformedId, noDemand, 0, function(record)
		return record.persistentState
	end, function() end)
	local malformedCaptureAccepted = pcall(function()
		malformedRuntime:step(malformedId, noDemand, 2, function()
			malformedCaptureCalls += 1
			return {
				invalid = 0 / 0,
			}
		end, function()
			malformedObserverCalls += 1
		end)
	end)
	local malformedAfter = malformedRuntime:getRecord(malformedId)
	local malformedMetrics = malformedRuntime:snapshot().fidelity
	expect("runtime rejects non-finite captured persistent state", not malformedCaptureAccepted)
	expect("runtime invokes rejected capture exactly once", malformedCaptureCalls == 1)
	expect(
		"runtime rejects malformed captured state before representation observer",
		malformedObserverCalls == 0
	)
	expect(
		"malformed capture preserves WorldEntity fidelity",
		malformedAfter.fidelity == malformedBefore.fidelity
	)
	expect(
		"malformed capture preserves WorldEntity state revision",
		malformedAfter.stateRevision == malformedBefore.stateRevision
	)
	expect(
		"malformed capture preserves WorldEntity representation revision",
		malformedAfter.representationRevision == malformedBefore.representationRevision
	)
	expect(
		"malformed capture preserves FidelityManager observed fidelity",
		malformedRuntime:getFidelity(malformedId) == malformedBefore.fidelity
	)
	expect("malformed capture does not count a transition", malformedMetrics.transitions == 0)
	expect("malformed capture does not count a transition hook", malformedMetrics.transitionHookCalls == 0)

	local recoveredCaptureCalls = 0
	local recovered, recoveredRecord = malformedRuntime:step(malformedId, noDemand, 2, function(record)
		recoveredCaptureCalls += 1
		return {
			recovered = true,
			priorRevision = record.stateRevision,
		}
	end, function() end)
	expect("runtime retries demotion after rejected capture at same monotonic time", recovered.transitioned)
	expect("recovery captures state exactly once", recoveredCaptureCalls == 1)
	expect("recovery commits F0 fidelity", recoveredRecord.fidelity == "F0")
	expect(
		"recovery advances state revision exactly once",
		recoveredRecord.stateRevision == malformedBefore.stateRevision + 1
	)
	expect(
		"recovery keeps both fidelity authorities synchronized",
		malformedRuntime:getFidelity(malformedId) == "F0"
	)
	malformedRuntime:dispose()

	local longCycleRuntime = PhysicsLabRuntime.new(recipe)
	local longCycleId = recipe.entities[1].entity.id
	local longCycleBefore = longCycleRuntime:getRecord(longCycleId)
	local longCycleBeforeSnapshot = longCycleRuntime:snapshot()
	local longCycleCaptures = 0
	local longCycleObservers = 0
	local cycleCount = 64
	local observed = {
		distanceStuds = 8,
		visible = true,
		directlyObserved = true,
		secondsSinceInteraction = 0,
		significance = 0,
		networkRelevance = 0,
		entityRelevance = 0,
	}

	local longCycleAccepted, longCycleFailure = pcall(function()
		for cycle = 1, cycleCount do
			local baseTime = cycle * 10
			local capturedState = {
				lifecycleProbe = {
					cycle = cycle,
					marker = `cycle-{cycle}`,
				},
			}

			local demotionHold = longCycleRuntime:step(longCycleId, noDemand, baseTime, function()
				longCycleCaptures += 1
				return capturedState
			end, function()
				longCycleObservers += 1
			end)
			assert(
				not demotionHold.transitioned and demotionHold.blockedReason == "hold",
				`cycle {cycle} demotion hold did not block as expected`
			)

			local demotionResult, demotedRecord = longCycleRuntime:step(
				longCycleId,
				noDemand,
				baseTime + 2,
				function()
					longCycleCaptures += 1
					return capturedState
				end,
				function()
					longCycleObservers += 1
				end
			)
			assert(
				demotionResult.transitioned and demotedRecord.fidelity == "F0",
				`cycle {cycle} demotion did not commit F0`
			)
			capturedState.lifecycleProbe.marker = "mutated-after-commit"
			assert(
				demotedRecord.persistentState.lifecycleProbe.marker == `cycle-{cycle}`,
				`cycle {cycle} demotion did not own captured state`
			)

			local promotionHold = longCycleRuntime:step(longCycleId, observed, baseTime + 3, nil, function()
				longCycleObservers += 1
			end)
			assert(
				not promotionHold.transitioned and promotionHold.blockedReason == "hold",
				`cycle {cycle} promotion hold did not block as expected`
			)

			local promotionResult, promotedRecord = longCycleRuntime:step(
				longCycleId,
				observed,
				baseTime + 3.2,
				nil,
				function()
					longCycleObservers += 1
				end
			)
			assert(
				promotionResult.transitioned and promotedRecord.fidelity == "F4",
				`cycle {cycle} promotion did not commit F4`
			)
			assert(
				promotedRecord.persistentState.lifecycleProbe.marker == `cycle-{cycle}`,
				`cycle {cycle} promotion lost captured state`
			)
		end
	end)
	if longCycleAccepted then
		expect("64-cycle runtime rebuild stress completes without lifecycle drift", true)
		local longCycleAfter = longCycleRuntime:getRecord(longCycleId)
		local longCycleAfterSnapshot = longCycleRuntime:snapshot()
		expect("long-cycle demotions capture exactly once per cycle", longCycleCaptures == cycleCount)
		expect(
			"long-cycle observers run exactly once per committed transition",
			longCycleObservers == cycleCount * 2
		)
		expect("long-cycle final fidelity is F4", longCycleAfter.fidelity == "F4")
		expect(
			"long-cycle state revisions advance once per demotion",
			longCycleAfter.stateRevision == longCycleBefore.stateRevision + cycleCount
		)
		expect(
			"long-cycle representation revisions advance twice per cycle",
			longCycleAfter.representationRevision == longCycleBefore.representationRevision + cycleCount * 2
		)
		expect(
			"long-cycle transition metric matches committed transitions",
			longCycleAfterSnapshot.fidelity.transitions == cycleCount * 2
		)
		expect(
			"long-cycle demotion metric matches cycles",
			longCycleAfterSnapshot.fidelity.demotions == cycleCount
		)
		expect(
			"long-cycle promotion metric matches cycles",
			longCycleAfterSnapshot.fidelity.promotions == cycleCount
		)
		expect(
			"long-cycle transition-hook metric matches committed transitions",
			longCycleAfterSnapshot.fidelity.transitionHookCalls == cycleCount * 2
		)
		expect(
			"long-cycle registry population remains constant",
			longCycleAfterSnapshot.registered == longCycleBeforeSnapshot.registered
		)
		expect(
			"long-cycle FidelityManager population remains constant",
			longCycleAfterSnapshot.fidelity.registered == longCycleBeforeSnapshot.fidelity.registered
		)
	else
		expect(`64-cycle runtime rebuild stress failed: {tostring(longCycleFailure)}`, false)
	end
	longCycleRuntime:dispose()

	failures += runSynthesis()
	return failures
end

return run
