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

	local oldId = "entity:mutable-registration"
	local newId = "entity:caller-mutated-id"
	local callerOrigin = {
		worldId = "world:0000000000000001",
		regionId = "region:office-a",
		generator = "objects.office",
		generatorVersion = 1,
		recipeKey = "chair/mutable-registration",
	}
	local callerState = {
		open = false,
		mechanism = { angle = 12.5 },
	}
	local callerRecord = {
		id = oldId,
		kind = "office-chair",
		origin = callerOrigin,
		fidelity = "F1",
		persistentState = callerState,
		stateRevision = 3,
		representationRevision = 4,
	}

	local registry = WorldEntity.createRegistry()
	local registered = WorldEntity.register(registry, callerRecord :: any)
	expectEqual("mutable structural record registers", registered, true)
	local owned = WorldEntity.get(registry, oldId) :: any
	expectEqual("registry stores a defensive record", owned ~= callerRecord, true)

	callerRecord.id = newId
	callerRecord.kind = "caller-mutated-kind"
	callerOrigin.recipeKey = "caller/mutated-recipe"
	callerState.open = true
	callerState.mechanism.angle = 90
	callerRecord.stateRevision = 99
	callerRecord.representationRevision = 101

	expectEqual("registered id is stable after caller mutation", owned.id, oldId)
	expectEqual("registered kind is stable after caller mutation", owned.kind, "office-chair")
	expectEqual(
		"registered origin is stable after caller mutation",
		owned.origin.recipeKey,
		"chair/mutable-registration"
	)
	expectEqual("registered state is stable after caller mutation", owned.persistentState.open, false)
	expectEqual(
		"registered nested state is stable after caller mutation",
		owned.persistentState.mechanism.angle,
		12.5
	)
	expectEqual("registered state revision is stable after caller mutation", owned.stateRevision, 3)
	expectEqual(
		"registered representation revision is stable after caller mutation",
		owned.representationRevision,
		4
	)
	expectEqual("mutated caller id is not registered", WorldEntity.get(registry, newId), nil)

	local storedMutationAccepted = pcall(function()
		owned.kind = "mutated-through-get"
	end)
	expectEqual("registered record rejects top-level mutation", storedMutationAccepted, false)
	local storedNestedMutationAccepted = pcall(function()
		owned.persistentState.mechanism.angle = 45
	end)
	expectEqual("registered record rejects nested state mutation", storedNestedMutationAccepted, false)

	local invalidRevisionAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), {
			id = "entity:invalid-registration-revision",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/invalid-registration-revision",
			},
			fidelity = "F0",
			persistentState = {},
			stateRevision = -1,
			representationRevision = 0,
		} :: any)
	end)
	expectEqual("registration rejects invalid lifecycle revisions", invalidRevisionAccepted, false)

	local unknownFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), {
			id = "entity:unknown-registration-field",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/unknown-registration-field",
			},
			fidelity = "F0",
			persistentState = {},
			stateRevision = 0,
			representationRevision = 0,
			unversionedExtra = "must-not-enter-registry-truth",
		} :: any)
	end)
	expectEqual("registration rejects unknown canonical record fields", unknownFieldAccepted, false)

	return failures
end

return run
