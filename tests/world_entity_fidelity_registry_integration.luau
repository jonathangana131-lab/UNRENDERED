local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(
				`FAIL worldentity/fidelity registry {name}: expected {tostring(expected)}, got {tostring(actual)}`
			)
		else
			print(`PASS worldentity/fidelity registry {name}`)
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

	local registry = WorldEntity.createRegistry()
	local initialRecord = WorldEntity.new({
		id = "entity:physics-lab-registry-composition",
		kind = "physics-lab-test-object",
		origin = {
			worldId = "world:physics-lab",
			regionId = "region:physics-lab",
			generator = "tests.physics-lab.registry-composition",
			generatorVersion = 1,
			recipeKey = "fixture/registry-composition",
		},
		fidelity = "F2",
		persistentState = {
			mechanismPosition = 0.25,
		},
	})

	local registered = registry.register(initialRecord)
	expectEqual("WorldEntity registry accepts canonical record", registered, true)

	local manager = FidelityManager.new()
	manager:register(initialRecord.id, initialRecord.fidelity)

	local hookCalls = 0
	local heroInputs = policyInputs({ distanceStuds = 10, directlyObserved = true })
	local currentRecord = registry.get(initialRecord.id)
	assert(currentRecord ~= nil)

	local result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		heroInputs,
		0,
		function()
			hookCalls += 1
		end
	)
	expectEqual("promotion hold blocks transition", result.blockedReason, "hold")
	expectEqual("promotion hold does not call transition hook", hookCalls, 0)

	currentRecord = registry.get(initialRecord.id)
	assert(currentRecord ~= nil)
	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		heroInputs,
		0.1,
		function(entityId, fromLevel, toLevel)
			hookCalls += 1
			expectEqual("promotion hook receives registry identity", entityId, initialRecord.id)
			expectEqual("promotion hook starts from authoritative registry fidelity", fromLevel, "F2")
			WorldEntity.transitionRegistered(registry, entityId, toLevel)
		end
	)
	expectEqual("registry-backed promotion commits", result.transitioned, true)
	expectEqual("promotion calls hook exactly once", hookCalls, 1)

	currentRecord = registry.get(initialRecord.id)
	assert(currentRecord ~= nil)
	expectEqual("registry owns promoted fidelity", currentRecord.fidelity, "F4")
	expectEqual("registry promotion increments representation revision", currentRecord.representationRevision, 1)
	expectEqual("promotion does not invent persistent-state revision", currentRecord.stateRevision, 0)
	expectEqual("manager mirrors promoted registry fidelity", manager:getObservedLevel(initialRecord.id), "F4")

	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		heroInputs,
		0.11,
		function()
			hookCalls += 1
		end
	)
	expectEqual("stable hero demand is a non-transition", result.transitioned, false)
	expectEqual("stable hero demand does not call hook", hookCalls, 1)

	local farInputs = policyInputs()
	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		farInputs,
		0.2,
		function()
			hookCalls += 1
		end
	)
	expectEqual("demotion enters hold", result.blockedReason, "hold")
	expectEqual("demotion hold does not call hook", hookCalls, 1)

	local capturedState = {
		mechanismPosition = 0.75,
		settled = true,
		nested = {
			contactCount = 4,
		},
	}
	currentRecord = registry.get(initialRecord.id)
	assert(currentRecord ~= nil)
	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		farInputs,
		1.7,
		function(entityId, fromLevel, toLevel)
			hookCalls += 1
			expectEqual("demotion hook starts from authoritative registry fidelity", fromLevel, "F4")
			WorldEntity.transitionRegistered(registry, entityId, toLevel, capturedState)
		end
	)
	expectEqual("registry-backed demotion commits", result.transitioned, true)
	expectEqual("demotion calls hook exactly once", hookCalls, 2)

	currentRecord = registry.get(initialRecord.id)
	assert(currentRecord ~= nil)
	expectEqual("registry owns demoted fidelity", currentRecord.fidelity, "F0")
	expectEqual("demotion increments representation revision", currentRecord.representationRevision, 2)
	expectEqual("demotion captures one persistent-state revision", currentRecord.stateRevision, 1)
	expectEqual("demotion captures scalar state", currentRecord.persistentState.mechanismPosition, 0.75)
	expectEqual("demotion captures nested state", currentRecord.persistentState.nested.contactCount, 4)
	expectEqual("manager mirrors demoted registry fidelity", manager:getObservedLevel(initialRecord.id), "F0")

	expectEqual("caller-owned initial record remains unchanged", initialRecord.fidelity, "F2")
	expectEqual("caller-owned initial record revision remains unchanged", initialRecord.representationRevision, 0)

	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		farInputs,
		1.705,
		function()
			hookCalls += 1
		end
	)
	expectEqual("no-demand at F0 is a non-transition", result.transitioned, false)
	expectEqual("no-demand does not call hook", hookCalls, 2)

	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		heroInputs,
		1.71,
		function()
			hookCalls += 1
		end
	)
	expectEqual("rapid promotion begins hold", result.blockedReason, "hold")
	expectEqual("rapid promotion hold does not call hook", hookCalls, 2)

	result = manager:step(
		initialRecord.id,
		currentRecord.fidelity,
		heroInputs,
		1.81,
		function()
			hookCalls += 1
		end
	)
	expectEqual("mature rapid promotion is blocked by cooldown", result.blockedReason, "cooldown")
	expectEqual("cooldown does not call hook", hookCalls, 2)

	local metrics = manager:getMetrics()
	expectEqual("manager records exactly two committed transitions", metrics.transitions, 2)
	expectEqual("manager records exactly two successful hook calls", metrics.transitionHookCalls, 2)
	expectEqual("manager records one promotion", metrics.promotions, 1)
	expectEqual("manager records one demotion", metrics.demotions, 1)
	expectEqual("manager final F0 count stays synchronized", metrics.counts.F0, 1)
	expectEqual("manager final F4 count is cleared", metrics.counts.F4, 0)

	return failures
end

return run
