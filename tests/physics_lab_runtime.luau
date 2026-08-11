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
	expect(
		"runtime FidelityManager owns every lab WorldEntity",
		initial.fidelity.registered == #recipe.entities
	)
	expect("runtime starts without duplicate identities", initial.duplicateIdentities == 0)
	expect("runtime is scoped to the exact lab recipe", initial.recipeKey == recipe.recipeKey)

	local floor = findEntity(recipe, "floor")
	expect("runtime lifecycle fixture finds floor entity", floor ~= nil)
	if floor == nil then
		runtime:dispose()
		return failures
	end

	local entityId = floor.entity.id
	local initialRecord = runtime:getRecord(entityId)
	expect(
		"runtime record begins at authored fidelity",
		runtime:getFidelity(entityId) == initialRecord.fidelity
	)

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
	local observerCalls = 0
	local capturedProbe = {
		lifecycleProbe = {
			marker = "captured-before-demotion",
			entityId = entityId,
		},
	}

	local firstDemotion = runtime:step(entityId, noDemand, 0, function()
		captureCalls += 1
		return capturedProbe
	end)
	expect("default demotion hold blocks first low-demand sample", not firstDemotion.transitioned)
	expect("blocked demotion does not capture representation state", captureCalls == 0)

	local demotion, demoted = runtime:step(entityId, noDemand, 2, function(record)
		captureCalls += 1
		expect("state capture runs while incumbent fidelity is still authoritative", record.fidelity == "F2")
		return capturedProbe
	end, function(before, after)
		observerCalls += 1
		expect("demotion observer sees same stable identity", before.id == after.id)
		expect("demotion observer sees F0 preview", before.fidelity == "F2" and after.fidelity == "F0")
		expect(
			"demotion observer sees captured state before commit",
			after.persistentState.lifecycleProbe.marker == "captured-before-demotion"
		)
	end)
	expect(
		"runtime demotes through production FidelityManager",
		demotion.transitioned and demoted.fidelity == "F0"
	)
	expect("runtime demotion captures state exactly once", captureCalls == 1)
	expect(
		"runtime demotion increments state revision",
		demoted.stateRevision == initialRecord.stateRevision + 1
	)
	expect(
		"runtime demotion increments representation revision",
		demoted.representationRevision == initialRecord.representationRevision + 1
	)
	expect(
		"runtime keeps fidelity authorities synchronized after demotion",
		runtime:getFidelity(entityId) == "F0"
	)

	local observed = {
		distanceStuds = 8,
		visible = true,
		directlyObserved = true,
		secondsSinceInteraction = 0,
		significance = 0,
		networkRelevance = 0,
		entityRelevance = 0,
	}

	local firstPromotion = runtime:step(entityId, observed, 3, nil, function(before, after)
		observerCalls += 1
		expect(
			"promotion observer preserves captured state revision",
			before.stateRevision == after.stateRevision
		)
	end)
	expect("default promotion hold blocks first observed sample", not firstPromotion.transitioned)

	local promotion, promoted = runtime:step(entityId, observed, 3.2, nil, function(before, after)
		observerCalls += 1
		expect("promotion observer sees higher fidelity", before.fidelity == "F0" and after.fidelity == "F4")
		expect(
			"promotion consumes previously captured persistent state",
			after.persistentState.lifecycleProbe.marker == "captured-before-demotion"
		)
	end)
	expect(
		"runtime promotes through production FidelityManager",
		promotion.transitioned and promoted.fidelity == "F4"
	)
	expect("promotion does not recapture persistent state", promoted.stateRevision == demoted.stateRevision)
	expect(
		"promotion preserves captured state",
		promoted.persistentState.lifecycleProbe.marker == "captured-before-demotion"
	)
	expect(
		"runtime keeps fidelity authorities synchronized after promotion",
		runtime:getFidelity(entityId) == "F4"
	)
	expect("transition observer only runs for committed transitions", observerCalls == 2)

	local snapshot = runtime:snapshot()
	expect("runtime metrics record one promotion", snapshot.fidelity.promotions == 1)
	expect("runtime metrics record one demotion", snapshot.fidelity.demotions == 1)
	expect("runtime metrics remain bounded to recipe population", snapshot.registered == #recipe.entities)

	local duplicateRecipe = {
		schemaVersion = recipe.schemaVersion,
		recipeKey = recipe.recipeKey,
		worldId = recipe.worldId,
		regionId = recipe.regionId,
		entities = { recipe.entities[1], recipe.entities[1] },
	}
	local duplicateAccepted = pcall(function()
		PhysicsLabRuntime.new(duplicateRecipe)
	end)
	expect("runtime rejects duplicate placed WorldEntity identities", not duplicateAccepted)

	local rejectionRuntime = PhysicsLabRuntime.new(recipe)
	local chair = findEntity(recipe, "chair-a")
	expect("runtime rejection fixture finds chair entity", chair ~= nil)
	if chair ~= nil then
		local rejectedId = chair.entity.id
		local before = rejectionRuntime:getRecord(rejectedId)
		rejectionRuntime:step(rejectedId, noDemand, 0, function(record)
			return record.persistentState
		end)
		local transitionOk = pcall(function()
			rejectionRuntime:step(rejectedId, noDemand, 2, function(record)
				return record.persistentState
			end, function()
				error("representation transition rejected")
			end)
		end)
		local after = rejectionRuntime:getRecord(rejectedId)
		expect("representation transition rejection propagates", not transitionOk)
		expect("rejected transition preserves WorldEntity fidelity", after.fidelity == before.fidelity)
		expect("rejected transition preserves state revision", after.stateRevision == before.stateRevision)
		expect(
			"rejected transition preserves representation revision",
			after.representationRevision == before.representationRevision
		)
		expect(
			"rejected transition preserves FidelityManager observed level",
			rejectionRuntime:getFidelity(rejectedId) == "F2"
		)
	end
	rejectionRuntime:dispose()

	local captureRejectionRuntime = PhysicsLabRuntime.new(recipe)
	local captureEntity = findEntity(recipe, "cart") or floor
	local captureId = captureEntity.entity.id
	local captureBefore = captureRejectionRuntime:getRecord(captureId)
	local malformedCaptureCalls = 0
	local malformedObserverCalls = 0
	captureRejectionRuntime:step(captureId, noDemand, 0, function(record)
		return record.persistentState
	end, function() end)
	local malformedCaptureAccepted = pcall(function()
		captureRejectionRuntime:step(captureId, noDemand, 2, function()
			malformedCaptureCalls += 1
			return {
				invalid = 0 / 0,
			}
		end, function()
			malformedObserverCalls += 1
		end)
	end)
	local captureAfterRejected = captureRejectionRuntime:getRecord(captureId)
	local captureRejectedMetrics = captureRejectionRuntime:snapshot().fidelity
	expect("runtime rejects non-finite captured persistent state", not malformedCaptureAccepted)
	expect("runtime calls malformed demotion capture exactly once", malformedCaptureCalls == 1)
	expect("invalid captured state is rejected before representation observer", malformedObserverCalls == 0)
	expect(
		"invalid captured state preserves WorldEntity fidelity",
		captureAfterRejected.fidelity == captureBefore.fidelity
	)
	expect(
		"invalid captured state preserves state revision",
		captureAfterRejected.stateRevision == captureBefore.stateRevision
	)
	expect(
		"invalid captured state preserves representation revision",
		captureAfterRejected.representationRevision == captureBefore.representationRevision
	)
	expect(
		"invalid captured state preserves FidelityManager observed level",
		captureRejectionRuntime:getFidelity(captureId) == captureBefore.fidelity
	)
	expect("invalid captured state does not count a transition", captureRejectedMetrics.transitions == 0)
	expect("invalid captured state does not count a transition hook", captureRejectedMetrics.transitionHookCalls == 0)
	local retryCaptureCalls = 0
	local retriedCapture, recoveredCapture = captureRejectionRuntime:step(captureId, noDemand, 2, function(record)
		retryCaptureCalls += 1
		return {
			recovered = true,
			priorRevision = record.stateRevision,
		}
	end, function() end)
	expect("runtime can retry demotion after malformed capture rejection", retriedCapture.transitioned)
	expect("retry after malformed capture captures exactly once", retryCaptureCalls == 1)
	expect("retry after malformed capture commits F0", recoveredCapture.fidelity == "F0")
	expect(
		"retry after malformed capture advances state revision once",
		recoveredCapture.stateRevision == captureBefore.stateRevision + 1
	)
	expect(
		"retry after malformed capture keeps fidelity authorities synchronized",
		captureRejectionRuntime:getFidelity(captureId) == "F0"
	)
	captureRejectionRuntime:dispose()

	local longCycleRuntime = PhysicsLabRuntime.new(recipe)
	local longCycleId = floor.entity.id
	local longCycleInitial = longCycleRuntime:getRecord(longCycleId)
	local longCycleInitialSnapshot = longCycleRuntime:snapshot()
	local longCycleCaptures = 0
	local longCycleObservers = 0
	local longCycleCount = 64
	local longCycleOk = pcall(function()
		for cycle = 1, longCycleCount do
			local baseTime = cycle * 10
			local capturedState = {
				lifecycleProbe = {
					cycle = cycle,
					marker = `cycle-{cycle}`,
				},
			}
			local heldDemotion = longCycleRuntime:step(longCycleId, noDemand, baseTime, function()
				longCycleCaptures += 1
				return capturedState
			end, function()
				longCycleObservers += 1
			end)
			assert(not heldDemotion.transitioned and heldDemotion.blockedReason == "hold")

			local demotionResult, longDemoted = longCycleRuntime:step(
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
			assert(demotionResult.transitioned and longDemoted.fidelity == "F0")
			capturedState.lifecycleProbe.marker = "mutated-after-capture"
			assert(longDemoted.persistentState.lifecycleProbe.marker == `cycle-{cycle}`)

			local heldPromotion = longCycleRuntime:step(longCycleId, observed, baseTime + 3, nil, function()
				longCycleObservers += 1
			end)
			assert(not heldPromotion.transitioned and heldPromotion.blockedReason == "hold")

			local promotionResult, longPromoted = longCycleRuntime:step(
				longCycleId,
				observed,
				baseTime + 3.2,
				nil,
				function()
					longCycleObservers += 1
				end
			)
			assert(promotionResult.transitioned and longPromoted.fidelity == "F4")
			assert(longPromoted.persistentState.lifecycleProbe.marker == `cycle-{cycle}`)
		end
	end)
	expect("64-cycle F2/F4 to F0 rebuild stress completes without lifecycle drift", longCycleOk)
	local longCycleFinal = longCycleRuntime:getRecord(longCycleId)
	local longCycleSnapshot = longCycleRuntime:snapshot()
	expect("long-cycle demotions capture exactly once per cycle", longCycleCaptures == longCycleCount)
	expect("long-cycle observers run exactly once per committed transition", longCycleObservers == longCycleCount * 2)
	expect("long-cycle final fidelity remains F4", longCycleFinal.fidelity == "F4")
	expect(
		"long-cycle state revisions advance exactly once per demotion",
		longCycleFinal.stateRevision == longCycleInitial.stateRevision + longCycleCount
	)
	expect(
		"long-cycle representation revisions advance exactly twice per cycle",
		longCycleFinal.representationRevision == longCycleInitial.representationRevision + longCycleCount * 2
	)
	expect("long-cycle metrics count every transition", longCycleSnapshot.fidelity.transitions == longCycleCount * 2)
	expect("long-cycle metrics count every demotion", longCycleSnapshot.fidelity.demotions == longCycleCount)
	expect("long-cycle metrics count every promotion", longCycleSnapshot.fidelity.promotions == longCycleCount)
	expect(
		"long-cycle transition hook metric matches committed transitions",
		longCycleSnapshot.fidelity.transitionHookCalls == longCycleCount * 2
	)
	expect("long-cycle registry population stays constant", longCycleSnapshot.registered == longCycleInitialSnapshot.registered)
	expect(
		"long-cycle fidelity population stays bounded",
		longCycleSnapshot.fidelity.registered == longCycleInitialSnapshot.fidelity.registered
	)
	longCycleRuntime:dispose()

	runtime:dispose()
	runtime:dispose()
	local disposedSnapshotOk = pcall(function()
		runtime:snapshot()
	end)
	expect("runtime dispose is idempotent and rejects later authority reads", not disposedSnapshotOk)

	return failures
end

return run
