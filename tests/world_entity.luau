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
	initialState.mechanism.angle = 90
	expectEqual("new entities start at F0", entity.fidelity, "F0")
	expectEqual("origin is copied", entity.origin.recipeKey, "chair/front-desk/01")
	expectEqual("persistent state is copied", entity.persistentState.open, false)
	expectEqual("nested persistent state is copied", (entity.persistentState.mechanism :: any).angle, 0)

	local topLevelMutationAccepted = pcall(function()
		entity.persistentState.open = true
	end)
	expectEqual("persistent state snapshot rejects mutation", topLevelMutationAccepted, false)

	local nestedMutationAccepted = pcall(function()
		(entity.persistentState.mechanism :: any).angle = 45
	end)
	expectEqual("nested persistent state snapshot rejects mutation", nestedMutationAccepted, false)

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

	local mixedNestedTableAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:mixed-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/mixed-state",
			},
			persistentState = {
				nested = { [1] = "first", named = "second" },
			},
		})
	end)
	expectEqual("persistent state rejects mixed nested table keys", mixedNestedTableAccepted, false)

	local sparseNestedArrayAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:sparse-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/sparse-state",
			},
			persistentState = {
				nested = { [1] = "first", [3] = "third" },
			},
		})
	end)
	expectEqual("persistent state rejects sparse nested arrays", sparseNestedArrayAccepted, false)

	local denseNestedArrayAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:dense-state",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/dense-state",
			},
			persistentState = {
				nested = { "first", "second" },
			},
		})
	end)
	expectEqual("persistent state accepts dense nested arrays", denseNestedArrayAccepted, true)

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
	expectEqual("demotion replaces removed state keys", structural.persistentState.mechanism, nil)
	expectEqual("demotion increments state revision", structural.stateRevision, 1)
	expectEqual("demotion increments representation revision", structural.representationRevision, 2)

	local rePromoted = WorldEntity.transition(structural, "F3")
	expectEqual("re-promotion preserves deleted state keys", rePromoted.persistentState.mechanism, nil)
	expectEqual("re-promotion preserves captured state revision", rePromoted.stateRevision, 1)

	local sameFidelityCapture = WorldEntity.transition(structural, "F1", { open = false })
	expectEqual("same-fidelity capture updates state", sameFidelityCapture.persistentState.open, false)
	expectEqual("same-fidelity capture increments state revision", sameFidelityCapture.stateRevision, 2)
	expectEqual(
		"same-fidelity capture does not recreate representation",
		sameFidelityCapture.representationRevision,
		structural.representationRevision
	)

	local lifecycleRegistry = WorldEntity.createRegistry()
	expectEqual("registry records backing is private", (lifecycleRegistry :: any)._records, nil)
	expectEqual("registry diagnostics backing is private", (lifecycleRegistry :: any)._duplicates, nil)
	local lifecycleRegistrySurfaceMutable = pcall(function()
		(lifecycleRegistry :: any)._records = {}
	end)
	expectEqual("registry public surface is frozen", lifecycleRegistrySurfaceMutable, false)

	WorldEntity.register(lifecycleRegistry, entity)
	local registeredInteractive = WorldEntity.transitionRegistered(lifecycleRegistry, entity.id, "F3")
	expectEqual("registered promotion returns current record", registeredInteractive.fidelity, "F3")
	expectEqual(
		"registered promotion updates registry lookup",
		WorldEntity.get(lifecycleRegistry, entity.id),
		registeredInteractive
	)

	local registeredStructural = WorldEntity.transitionRegistered(lifecycleRegistry, entity.id, "F1", {
		open = true,
		hingeAngle = 22.5,
	})
	expectEqual("registered demotion updates fidelity", registeredStructural.fidelity, "F1")
	expectEqual("registered demotion captures state", registeredStructural.persistentState.open, true)
	expectEqual(
		"registered demotion updates registry lookup",
		WorldEntity.get(lifecycleRegistry, entity.id),
		registeredStructural
	)

	local registeredCapture = WorldEntity.captureRegistered(lifecycleRegistry, entity.id, {
		open = false,
		hingeAngle = 0,
	})
	expectEqual("registered capture preserves fidelity", registeredCapture.fidelity, "F1")
	expectEqual("registered capture increments state revision", registeredCapture.stateRevision, 2)
	expectEqual(
		"registered capture updates registry lookup",
		WorldEntity.get(lifecycleRegistry, entity.id),
		registeredCapture
	)

	local unknownTransitionAccepted = pcall(function()
		WorldEntity.transitionRegistered(lifecycleRegistry, "entity:missing", "F1", {})
	end)
	expectEqual("registered transition rejects unknown identity", unknownTransitionAccepted, false)

	local mutableRecord = {
		id = "entity:mutable-registration",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/mutable-registration",
		},
		fidelity = "F2",
		persistentState = {
			mechanism = { angle = 12 },
		},
		stateRevision = 3,
		representationRevision = 4,
	}
	local ownershipRegistry = WorldEntity.createRegistry()
	local mutableRegistrationAccepted = WorldEntity.register(ownershipRegistry, mutableRecord :: any)
	expectEqual("registry accepts structurally valid mutable record", mutableRegistrationAccepted, true)
	local ownedRecord = WorldEntity.get(ownershipRegistry, mutableRecord.id) :: any
	expectEqual("registry stores an owned record snapshot", ownedRecord == mutableRecord, false)

	mutableRecord.id = "entity:mutated-after-registration"
	mutableRecord.kind = "mutated-kind"
	mutableRecord.origin.recipeKey = "mutated/recipe"
	mutableRecord.persistentState.mechanism.angle = 99
	mutableRecord.stateRevision = 99
	mutableRecord.representationRevision = 100

	expectEqual(
		"caller id mutation cannot move registry identity",
		ownedRecord.id,
		"entity:mutable-registration"
	)
	expectEqual("caller kind mutation cannot rewrite registry truth", ownedRecord.kind, "office-chair")
	expectEqual(
		"caller origin mutation cannot rewrite registry truth",
		ownedRecord.origin.recipeKey,
		"chair/mutable-registration"
	)
	expectEqual(
		"caller nested state mutation cannot rewrite registry truth",
		ownedRecord.persistentState.mechanism.angle,
		12
	)
	expectEqual("caller state revision mutation cannot rewrite registry truth", ownedRecord.stateRevision, 3)
	expectEqual(
		"caller representation revision mutation cannot rewrite registry truth",
		ownedRecord.representationRevision,
		4
	)
	expectEqual(
		"old registry key remains authoritative after caller id mutation",
		WorldEntity.get(ownershipRegistry, "entity:mutable-registration"),
		ownedRecord
	)
	expectEqual(
		"mutated caller id is absent from registry",
		WorldEntity.get(ownershipRegistry, "entity:mutated-after-registration"),
		nil
	)
	local ownedRecordMutationAccepted = pcall(function()
		ownedRecord.kind = "registry-bypass"
	end)
	expectEqual("owned registered record rejects mutation", ownedRecordMutationAccepted, false)

	local function mutableRegistrationFixture()
		return {
			id = "entity:registration-validation",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				regionId = "region:office-a",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/registration-validation",
			},
			fidelity = "F1",
			persistentState = { open = false },
			stateRevision = 0,
			representationRevision = 0,
		}
	end

	local malformedFidelity = mutableRegistrationFixture()
	malformedFidelity.fidelity = "F9"
	local malformedFidelityAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), malformedFidelity :: any)
	end)
	expectEqual("registry rejects malformed record fidelity", malformedFidelityAccepted, false)

	local negativeStateRevision = mutableRegistrationFixture()
	negativeStateRevision.stateRevision = -1
	local negativeStateRevisionAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), negativeStateRevision :: any)
	end)
	expectEqual("registry rejects negative state revision", negativeStateRevisionAccepted, false)

	local fractionalRepresentationRevision = mutableRegistrationFixture()
	fractionalRepresentationRevision.representationRevision = 1.5
	local fractionalRepresentationRevisionAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), fractionalRepresentationRevision :: any)
	end)
	expectEqual(
		"registry rejects fractional representation revision",
		fractionalRepresentationRevisionAccepted,
		false
	)

	local malformedOrigin = mutableRegistrationFixture()
	malformedOrigin.origin.generatorVersion = 0
	local malformedOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), malformedOrigin :: any)
	end)
	expectEqual("registry rejects malformed record origin", malformedOriginAccepted, false)

	local malformedState = mutableRegistrationFixture()
	malformedState.persistentState = {
		callback = function() end,
	}
	local malformedStateAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), malformedState :: any)
	end)
	expectEqual("registry rejects malformed record persistent state", malformedStateAccepted, false)

	local registry = WorldEntity.createRegistry()
	local registered = WorldEntity.register(registry, entity)
	expectEqual("first registration succeeds", registered, true)
	expectEqual("registry count", WorldEntity.count(registry), 1)
	local authoritativeRecord = WorldEntity.get(registry, entity.id) :: any
	expectEqual("registry owns registered record", authoritativeRecord == entity, false)
	expectEqual("registry preserves registered identity", authoritativeRecord.id, entity.id)

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
	expectEqual(
		"duplicate does not replace authoritative identity",
		WorldEntity.get(registry, entity.id),
		authoritativeRecord
	)
	expectEqual("duplicate diagnostic retained", #WorldEntity.duplicateDiagnostics(registry), 1)

	local diagnosticSnapshot = WorldEntity.duplicateDiagnostics(registry)
	table.clear(diagnosticSnapshot)
	expectEqual(
		"diagnostic snapshot cannot mutate registry history",
		#WorldEntity.duplicateDiagnostics(registry),
		1
	)

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
					generator = "objects.office",
					generatorVersion = 1,
					recipeKey = `duplicate/{index}`,
				},
			})
		)
	end
	local boundedDiagnostics = WorldEntity.duplicateDiagnostics(boundedRegistry)
	expectEqual("duplicate diagnostics stay bounded", #boundedDiagnostics, 2)
	expectEqual(
		"duplicate diagnostics discard oldest",
		boundedDiagnostics[1].incomingRecipeKey,
		"duplicate/2"
	)
	expectEqual("duplicate diagnostics retain newest", boundedDiagnostics[2].incomingRecipeKey, "duplicate/3")

	local disabledDiagnosticsRegistry = WorldEntity.createRegistry(0)
	WorldEntity.register(disabledDiagnosticsRegistry, entity)
	local rejectedWithoutRetention = WorldEntity.register(disabledDiagnosticsRegistry, duplicate)
	expectEqual("zero-capacity registry still rejects duplicates", rejectedWithoutRetention, false)
	expectEqual(
		"zero-capacity registry retains no diagnostic history",
		#WorldEntity.duplicateDiagnostics(disabledDiagnosticsRegistry),
		0
	)

	local maximumCapacityAccepted = pcall(function()
		WorldEntity.createRegistry(WorldEntity.MAX_DUPLICATE_DIAGNOSTIC_CAPACITY)
	end)
	expectEqual("duplicate diagnostic capacity accepts project maximum", maximumCapacityAccepted, true)

	local oversizedCapacityAccepted = pcall(function()
		WorldEntity.createRegistry(WorldEntity.MAX_DUPLICATE_DIAGNOSTIC_CAPACITY + 1)
	end)
	expectEqual(
		"duplicate diagnostic capacity rejects values above project maximum",
		oversizedCapacityAccepted,
		false
	)

	local diagnosticStringBudget = WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES
	local oversizedDiagnosticMetadata = string.rep("x", diagnosticStringBudget + 1)
	local oversizedDiagnosticRegistry = WorldEntity.createRegistry(1)
	WorldEntity.register(oversizedDiagnosticRegistry, entity)
	local oversizedDiagnosticCallAccepted = pcall(function()
		local oversizedDuplicate = WorldEntity.new({
			id = entity.id,
			kind = oversizedDiagnosticMetadata,
			origin = {
				worldId = "world:0000000000000001",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = oversizedDiagnosticMetadata,
			},
		})
		WorldEntity.register(oversizedDiagnosticRegistry, oversizedDuplicate)
	end)
	local oversizedDiagnosticRetentionIsBounded = not oversizedDiagnosticCallAccepted
	if oversizedDiagnosticCallAccepted then
		local retainedDiagnostics = WorldEntity.duplicateDiagnostics(oversizedDiagnosticRegistry)
		oversizedDiagnosticRetentionIsBounded = #retainedDiagnostics == 0
		if #retainedDiagnostics > 0 then
			local retained = retainedDiagnostics[1]
			oversizedDiagnosticRetentionIsBounded = #retained.incomingKind <= diagnosticStringBudget
				and #retained.incomingRecipeKey <= diagnosticStringBudget
		end
	end
	expectEqual(
		"duplicate diagnostic retention does not retain metadata beyond the owned WorldEntity string budget",
		oversizedDiagnosticRetentionIsBounded,
		true
	)

	local invalidCapacityAccepted = pcall(function()
		WorldEntity.createRegistry(math.huge)
	end)
	expectEqual("duplicate diagnostic capacity rejects infinity", invalidCapacityAccepted, false)

	local removed = WorldEntity.unregister(registry, entity.id) :: any
	expectEqual("unregister returns canonical record identity", removed.id, entity.id)
	expectEqual("unregister returns registry-owned record", removed, authoritativeRecord)
	expectEqual("registry empty after unregister", WorldEntity.count(registry), 0)
	local reRegistered = WorldEntity.register(registry, removed)
	expectEqual("identity can be re-registered after teardown", reRegistered, true)
	local reRegisteredRecord = WorldEntity.get(registry, entity.id) :: any
	expectEqual("re-register restores same current identity", reRegisteredRecord.id, removed.id)
	expectEqual("re-register takes a fresh owned snapshot", reRegisteredRecord == removed, false)
	WorldEntity.unregister(registry, entity.id)
	expectEqual("registry empty after second unregister", WorldEntity.count(registry), 0)

	return failures
end

return run
