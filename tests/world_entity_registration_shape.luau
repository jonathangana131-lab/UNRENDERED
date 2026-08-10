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

	local function makeOrigin()
		return {
			worldId = "world:shape-boundary",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/shape-boundary",
		}
	end

	local function makeRecord()
		return {
			id = "entity:shape-boundary",
			kind = "office-chair",
			origin = makeOrigin(),
			fidelity = "F1",
			persistentState = { open = false },
			stateRevision = 0,
			representationRevision = 0,
		}
	end

	local validRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), makeRecord() :: any)
	end)
	expectEqual("registration accepts exact plain record", validRecordAccepted, true)

	local extraRecordField = makeRecord()
	extraRecordField.authorityLease = "unexpected"
	local extraRecordFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraRecordField :: any)
	end)
	expectEqual("registration rejects undeclared record field", extraRecordFieldAccepted, false)

	local extraOriginField = makeRecord()
	extraOriginField.origin.constructionEpoch = 1994
	local extraOriginFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraOriginField :: any)
	end)
	expectEqual("registration rejects undeclared origin field", extraOriginFieldAccepted, false)

	local recordReads = 0
	local recordBacking = makeRecord()
	local metatableRecord = setmetatable({}, {
		__index = function(_, key)
			recordReads += 1
			return recordBacking[key]
		end,
	})
	local metatableRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableRecord :: any)
	end)
	expectEqual("registration rejects metatable-backed record", metatableRecordAccepted, false)
	expectEqual("record metatable is rejected before canonical field reads", recordReads, 0)

	local originReads = 0
	local originBacking = makeOrigin()
	local metatableOrigin = setmetatable({}, {
		__index = function(_, key)
			originReads += 1
			return originBacking[key]
		end,
	})
	local recordWithMetatableOrigin = makeRecord()
	recordWithMetatableOrigin.origin = metatableOrigin
	local metatableOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), recordWithMetatableOrigin :: any)
	end)
	expectEqual("registration rejects metatable-backed origin", metatableOriginAccepted, false)
	expectEqual("origin metatable is rejected before canonical field reads", originReads, 0)

	return failures
end

return run
