local WorldEntity = require("../src/shared/Reality/WorldEntity")

local MAX_SAFE_INTEGER = 9007199254740991

local function makeRecord()
	return {
		id = "entity:registry-shape",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/registry-shape",
		},
		fidelity = "F1",
		persistentState = {},
		stateRevision = 0,
		representationRevision = 0,
	}
end

local function makeSpec()
	return {
		id = "entity:new-shape",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/new-shape",
		},
		persistentState = {
			open = false,
		},
	}
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean): ()
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local function registerAccepts(record): boolean
		local registry = WorldEntity.createRegistry()
		local ok = pcall(function()
			WorldEntity.register(registry, record)
		end)
		return ok
	end

	local function newResult(spec)
		local ok, result = pcall(function()
			return WorldEntity.new(spec)
		end)
		return ok, result
	end

	expect("registry accepts exact mutable record shape", registerAccepts(makeRecord()))

	local extraRecord = makeRecord()
	extraRecord.authorityLease = "future-field"
	expect("registry rejects unknown record field", not registerAccepts(extraRecord))

	local extraOrigin = makeRecord()
	extraOrigin.origin.persistenceEpoch = 2
	expect("registry rejects unknown origin field", not registerAccepts(extraOrigin))

	local recordIndexCalls = 0
	local metatableRecord = setmetatable({}, {
		__index = function()
			recordIndexCalls += 1
			return "forged"
		end,
	})
	expect("registry rejects record metatable", not registerAccepts(metatableRecord))
	expect("registry rejects record before __index", recordIndexCalls == 0)

	local originIndexCalls = 0
	local metatableOrigin = makeRecord()
	metatableOrigin.origin = setmetatable({}, {
		__index = function()
			originIndexCalls += 1
			return "forged"
		end,
	})
	expect("registry rejects origin metatable", not registerAccepts(metatableOrigin))
	expect("registry rejects origin before __index", originIndexCalls == 0)

	local hostileUnknownKeyCallbacks = 0
	local hostileUnknownKey = setmetatable({}, {
		__tostring = function()
			hostileUnknownKeyCallbacks += 1
			error("hostile schema key __tostring must not execute")
		end,
	})
	local hostileKeySpec = makeSpec()
	hostileKeySpec[hostileUnknownKey] = true
	local hostileKeyAccepted = newResult(hostileKeySpec)
	expect("new rejects hostile non-string schema key", not hostileKeyAccepted)
	expect("new rejects hostile schema key before __tostring", hostileUnknownKeyCallbacks == 0)

	local validSpecAccepted, validEntity = newResult(makeSpec())
	expect("new accepts exact mutable spec shape", validSpecAccepted)
	if validSpecAccepted then
		expect("new keeps default fidelity", validEntity.fidelity == "F0")
		expect("new keeps plain state", validEntity.persistentState.open == false)
	end

	local maxSafeGeneratorSpec = makeSpec()
	maxSafeGeneratorSpec.id = "entity:max-safe-generator-new"
	maxSafeGeneratorSpec.origin.generatorVersion = MAX_SAFE_INTEGER
	local maxSafeGeneratorNewAccepted, maxSafeGeneratorEntity = newResult(maxSafeGeneratorSpec)
	expect("new accepts maximum safe generator version", maxSafeGeneratorNewAccepted)
	if maxSafeGeneratorNewAccepted then
		expect(
			"new preserves maximum safe generator version exactly",
			maxSafeGeneratorEntity.origin.generatorVersion == MAX_SAFE_INTEGER
		)
	end

	local unsafeGeneratorSpec = makeSpec()
	unsafeGeneratorSpec.id = "entity:unsafe-generator-new"
	unsafeGeneratorSpec.origin.generatorVersion = MAX_SAFE_INTEGER + 1
	local unsafeGeneratorNewAccepted = newResult(unsafeGeneratorSpec)
	expect("new rejects generator version beyond safe integer range", not unsafeGeneratorNewAccepted)

	local maxSafeGeneratorRecord = makeRecord()
	maxSafeGeneratorRecord.id = "entity:max-safe-generator-registry"
	maxSafeGeneratorRecord.origin.generatorVersion = MAX_SAFE_INTEGER
	expect(
		"registry accepts maximum safe generator version",
		registerAccepts(maxSafeGeneratorRecord)
	)

	local unsafeGeneratorRecord = makeRecord()
	unsafeGeneratorRecord.id = "entity:unsafe-generator-registry"
	unsafeGeneratorRecord.origin.generatorVersion = MAX_SAFE_INTEGER + 1
	expect(
		"registry rejects generator version beyond safe integer range",
		not registerAccepts(unsafeGeneratorRecord)
	)

	local specIndexCalls = 0
	local forgedSpec = setmetatable({}, {
		__index = function(_, key)
			specIndexCalls += 1
			if key == "id" then
				return "entity:forged-spec"
			elseif key == "kind" then
				return "office-chair"
			elseif key == "origin" then
				return makeSpec().origin
			end
			return nil
		end,
	})
	local forgedSpecAccepted = newResult(forgedSpec)
	expect("new rejects top-level spec metatable", not forgedSpecAccepted)
	expect("new rejects spec before __index", specIndexCalls == 0)

	local newOriginIndexCalls = 0
	local metatableNewOrigin = makeSpec()
	metatableNewOrigin.origin = setmetatable({}, {
		__index = function()
			newOriginIndexCalls += 1
			return "forged"
		end,
	})
	local metatableNewOriginAccepted = newResult(metatableNewOrigin)
	expect("new rejects origin metatable", not metatableNewOriginAccepted)
	expect("new rejects origin before __index", newOriginIndexCalls == 0)

	local stateCallbacks = 0
	local metatableState = makeSpec()
	metatableState.persistentState = setmetatable({ open = false }, {
		__index = function()
			stateCallbacks += 1
			return "forged"
		end,
		__iter = function()
			stateCallbacks += 1
			return function()
				return nil
			end
		end,
	})
	local metatableStateAccepted = newResult(metatableState)
	expect("new rejects top-level persistent state metatable", not metatableStateAccepted)
	expect("new rejects persistent state before metatable callbacks", stateCallbacks == 0)

	local omittedStateSpec = makeSpec()
	omittedStateSpec.persistentState = nil
	local omittedStateAccepted, omittedStateEntity = newResult(omittedStateSpec)
	expect("new accepts omitted persistent state", omittedStateAccepted)
	if omittedStateAccepted then
		expect(
			"new defaults omitted persistent state to empty data",
			next(omittedStateEntity.persistentState) == nil
		)
	end

	local hostileFidelityCallbacks = 0
	local hostileFidelity = setmetatable({}, {
		__tostring = function()
			hostileFidelityCallbacks += 1
			error("hostile fidelity __tostring must not execute")
		end,
	})
	local hostileFidelitySpec = makeSpec()
	hostileFidelitySpec.fidelity = hostileFidelity
	local hostileFidelityAccepted = newResult(hostileFidelitySpec)
	expect("new rejects hostile fidelity", not hostileFidelityAccepted)
	expect("new rejects hostile fidelity before __tostring", hostileFidelityCallbacks == 0)
	local hostileFidelityRankAccepted = pcall(function()
		WorldEntity.fidelityRank(hostileFidelity :: any)
	end)
	expect("fidelityRank rejects hostile fidelity", not hostileFidelityRankAccepted)
	expect("fidelityRank rejects before __tostring", hostileFidelityCallbacks == 0)

	local captureTarget = WorldEntity.new(makeSpec())
	local falseCaptureAccepted = pcall(function()
		WorldEntity.captureState(captureTarget, false :: any)
	end)
	expect("captureState rejects false persistent state", not falseCaptureAccepted)
	local nilCaptureAccepted = pcall(function()
		WorldEntity.captureState(captureTarget, nil :: any)
	end)
	expect("captureState rejects omitted required state", not nilCaptureAccepted)

	local nilCaptureRegistry = WorldEntity.createRegistry()
	WorldEntity.register(nilCaptureRegistry, captureTarget)
	local beforeNilRegisteredCapture = WorldEntity.get(nilCaptureRegistry, captureTarget.id)
	local nilRegisteredCaptureAccepted = pcall(function()
		WorldEntity.captureRegistered(nilCaptureRegistry, captureTarget.id, nil :: any)
	end)
	expect("captureRegistered rejects omitted required state", not nilRegisteredCaptureAccepted)
	expect(
		"rejected nil registered capture preserves registry record",
		WorldEntity.get(nilCaptureRegistry, captureTarget.id) == beforeNilRegisteredCapture
	)

	local mutableDirectRecord = makeRecord()
	mutableDirectRecord.persistentState = {
		open = false,
		mechanism = { angle = 12 },
	}
	mutableDirectRecord.stateRevision = 2
	mutableDirectRecord.representationRevision = 3
	local promoted = WorldEntity.transition(mutableDirectRecord :: any, "F2")
	mutableDirectRecord.kind = "mutated-kind"
	mutableDirectRecord.origin.recipeKey = "mutated/recipe"
	mutableDirectRecord.persistentState.open = true
	mutableDirectRecord.persistentState.mechanism.angle = 99
	expect("direct promotion owns kind", promoted.kind == "office-chair")
	expect("direct promotion owns origin", promoted.origin.recipeKey == "chair/registry-shape")
	expect("direct promotion owns state", promoted.persistentState.open == false)
	expect("direct promotion owns nested state", (promoted.persistentState.mechanism :: any).angle == 12)
	expect("direct promotion advances representation revision", promoted.representationRevision == 4)
	local promotedOriginMutationAccepted = pcall(function()
		(promoted.origin :: any).recipeKey = "bypass"
	end)
	expect("direct promotion freezes owned origin", not promotedOriginMutationAccepted)
	local promotedStateMutationAccepted = pcall(function()
		(promoted.persistentState.mechanism :: any).angle = 45
	end)
	expect("direct promotion freezes owned nested state", not promotedStateMutationAccepted)

	local captureSource = makeRecord()
	captureSource.id = "entity:direct-capture"
	captureSource.kind = "filing-cabinet"
	captureSource.origin.recipeKey = "cabinet/direct-capture"
	captureSource.fidelity = "F2"
	captureSource.persistentState = { open = false }
	captureSource.stateRevision = 5
	captureSource.representationRevision = 7
	local capturedState = {
		open = true,
		drawer = { extension = 0.5 },
	}
	local captured = WorldEntity.captureState(captureSource :: any, capturedState)
	captureSource.origin.recipeKey = "mutated/capture-origin"
	capturedState.open = false
	capturedState.drawer.extension = 1
	expect("direct capture owns origin", captured.origin.recipeKey == "cabinet/direct-capture")
	expect("direct capture owns captured state", captured.persistentState.open == true)
	expect(
		"direct capture owns nested captured state",
		(captured.persistentState.drawer :: any).extension == 0.5
	)
	expect("direct capture advances state revision", captured.stateRevision == 6)
	expect("direct capture preserves representation revision", captured.representationRevision == 7)

	local nearStateRevisionLimit = makeRecord()
	nearStateRevisionLimit.id = "entity:near-state-revision-limit"
	nearStateRevisionLimit.stateRevision = MAX_SAFE_INTEGER - 1
	local finalStateRevision = WorldEntity.captureState(nearStateRevisionLimit :: any, { open = true })
	expect(
		"capture can advance to maximum safe state revision",
		finalStateRevision.stateRevision == MAX_SAFE_INTEGER
	)
	local exhaustedStateRevision = makeRecord()
	exhaustedStateRevision.id = "entity:exhausted-state-revision"
	exhaustedStateRevision.stateRevision = MAX_SAFE_INTEGER
	local exhaustedStateRevisionAccepted = pcall(function()
		WorldEntity.captureState(exhaustedStateRevision :: any, { open = true })
	end)
	expect("capture rejects exhausted safe state revision", not exhaustedStateRevisionAccepted)
	local unsafeStateRevision = makeRecord()
	unsafeStateRevision.id = "entity:unsafe-state-revision"
	unsafeStateRevision.stateRevision = MAX_SAFE_INTEGER + 1
	expect(
		"registry rejects state revision beyond safe integer range",
		not registerAccepts(unsafeStateRevision)
	)

	local nearRepresentationRevisionLimit = makeRecord()
	nearRepresentationRevisionLimit.id = "entity:near-representation-revision-limit"
	nearRepresentationRevisionLimit.representationRevision = MAX_SAFE_INTEGER - 1
	local finalRepresentationRevision = WorldEntity.transition(nearRepresentationRevisionLimit :: any, "F2")
	expect(
		"transition can advance to maximum safe representation revision",
		finalRepresentationRevision.representationRevision == MAX_SAFE_INTEGER
	)
	local exhaustedRepresentationRevision = makeRecord()
	exhaustedRepresentationRevision.id = "entity:exhausted-representation-revision"
	exhaustedRepresentationRevision.representationRevision = MAX_SAFE_INTEGER
	local exhaustedRepresentationRevisionAccepted = pcall(function()
		WorldEntity.transition(exhaustedRepresentationRevision :: any, "F2")
	end)
	expect(
		"transition rejects exhausted safe representation revision",
		not exhaustedRepresentationRevisionAccepted
	)
	local unsafeRepresentationRevision = makeRecord()
	unsafeRepresentationRevision.id = "entity:unsafe-representation-revision"
	unsafeRepresentationRevision.representationRevision = MAX_SAFE_INTEGER + 1
	expect(
		"registry rejects representation revision beyond safe integer range",
		not registerAccepts(unsafeRepresentationRevision)
	)

	local malformedRevision = makeRecord()
	malformedRevision.stateRevision = math.huge
	local malformedTransitionAccepted = pcall(function()
		WorldEntity.transition(malformedRevision :: any, "F2")
	end)
	expect("direct transition validates record revisions", not malformedTransitionAccepted)

	local unknownDirectShape = makeRecord()
	unknownDirectShape.unexpected = true
	local unknownShapeAccepted = pcall(function()
		WorldEntity.captureState(unknownDirectShape :: any, {})
	end)
	expect("direct capture rejects unknown record schema keys", not unknownShapeAccepted)

	local hostileTargetCallbacks = 0
	local hostileTarget = setmetatable({}, {
		__tostring = function()
			hostileTargetCallbacks += 1
			error("hostile target __tostring must not execute")
		end,
	})
	local hostileTargetAccepted = pcall(function()
		WorldEntity.transition(makeRecord() :: any, hostileTarget :: any)
	end)
	expect("direct transition rejects hostile target fidelity", not hostileTargetAccepted)
	expect("direct transition rejects target before __tostring", hostileTargetCallbacks == 0)

	local falseCapacityAccepted = pcall(function()
		WorldEntity.createRegistry(false :: any)
	end)
	expect("registry rejects false diagnostic capacity instead of defaulting it", not falseCapacityAccepted)

	local hostileCapacityCallbacks = 0
	local hostileCapacity = setmetatable({}, {
		__lt = function()
			hostileCapacityCallbacks += 1
			error("hostile capacity comparison must not execute")
		end,
		__le = function()
			hostileCapacityCallbacks += 1
			error("hostile capacity comparison must not execute")
		end,
		__tostring = function()
			hostileCapacityCallbacks += 1
			error("hostile capacity __tostring must not execute")
		end,
	})
	local hostileCapacityAccepted = pcall(function()
		WorldEntity.createRegistry(hostileCapacity :: any)
	end)
	expect("registry rejects hostile diagnostic capacity", not hostileCapacityAccepted)
	expect("registry rejects hostile capacity before metamethod callbacks", hostileCapacityCallbacks == 0)

	local hostileIdCallbacks = 0
	local hostileId = setmetatable({}, {
		__tostring = function()
			hostileIdCallbacks += 1
			error("hostile entity id __tostring must not execute")
		end,
	})
	local hostileIdAccepted = pcall(function()
		WorldEntity.captureRegistered(WorldEntity.createRegistry(), hostileId :: any, {})
	end)
	expect("registered capture rejects hostile unknown identity", not hostileIdAccepted)
	expect("registered capture rejects hostile identity before __tostring", hostileIdCallbacks == 0)

	local wrongKind = makeSpec()
	wrongKind.kind = 17
	local wrongKindAccepted, wrongKindError = newResult(wrongKind)
	expect("new rejects non-string kind", not wrongKindAccepted)
	expect(
		"non-string kind reports contract error",
		string.find(tostring(wrongKindError), "WorldEntity.kind must be a string", 1, true) ~= nil
	)

	local wrongWorldId = makeSpec()
	wrongWorldId.origin.worldId = 17
	local wrongWorldIdAccepted, wrongWorldIdError = newResult(wrongWorldId)
	expect("new rejects non-string origin worldId", not wrongWorldIdAccepted)
	expect(
		"non-string origin worldId reports contract error",
		string.find(tostring(wrongWorldIdError), "origin.worldId must be a string", 1, true) ~= nil
	)

	return failures
end

return run
