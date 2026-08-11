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

	return failures
end

return run
