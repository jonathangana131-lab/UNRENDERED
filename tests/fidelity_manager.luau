local FidelityManager = require("../src/shared/Physics/FidelityManager")

return function()
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL fidelity {name}: expected {expected}, got {actual}`)
		else
			print(`PASS fidelity {name}`)
		end
	end

	local function expectTrue(name, value)
		expectEqual(name, value, true)
	end

	local function inputs(overrides)
		local value = {
			distanceStuds = 900,
			visible = false,
			directlyObserved = false,
			secondsSinceInteraction = math.huge,
			significance = 0,
			networkRelevance = 0,
			entityRelevance = 0,
		}
		for key, override in overrides or {} do
			value[key] = override
		end
		return value
	end

	expectEqual("far entity stays potential", FidelityManager.selectDesiredLevel(inputs()), "F0")
	expectEqual(
		"visible entity renders despite distance",
		FidelityManager.selectDesiredLevel(inputs({ visible = true })),
		"F2"
	)
	expectEqual(
		"significance keeps data structural not hero",
		FidelityManager.selectDesiredLevel(inputs({ significance = 1 })),
		"F1"
	)
	expectEqual(
		"close observed entity requests hero fidelity",
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = 10, directlyObserved = true })),
		"F4"
	)
	expectEqual(
		"distance hysteresis retains interactive level",
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = 52 }), nil, "F3"),
		"F3"
	)
	expectEqual(
		"same distance does not promote lower level",
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = 52 }), nil, "F2"),
		"F2"
	)

	local manager = FidelityManager.new()
	manager:register("entity/a", "F3")

	local demotionInputs = inputs({ distanceStuds = 60 })
	local result = manager:step("entity/a", demotionInputs, 0)
	expectEqual("demotion enters hold", result.blockedReason, "hold")
	expectEqual("hold preserves level", manager:getLevel("entity/a"), "F3")

	result = manager:step("entity/a", demotionInputs, 1.49)
	expectEqual("demotion hold is stable", result.blockedReason, "hold")

	result = manager:step("entity/a", demotionInputs, 1.5)
	expectEqual("demotion requires capture", result.blockedReason, "capture-required")
	expectEqual("capture gate preserves level", manager:getLevel("entity/a"), "F3")

	local captured = false
	result = manager:step("entity/a", demotionInputs, 1.5, function(entityId, fromLevel, toLevel)
		captured = entityId == "entity/a" and fromLevel == "F3" and toLevel == "F2"
	end)
	expectTrue("capture runs before demotion commit", captured)
	expectTrue("demotion commits after capture", result.changed)
	expectEqual("demotion reaches render", manager:getLevel("entity/a"), "F2")

	local heroInputs = inputs({ distanceStuds = 10, directlyObserved = true })
	result = manager:step("entity/a", heroInputs, 1.6)
	expectEqual("promotion enters hold", result.blockedReason, "hold")

	result = manager:step("entity/a", heroInputs, 1.71)
	expectEqual("cooldown blocks rapid retrigger", result.blockedReason, "cooldown")

	result = manager:step("entity/a", heroInputs, 1.76)
	expectTrue("promotion commits after cooldown", result.changed)
	expectEqual("promotion reaches hero", manager:getLevel("entity/a"), "F4")

	local metrics = manager:getMetrics()
	expectEqual("metrics transition count", metrics.transitions, 2)
	expectEqual("metrics promotion count", metrics.promotions, 1)
	expectEqual("metrics demotion count", metrics.demotions, 1)
	expectEqual("metrics capture count", metrics.captureCalls, 1)
	expectEqual("metrics capture block count", metrics.blockedByCapture, 1)
	expectEqual("metrics current hero count", metrics.counts.F4, 1)

	local duplicateOk = pcall(function()
		manager:register("entity/a")
	end)
	expectEqual("duplicate manager registration rejected", duplicateOk, false)

	manager:unregister("entity/a")
	metrics = manager:getMetrics()
	expectEqual("unregister removes record", metrics.registered, 0)
	expectEqual("unregister updates fidelity counts", metrics.counts.F4, 0)

	return failures
end
