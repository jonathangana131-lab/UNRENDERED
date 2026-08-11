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

	local function expectMalformedEntityIdBoundary(name, invoke)
		local boundaryRuntime = PhysicsLabRuntime.new(recipe)
		local stringifyCalls = 0
		local hostileEntityId = setmetatable({}, {
			__tostring = function()
				stringifyCalls += 1
				boundaryRuntime:dispose()
				return "hostile-entity-id"
			end,
		})
		local accepted = pcall(function()
			invoke(boundaryRuntime, hostileEntityId :: any)
		end)
		local snapshotOk, boundarySnapshot = pcall(function()
			return boundaryRuntime:snapshot()
		end)
		expect(`${name} rejects a non-string WorldEntityId`, not accepted)
		expect(`${name} rejects before caller __tostring executes`, stringifyCalls == 0)
		expect(
			`${name} rejection preserves both runtime authority populations`,
			snapshotOk
				and boundarySnapshot.registered == #recipe.entities
				and boundarySnapshot.fidelity.registered == #recipe.entities
		)
		if snapshotOk then
			local retryOk = pcall(function()
				local retryRecord = boundaryRuntime:getRecord(entityId)
				assert(retryRecord.id == entityId)
			end)
			expect(`${name} rejection leaves an immediate valid retry available`, retryOk)
		end
		boundaryRuntime:dispose()
	end

	expectMalformedEntityIdBoundary("getRecord", function(boundaryRuntime, malformedEntityId)
		boundaryRuntime:getRecord(malformedEntityId)
	end)
	expectMalformedEntityIdBoundary("getFidelity", function(boundaryRuntime, malformedEntityId)
		boundaryRuntime:getFidelity(malformedEntityId)
	end)
	expectMalformedEntityIdBoundary("step", function(boundaryRuntime, malformedEntityId)
		boundaryRuntime:step(malformedEntityId, noDemand, 0)
	end)

	local unknownRuntime = PhysicsLabRuntime.new(recipe)
	local unknownEntityId = "we:physics-lab:unknown"
	local unknownAccepted, unknownError = pcall(function()
		unknownRuntime:getRecord(unknownEntityId)
	end)
	expect("valid unknown WorldEntityId still rejects", not unknownAccepted)
	expect(
		"valid unknown WorldEntityId keeps a safe bounded diagnostic",
		not unknownAccepted
			and type(unknownError) == "string"
			and string.find(unknownError, unknownEntityId, 1, true) ~= nil
	)
	local unknownSnapshot = unknownRuntime:snapshot()
	expect(
		"valid unknown WorldEntityId rejection preserves runtime authority",
		unknownSnapshot.registered == #recipe.entities
			and unknownSnapshot.fidelity.registered == #recipe.entities
	)
	unknownRuntime:dispose()

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

	runtime:dispose()
	runtime:dispose()
	local disposedSnapshotOk = pcall(function()
		runtime:snapshot()
	end)
	expect("runtime dispose is idempotent and rejects later authority reads", not disposedSnapshotOk)

	return failures
end

return run
