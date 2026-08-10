local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function baseOrigin()
	return {
		worldId = "world:plain-boundary",
		regionId = "region:test",
		generator = "tests.world-entity",
		generatorVersion = 1,
		recipeKey = "plain-boundary",
	}
end

local function baseRecord()
	return {
		id = "entity:plain-boundary",
		kind = "test-object",
		origin = baseOrigin(),
		fidelity = "F1",
		persistentState = { open = false },
		stateRevision = 0,
		representationRevision = 0,
	}
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS world_entity_plain_boundary {name}`)
		else
			failures += 1
			print(`FAIL world_entity_plain_boundary {name}`)
		end
	end

	local specReads = 0
	local specBacking = {
		id = "entity:metatable-spec",
		kind = "test-object",
		origin = baseOrigin(),
	}
	local metatableSpec = setmetatable({}, {
		__index = function(_, key)
			specReads += 1
			return specBacking[key]
		end,
	})
	local specAccepted = pcall(function()
		WorldEntity.new(metatableSpec :: any)
	end)
	expect("new rejects metatable-backed spec", not specAccepted)
	expect("new rejects spec before __index", specReads == 0)

	local originReads = 0
	local originBacking = baseOrigin()
	local metatableOrigin = setmetatable({}, {
		__index = function(_, key)
			originReads += 1
			return originBacking[key]
		end,
	})
	local originAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:metatable-origin",
			kind = "test-object",
			origin = metatableOrigin :: any,
		})
	end)
	expect("new rejects metatable-backed origin", not originAccepted)
	expect("origin rejected before __index", originReads == 0)

	local stateAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:metatable-state",
			kind = "test-object",
			origin = baseOrigin(),
			persistentState = setmetatable({ open = false }, {}) :: any,
		})
	end)
	expect("new rejects metatable-backed persistent state", not stateAccepted)

	local falseStateAccepted = pcall(function()
		WorldEntity.new({
			id = "entity:false-state",
			kind = "test-object",
			origin = baseOrigin(),
			persistentState = false :: any,
		})
	end)
	expect("new rejects false persistent state instead of treating it as empty", not falseStateAccepted)

	local recordReads = 0
	local recordBacking = baseRecord()
	local metatableRecord = setmetatable({}, {
		__index = function(_, key)
			recordReads += 1
			return recordBacking[key]
		end,
	})
	local recordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableRecord :: any)
	end)
	expect("registry rejects metatable-backed record", not recordAccepted)
	expect("registry rejects record before __index", recordReads == 0)

	local wrongOriginStringAccepted = pcall(function()
		local origin = baseOrigin()
		origin.worldId = 123 :: any
		WorldEntity.new({
			id = "entity:wrong-origin-string",
			kind = "test-object",
			origin = origin,
		})
	end)
	expect("origin rejects non-string fields intentionally", not wrongOriginStringAccepted)

	local valid = WorldEntity.new({
		id = "entity:plain-valid",
		kind = "test-object",
		origin = baseOrigin(),
		persistentState = { open = false },
	})
	local registry = WorldEntity.createRegistry()
	local registered = WorldEntity.register(registry, valid)
	expect("valid plain entity still registers", registered and WorldEntity.get(registry, valid.id) ~= nil)

	return failures
end

return run
