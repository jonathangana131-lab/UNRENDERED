local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL fidelity {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS fidelity {name}`)
		end
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
		"significance keeps distant truth structural",
		FidelityManager.selectDesiredLevel(inputs({ significance = 1 })),
		"F1"
	)
	expectEqual(
		"unseen significance inside render range does not force hero",
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = 100, significance = 1 })),
		"F2"
	)
	expectEqual(
		"visible hero relevance can request hero fidelity",
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = 100, visible = true, significance = 1 })),
		"F4"
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

	local infiniteDistanceAccepted = pcall(function()
		FidelityManager.selectDesiredLevel(inputs({ distanceStuds = math.huge }))
	end)
	expectEqual("infinite physical distance rejected", infiniteDistanceAccepted, false)

	local infiniteConfig = table.clone(FidelityManager.defaultConfig())
	infiniteConfig.transitionCooldownSeconds = math.huge
	local infiniteConfigAccepted = pcall(function()
		FidelityManager.new(infiniteConfig)
	end)
	expectEqual("infinite timing config rejected", infiniteConfigAccepted, false)

	local overflowConfig = table.clone(FidelityManager.defaultConfig())
	overflowConfig.structuralDistanceStuds = 1e308
	overflowConfig.distanceHysteresisStuds = 1e308
	local overflowConfigAccepted = pcall(function()
		FidelityManager.new(overflowConfig)
	end)
	expectEqual("distance plus hysteresis overflow rejected", overflowConfigAccepted, false)

	expectEqual("registration safety ceiling is explicit", FidelityManager.MAX_REGISTERED_ENTITIES, 65536)
	expectEqual(
		"default registration budget stays below safety ceiling",
		FidelityManager.defaultConfig().maxRegisteredEntities < FidelityManager.MAX_REGISTERED_ENTITIES,
		true
	)
	local ceilingConfig = table.clone(FidelityManager.defaultConfig())
	ceilingConfig.maxRegisteredEntities = FidelityManager.MAX_REGISTERED_ENTITIES
	local ceilingConstructorAccepted = pcall(function()
		FidelityManager.new(ceilingConfig)
	end)
	expectEqual("exact registration safety ceiling accepted by constructor", ceilingConstructorAccepted, true)
	local ceilingPolicyAccepted = pcall(function()
		FidelityManager.evaluatePolicy(inputs(), ceilingConfig, "F0")
	end)
	expectEqual("exact registration safety ceiling accepted by pure policy", ceilingPolicyAccepted, true)

	local overCeilingConfig = table.clone(FidelityManager.defaultConfig())
	overCeilingConfig.maxRegisteredEntities = FidelityManager.MAX_REGISTERED_ENTITIES + 1
	local overCeilingConstructorAccepted = pcall(function()
		FidelityManager.new(overCeilingConfig)
	end)
	expectEqual(
		"registration safety ceiling plus one rejected by constructor",
		overCeilingConstructorAccepted,
		false
	)
	local overCeilingPolicyAccepted = pcall(function()
		FidelityManager.evaluatePolicy(inputs(), overCeilingConfig, "F0")
	end)
	expectEqual(
		"registration safety ceiling plus one rejected by pure policy",
		overCeilingPolicyAccepted,
		false
	)

	local timestampManager = FidelityManager.new()
	timestampManager:register("entity:finite-time", "F0")
	timestampManager:step("entity:finite-time", "F0", inputs(), 1)
	local infiniteTimestampAccepted = pcall(function()
		timestampManager:step("entity:finite-time", "F0", inputs(), math.huge)
	end)
	expectEqual("infinite step timestamp rejected", infiniteTimestampAccepted, false)
	local finiteTimestampAfterRejectionAccepted = pcall(function()
		timestampManager:step("entity:finite-time", "F0", inputs(), 2)
	end)
	expectEqual(
		"rejected infinite timestamp does not poison monotonic clock",
		finiteTimestampAfterRejectionAccepted,
		true
	)

	local entity = WorldEntity.new({
		id = "entity:fidelity-test",
		kind = "office-chair",
		origin = {
			worldId = "world:fidelity-test",
			regionId = "region:fidelity-test",
			generator = "tests.fidelity",
			generatorVersion = 1,
			recipeKey = "chair/01",
		},
		fidelity = "F3",
		persistentState = { hingeAngle = 0 },
	})

	local manager = FidelityManager.new()
	manager:register(entity.id, entity.fidelity)
	local demotionInputs = inputs({ distanceStuds = 60 })

	local result = manager:step(entity.id, entity.fidelity, demotionInputs, 0)
	expectEqual("demotion enters hold", result.blockedReason, "hold")
	expectEqual("manager observes authoritative F3", manager:getObservedLevel(entity.id), "F3")

	result = manager:step(entity.id, entity.fidelity, demotionInputs, 1.49)
	expectEqual("demotion hold is stable", result.blockedReason, "hold")

	result = manager:step(entity.id, entity.fidelity, demotionInputs, 1.5)
	expectEqual("transition hook required", result.blockedReason, "transition-required")
	expectEqual("missing hook cannot change manager state", manager:getObservedLevel(entity.id), "F3")

	local unsafeDemotionAccepted = pcall(function()
		manager:step(entity.id, entity.fidelity, demotionInputs, 1.5, function(_, _, toLevel)
			entity = WorldEntity.transition(entity, toLevel)
		end)
	end)
	expectEqual("WorldEntity rejects demotion without captured state", unsafeDemotionAccepted, false)
	expectEqual(
		"failed authoritative transition leaves manager at F3",
		manager:getObservedLevel(entity.id),
		"F3"
	)
	expectEqual("failed authoritative transition leaves entity at F3", entity.fidelity, "F3")

	result = manager:step(entity.id, entity.fidelity, demotionInputs, 1.5, function(_, fromLevel, toLevel)
		expectEqual(
			"transition runs before manager cache commit",
			manager:getObservedLevel(entity.id),
			fromLevel
		)
		entity = WorldEntity.transition(entity, toLevel, { hingeAngle = 17.5 })
	end)
	expectEqual("captured demotion commits", result.transitioned, true)
	expectEqual("WorldEntity becomes authoritative F2", entity.fidelity, "F2")
	expectEqual("manager mirrors committed F2", manager:getObservedLevel(entity.id), "F2")
	expectEqual("demotion captured durable state", entity.persistentState.hingeAngle, 17.5)

	local heroInputs = inputs({ distanceStuds = 10, directlyObserved = true })
	result = manager:step(entity.id, entity.fidelity, heroInputs, 1.6)
	expectEqual("promotion enters hold", result.blockedReason, "hold")

	result = manager:step(entity.id, entity.fidelity, heroInputs, 1.71, function(_, _, toLevel)
		entity = WorldEntity.transition(entity, toLevel)
	end)
	expectEqual("cooldown blocks rapid reversal", result.blockedReason, "cooldown")
	expectEqual("cooldown leaves WorldEntity unchanged", entity.fidelity, "F2")

	result = manager:step(entity.id, entity.fidelity, heroInputs, 1.76, function(_, _, toLevel)
		entity = WorldEntity.transition(entity, toLevel)
	end)
	expectEqual("promotion commits after cooldown", result.transitioned, true)
	expectEqual("promotion reaches hero in WorldEntity", entity.fidelity, "F4")
	expectEqual("manager mirrors hero fidelity", manager:getObservedLevel(entity.id), "F4")

	entity = WorldEntity.transition(entity, "F1", { hingeAngle = 4 })
	result = manager:step(entity.id, entity.fidelity, inputs(), 2)
	expectEqual("external lifecycle change is synchronized", manager:getObservedLevel(entity.id), "F1")
	expectEqual("external sync starts a demotion hold", result.blockedReason, "hold")

	local metrics = manager:getMetrics()
	expectEqual("metrics transition count", metrics.transitions, 2)
	expectEqual("metrics promotion count", metrics.promotions, 1)
	expectEqual("metrics demotion count", metrics.demotions, 1)
	expectEqual("metrics successful transition hooks", metrics.transitionHookCalls, 2)
	expectEqual("metrics missing transition blocks", metrics.blockedByMissingTransition, 1)
	expectEqual("metrics external synchronization", metrics.externalSynchronizations, 1)
	expectEqual("metrics current structural count", metrics.counts.F1, 1)

	local duplicateRegistrationAccepted = pcall(function()
		manager:register(entity.id, entity.fidelity)
	end)
	expectEqual("duplicate manager registration rejected", duplicateRegistrationAccepted, false)

	manager:unregister(entity.id)
	metrics = manager:getMetrics()
	expectEqual("unregister removes record", metrics.registered, 0)
	expectEqual("unregister updates fidelity counts", metrics.counts.F1, 0)

	local capacityConfig = table.clone(FidelityManager.defaultConfig())
	capacityConfig.maxRegisteredEntities = 1
	local capacityManager = FidelityManager.new(capacityConfig)
	capacityManager:register("entity:capacity-a", "F0")
	local overCapacityAccepted = pcall(function()
		capacityManager:register("entity:capacity-b", "F0")
	end)
	expectEqual("registered state is hard bounded", overCapacityAccepted, false)
	expectEqual(
		"capacity rejection is observable",
		capacityManager:getMetrics().registrationCapacityRejections,
		1
	)

	local stableTargetEntity = WorldEntity.new({
		id = "entity:stable-target",
		kind = "office-chair",
		origin = {
			worldId = "world:fidelity-test",
			regionId = "region:fidelity-test",
			generator = "tests.fidelity",
			generatorVersion = 1,
			recipeKey = "chair/stable-target",
		},
	})
	local stableTargetManager = FidelityManager.new()
	stableTargetManager:register(stableTargetEntity.id, stableTargetEntity.fidelity)

	local stableResult = stableTargetManager:step(
		stableTargetEntity.id,
		stableTargetEntity.fidelity,
		inputs({ networkRelevance = 0.9 }),
		0
	)
	expectEqual("stable target starts promotion hold", stableResult.blockedReason, "hold")

	stableResult = stableTargetManager:step(
		stableTargetEntity.id,
		stableTargetEntity.fidelity,
		inputs({ directlyObserved = true }),
		0.05
	)
	expectEqual("changed cause preserves same target hold", stableResult.blockedReason, "hold")

	stableResult = stableTargetManager:step(
		stableTargetEntity.id,
		stableTargetEntity.fidelity,
		inputs({ networkRelevance = 0.9 }),
		0.11,
		function(_, _, toLevel)
			stableTargetEntity = WorldEntity.transition(stableTargetEntity, toLevel)
		end
	)
	expectEqual("same target matures despite changed causes", stableResult.transitioned, true)
	expectEqual("stable target reaches interactive", stableTargetEntity.fidelity, "F3")

	local nestedConfig = table.clone(FidelityManager.defaultConfig())
	nestedConfig.promotionHoldSeconds = 0
	nestedConfig.transitionCooldownSeconds = 0
	local nestedManager = FidelityManager.new(nestedConfig)
	local outerId = "entity:nested-transition-outer"
	local innerId = "entity:nested-transition-inner"
	nestedManager:register(outerId, "F0")
	nestedManager:register(innerId, "F0")
	local nestedHeroInputs = inputs({ distanceStuds = 10, directlyObserved = true })

	local nestedFailureAccepted = pcall(function()
		nestedManager:step(outerId, "F0", nestedHeroInputs, 0, function()
			nestedManager:step(innerId, "F0", nestedHeroInputs, 0, function()
				nestedManager:step(outerId, "F0", nestedHeroInputs, 0, function() end)
			end)
		end)
	end)
	expectEqual(
		"nested callback cannot reenter already-transitioning outer entity",
		nestedFailureAccepted,
		false
	)
	expectEqual(
		"nested failure leaves outer fidelity uncommitted",
		nestedManager:getObservedLevel(outerId),
		"F0"
	)
	expectEqual(
		"nested failure leaves inner fidelity uncommitted",
		nestedManager:getObservedLevel(innerId),
		"F0"
	)
	local nestedFailureMetrics = nestedManager:getMetrics()
	expectEqual("nested failure preserves registrations", nestedFailureMetrics.registered, 2)
	expectEqual("nested failure preserves F0 accounting", nestedFailureMetrics.counts.F0, 2)
	expectEqual("nested failure leaves F4 accounting empty", nestedFailureMetrics.counts.F4, 0)
	expectEqual(
		"nested failure counts no successful transition hooks",
		nestedFailureMetrics.transitionHookCalls,
		0
	)
	expectEqual("nested failure counts no transitions", nestedFailureMetrics.transitions, 0)

	local innerRetryHookCalled = false
	local nestedRetryAccepted = pcall(function()
		local outerRetryResult = nestedManager:step(outerId, "F0", nestedHeroInputs, 0.1, function()
			local innerRetryResult = nestedManager:step(innerId, "F0", nestedHeroInputs, 0.1, function()
				innerRetryHookCalled = true
			end)
			expectEqual("nested inner retry commits after unwind", innerRetryResult.transitioned, true)
		end)
		expectEqual("nested outer retry commits after unwind", outerRetryResult.transitioned, true)
	end)
	expectEqual("nested failure clears both transition fences for retry", nestedRetryAccepted, true)
	expectEqual("nested retry invokes inner transition hook", innerRetryHookCalled, true)
	expectEqual("nested retry commits outer hero fidelity", nestedManager:getObservedLevel(outerId), "F4")
	expectEqual("nested retry commits inner hero fidelity", nestedManager:getObservedLevel(innerId), "F4")
	local nestedRetryMetrics = nestedManager:getMetrics()
	expectEqual("nested retry preserves registrations", nestedRetryMetrics.registered, 2)
	expectEqual("nested retry drains F0 accounting", nestedRetryMetrics.counts.F0, 0)
	expectEqual("nested retry commits both F4 counts", nestedRetryMetrics.counts.F4, 2)
	expectEqual("nested retry counts both successful hooks", nestedRetryMetrics.transitionHookCalls, 2)
	expectEqual("nested retry counts both transitions", nestedRetryMetrics.transitions, 2)
	expectEqual("nested retry counts both promotions", nestedRetryMetrics.promotions, 2)

	return failures
end

return run
