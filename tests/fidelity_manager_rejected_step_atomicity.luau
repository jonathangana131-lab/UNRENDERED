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

	return failures
end

return run
