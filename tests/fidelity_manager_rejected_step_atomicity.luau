local FidelityManager = require("../src/shared/Physics/FidelityManager")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL fidelity atomicity {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS fidelity atomicity {name}`)
		end
	end

	local function expectAccounting(name, metrics)
		local counts = metrics.counts
		local total = counts.F0 + counts.F1 + counts.F2 + counts.F3 + counts.F4
		expectEqual(`{name} count sum`, total, metrics.registered)
		expectEqual(`{name} F0 non-negative`, counts.F0 >= 0, true)
		expectEqual(`{name} F1 non-negative`, counts.F1 >= 0, true)
		expectEqual(`{name} F2 non-negative`, counts.F2 >= 0, true)
		expectEqual(`{name} F3 non-negative`, counts.F3 >= 0, true)
		expectEqual(`{name} F4 non-negative`, counts.F4 >= 0, true)
	end

	local function validInputs()
		return {
			distanceStuds = 900,
			visible = false,
			directlyObserved = false,
			secondsSinceInteraction = math.huge,
			significance = 0,
			networkRelevance = 0,
			entityRelevance = 0,
		}
	end

	local function heroInputs()
		local inputs = validInputs()
		inputs.distanceStuds = 10
		inputs.directlyObserved = true
		return inputs
	end

	local function hostileNumeric()
		local calls = 0
		local function called()
			calls += 1
		end
		local value = setmetatable({}, {
			__eq = function()
				called()
				return false
			end,
			__lt = function()
				called()
				return false
			end,
			__le = function()
				called()
				return false
			end,
			__add = function()
				called()
				return 0
			end,
			__sub = function()
				called()
				return 0
			end,
		})
		return value, function()
			return calls
		end
	end

	local function hostileConfigProxy()
		local source = table.clone(FidelityManager.defaultConfig())
		local reads = 0
		local proxy = setmetatable({}, {
			__index = function(_, key)
				reads += 1
				return source[key]
			end,
		})
		return proxy, function()
			return reads
		end
	end

	local hostileNewConfig, hostileNewConfigReads = hostileConfigProxy()
	local hostileNewConfigAccepted = pcall(function()
		FidelityManager.new(hostileNewConfig)
	end)
	expectEqual("constructor rejects metatable-backed config", hostileNewConfigAccepted, false)
	expectEqual("constructor config rejection executes no metamethod", hostileNewConfigReads(), 0)

	local hostilePureConfig, hostilePureConfigReads = hostileConfigProxy()
	local hostilePureConfigAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), hostilePureConfig, "F0")
	end)
	expectEqual("pure policy rejects metatable-backed config", hostilePureConfigAccepted, false)
	expectEqual("pure policy config rejection executes no metamethod", hostilePureConfigReads(), 0)

	local inertMetatableConfig = setmetatable(table.clone(FidelityManager.defaultConfig()), {
		__metatable = "locked-policy-config",
	})
	local inertMetatableAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), inertMetatableConfig, "F0")
	end)
	expectEqual("pure policy rejects inert PolicyConfig metatable", inertMetatableAccepted, false)

	local hostileDistanceConfig = table.clone(FidelityManager.defaultConfig())
	local hostileDistanceValue, hostileDistanceCalls = hostileNumeric()
	hostileDistanceConfig.heroDistanceStuds = hostileDistanceValue
	local hostileDistanceAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), hostileDistanceConfig, "F0")
	end)
	expectEqual("pure policy rejects hostile PolicyConfig numeric scalar", hostileDistanceAccepted, false)
	expectEqual("PolicyConfig scalar validation never executes metamethod", hostileDistanceCalls(), 0)

	local hostileCapacityConfig = table.clone(FidelityManager.defaultConfig())
	local hostileCapacityValue, hostileCapacityCalls = hostileNumeric()
	hostileCapacityConfig.maxRegisteredEntities = hostileCapacityValue
	local hostileCapacityConstructorAccepted = pcall(function()
		FidelityManager.new(hostileCapacityConfig)
	end)
	expectEqual(
		"constructor rejects hostile maxRegisteredEntities scalar",
		hostileCapacityConstructorAccepted,
		false
	)
	expectEqual(
		"constructor maxRegisteredEntities rejection executes no metamethod",
		hostileCapacityCalls(),
		0
	)
	local hostileCapacityPureAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), hostileCapacityConfig, "F0")
	end)
	expectEqual(
		"pure policy rejects hostile maxRegisteredEntities scalar",
		hostileCapacityPureAccepted,
		false
	)
	expectEqual(
		"pure policy maxRegisteredEntities rejection executes no metamethod",
		hostileCapacityCalls(),
		0
	)

	local explicitFalseConfigAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), false :: any, "F0")
	end)
	expectEqual("explicit false PolicyConfig does not select defaults", explicitFalseConfigAccepted, false)

	local clockManager = FidelityManager.new()
	clockManager:register("entity:atomic-clock", "F0")
	clockManager:step("entity:atomic-clock", "F0", validInputs(), 1)

	local invalidFutureInputs = validInputs()
	invalidFutureInputs.significance = 0 / 0
	local invalidFutureAccepted = pcall(function()
		clockManager:step("entity:atomic-clock", "F0", invalidFutureInputs, 100)
	end)
	expectEqual("invalid future policy input rejected", invalidFutureAccepted, false)

	local validAfterRejectedFutureAccepted = pcall(function()
		clockManager:step("entity:atomic-clock", "F0", validInputs(), 2)
	end)
	expectEqual(
		"rejected policy input does not poison monotonic clock",
		validAfterRejectedFutureAccepted,
		true
	)

	local metatableManager = FidelityManager.new()
	metatableManager:register("entity:atomic-metatable", "F0")
	local metatableSource = validInputs()
	local metatableReads = 0
	local metatableInputs = setmetatable({}, {
		__index = function(_, key)
			metatableReads += 1
			return metatableSource[key]
		end,
	})
	local metatableFutureAccepted = pcall(function()
		metatableManager:step("entity:atomic-metatable", "F0", metatableInputs, 100)
	end)
	expectEqual("metatable-backed policy input rejected", metatableFutureAccepted, false)
	expectEqual("policy input metatable callback never executes", metatableReads, 0)
	local validAfterMetatableRejected = pcall(function()
		metatableManager:step("entity:atomic-metatable", "F0", validInputs(), 1)
	end)
	expectEqual("metatable-backed input cannot poison monotonic clock", validAfterMetatableRejected, true)

	local pureMetatableReads = 0
	local pureMetatableInputs = setmetatable({}, {
		__index = function(_, key)
			pureMetatableReads += 1
			return metatableSource[key]
		end,
	})
	local pureMetatableAccepted = pcall(function()
		FidelityManager.evaluatePolicy(pureMetatableInputs)
	end)
	expectEqual("pure policy rejects metatable-backed input", pureMetatableAccepted, false)
	expectEqual("pure policy never executes policy-input metatable", pureMetatableReads, 0)

	local numericFields = {
		"distanceStuds",
		"secondsSinceInteraction",
		"significance",
		"networkRelevance",
		"entityRelevance",
	}
	local hostilePolicyManager = FidelityManager.new()
	hostilePolicyManager:register("entity:atomic-hostile-numeric", "F0")
	for _, field in numericFields do
		local pureInputs = validInputs()
		local pureHostile, pureCalls = hostileNumeric()
		pureInputs[field] = pureHostile
		local pureAccepted = pcall(function()
			FidelityManager.evaluatePolicy(pureInputs)
		end)
		expectEqual(`hostile numeric {field} rejected by pure policy`, pureAccepted, false)
		expectEqual(`hostile numeric {field} pure policy executes no metamethod`, pureCalls(), 0)

		local stepInputs = validInputs()
		local stepHostile, stepCalls = hostileNumeric()
		stepInputs[field] = stepHostile
		local stepAccepted = pcall(function()
			hostilePolicyManager:step("entity:atomic-hostile-numeric", "F0", stepInputs, 100)
		end)
		expectEqual(`hostile numeric {field} rejected by step`, stepAccepted, false)
		expectEqual(`hostile numeric {field} step executes no metamethod`, stepCalls(), 0)
	end
	local validAfterHostilePolicyAccepted = pcall(function()
		hostilePolicyManager:step("entity:atomic-hostile-numeric", "F0", validInputs(), 1)
	end)
	expectEqual(
		"hostile numeric policy fields cannot poison monotonic clock",
		validAfterHostilePolicyAccepted,
		true
	)

	local hostileTimeManager = FidelityManager.new()
	hostileTimeManager:register("entity:atomic-hostile-time", "F0")
	hostileTimeManager:step("entity:atomic-hostile-time", "F0", validInputs(), 1)
	local hostileNowSeconds, hostileNowCalls = hostileNumeric()
	local hostileNowAccepted = pcall(function()
		hostileTimeManager:step("entity:atomic-hostile-time", "F0", validInputs(), hostileNowSeconds)
	end)
	expectEqual("hostile nowSeconds rejected", hostileNowAccepted, false)
	expectEqual("hostile nowSeconds executes no metamethod", hostileNowCalls(), 0)
	local validAfterHostileNowAccepted = pcall(function()
		hostileTimeManager:step("entity:atomic-hostile-time", "F0", validInputs(), 2)
	end)
	expectEqual("hostile nowSeconds cannot poison monotonic clock", validAfterHostileNowAccepted, true)

	local booleanManager = FidelityManager.new()
	booleanManager:register("entity:atomic-boolean", "F0")

	local invalidVisibleInputs = validInputs()
	invalidVisibleInputs.visible = 0
	local beforeInvalidVisible = booleanManager:getMetrics()
	local invalidVisibleAccepted = pcall(function()
		booleanManager:step("entity:atomic-boolean", "F0", invalidVisibleInputs, 100)
	end)
	expectEqual("non-boolean visible flag rejected", invalidVisibleAccepted, false)
	local afterInvalidVisible = booleanManager:getMetrics()
	expectEqual(
		"rejected visible flag leaves hold metric atomic",
		afterInvalidVisible.blockedByHold,
		beforeInvalidVisible.blockedByHold
	)
	expectEqual(
		"rejected visible flag leaves observed fidelity atomic",
		booleanManager:getObservedLevel("entity:atomic-boolean"),
		"F0"
	)

	local invalidObservedInputs = validInputs()
	invalidObservedInputs.directlyObserved = "false"
	local beforeInvalidObserved = booleanManager:getMetrics()
	local invalidObservedAccepted = pcall(function()
		booleanManager:step("entity:atomic-boolean", "F0", invalidObservedInputs, 100)
	end)
	expectEqual("non-boolean direct-observation flag rejected", invalidObservedAccepted, false)
	local afterInvalidObserved = booleanManager:getMetrics()
	expectEqual(
		"rejected direct-observation flag leaves hold metric atomic",
		afterInvalidObserved.blockedByHold,
		beforeInvalidObserved.blockedByHold
	)
	expectEqual(
		"rejected direct-observation flag leaves observed fidelity atomic",
		booleanManager:getObservedLevel("entity:atomic-boolean"),
		"F0"
	)

	local validAfterRejectedBooleansAccepted = pcall(function()
		booleanManager:step("entity:atomic-boolean", "F0", validInputs(), 1)
	end)
	expectEqual(
		"rejected boolean policy input does not poison monotonic clock",
		validAfterRejectedBooleansAccepted,
		true
	)

	local syncManager = FidelityManager.new()
	syncManager:register("entity:atomic-sync", "F3")
	local beforeMetrics = syncManager:getMetrics()

	local invalidSyncInputs = validInputs()
	invalidSyncInputs.networkRelevance = 2
	local invalidSyncAccepted = pcall(function()
		syncManager:step("entity:atomic-sync", "F2", invalidSyncInputs, 50)
	end)
	expectEqual("invalid sync policy input rejected", invalidSyncAccepted, false)
	expectEqual(
		"rejected input does not synchronize observed fidelity",
		syncManager:getObservedLevel("entity:atomic-sync"),
		"F3"
	)

	local afterRejectedMetrics = syncManager:getMetrics()
	expectEqual(
		"rejected input does not increment external synchronization metric",
		afterRejectedMetrics.externalSynchronizations,
		beforeMetrics.externalSynchronizations
	)
	expectEqual("rejected input preserves F3 count", afterRejectedMetrics.counts.F3, beforeMetrics.counts.F3)
	expectEqual("rejected input preserves F2 count", afterRejectedMetrics.counts.F2, beforeMetrics.counts.F2)

	local acceptedSync = pcall(function()
		syncManager:step("entity:atomic-sync", "F2", validInputs(), 1)
	end)
	expectEqual("valid synchronization after rejected future step accepted", acceptedSync, true)
	expectEqual(
		"valid synchronization still updates observed fidelity",
		syncManager:getObservedLevel("entity:atomic-sync"),
		"F2"
	)
	expectEqual(
		"valid synchronization remains observable",
		syncManager:getMetrics().externalSynchronizations,
		beforeMetrics.externalSynchronizations + 1
	)

	local capacityConfig = table.clone(FidelityManager.defaultConfig())
	capacityConfig.maxRegisteredEntities = 1
	local capacityManager = FidelityManager.new(capacityConfig)
	capacityManager:register("entity:atomic-capacity-existing", "F0")
	local beforeInvalidCapacityLevel = capacityManager:getMetrics()
	local invalidCapacityLevelAccepted = pcall(function()
		capacityManager:register("entity:atomic-capacity-invalid-level", "F9")
	end)
	expectEqual("invalid fidelity level is rejected even at capacity", invalidCapacityLevelAccepted, false)
	local afterInvalidCapacityLevel = capacityManager:getMetrics()
	expectEqual(
		"invalid fidelity level does not consume capacity rejection metric",
		afterInvalidCapacityLevel.registrationCapacityRejections,
		beforeInvalidCapacityLevel.registrationCapacityRejections
	)
	local invalidCapacityRecordExists = pcall(function()
		capacityManager:getObservedLevel("entity:atomic-capacity-invalid-level")
	end)
	expectEqual("invalid fidelity level never creates a registration", invalidCapacityRecordExists, false)

	local hookConfig = table.clone(FidelityManager.defaultConfig())
	hookConfig.promotionHoldSeconds = 0.1
	local hookManager = FidelityManager.new(hookConfig)
	hookManager:register("entity:atomic-hook", "F0")

	local initialHookResult = hookManager:step("entity:atomic-hook", "F0", heroInputs(), 0)
	expectEqual("hook-failure setup enters promotion hold", initialHookResult.blockedReason, "hold")
	local beforeHookFailureMetrics = hookManager:getMetrics()

	local failedFutureHookAccepted = pcall(function()
		hookManager:step("entity:atomic-hook", "F0", heroInputs(), 100, function()
			error("intentional transition failure")
		end)
	end)
	expectEqual("failing transition hook propagates rejection", failedFutureHookAccepted, false)
	expectEqual(
		"failing transition hook leaves observed fidelity uncommitted",
		hookManager:getObservedLevel("entity:atomic-hook"),
		"F0"
	)

	local afterHookFailureMetrics = hookManager:getMetrics()
	expectEqual(
		"failing transition hook does not count as a hook call",
		afterHookFailureMetrics.transitionHookCalls,
		beforeHookFailureMetrics.transitionHookCalls
	)
	expectEqual(
		"failing transition hook does not count as a transition",
		afterHookFailureMetrics.transitions,
		beforeHookFailureMetrics.transitions
	)
	expectEqual("failing transition hook preserves F0 count", afterHookFailureMetrics.counts.F0, 1)
	expectEqual("failing transition hook preserves F4 count", afterHookFailureMetrics.counts.F4, 0)
	expectAccounting("failing transition hook", afterHookFailureMetrics)

	local retryHookCalled = false
	local retryAfterFailedFutureHookAccepted = pcall(function()
		local retryResult = hookManager:step("entity:atomic-hook", "F0", heroInputs(), 0.2, function()
			retryHookCalled = true
		end)
		expectEqual("retry after failed future hook can commit", retryResult.transitioned, true)
	end)
	expectEqual(
		"failed future transition hook does not poison monotonic clock",
		retryAfterFailedFutureHookAccepted,
		true
	)
	expectEqual("retry after failed future hook invokes transition", retryHookCalled, true)
	expectEqual(
		"retry after failed future hook commits observed fidelity",
		hookManager:getObservedLevel("entity:atomic-hook"),
		"F4"
	)

	local reentrantConfig = table.clone(FidelityManager.defaultConfig())
	reentrantConfig.promotionHoldSeconds = 0
	reentrantConfig.transitionCooldownSeconds = 0

	local unregisterManager = FidelityManager.new(reentrantConfig)
	unregisterManager:register("entity:atomic-unregister", "F0")
	local unregisterAccepted = pcall(function()
		unregisterManager:step("entity:atomic-unregister", "F0", heroInputs(), 0, function(entityId)
			unregisterManager:unregister(entityId)
		end)
	end)
	expectEqual("transition hook cannot unregister transitioning entity", unregisterAccepted, false)
	expectEqual(
		"rejected unregister callback preserves observed fidelity",
		unregisterManager:getObservedLevel("entity:atomic-unregister"),
		"F0"
	)
	local unregisterMetrics = unregisterManager:getMetrics()
	expectEqual("rejected unregister callback preserves registration", unregisterMetrics.registered, 1)
	expectEqual("rejected unregister callback preserves F0 count", unregisterMetrics.counts.F0, 1)
	expectEqual("rejected unregister callback preserves F4 count", unregisterMetrics.counts.F4, 0)
	expectEqual(
		"rejected unregister callback does not count hook call",
		unregisterMetrics.transitionHookCalls,
		0
	)
	expectEqual("rejected unregister callback does not count transition", unregisterMetrics.transitions, 0)
	expectAccounting("rejected unregister callback", unregisterMetrics)

	local unregisterRetryCalled = false
	local unregisterRetryAccepted = pcall(function()
		local result = unregisterManager:step("entity:atomic-unregister", "F0", heroInputs(), 0.1, function()
			unregisterRetryCalled = true
		end)
		expectEqual("retry after rejected unregister callback commits", result.transitioned, true)
	end)
	expectEqual("rejected unregister callback does not poison retry clock", unregisterRetryAccepted, true)
	expectEqual("retry after rejected unregister callback invokes hook", unregisterRetryCalled, true)

	local recursiveManager = FidelityManager.new(reentrantConfig)
	recursiveManager:register("entity:atomic-recursive-step", "F0")
	local recursiveAccepted = pcall(function()
		recursiveManager:step("entity:atomic-recursive-step", "F0", heroInputs(), 0, function()
			recursiveManager:step("entity:atomic-recursive-step", "F0", heroInputs(), 0, function() end)
		end)
	end)
	expectEqual("transition hook cannot recursively step same entity", recursiveAccepted, false)
	expectEqual(
		"rejected recursive callback preserves observed fidelity",
		recursiveManager:getObservedLevel("entity:atomic-recursive-step"),
		"F0"
	)
	local recursiveMetrics = recursiveManager:getMetrics()
	expectEqual(
		"rejected recursive callback does not count hook call",
		recursiveMetrics.transitionHookCalls,
		0
	)
	expectEqual("rejected recursive callback does not count transition", recursiveMetrics.transitions, 0)
	expectAccounting("rejected recursive callback", recursiveMetrics)

	local crossEntityManager = FidelityManager.new(reentrantConfig)
	crossEntityManager:register("entity:atomic-cross-outer", "F0")
	local crossEntityAccepted = pcall(function()
		crossEntityManager:step("entity:atomic-cross-outer", "F0", heroInputs(), 0, function()
			crossEntityManager:register("entity:atomic-cross-created", "F2")
			error("intentional callback failure after cross-entity mutation")
		end)
	end)
	expectEqual("failing hook after cross-entity mutation propagates rejection", crossEntityAccepted, false)
	expectEqual(
		"cross-entity mutation keeps outer fidelity uncommitted",
		crossEntityManager:getObservedLevel("entity:atomic-cross-outer"),
		"F0"
	)
	expectEqual(
		"cross-entity mutation remains independently registered",
		crossEntityManager:getObservedLevel("entity:atomic-cross-created"),
		"F2"
	)
	local crossEntityMetrics = crossEntityManager:getMetrics()
	expectEqual("cross-entity mutation preserves two registrations", crossEntityMetrics.registered, 2)
	expectEqual("cross-entity mutation preserves outer F0 count", crossEntityMetrics.counts.F0, 1)
	expectEqual("cross-entity mutation preserves created F2 count", crossEntityMetrics.counts.F2, 1)
	expectEqual("cross-entity failure leaves F4 count zero", crossEntityMetrics.counts.F4, 0)
	expectEqual("cross-entity failure does not count hook call", crossEntityMetrics.transitionHookCalls, 0)
	expectEqual("cross-entity failure does not count transition", crossEntityMetrics.transitions, 0)
	expectAccounting("cross-entity failing callback", crossEntityMetrics)

	return failures
end

return run
