local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function makeOrigin()
	return {
		worldId = "world:new-state-shape",
		regionId = "region:test",
		generator = "tests.world-entity",
		generatorVersion = 1,
		recipeKey = "new-state-shape",
	}
end

local function makeSpec()
	return {
		id = "entity:new-state-shape",
		kind = "test-object",
		origin = makeOrigin(),
		fidelity = "F1",
		persistentState = { open = false },
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

	local function newAccepts(spec): boolean
		return pcall(function()
			WorldEntity.new(spec)
		end)
	end

	expect("new accepts exact mutable spec shape", newAccepts(makeSpec()))

	local extraSpec = makeSpec()
	extraSpec.authorityLease = "future-field"
	expect("new rejects unknown spec field", not newAccepts(extraSpec))

	local specReads = 0
	local specBacking = makeSpec()
	local metatableSpec = setmetatable({}, {
		__index = function(_, key)
			specReads += 1
			return specBacking[key]
		end,
	})
	expect("new rejects spec metatable", not newAccepts(metatableSpec))
	expect("new rejects spec before __index", specReads == 0)

	local metatableState = makeSpec()
	metatableState.persistentState = setmetatable({ open = false }, {})
	expect("new rejects top-level persistentState metatable", not newAccepts(metatableState))

	local falseState = makeSpec()
	falseState.persistentState = false
	expect("new rejects false persistentState instead of normalizing empty", not newAccepts(falseState))

	local missingState = makeSpec()
	missingState.persistentState = nil
	local missingStateOk, missingStateRecord = pcall(function()
		return WorldEntity.new(missingState)
	end)
	expect(
		"new still defaults omitted persistentState",
		missingStateOk and next(missingStateRecord.persistentState) == nil
	)

	local wrongWorldId = makeSpec()
	wrongWorldId.origin.worldId = 123
	local wrongWorldIdOk, wrongWorldIdError = pcall(function()
		WorldEntity.new(wrongWorldId)
	end)
	expect(
		"origin primitive type failure is intentional",
		not wrongWorldIdOk and string.find(tostring(wrongWorldIdError), "origin.worldId must be a string", 1, true) ~= nil
	)

	local wrongGeneratorVersion = makeSpec()
	wrongGeneratorVersion.origin.generatorVersion = "1"
	local wrongVersionOk, wrongVersionError = pcall(function()
		WorldEntity.new(wrongGeneratorVersion)
	end)
	expect(
		"origin numeric type failure is intentional",
		not wrongVersionOk
			and string.find(tostring(wrongVersionError), "origin.generatorVersion must be a number", 1, true) ~= nil
	)

	return failures
end

return run
