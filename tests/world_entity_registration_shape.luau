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

	local function registrationFixture()
		return {
			id = "entity:registration-shape",
			kind = "office-chair",
			origin = {
				worldId = "world:0000000000000001",
				regionId = "region:office-a",
				generator = "objects.office",
				generatorVersion = 1,
				recipeKey = "chair/registration-shape",
			},
			fidelity = "F1",
			persistentState = { open = false },
			stateRevision = 0,
			representationRevision = 0,
		}
	end

	local topLevelBacking = registrationFixture()
	local topLevelIndexCalls = 0
	local metatableRecord = setmetatable({}, {
		__index = function(_, key)
			topLevelIndexCalls += 1
			return topLevelBacking[key]
		end,
	})
	local metatableRecordAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableRecord :: any)
	end)
	expectEqual("registry rejects metatable-backed record", metatableRecordAccepted, false)
	expectEqual("record metatable is rejected before __index", topLevelIndexCalls, 0)

	local metatableOriginRecord = registrationFixture()
	local originBacking = metatableOriginRecord.origin
	local originIndexCalls = 0
	metatableOriginRecord.origin = setmetatable({}, {
		__index = function(_, key)
			originIndexCalls += 1
			return originBacking[key]
		end,
	})
	local metatableOriginAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), metatableOriginRecord :: any)
	end)
	expectEqual("registry rejects metatable-backed origin", metatableOriginAccepted, false)
	expectEqual("origin metatable is rejected before __index", originIndexCalls, 0)

	local unknownRecordField = registrationFixture()
	unknownRecordField.authorityLease = "future-field"
	local unknownRecordFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), unknownRecordField :: any)
	end)
	expectEqual("registry rejects unknown record field", unknownRecordFieldAccepted, false)

	local unknownOriginField = registrationFixture()
	unknownOriginField.origin.futureField = "future-field"
	local unknownOriginFieldAccepted = pcall(function()
		WorldEntity.register(WorldEntity.createRegistry(), unknownOriginField :: any)
	end)
	expectEqual("registry rejects unknown origin field", unknownOriginFieldAccepted, false)

	local validMutableRecord = registrationFixture()
	local registry = WorldEntity.createRegistry()
	local validMutableAccepted = WorldEntity.register(registry, validMutableRecord :: any)
	expectEqual("registry still accepts valid mutable structural record", validMutableAccepted, true)
	local ownedRecord = WorldEntity.get(registry, validMutableRecord.id) :: any
	expectEqual("registry still owns a fresh snapshot", ownedRecord == validMutableRecord, false)
	local ownedRecordMutationAccepted = pcall(function()
		ownedRecord.kind = "mutated"
	end)
	expectEqual("owned record remains immutable", ownedRecordMutationAccepted, false)

	return failures
end

return run
