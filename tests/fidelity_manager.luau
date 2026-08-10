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

	expectEqual(
		"visible policy reason is explicit",
		FidelityManager.selectDecision(inputs({ visible = true })).reason,
		"visibility"
	)
	expectEqual(
		"network policy reason is explicit",
		FidelityManager.selectDecision(inputs({ networkRelevance = 0.9 })).reason,
		"network-relevance"
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

	local demotionReason
	result = manager:step(
		entity.id,
		entity.fidelity,
		demotionInputs,
		1.5,
		function(_, fromLevel, toLevel, reason)
			demotionReason = reason
			expectEqual(
				"transition runs before manager cache commit",
				manager:getObservedLevel(entity.id),
				fromLevel
			)
			entity = WorldEntity.transition(entity, toLevel, { hingeAngle = 17.5 })
		end
	)
	expectEqual("captured demotion commits", result.transitioned, true)
	expectEqual("demotion callback receives reason", demotionReason, "distance")
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

	local infiniteCapacityConfig = table.clone(FidelityManager.defaultConfig())
	infiniteCapacityConfig.maxRegisteredEntities = math.huge
	local infiniteCapacityAccepted = pcall(function()
		FidelityManager.new(infiniteCapacityConfig)
	end)
	expectEqual("infinite registration capacity rejected", infiniteCapacityAccepted, false)

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
	expectEqual("first stable-target reason", stableResult.reason, "network-relevance")

	stableResult = stableTargetManager:step(
		stableTargetEntity.id,
		stableTargetEntity.fidelity,
		inputs({ directlyObserved = true }),
		0.05
	)
	expectEqual("changed cause preserves same target hold", stableResult.blockedReason, "hold")
	expectEqual("reason can change without resetting hold", stableResult.reason, "observation")

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
	expectEqual("matured transition reports current reason", stableResult.reason, "network-relevance")
	expectEqual("stable target reaches interactive", stableTargetEntity.fidelity, "F3")

	local infiniteTimeAccepted = pcall(function()
		stableTargetManager:step(stableTargetEntity.id, stableTargetEntity.fidelity, inputs(), math.huge)
	end)
	expectEqual("non-finite evaluation time rejected", infiniteTimeAccepted, false)

	local deterministicConfig = table.clone(FidelityManager.defaultConfig())
	deterministicConfig.promotionHoldSeconds = 0
	deterministicConfig.demotionHoldSeconds = 0
	deterministicConfig.transitionCooldownSeconds = 0
	local deterministicA = FidelityManager.new(deterministicConfig)
	local deterministicB = FidelityManager.new(deterministicConfig)
	deterministicA:register("entity:deterministic", "F0")
	deterministicB:register("entity:deterministic", "F0")
	local deterministicInputs = inputs({ distanceStuds = 100 })
	local resultA = deterministicA:step(
		"entity:deterministic",
		"F0",
		deterministicInputs,
		10,
		function() end
	)
	local resultB = deterministicB:step(
		"entity:deterministic",
		"F0",
		deterministicInputs,
		10,
		function() end
	)
	expectEqual("identical transition target is deterministic", resultA.desiredLevel, resultB.desiredLevel)
	expectEqual("identical transition reason is deterministic", resultA.reason, resultB.reason)
	expectEqual("identical transition outcome is deterministic", resultA.transitioned, resultB.transitioned)
	expectEqual(
		"identical transition metrics are deterministic",
		deterministicA:getMetrics().transitions,
		deterministicB:getMetrics().transitions
	)

	return failures
end

return run
