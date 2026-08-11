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

	local function hostileComparable(onRead)
		local function read(): boolean
			onRead()
			return true
		end
		return setmetatable({}, {
			__eq = read,
			__lt = read,
			__le = read,
		})
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

	local configSource = FidelityManager.defaultConfig()
	local constructorConfigReads = 0
	local constructorMetatableConfig = setmetatable({}, {
		__index = function(_, key)
			constructorConfigReads += 1
			return configSource[key]
		end,
	})
	local constructorMetatableAccepted = pcall(function()
		FidelityManager.new(constructorMetatableConfig :: any)
	end)
	expectEqual("constructor rejects metatable-backed PolicyConfig", constructorMetatableAccepted, false)
	expectEqual("constructor rejects PolicyConfig before __index executes", constructorConfigReads, 0)

	local policyConfigReads = 0
	local policyMetatableConfig = setmetatable({}, {
		__index = function(_, key)
			policyConfigReads += 1
			return configSource[key]
		end,
	})
	local policyMetatableAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), policyMetatableConfig :: any, "F0")
	end)
	expectEqual("pure policy rejects metatable-backed PolicyConfig", policyMetatableAccepted, false)
	expectEqual("pure policy rejects PolicyConfig before __index executes", policyConfigReads, 0)

	local inertMetatableConfig = setmetatable(table.clone(configSource), {
		__metatable = "locked-policy-config",
	})
	local inertMetatableAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), inertMetatableConfig, "F0")
	end)
	expectEqual("pure policy rejects inert PolicyConfig metatable", inertMetatableAccepted, false)

	local hostileConfigReads = 0
	local hostileScalarConfig: any = table.clone(configSource)
	hostileScalarConfig.heroDistanceStuds = hostileComparable(function()
		hostileConfigReads += 1
	end)
	local hostileScalarConfigAccepted = pcall(function()
		FidelityManager.evaluatePolicy(validInputs(), hostileScalarConfig, "F0")
	end)
	expectEqual("pure policy rejects hostile PolicyConfig numeric scalar", hostileScalarConfigAccepted, false)
	expectEqual("PolicyConfig scalar validation never executes metamethod", hostileConfigReads, 0)

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
