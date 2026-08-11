local WorldEntity = require("../src/shared/Reality/WorldEntity")

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

	local identityRegistry = WorldEntity.createRegistry()
	local identityRecord = makeRecord()
	local identityRegistered = WorldEntity.register(identityRegistry, identityRecord)
	expect("identity boundary fixture registers", identityRegistered)
	local validMissingGetAccepted, validMissingGetResult = pcall(function()
		return WorldEntity.get(identityRegistry, "entity:valid-but-absent")
	end)
	expect(
		"registry get permits a valid absent identity",
		validMissingGetAccepted and validMissingGetResult == nil
	)

	local malformedGetAccepted = pcall(function()
		WorldEntity.get(identityRegistry, "" :: any)
	end)
	expect("registry get rejects malformed identity instead of reporting absence", not malformedGetAccepted)

	local malformedUnregisterAccepted = pcall(function()
		WorldEntity.unregister(identityRegistry, "" :: any)
	end)
	expect(
		"registry unregister rejects malformed identity instead of reporting absence",
		not malformedUnregisterAccepted
	)
	expect(
		"rejected malformed unregister preserves the registered entity",
		WorldEntity.get(identityRegistry, identityRecord.id) ~= nil
	)

	local hostileIdentityCallbacks = 0
	local hostileIdentity = setmetatable({}, {
		__tostring = function()
			hostileIdentityCallbacks += 1
			error("hostile registry identity __tostring must not execute")
		end,
	})
	local hostileGetAccepted = pcall(function()
		WorldEntity.get(identityRegistry, hostileIdentity :: any)
	end)
	expect("registry get rejects hostile non-string identity", not hostileGetAccepted)
	expect("registry get rejects hostile identity before __tostring", hostileIdentityCallbacks == 0)
	local hostileUnregisterAccepted = pcall(function()
		WorldEntity.unregister(identityRegistry, hostileIdentity :: any)
	end)
	expect("registry unregister rejects hostile non-string identity", not hostileUnregisterAccepted)
	expect("registry unregister rejects hostile identity before __tostring", hostileIdentityCallbacks == 0)

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

	local validSpecAccepted, validEntity = newResult(makeSpec())
	expect("new accepts exact mutable spec shape", validSpecAccepted)
	if validSpecAccepted then
		expect("new keeps default fidelity", validEntity.fidelity == "F0")
		expect("new keeps plain state", validEntity.persistentState.open == false)
	end

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

	local captureTarget = WorldEntity.new(makeSpec())
	local falseCaptureAccepted = pcall(function()
		WorldEntity.captureState(captureTarget, false :: any)
	end)
	expect("captureState rejects false persistent state", not falseCaptureAccepted)

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
