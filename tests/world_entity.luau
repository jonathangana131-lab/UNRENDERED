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

	local origin = {
		worldId = "world:0000000000000001",
		regionId = "region:office-a",
		generator = "objects.office",
		generatorVersion = 1,
		recipeKey = "chair/front-desk/01",
	}
	local initialState = {
		open = false,
		mechanism = { angle = 0 },
	}
	local entity = WorldEntity.new({
		id = "entity:0000000000000001",
		kind = "office-chair",
		origin = origin,
		persistentState = initialState,
	})

	origin.recipeKey = "changed"
	initialState.open = true
	expectEqual("new entities start at F0", entity.fidelity, "F0")
	expectEqual("origin is copied", entity.origin.recipeKey, "chair/front-desk/01")
	expectEqual("persistent state is copied", entity.persistentState.open, false)

	local interactive = WorldEntity.transition(entity, "F3")
	expectEqual("promotion preserves identity", interactive.id, entity.id)
	expectEqual("promotion changes fidelity", interactive.fidelity, "F3")
	expectEqual("promotion increments representation revision", interactive.representationRevision, 1)

	local captured = { open = true, hingeAngle = 37.5 }
	local structural = WorldEntity.transition(interactive, "F1", captured)
	captured.open = false
	expectEqual("demotion preserves identity", structural.id, entity.id)
	expectEqual("demotion captures state", structural.persistentState.open, true)
	expectEqual("demotion increments state revision", structural.stateRevision, 1)
	expectEqual("demotion increments representation revision", structural.representationRevision, 2)

	local registry = WorldEntity.createRegistry()
	local registered = WorldEntity.register(registry, entity)
	expectEqual("first registration succeeds", registered, true)
	expectEqual("registry count", WorldEntity.count(registry), 1)

	local duplicate = WorldEntity.new({
		id = entity.id,
		kind = "filing-cabinet",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "cabinet/front-desk/01",
		},
	})
	local duplicateRegistered, diagnostic = WorldEntity.register(registry, duplicate)
	expectEqual("duplicate registration is rejected", duplicateRegistered, false)
	expectEqual("duplicate diagnostic exists", diagnostic ~= nil, true)
	expectEqual("duplicate does not replace original", WorldEntity.get(registry, entity.id), entity)
	expectEqual("duplicate diagnostic retained", #WorldEntity.duplicateDiagnostics(registry), 1)

	local removed = WorldEntity.unregister(registry, entity.id)
	expectEqual("unregister returns record", removed, entity)
	expectEqual("registry empty after unregister", WorldEntity.count(registry), 0)

	return failures
end

return run
