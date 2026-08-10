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

	local function validRecord()
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
			persistentState = { open = false },
			stateRevision = 0,
			representationRevision = 0,
		}
	end

	local valid = validRecord()
	local validRegistry = WorldEntity.createRegistry()
	local validAccepted = WorldEntity.register(validRegistry, valid :: any)
	expectEqual("exact structural record remains accepted", validAccepted, true)
	local owned = WorldEntity.get(validRegistry, valid.id) :: any
	expectEqual("exact structural record remains defensively owned", owned == valid, false)
	expectEqual("optional origin regionId remains canonical", owned.origin.regionId, "region:office-a")

	local extraRecordField = validRecord()
	extraRecordField.authorityLease = "unversioned"
	local extraRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraRecordField :: any)
	end)
	expectEqual("registration rejects unknown record fields", extraRecordAccepted, false)

	local extraOriginField = validRecord()
	extraOriginField.origin.workerHint = "unversioned"
	local extraOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraOriginField :: any)
	end)
	expectEqual("registration rejects unknown origin fields", extraOriginAccepted, false)

	local metatableRecord = setmetatable({}, {
		__index = validRecord(),
	})
	local metatableRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableRecord :: any)
	end)
	expectEqual("registration rejects metatable-backed records", metatableRecordAccepted, false)

	local metatableOriginRecord = validRecord()
	metatableOriginRecord.origin = setmetatable({}, {
		__index = validRecord().origin,
	})
	local metatableOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableOriginRecord :: any)
	end)
	expectEqual("registration rejects metatable-backed origins", metatableOriginAccepted, false)

	local numericRecordKey = validRecord()
	numericRecordKey[1] = "unversioned"
	local numericRecordKeyAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), numericRecordKey :: any)
	end)
	expectEqual("registration rejects non-string record fields", numericRecordKeyAccepted, false)

	local numericOriginKey = validRecord()
	numericOriginKey.origin[1] = "unversioned"
	local numericOriginKeyAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), numericOriginKey :: any)
	end)
	expectEqual("registration rejects non-string origin fields", numericOriginKeyAccepted, false)

	return failures
end

return run
