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

	local directMutationAccepted = pcall(function()
		entity.persistentState.open = true
	end)
	expectEqual("persistent state root is immutable", directMutationAccepted, false)
	local nestedMutationAccepted = pcall(function()
		(entity.persistentState.mechanism :: any).angle = 90
	end)
	expectEqual("persistent state is deeply immutable", nestedMutationAccepted, false)

	local infiniteVersionAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:invalid-version",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				regionId = "region:office-a",
				generator = "objects.office",
				generatorVersion = math.huge,
				recipeKey = "chair/invalid-version",
			},
		})
	end)
	expectEqual("generator version rejects infinity", infiniteVersionAccepted, false)

	local functionStateAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:function-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/function-state",
			},
			persistentState = {
				callback = function() end,
			},
		})
	end)
	expectEqual("persistent state rejects functions", functionStateAccepted, false)

	local cyclicState = {}
	cyclicState.self = cyclicState
	local cyclicStateAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:cyclic-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/cyclic-state",
			},
			persistentState = cyclicState,
		})
	end)
	expectEqual("persistent state rejects cycles", cyclicStateAccepted, false)

	local nonFiniteStateAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:nonfinite-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/nonfinite-state",
			},
			persistentState = {
				energy = math.huge,
			},
		})
	end)
	expectEqual("persistent state rejects non-finite numbers", nonFiniteStateAccepted, false)

	local mixedTableAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:mixed-table-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/mixed-table-state",
			},
			persistentState = {
				contacts = {
					[1] = "front-left",
					primary = "front-left",
				},
			},
		})
	end)
	expectEqual("persistent state rejects mixed map-array tables", mixedTableAccepted, false)

	local sparseArrayAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:sparse-array-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/sparse-array-state",
			},
			persistentState = {
				contacts = {
					[1] = "front-left",
					[3] = "rear-left",
				},
			},
		})
	end)
	expectEqual("persistent state rejects sparse arrays", sparseArrayAccepted, false)

	local interactive = WorldEntity.transition(entity, "F3")
	expectEqual("promotion preserves identity", interactive.id, entity.id)
	expectEqual("promotion changes fidelity", interactive.fidelity, "F3")
	expectEqual("promotion increments representation revision", interactive.representationRevision, 1)

	local promotionCaptureAccepted = pcall(function()
		WorldEntity.transition(entity, "F3", { open = true })
	end)
	expectEqual("promotion rejects fresh captured state", promotionCaptureAccepted, false)

	local missingDemotionCaptureAccepted = pcall(function()
		WorldEntity.transition(interactive, "F1")
	end)
	expectEqual("demotion requires captured state", missingDemotionCaptureAccepted, false)

	local captured = { open = true, hingeAngle = 37.5 }
	local structural = WorldEntity.transition(interactive, "F1", captured)
	captured.open = false
	expectEqual("demotion preserves identity", structural.id, entity.id)
	expectEqual("demotion captures state", structural.persistentState.open, true)
	expectEqual("demotion snapshot deletes absent keys", structural.persistentState.mechanism, nil)
	expectEqual("demotion increments state revision", structural.stateRevision, 1)
	expectEqual("demotion increments representation revision", structural.representationRevision, 2)

	local refreshed = WorldEntity.transition(structural, "F1", { open = false })
	expectEqual("same-fidelity capture updates state", refreshed.persistentState.open, false)
	expectEqual("same-fidelity capture increments state revision", refreshed.stateRevision, 2)
	expectEqual("same-fidelity capture preserves representation revision", refreshed.representationRevision, 2)

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

	local boundedRegistry = WorldEntity.createRegistry(2)
	WorldEntity.register(boundedRegistry, entity)
	for index = 1, 3 do
		WorldEntity.register(
			boundedRegistry,
			WorldEntity.new({
				id = entity.id,
				kind = "duplicate-fixture",
				origin = {
					worldId = "world:0000000000000001",
					regionId = "region:office-a",
					generator = "objects.office",
					generatorVersion = 1,
					recipeKey = `duplicate/{index}`,
				},
			})
		)
	end
	local boundedDiagnostics = WorldEntity.duplicateDiagnostics(boundedRegistry)
	expectEqual("duplicate diagnostics stay bounded", #boundedDiagnostics, 2)
	expectEqual("duplicate diagnostics discard oldest", boundedDiagnostics[1].incomingRecipeKey, "duplicate/2")
	expectEqual("duplicate diagnostics retain newest", boundedDiagnostics[2].incomingRecipeKey, "duplicate/3")

	local removed = WorldEntity.unregister(registry, entity.id)
	expectEqual("unregister returns record", removed, entity)
	expectEqual("registry empty after unregister", WorldEntity.count(registry), 0)
	local reRegistered = WorldEntity.register(registry, removed)
	expectEqual("identity can re-register after representation recreation", reRegistered, true)
	expectEqual("re-register preserves same identity record", WorldEntity.get(registry, entity.id), entity)

	return failures
end

return run
