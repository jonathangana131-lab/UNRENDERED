local FidelityManager = require("../src/shared/Physics/FidelityManager")

local function run(): number
	local failures = 0

	local function expectEqual(name: string, actual: any, expected: any)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectTrue(name: string, value: boolean)
		if not value then
			failures += 1
			print(`FAIL {name}`)
		else
			print(`PASS {name}`)
		end
	end

	local farInput = {
		distanceStuds = 2000,
		observationStrength = 0,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
	}
	local observedInput = {
		distanceStuds = 80,
		observationStrength = 0.8,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
	}
	local heroInput = {
		distanceStuds = 10,
		observationStrength = 1,
		secondsSinceInteraction = 0.2,
		significance = 0.2,
		networkRelevance = 0.2,
	}

	local farLevel, farReason = FidelityManager.evaluate(farInput)
	expectEqual("far entity remains potential", farLevel, "F0")
	expectEqual("far entity reason", farReason, "potential")

	local observedLevel = FidelityManager.evaluate(observedInput)
	expectEqual("strong nearby observation is interactive", observedLevel, "F3")

	local heroLevel = FidelityManager.evaluate(heroInput)
	expectEqual("near recent interaction is hero fidelity", heroLevel, "F4")

	local requestedLevel, requestedReason = FidelityManager.evaluate(farInput, nil, {
		level = "F3",
		mode = "at-least",
		reason = "radio-session",
	})
	expectEqual("at-least request promotes target", requestedLevel, "F3")
	expectEqual("request reason is preserved", requestedReason, "radio-session")

	local cappedLevel, cappedReason = FidelityManager.evaluate(heroInput, nil, {
		level = "F2",
		mode = "at-most",
		reason = "server-budget",
	})
	expectEqual("at-most request caps target", cappedLevel, "F2")
	expectEqual("cap reason is preserved", cappedReason, "server-budget")

	local repeatLevel, repeatReason = FidelityManager.evaluate(observedInput)
	local repeatLevel2, repeatReason2 = FidelityManager.evaluate(observedInput)
	expectEqual("policy level is deterministic", repeatLevel, repeatLevel2)
	expectEqual("policy reason is deterministic", repeatReason, repeatReason2)

	local invalidOk = pcall(function()
		FidelityManager.evaluate({
			distanceStuds = -1,
			observationStrength = 0,
			secondsSinceInteraction = 0,
			significance = 0,
			networkRelevance = 0,
		})
	end)
	expectEqual("invalid policy input is rejected", invalidOk, false)

	local config = table.clone(FidelityManager.defaultConfig())
	config.promotionHoldSeconds = 0
	config.demotionHoldSeconds = 0.5
	config.transitionCooldownSeconds = 0.25

	local callbackOrder = {}
	local manager = FidelityManager.new(config, {
		captureBeforeDemotion = function(entityId, fromLevel, toLevel)
			table.insert(callbackOrder, `capture:{entityId}:{fromLevel}>{toLevel}`)
			return { sleeping = true }
		end,
		applyTransition = function(entityId, fromLevel, toLevel, capturedState)
			local stateTag = if capturedState == nil then "none" else "captured"
			table.insert(callbackOrder, `apply:{entityId}:{fromLevel}>{toLevel}:{stateTag}`)
		end,
	})

	FidelityManager.register(manager, "entity:test-chair", "F0", 0)
	local promotion = FidelityManager.update(manager, "entity:test-chair", heroInput, 0)
	expectEqual("promotion reaches requested policy level", promotion.level, "F4")
	expectEqual("promotion transitions immediately with zero hold", promotion.transitioned, true)

	local firstDemotion = FidelityManager.update(manager, "entity:test-chair", farInput, 0.1)
	expectEqual("demotion waits for hysteresis", firstDemotion.blockedByHysteresis, true)
	expectEqual("hysteresis preserves current level", firstDemotion.level, "F4")

	local demotion = FidelityManager.update(manager, "entity:test-chair", farInput, 0.6)
	expectEqual("stable demotion eventually transitions", demotion.level, "F0")
	expectEqual("stable demotion reports transition", demotion.transitioned, true)
	expectEqual("demotion capture runs before realization", callbackOrder[2], "capture:entity:test-chair:F4>F0")
	expectEqual("realization receives captured state", callbackOrder[3], "apply:entity:test-chair:F4>F0:captured")

	local snapshot = FidelityManager.getSnapshot(manager, "entity:test-chair")
	expectTrue("captured state survives representation demotion", snapshot ~= nil and snapshot.capturedState ~= nil)

	local metrics = FidelityManager.getMetrics(manager)
	expectEqual("metrics track registrations", metrics.registeredEntities, 1)
	expectEqual("metrics track current F0 count", metrics.levelCounts.F0, 1)
	expectEqual("metrics track transitions", metrics.transitions, 2)
	expectEqual("metrics split promotions", metrics.promotions, 1)
	expectEqual("metrics split demotions", metrics.demotions, 1)
	expectTrue("metrics expose hysteresis pressure", metrics.hysteresisBlocks >= 1)

	local cooldownConfig = table.clone(FidelityManager.defaultConfig())
	cooldownConfig.promotionHoldSeconds = 0
	cooldownConfig.demotionHoldSeconds = 0
	cooldownConfig.transitionCooldownSeconds = 1
	local cooldownManager = FidelityManager.new(cooldownConfig)
	FidelityManager.register(cooldownManager, "entity:cooldown", "F0", 0)
	local renderInput = {
		distanceStuds = 100,
		observationStrength = 0,
		secondsSinceInteraction = 100,
		significance = 0,
		networkRelevance = 0,
	}
	FidelityManager.update(cooldownManager, "entity:cooldown", renderInput, 0)
	local cooldownResult = FidelityManager.update(cooldownManager, "entity:cooldown", farInput, 0.1)
	expectEqual("cooldown blocks immediate reversal", cooldownResult.blockedByCooldown, true)
	expectEqual("cooldown preserves rendered level", cooldownResult.level, "F2")
	expectEqual("cooldown metric increments", FidelityManager.getMetrics(cooldownManager).cooldownBlocks, 1)

	local unregisterSnapshot = FidelityManager.unregister(manager, "entity:test-chair")
	expectTrue("unregister returns final snapshot", unregisterSnapshot ~= nil)
	expectEqual("unregister decrements tracked count", FidelityManager.getMetrics(manager).registeredEntities, 0)

	return failures
end

return run
