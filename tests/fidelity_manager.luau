local FidelityManager = require("../src/shared/Physics/FidelityManager")

return function(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL fidelity {name}: expected {tostring(expected)}, got {tostring(actual)}`)
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
			observationStrength = 0,
			secondsSinceInteraction = math.huge,
			significance = 0,
			networkRelevance = 0,
		}
		for key, override in overrides or {} do
			value[key] = override
		end
		return value
	end

	local decision = FidelityManager.evaluate(inputs())
	expectEqual("far entity stays potential", decision.level, "F0")
	expectEqual("potential decision exposes reason", decision.reason, "potential")

	decision = FidelityManager.evaluate(inputs({ distanceStuds = 500 }))
	expectEqual("structural distance selects F1", decision.level, "F1")
	expectEqual("structural distance reason", decision.reason, "distance-structural")

	decision = FidelityManager.evaluate(inputs({ distanceStuds = 200 }))
	expectEqual("render distance selects F2", decision.level, "F2")
	decision = FidelityManager.evaluate(inputs({ distanceStuds = 40 }))
	expectEqual("interactive distance selects F3", decision.level, "F3")
	decision = FidelityManager.evaluate(inputs({ significance = 1 }))
	expectEqual("significance keeps distant truth structural", decision.level, "F1")
	expectEqual("significance reason", decision.reason, "significance")
	decision = FidelityManager.evaluate(inputs({ networkRelevance = 0.9 }))
	expectEqual("network relevance selects interactive", decision.level, "F3")
	expectEqual("network relevance reason", decision.reason, "network-relevance")
	decision = FidelityManager.evaluate(inputs({ distanceStuds = 10, observationStrength = 0.8 }))
	expectEqual("close strong observation selects hero", decision.level, "F4")
	expectEqual("hero observation reason", decision.reason, "observation")

	decision = FidelityManager.evaluate(inputs(), nil, nil, {
		level = "F4",
		mode = "at-least",
		reason = "explicit-grip-demand",
	})
	expectEqual("at-least request promotes policy result", decision.level, "F4")
	expectEqual("request reason preserved", decision.reason, "explicit-grip-demand")

	decision = FidelityManager.evaluate(inputs({ distanceStuds = 10, observationStrength = 1 }), nil, nil, {
		level = "F1",
		mode = "at-most",
		reason = "explicit-budget-cap",
	})
	expectEqual("at-most request caps policy result", decision.level, "F1")
	expectEqual("cap request reason preserved", decision.reason, "explicit-budget-cap")

	local repeatA = FidelityManager.evaluate(inputs({ distanceStuds = 17, observationStrength = 0.8 }), nil, "F3")
	local repeatB = FidelityManager.evaluate(inputs({ distanceStuds = 17, observationStrength = 0.8 }), nil, "F3")
	expectEqual("policy level deterministic for identical input", repeatA.level, repeatB.level)
	expectEqual("policy reason deterministic for identical input", repeatA.reason, repeatB.reason)

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

	local events = {}
	local manager = FidelityManager.new(nil, {
		captureBeforeDemotion = function(entityId, fromLevel, toLevel)
			table.insert(events, `capture:{entityId}:{fromLevel}:{toLevel}`)
		end,
		applyTransition = function(entityId, fromLevel, toLevel, reason)
			table.insert(events, `apply:{entityId}:{fromLevel}:{toLevel}:{reason}`)
		end,
	})
	manager:register("entity/a", "F3")

	local demotionInputs = inputs({ distanceStuds = 60 })
	local result = manager:step("entity/a", demotionInputs, 0)
	expectEqual("demotion enters hold", result.blockedReason, "hold")
	expectEqual("hold preserves level", manager:getLevel("entity/a"), "F3")
	result = manager:step("entity/a", demotionInputs, 1.49)
	expectEqual("demotion hold is stable", result.blockedReason, "hold")
	result = manager:step("entity/a", demotionInputs, 1.5)
	expectTrue("demotion commits after capture", result.changed)
	expectEqual("demotion reaches render", manager:getLevel("entity/a"), "F2")
	expectEqual("capture runs before realization", events[1], "capture:entity/a:F3:F2")
	expectEqual("realization receives transition reason", events[2], "apply:entity/a:F3:F2:distance-render")

	local heroInputs = inputs({ distanceStuds = 10, observationStrength = 0.8 })
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
	expectEqual("metrics current hero count", metrics.counts.F4, 1)

	local unsafe = FidelityManager.new()
	unsafe:register("entity/unsafe", "F3")
	unsafe:step("entity/unsafe", demotionInputs, 0)
	local unsafeResult = unsafe:step("entity/unsafe", demotionInputs, 2)
	expectEqual("demotion without capture is rejected", unsafeResult.blockedReason, "capture-required")
	expectEqual("capture gate preserves source level", unsafe:getLevel("entity/unsafe"), "F3")
	expectEqual("capture block metric", unsafe:getMetrics().blockedByCapture, 1)

	local duplicateOk = pcall(function()
		manager:register("entity/a")
	end)
	expectEqual("duplicate manager registration rejected", duplicateOk, false)

	manager:unregister("entity/a")
	metrics = manager:getMetrics()
	expectEqual("unregister removes record", metrics.registered, 0)
	expectEqual("unregister updates fidelity counts", metrics.counts.F4, 0)

	local nanAccepted = pcall(function()
		FidelityManager.evaluate(inputs({ observationStrength = 0 / 0 }))
	end)
	expectEqual("NaN policy input rejected", nanAccepted, false)

	return failures
end
