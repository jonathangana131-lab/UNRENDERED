local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL fidelity-id {name}`)
		else
			print(`PASS fidelity-id {name}`)
		end
	end

	local function inputs()
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

	local validMaxLengthId = string.rep("a", 256)
	expect("WorldEntity accepts 256-byte control-free id", WorldEntity.isId(validMaxLengthId))

	local manager = FidelityManager.new()
	local validAccepted = pcall(function()
		manager:register(validMaxLengthId, "F0")
	end)
	expect("FidelityManager accepts the same valid max-length id", validAccepted)
	expect("valid registration is counted", manager:getMetrics().registered == 1)

	local invalidIds = {
		17,
		"",
		string.rep("a", 257),
		"entity:\ninvalid",
	}

	for index, invalidId in invalidIds do
		expect(`WorldEntity rejects invalid id {index}`, not WorldEntity.isId(invalidId))
		local before = manager:getMetrics()
		local accepted = pcall(function()
			manager:register(invalidId, "F0")
		end)
		local after = manager:getMetrics()
		expect(`register rejects invalid id {index}`, not accepted)
		expect(
			`register invalid id {index} leaves registered count atomic`,
			after.registered == before.registered
		)
		expect(`register invalid id {index} leaves F0 count atomic`, after.counts.F0 == before.counts.F0)
		expect(
			`register invalid id {index} does not consume capacity rejection metric`,
			after.registrationCapacityRejections == before.registrationCapacityRejections
		)
	end

	local invalidLookupId = 17
	local unregisterAccepted = pcall(function()
		manager:unregister(invalidLookupId)
	end)
	expect("unregister rejects invalid id before lookup", not unregisterAccepted)
	expect(
		"invalid unregister leaves valid registration present",
		manager:getObservedLevel(validMaxLengthId) == "F0"
	)

	local getAccepted = pcall(function()
		manager:getObservedLevel(invalidLookupId)
	end)
	expect("getObservedLevel rejects invalid id before lookup", not getAccepted)

	local transitionCalls = 0
	local beforeStep = manager:getMetrics()
	local stepAccepted = pcall(function()
		manager:step(invalidLookupId, "F0", inputs(), 0, function()
			transitionCalls += 1
		end)
	end)
	local afterStep = manager:getMetrics()
	expect("step rejects invalid id before state lookup", not stepAccepted)
	expect("invalid step cannot invoke transition hook", transitionCalls == 0)
	expect("invalid step leaves transitions atomic", afterStep.transitions == beforeStep.transitions)
	expect("invalid step leaves hold metric atomic", afterStep.blockedByHold == beforeStep.blockedByHold)
	expect(
		"invalid step leaves cooldown metric atomic",
		afterStep.blockedByCooldown == beforeStep.blockedByCooldown
	)
	expect(
		"invalid step leaves missing-transition metric atomic",
		afterStep.blockedByMissingTransition == beforeStep.blockedByMissingTransition
	)
	expect(
		"invalid step leaves external-sync metric atomic",
		afterStep.externalSynchronizations == beforeStep.externalSynchronizations
	)

	manager:unregister(validMaxLengthId)
	expect("valid id still unregisters normally", manager:getMetrics().registered == 0)

	return failures
end

return run
