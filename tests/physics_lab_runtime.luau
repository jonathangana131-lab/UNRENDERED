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

	local snapshotRuntime = PhysicsLabRuntime.new(recipe)
	local snapshotId = floor.entity.id
	local mutableCapture = {
		lifecycleProbe = {
			marker = "approved-preview-state",
		},
	}
	snapshotRuntime:step(snapshotId, noDemand, 0, function()
		return mutableCapture
	end)
	local snapshotDemotion, snapshotRecord = snapshotRuntime:step(snapshotId, noDemand, 2, function()
		return mutableCapture
	end, function(_before, preview)
		expect(
			"demotion preview owns the capture adapter state",
			preview.persistentState.lifecycleProbe.marker == "approved-preview-state"
		)
		mutableCapture.lifecycleProbe.marker = "mutated-after-preview"
	end)
	expect("capture snapshot fixture commits a demotion", snapshotDemotion.transitioned)
	expect(
		"authoritative demotion commit matches the adapter-approved preview snapshot",
		snapshotRecord.persistentState.lifecycleProbe.marker == "approved-preview-state"
	)
	expect(
		"adapter buffer mutation remains external to authoritative state",
		mutableCapture.lifecycleProbe.marker == "mutated-after-preview"
	)
	snapshotRuntime:dispose()

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

	local captureDisposeRuntime = PhysicsLabRuntime.new(recipe)
	local captureDisposeId = floor.entity.id
	captureDisposeRuntime:step(captureDisposeId, noDemand, 0)
	local captureDisposeOk = pcall(function()
		captureDisposeRuntime:step(captureDisposeId, noDemand, 2, function(record)
			captureDisposeRuntime:dispose()
			return record.persistentState
		end, function() end)
	end)
	local afterCaptureDispose = captureDisposeRuntime:snapshot()
	expect("capture callback cannot dispose the runtime", not captureDisposeOk)
	expect(
		"capture callback dispose rejection preserves registry population",
		afterCaptureDispose.registered == #recipe.entities
			and afterCaptureDispose.fidelity.registered == #recipe.entities
	)
	expect(
		"capture callback dispose rejection preserves fidelity authority",
		captureDisposeRuntime:getFidelity(captureDisposeId) == "F2"
	)
	local captureRetry, captureRetryRecord = captureDisposeRuntime:step(
		captureDisposeId,
		noDemand,
		2,
		function(record)
			return record.persistentState
		end,
		function() end
	)
	expect(
		"capture callback rejection clears the runtime transition guard for retry",
		captureRetry.transitioned and captureRetryRecord.fidelity == "F0"
	)
	captureDisposeRuntime:dispose()

	local observerDisposeRuntime = PhysicsLabRuntime.new(recipe)
	local observerDisposeId = floor.entity.id
	observerDisposeRuntime:step(observerDisposeId, noDemand, 0)
	local observerDisposeOk = pcall(function()
		observerDisposeRuntime:step(observerDisposeId, noDemand, 2, function(record)
			return record.persistentState
		end, function()
			observerDisposeRuntime:dispose()
		end)
	end)
	local afterObserverDispose = observerDisposeRuntime:snapshot()
	expect("transition observer cannot dispose the runtime", not observerDisposeOk)
	expect(
		"observer dispose rejection preserves both authority populations",
		afterObserverDispose.registered == #recipe.entities
			and afterObserverDispose.fidelity.registered == #recipe.entities
	)
	expect(
		"observer dispose rejection leaves runtime authority synchronized",
		observerDisposeRuntime:getFidelity(observerDisposeId) == "F2"
	)
	local observerRetry, observerRetryRecord = observerDisposeRuntime:step(
		observerDisposeId,
		noDemand,
		2,
		function(record)
			return record.persistentState
		end,
		function() end
	)
	expect(
		"observer dispose rejection clears the runtime transition guard for retry",
		observerRetry.transitioned and observerRetryRecord.fidelity == "F0"
	)
	observerDisposeRuntime:dispose()

	local recursiveRuntime = PhysicsLabRuntime.new(recipe)
	local recursiveOuterId = floor.entity.id
	local recursiveInner = findEntity(recipe, "chair-a")
	expect("runtime reentrancy fixture finds an independent inner entity", recursiveInner ~= nil)
	if recursiveInner ~= nil then
		local recursiveInnerId = recursiveInner.entity.id
		local innerBefore = recursiveRuntime:getRecord(recursiveInnerId)
		recursiveRuntime:step(recursiveOuterId, noDemand, 0)
		local recursiveStepOk = pcall(function()
			recursiveRuntime:step(recursiveOuterId, noDemand, 2, function(record)
				return record.persistentState
			end, function()
				recursiveRuntime:step(recursiveInnerId, noDemand, 0)
			end)
		end)
		local afterRecursiveStep = recursiveRuntime:snapshot()
		local innerAfter = recursiveRuntime:getRecord(recursiveInnerId)
		expect("transition observer cannot recursively step the runtime", not recursiveStepOk)
		expect(
			"recursive step rejection preserves runtime population",
			afterRecursiveStep.registered == #recipe.entities
				and afterRecursiveStep.fidelity.registered == #recipe.entities
		)
		expect(
			"recursive step rejection does not mutate the independent inner entity",
			innerAfter.fidelity == innerBefore.fidelity
				and innerAfter.stateRevision == innerBefore.stateRevision
				and innerAfter.representationRevision == innerBefore.representationRevision
		)
		local recursiveRetry, recursiveRetryRecord = recursiveRuntime:step(
			recursiveOuterId,
			noDemand,
			2,
			function(record)
				return record.persistentState
			end,
			function() end
		)
		expect(
			"recursive step rejection clears the runtime transition guard for retry",
			recursiveRetry.transitioned and recursiveRetryRecord.fidelity == "F0"
		)
	end
	recursiveRuntime:dispose()

	local facadeRuntime = PhysicsLabRuntime.new(recipe)
	expect(
		"runtime facade hides mutable authority capabilities",
		(facadeRuntime :: any)._registry == nil
			and (facadeRuntime :: any)._fidelity == nil
			and (facadeRuntime :: any)._entityIds == nil
			and (facadeRuntime :: any)._disposed == nil
			and (facadeRuntime :: any)._transitionInFlight == nil
	)
	local facadeMutationOk = pcall(function()
		(facadeRuntime :: any).recipeKey = "tampered-runtime"
	end)
	expect("runtime facade itself is immutable", not facadeMutationOk)
	if chair ~= nil then
		local facadeId = floor.entity.id
		local facadeOtherId = chair.entity.id
		facadeRuntime:step(facadeId, noDemand, 0)
		local facadeTamperOk = pcall(function()
			facadeRuntime:step(facadeId, noDemand, 2, function(record)
				return record.persistentState
			end, function()
				local leakedRegistry = (facadeRuntime :: any)._registry
				assert(leakedRegistry ~= nil, "runtime facade does not expose registry authority")
				leakedRegistry.unregister(facadeOtherId)
			end)
		end)
		local afterFacadeTamper = facadeRuntime:snapshot()
		expect("callback cannot reach registry capability through runtime facade", not facadeTamperOk)
		expect(
			"facade capability rejection preserves both authority populations",
			afterFacadeTamper.registered == #recipe.entities
				and afterFacadeTamper.fidelity.registered == #recipe.entities
		)
		local otherRecordOk = pcall(function()
			facadeRuntime:getRecord(facadeOtherId)
		end)
		expect("facade capability rejection preserves unrelated registry entity", otherRecordOk)
		local facadeRetry, facadeRetryRecord = facadeRuntime:step(facadeId, noDemand, 2, function(record)
			return record.persistentState
		end, function() end)
		expect(
			"facade capability rejection remains retryable",
			facadeRetry.transitioned and facadeRetryRecord.fidelity == "F0"
		)
	end
	facadeRuntime:dispose()

	local guardTamperRuntime = PhysicsLabRuntime.new(recipe)
	local guardTamperId = floor.entity.id
	guardTamperRuntime:step(guardTamperId, noDemand, 0)
	local guardTamperOk = pcall(function()
		guardTamperRuntime:step(guardTamperId, noDemand, 2, function(record)
			return record.persistentState
		end, function()
			(guardTamperRuntime :: any)._transitionInFlight = false
			guardTamperRuntime:dispose()
		end)
	end)
	expect("callback cannot reset hidden runtime transition guard", not guardTamperOk)
	local guardSnapshotOk = pcall(function()
		local afterGuardTamper = guardTamperRuntime:snapshot()
		expect(
			"guard reset rejection preserves both authority populations",
			afterGuardTamper.registered == #recipe.entities
				and afterGuardTamper.fidelity.registered == #recipe.entities
		)
		expect(
			"guard reset rejection preserves fidelity authority",
			guardTamperRuntime:getFidelity(guardTamperId) == "F2"
		)
	end)
	expect("guard reset rejection leaves runtime active", guardSnapshotOk)
	local guardRetryOk, guardRetryTransitioned = pcall(function()
		local retry, retryRecord = guardTamperRuntime:step(guardTamperId, noDemand, 2, function(record)
			return record.persistentState
		end, function() end)
		return retry.transitioned and retryRecord.fidelity == "F0"
	end)
	expect(
		"guard reset rejection clears private transition state for retry",
		guardRetryOk and guardRetryTransitioned == true
	)
	guardTamperRuntime:dispose()

	runtime:dispose()
	runtime:dispose()
	local disposedSnapshotOk = pcall(function()
		runtime:snapshot()
	end)
	expect("runtime dispose is idempotent and rejects later authority reads", not disposedSnapshotOk)

	return failures
end

return run
