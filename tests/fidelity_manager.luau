local FidelityManager = require("../src/shared/Physics/FidelityManager")

local function run()
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {expected}, got {actual}`)
		else
			print(`PASS {name}`)
		end
	end

	local farUnobserved = {
		distanceStuds = 1000,
		observed = false,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
		isMoving = false,
	}

	local targetA, reasonA = FidelityManager.evaluateTarget("F0", farUnobserved)
	local targetB, reasonB = FidelityManager.evaluateTarget("F0", farUnobserved)
	expectEqual("policy deterministic target", targetA, targetB)
	expectEqual("policy deterministic reason", reasonA, reasonB)
	expectEqual("far unobserved remains potential", targetA, "F0")

	local nearRelevant = {
		distanceStuds = 12,
		observed = true,
		secondsSinceInteraction = 0.5,
		significance = 0.2,
		networkRelevance = 0.1,
		isMoving = true,
	}
	local heroTarget = FidelityManager.evaluateTarget("F0", nearRelevant)
	expectEqual("near interacted object promotes hero", heroTarget, "F4")

	local hysteresisInput = {
		distanceStuds = FidelityManager.DEFAULT_CONFIG.renderDistanceStuds + 6,
		observed = true,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
		isMoving = false,
	}
	local retainedRender = FidelityManager.evaluateTarget("F2", hysteresisInput)
	local freshTarget = FidelityManager.evaluateTarget("F1", hysteresisInput)
	expectEqual("render hysteresis retains F2 near boundary", retainedRender, "F2")
	expectEqual("render hysteresis does not pull fresh entity in", freshTarget, "F1")

	local registry = FidelityManager.newRegistry()
	FidelityManager.register(registry, "world-entity:test", "F2", 0)

	local callOrder = {}
	local adapter = {
		captureState = function(_entityId, _fromLevel, _toLevel)
			table.insert(callOrder, "capture")
			return { pose = "settled" }
		end,
		applyTransition = function(_entityId, _fromLevel, _toLevel, _snapshot)
			table.insert(callOrder, "apply")
		end,
	}

	local demotion = FidelityManager.request(registry, "world-entity:test", "F1", 2, "test-demotion", adapter)
	expectEqual("demotion changed", demotion.changed, true)
	expectEqual("demotion captures before apply", table.concat(callOrder, ","), "capture,apply")
	expectEqual("demotion target stored", FidelityManager.getState(registry, "world-entity:test").level, "F1")

	local blocked = FidelityManager.request(registry, "world-entity:test", "F0", 2.25, "too-soon", adapter)
	expectEqual("demotion cooldown blocks thrash", blocked.blockedReason, "cooldown")
	expectEqual("cooldown preserves level", FidelityManager.getState(registry, "world-entity:test").level, "F1")

	local metrics = FidelityManager.getMetrics(registry)
	expectEqual("metrics transition count", metrics.transitions, 1)
	expectEqual("metrics demotion count", metrics.demotions, 1)
	expectEqual("metrics cooldown count", metrics.blockedByCooldown, 1)
	expectEqual("metrics F1 count", metrics.counts.F1, 1)

	return failures
end

return run
