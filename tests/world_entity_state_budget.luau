local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function makeSpec(persistentState)
	return {
		id = "entity:state-budget",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/state-budget",
		},
		persistentState = persistentState,
	}
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean): ()
		if condition then
			print(`PASS world_entity_state_budget {name}`)
		else
			failures += 1
			print(`FAIL world_entity_state_budget {name}`)
		end
	end

	local function newResult(state)
		return pcall(function()
			return WorldEntity.new(makeSpec(state))
		end)
	end

	expect("depth budget is explicit", WorldEntity.MAX_PERSISTENT_STATE_DEPTH > 0)
	expect("node budget is explicit", WorldEntity.MAX_PERSISTENT_STATE_NODES > 0)
	expect("string-byte budget is explicit", WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES > 0)

	local exactDepthState = {}
	local exactDepthCursor = exactDepthState
	for _ = 1, WorldEntity.MAX_PERSISTENT_STATE_DEPTH do
		local child = {}
		exactDepthCursor.child = child
		exactDepthCursor = child
	end
	local exactDepthAccepted = newResult(exactDepthState)
	expect("accepts state at exact owned depth budget", exactDepthAccepted)

	local deepState = {}
	local depthCursor = deepState
	for _ = 1, WorldEntity.MAX_PERSISTENT_STATE_DEPTH + 1 do
		local child = {}
		depthCursor.child = child
		depthCursor = child
	end
	local deepAccepted, deepError = newResult(deepState)
	expect("rejects state beyond owned depth budget", not deepAccepted)
	expect(
		"depth rejection uses owned structural diagnostic",
		not deepAccepted
			and string.find(tostring(deepError), "persistentState exceeds structural limits", 1, true)
				~= nil
	)

	local exactWideState = {}
	for index = 1, WorldEntity.MAX_PERSISTENT_STATE_NODES - 1 do
		exactWideState[`key-{index}`] = index
	end
	local exactWideAccepted = newResult(exactWideState)
	expect("accepts flat state at exact owned node budget", exactWideAccepted)

	local wideState = {}
	for index = 1, WorldEntity.MAX_PERSISTENT_STATE_NODES do
		wideState[`key-{index}`] = index
	end
	local wideAccepted, wideError = newResult(wideState)
	expect("rejects state beyond owned node budget", not wideAccepted)
	expect(
		"node rejection uses owned structural diagnostic",
		not wideAccepted
			and string.find(tostring(wideError), "persistentState exceeds structural limits", 1, true)
				~= nil
	)

	local exactNestedArray = {}
	for index = 1, WorldEntity.MAX_PERSISTENT_STATE_NODES - 2 do
		exactNestedArray[index] = index
	end
	local exactNestedAccepted = newResult({ nested = exactNestedArray })
	expect("accepts nested state at exact recursive node budget", exactNestedAccepted)

	local overNestedArray = {}
	for index = 1, WorldEntity.MAX_PERSISTENT_STATE_NODES - 1 do
		overNestedArray[index] = index
	end
	local overNestedAccepted, overNestedError = newResult({ nested = overNestedArray })
	expect("rejects nested state beyond recursive node budget", not overNestedAccepted)
	expect(
		"nested node rejection uses owned structural diagnostic",
		not overNestedAccepted
			and string.find(
				tostring(overNestedError),
				"persistentState exceeds structural limits",
				1,
				true
			)
				~= nil
	)

	local payloadKey = "payload"
	local exactPayloadBytes = WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES - #payloadKey
	local exactByteAccepted = newResult({
		[payloadKey] = string.rep("x", exactPayloadBytes),
	})
	expect("accepts state at exact owned string-byte budget", exactByteAccepted)

	local overByteAccepted, overByteError = newResult({
		[payloadKey] = string.rep("x", exactPayloadBytes + 1),
	})
	expect("rejects shallow string value beyond owned byte budget", not overByteAccepted)
	expect(
		"value byte rejection uses owned structural diagnostic",
		not overByteAccepted
			and string.find(tostring(overByteError), "persistentState exceeds structural limits", 1, true)
				~= nil
	)

	local distributedPayloadBytes = WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES - 2
	local firstPayloadBytes = math.floor(distributedPayloadBytes / 2)
	local secondPayloadBytes = distributedPayloadBytes - firstPayloadBytes
	local distributedExactAccepted = newResult({
		a = string.rep("a", firstPayloadBytes),
		b = string.rep("b", secondPayloadBytes),
	})
	expect("accepts distributed strings at exact cumulative byte budget", distributedExactAccepted)
	local distributedOverAccepted, distributedOverError = newResult({
		a = string.rep("a", firstPayloadBytes),
		b = string.rep("b", secondPayloadBytes + 1),
	})
	expect("rejects distributed strings beyond cumulative byte budget", not distributedOverAccepted)
	expect(
		"distributed byte rejection uses owned structural diagnostic",
		not distributedOverAccepted
			and string.find(
				tostring(distributedOverError),
				"persistentState exceeds structural limits",
				1,
				true
			)
				~= nil
	)

	local overlongKey = string.rep("k", WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES + 1)
	local overKeyAccepted, overKeyError = newResult({
		[overlongKey] = true,
	})
	expect("rejects shallow string key beyond owned byte budget", not overKeyAccepted)
	expect(
		"key byte rejection uses owned structural diagnostic",
		not overKeyAccepted
			and string.find(tostring(overKeyError), "persistentState exceeds structural limits", 1, true)
				~= nil
	)

	local registry = WorldEntity.createRegistry()
	local registeredEntity = WorldEntity.new({
		id = "entity:state-budget-atomicity",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/state-budget-atomicity",
		},
		fidelity = "F2",
		persistentState = {
			open = false,
		},
	})
	local registered, diagnostic = WorldEntity.register(registry, registeredEntity)
	expect("registers atomicity fixture", registered and diagnostic == nil)

	local oversizedState = {
		payload = string.rep("x", WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES),
	}
	local beforeRejectedCapture = WorldEntity.get(registry, registeredEntity.id)
	local rejectedCaptureAccepted = pcall(function()
		WorldEntity.captureRegistered(registry, registeredEntity.id, oversizedState)
	end)
	expect("registered capture rejects over-budget state", not rejectedCaptureAccepted)
	expect(
		"rejected over-budget capture preserves registry record atomically",
		WorldEntity.get(registry, registeredEntity.id) == beforeRejectedCapture
	)

	local beforeRejectedDemotion = WorldEntity.get(registry, registeredEntity.id)
	local rejectedDemotionAccepted = pcall(function()
		WorldEntity.transitionRegistered(registry, registeredEntity.id, "F1", oversizedState)
	end)
	expect("registered demotion rejects over-budget state", not rejectedDemotionAccepted)
	expect(
		"rejected over-budget demotion preserves registry record atomically",
		WorldEntity.get(registry, registeredEntity.id) == beforeRejectedDemotion
	)

	return failures
end

return run
