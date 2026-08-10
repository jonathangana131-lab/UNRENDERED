local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectTrue(name, value)
		expectEqual(name, value, true)
	end

	local function cloneInput(source)
		return table.clone(source)
	end

	local farIdle = {
		distanceStuds = 900,
		isVisible = false,
		observationStrength = 0,
		secondsSinceInteraction = nil,
		significance = 0,
		networkRelevance = 0,
		isMoving = false,
		entityRelevance = 0,
	}
	expectEqual(
		"fidelity policy leaves irrelevant distant entity at F0",
		FidelityManager.evaluateTarget(farIdle),
		"F0"
	)

	local visible = cloneInput(farIdle)
	visible.distanceStuds = 120
	visible.isVisible = true
	expectEqual(
		"visible nearby entity reaches render fidelity",
		FidelityManager.evaluateTarget(visible),
		"F2"
	)

	local interactive = cloneInput(visible)
	interactive.distanceStuds = 60
	interactive.secondsSinceInteraction = 3
	expectEqual(
		"recently interacted entity reaches interactive fidelity",
		FidelityManager.evaluateTarget(interactive),
		"F3"
	)

	local hero = cloneInput(interactive)
	hero.distanceStuds = 12
	hero.secondsSinceInteraction = 0.5
	expectEqual(
		"very recent close interaction reaches hero fidelity",
		FidelityManager.evaluateTarget(hero),
		"F4"
	)

	local networkRelevant = cloneInput(farIdle)
	networkRelevant.networkRelevance = 0.8
	expectEqual(
		"network relevance can retain render fidelity at distance",
		FidelityManager.evaluateTarget(networkRelevant),
		"F2"
	)

	local eventOrder = {}
	local lifecycleRegistry = WorldEntity.createRegistry()
	local worldEntity = WorldEntity.new({
		id = "entity:test",
		kind = "object",
		origin = {
			worldId = "world:fixture",
			generator = "FidelityFixture",
			generatorVersion = 1,
			recipeKey = "fidelity/entity-test",
		},
		fidelity = "F1",
	})
	WorldEntity.register(lifecycleRegistry, worldEntity)

	local manager = FidelityManager.new({
		promotionHoldSeconds = 0.2,
		demotionHoldSeconds = 1,
		transitionCooldownSeconds = 0.5,
	}, {
		captureBeforeDemotion = function(entityId, from, to)
			table.insert(eventOrder, `capture:{entityId}:{from}->{to}`)
			return {
				mechanism = "settled",
			}
		end,
		applyTransition = function(entityId, from, to, capturedState)
			if capturedState ~= nil then
				table.insert(eventOrder, `apply:{entityId}:{from}->{to}:{capturedState.mechanism}`)
			else
				table.insert(eventOrder, `apply:{entityId}:{from}->{to}`)
			end

			local current = WorldEntity.get(lifecycleRegistry, entityId)
			assert(current ~= nil, `missing lifecycle record for {entityId}`)
			WorldEntity.unregister(lifecycleRegistry, entityId)
			WorldEntity.register(lifecycleRegistry, WorldEntity.transition(current, to, capturedState))
		end,
	})

	manager:register("entity:test", "F1")

	local firstPromotion = manager:request("entity:test", "F3", "near_observer", 10)
	expectEqual("promotion starts hysteresis instead of thrashing", firstPromotion.blockedBy, "hysteresis")
	expectEqual("fidelity remains stable during promotion hold", manager:getFidelity("entity:test"), "F1")

	local secondPromotion = manager:request("entity:test", "F3", "near_observer", 10.25)
	expectTrue("promotion commits after stable hold", secondPromotion.changed)
	expectEqual("promotion reaches requested fidelity", manager:getFidelity("entity:test"), "F3")
	expectEqual(
		"WorldEntity lifecycle receives committed promotion",
		WorldEntity.get(lifecycleRegistry, "entity:test").fidelity,
		"F3"
	)

	local firstHeroRequest = manager:request("entity:test", "F4", "hero_detail", 10.3)
	expectEqual("new higher target starts promotion hysteresis", firstHeroRequest.blockedBy, "hysteresis")
	local cooldownPromotion = manager:request("entity:test", "F4", "hero_detail", 10.55)
	expectEqual("transition cooldown blocks rapid promotion churn", cooldownPromotion.blockedBy, "cooldown")

	local firstDemotion = manager:request("entity:test", "F1", "observer_departed", 10.6)
	expectEqual("demotion starts its longer hysteresis", firstDemotion.blockedBy, "hysteresis")
	local heldDemotion = manager:request("entity:test", "F1", "observer_departed", 11.5)
	expectEqual(
		"demotion remains held until its stability window completes",
		heldDemotion.blockedBy,
		"hysteresis"
	)

	local demotion = manager:request("entity:test", "F1", "observer_departed", 11.65)
	expectTrue("demotion commits after stable hold", demotion.changed)
	expectEqual("demotion reaches requested fidelity", manager:getFidelity("entity:test"), "F1")
	local demotedEntity = WorldEntity.get(lifecycleRegistry, "entity:test")
	assert(demotedEntity ~= nil, "demoted entity must remain registered")
	expectEqual("WorldEntity lifecycle receives committed demotion", demotedEntity.fidelity, "F1")
	expectEqual(
		"captured state reaches WorldEntity persistent state",
		demotedEntity.persistentState.mechanism,
		"settled"
	)
	expectEqual("demotion captures state before transition", eventOrder[2], "capture:entity:test:F3->F1")
	expectEqual(
		"demotion applies captured state after capture",
		eventOrder[3],
		"apply:entity:test:F3->F1:settled"
	)

	local metrics = manager:getMetrics()
	expectEqual("metrics count registered entities", metrics.registered, 1)
	expectEqual("metrics count current F1 entities", metrics.counts.F1, 1)
	expectEqual("metrics count promotions", metrics.promotions, 1)
	expectEqual("metrics count demotions", metrics.demotions, 1)
	expectEqual("metrics count cooldown blocks", metrics.cooldownBlocks, 1)
	expectEqual(
		"metrics retain diagnostic transition reason",
		metrics.lastTransitionReason["entity:test"],
		"observer_departed"
	)

	local deterministicA = FidelityManager.evaluateTarget(interactive)
	local deterministicB = FidelityManager.evaluateTarget(interactive)
	expectEqual("identical fidelity policy inputs are deterministic", deterministicA, deterministicB)

	local failingManager = FidelityManager.new({
		promotionHoldSeconds = 0,
		demotionHoldSeconds = 0,
		transitionCooldownSeconds = 0,
	}, {
		captureBeforeDemotion = function()
			error("capture unavailable")
		end,
		applyTransition = function() end,
	})
	failingManager:register("entity:capture-failure", "F3")
	failingManager:request("entity:capture-failure", "F1", "sleep", 1)
	local blockedDemotion = failingManager:request("entity:capture-failure", "F1", "sleep", 1)
	expectEqual("failed state capture blocks demotion", blockedDemotion.blockedBy, "capture_failed")
	expectEqual(
		"failed state capture preserves current fidelity",
		failingManager:getFidelity("entity:capture-failure"),
		"F3"
	)
	expectEqual("capture failure is observable in metrics", failingManager:getMetrics().captureFailures, 1)

	manager:unregister("entity:test")
	local afterUnregister = manager:getMetrics()
	expectEqual("unregister removes per-entity metrics", afterUnregister.registered, 0)
	expectEqual(
		"unregister clears last transition reason",
		afterUnregister.lastTransitionReason["entity:test"],
		nil
	)

	return failures
end

return run
