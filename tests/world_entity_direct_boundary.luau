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

	local mutableRecord = {
		id = "entity:direct-boundary",
		kind = "office-chair",
		origin = {
			worldId = "world:direct-boundary",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/direct-boundary",
		},
		fidelity = "F1",
		persistentState = {
			open = false,
			mechanism = { angle = 12 },
		},
		stateRevision = 2,
		representationRevision = 3,
	}

	local promoted = WorldEntity.transition(mutableRecord :: any, "F2")
	mutableRecord.kind = "mutated-kind"
	mutableRecord.origin.recipeKey = "mutated/recipe"
	mutableRecord.persistentState.open = true
	mutableRecord.persistentState.mechanism.angle = 99

	expectEqual("direct promotion owns kind", promoted.kind, "office-chair")
	expectEqual("direct promotion owns origin", promoted.origin.recipeKey, "chair/direct-boundary")
	expectEqual("direct promotion owns state", promoted.persistentState.open, false)
	expectEqual("direct promotion owns nested state", (promoted.persistentState.mechanism :: any).angle, 12)
	expectEqual("direct promotion advances representation revision", promoted.representationRevision, 4)

	local promotedOriginMutationAccepted = pcall(function()
		(promoted.origin :: any).recipeKey = "bypass"
	end)
	expectEqual("direct promotion freezes owned origin", promotedOriginMutationAccepted, false)

	local promotedStateMutationAccepted = pcall(function()
		(promoted.persistentState.mechanism :: any).angle = 45
	end)
	expectEqual("direct promotion freezes owned nested state", promotedStateMutationAccepted, false)

	local captureSource = {
		id = "entity:direct-capture",
		kind = "filing-cabinet",
		origin = {
			worldId = "world:direct-boundary",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "cabinet/direct-capture",
		},
		fidelity = "F2",
		persistentState = { open = false },
		stateRevision = 5,
		representationRevision = 7,
	}
	local capturedState = {
		open = true,
		drawer = { extension = 0.5 },
	}
	local captured = WorldEntity.captureState(captureSource :: any, capturedState)
	captureSource.origin.recipeKey = "mutated/capture-origin"
	capturedState.open = false
	capturedState.drawer.extension = 1

	expectEqual("direct capture owns origin", captured.origin.recipeKey, "cabinet/direct-capture")
	expectEqual("direct capture owns captured state", captured.persistentState.open, true)
	expectEqual("direct capture owns nested captured state", (captured.persistentState.drawer :: any).extension, 0.5)
	expectEqual("direct capture advances state revision", captured.stateRevision, 6)
	expectEqual("direct capture preserves representation revision", captured.representationRevision, 7)

	local malformedRevision = {
		id = "entity:malformed-direct",
		kind = "office-chair",
		origin = {
			worldId = "world:direct-boundary",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/malformed-direct",
		},
		fidelity = "F1",
		persistentState = {},
		stateRevision = math.huge,
		representationRevision = 0,
	}
	local malformedTransitionAccepted = pcall(function()
		WorldEntity.transition(malformedRevision :: any, "F2")
	end)
	expectEqual("direct transition validates record revisions", malformedTransitionAccepted, false)

	local unknownShape = {
		id = "entity:unknown-shape",
		kind = "office-chair",
		origin = {
			worldId = "world:direct-boundary",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/unknown-shape",
		},
		fidelity = "F1",
		persistentState = {},
		stateRevision = 0,
		representationRevision = 0,
		unexpected = true,
	}
	local unknownShapeAccepted = pcall(function()
		WorldEntity.captureState(unknownShape :: any, {})
	end)
	expectEqual("direct capture rejects unknown record schema keys", unknownShapeAccepted, false)

	return failures
end

return run
