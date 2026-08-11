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

	local function metricsAreInternallyConsistent(metrics)
		local total = 0
		for _, level in { "F0", "F1", "F2", "F3", "F4" } do
			local count = metrics.counts[level]
			if count < 0 then
				return false
			end
			total += count
		end
		return total == metrics.registered
	end

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

	local inertMetatableInputs = setmetatable(validInputs(), {
		__metatable = "locked-policy-input",
	})
	local inertMetatableAccepted = pcall(function()
		FidelityManager.evaluatePolicy(inertMetatableInputs)
	end)
	expectEqual("pure policy rejects inert policy-input metatable", inertMetatableAccepted, false)

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

	local unregisteringHookManager = FidelityManager.new(reentrantConfig)
	unregisteringHookManager:register("entity:atomic-unregister-hook", "F0")
	pcall(function()
		unregisteringHookManager:step(
			"entity:atomic-unregister-hook",
			"F0",
			heroInputs(),
			0,
			function(entityId)
				unregisteringHookManager:unregister(entityId)
			end
		)
	end)
	expectEqual(
		"callback reentrancy cannot corrupt aggregate fidelity accounting",
		metricsAreInternallyConsistent(unregisteringHookManager:getMetrics()),
		true
	)

	local recursiveStepManager = FidelityManager.new(reentrantConfig)
	recursiveStepManager:register("entity:atomic-recursive-step", "F0")
	pcall(function()
		recursiveStepManager:step("entity:atomic-recursive-step", "F0", heroInputs(), 0, function(entityId)
			recursiveStepManager:step(entityId, "F0", heroInputs(), 0, function() end)
		end)
	end)
	expectEqual(
		"recursive callback step cannot double-commit aggregate fidelity accounting",
		metricsAreInternallyConsistent(recursiveStepManager:getMetrics()),
		true
	)

	local registeringFailureManager = FidelityManager.new(reentrantConfig)
	registeringFailureManager:register("entity:atomic-register-hook", "F0")
	local registeringFailureAccepted = pcall(function()
		registeringFailureManager:step("entity:atomic-register-hook", "F0", heroInputs(), 0, function()
			registeringFailureManager:register("entity:atomic-register-side-effect", "F1")
			error("intentional failure after manager mutation")
		end)
	end)
	expectEqual("failing manager-mutating hook propagates rejection", registeringFailureAccepted, false)
	expectEqual(
		"callback rollback cannot desynchronize global counts from registered state",
		metricsAreInternallyConsistent(registeringFailureManager:getMetrics()),
		true
	)

	return failures
end

return run
