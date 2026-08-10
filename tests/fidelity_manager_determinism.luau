local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL fidelity determinism {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS fidelity determinism {name}`)
		end
	end

	local function policyInputs(overrides)
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

	local function runSequence(entityId)
		local entity = WorldEntity.new({
			id = entityId,
			kind = "office-chair",
			origin = {
				worldId = "world:fidelity-determinism",
				regionId = "region:fidelity-determinism",
				generator = "tests.fidelity-determinism",
				generatorVersion = 1,
				recipeKey = "chair/stable-target",
			},
		})
		local manager = FidelityManager.new()
		manager:register(entity.id, entity.fidelity)

		local results = {}
		local transitionReason = nil

		results[1] = manager:step(entity.id, entity.fidelity, policyInputs({ networkRelevance = 0.9 }), 0)
		results[2] = manager:step(entity.id, entity.fidelity, policyInputs({ directlyObserved = true }), 0.05)
		results[3] = manager:step(
			entity.id,
			entity.fidelity,
			policyInputs({ networkRelevance = 0.9 }),
			0.11,
			function(_, _, toLevel, reason)
				transitionReason = reason
				entity = WorldEntity.transition(entity, toLevel)
			end
		)

		return results, transitionReason, entity, manager:getMetrics()
	end

	local resultsA, transitionReasonA, entityA, metricsA = runSequence("entity:fidelity-determinism-a")
	local resultsB, transitionReasonB, entityB, metricsB = runSequence("entity:fidelity-determinism-b")

	expectEqual("network reason exposed during hold", resultsA[1].reason, "network-relevance")
	expectEqual("observer reason exposed while target stays F3", resultsA[2].reason, "observation")
	expectEqual("changing reason does not restart target hold", resultsA[3].transitioned, true)
	expectEqual("transition hook receives primary reason", transitionReasonA, "network-relevance")
	expectEqual("stable target reaches F3", entityA.fidelity, "F3")

	for index = 1, #resultsA do
		local left = resultsA[index]
		local right = resultsB[index]
		expectEqual(`sequence {index} transitioned`, left.transitioned, right.transitioned)
		expectEqual(`sequence {index} current level`, left.currentLevel, right.currentLevel)
		expectEqual(`sequence {index} desired level`, left.desiredLevel, right.desiredLevel)
		expectEqual(`sequence {index} policy reason`, left.reason, right.reason)
		expectEqual(`sequence {index} block reason`, left.blockedReason, right.blockedReason)
	end

	expectEqual("identical sequence transition reason", transitionReasonA, transitionReasonB)
	expectEqual("identical sequence final fidelity", entityA.fidelity, entityB.fidelity)
	expectEqual("identical sequence transition count", metricsA.transitions, metricsB.transitions)
	expectEqual("identical sequence promotion count", metricsA.promotions, metricsB.promotions)
	expectEqual("identical sequence hold blocks", metricsA.blockedByHold, metricsB.blockedByHold)
	expectEqual("identical sequence registered count", metricsA.registered, metricsB.registered)

	local _, reason = FidelityManager.evaluatePolicy(policyInputs({ visible = true }), nil, "F0")
	expectEqual("pure policy exposes visibility reason", reason, "visibility")

	return failures
end

return run
