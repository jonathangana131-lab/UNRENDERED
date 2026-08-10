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

	local function makeRecord()
		return {
			id = "entity:record-shape",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				regionId = "region:office-a",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/record-shape",
			},
			fidelity = "F2",
			persistentState = {
				mechanism = { angle = 12 },
			},
			stateRevision = 3,
			representationRevision = 4,
		}
	end

	local validRecord = makeRecord()
	local validRegistry = WorldEntity.createRegistry()
	local validAccepted = WorldEntity.register(validRegistry, validRecord :: any)
	expectEqual("exact structural record still registers", validAccepted, true)
	local ownedRecord = WorldEntity.get(validRegistry, validRecord.id) :: any
	expectEqual("exact structural record is still defensively owned", ownedRecord == validRecord, false)
	expectEqual("optional origin regionId survives ownership", ownedRecord.origin.regionId, "region:office-a")

	local extraRecordField = makeRecord()
	extraRecordField.authorityLease = "future-field"
	local extraRecordFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraRecordField :: any)
	end)
	expectEqual("registry rejects undeclared record fields", extraRecordFieldAccepted, false)

	local extraOriginField = makeRecord()
	extraOriginField.origin.futureCanonicalField = "future-field"
	local extraOriginFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), extraOriginField :: any)
	end)
	expectEqual("registry rejects undeclared origin fields", extraOriginFieldAccepted, false)

	local recordFallback = makeRecord()
	local recordIndexReads = 0
	local metatableRecord = setmetatable({}, {
		__index = function(_, key)
			recordIndexReads += 1
			return recordFallback[key]
		end,
	})
	local metatableRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableRecord :: any)
	end)
	expectEqual("registry rejects metatable-backed records", metatableRecordAccepted, false)
	expectEqual("record metatable is rejected before __index reads", recordIndexReads, 0)

	local metatableOriginRecord = makeRecord()
	local originFallback = metatableOriginRecord.origin
	local originIndexReads = 0
	metatableOriginRecord.origin = setmetatable({}, {
		__index = function(_, key)
			originIndexReads += 1
			return originFallback[key]
		end,
	})
	local metatableOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableOriginRecord :: any)
	end)
	expectEqual("registry rejects metatable-backed origins", metatableOriginAccepted, false)
	expectEqual("origin metatable is rejected before __index reads", originIndexReads, 0)

	if failures > 0 then
		print(`WorldEntity record-shape tests failed: {failures}`)
	else
		print("WorldEntity record-shape tests passed")
	end

	return failures
end

return run
