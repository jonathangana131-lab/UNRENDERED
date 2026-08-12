local WorldEntity = require("../src/shared/Reality/WorldEntity")

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

	local metadataBudget = WorldEntity.MAX_PERSISTENT_STATE_STRING_BYTES
	local entityKind = "office-chair"
	local worldIdValue = "world:0000000000000001"
	local regionIdValue = "region:office-a"
	local generatorName = "objects.office"
	local fixedMetadataBytes = #entityKind + #worldIdValue + #regionIdValue + #generatorName
	local exactRecipeKeyBytes = metadataBudget - fixedMetadataBytes
	assert(exactRecipeKeyBytes > 0, "WorldEntity metadata budget must fit canonical fixture fields")

	local function makeEntity(entityId: string, recipeKeyBytes: number)
		return WorldEntity.new({
			id = entityId,
			kind = entityKind,
			origin = {
				worldId = worldIdValue,
				regionId = regionIdValue,
				generator = generatorName,
				generatorVersion = 1,
				recipeKey = string.rep("r", recipeKeyBytes),
			},
		})
	end

	-- Direct mutable records are also a supported registry ownership boundary and must share the same budget.
	local function makeMutableRecord(entityId: string, recipeKeyBytes: number)
		return {
			id = entityId,
			kind = entityKind,
			origin = {
				worldId = worldIdValue,
				regionId = regionIdValue,
				generator = generatorName,
				generatorVersion = 1,
				recipeKey = string.rep("r", recipeKeyBytes),
			},
			fidelity = "F0",
			persistentState = {},
			stateRevision = 0,
			representationRevision = 0,
		}
	end

	local exactRegistry = WorldEntity.createRegistry()
	local exactAccepted = pcall(function()
		local exactEntity = makeEntity("entity:canonical-metadata-exact-budget", exactRecipeKeyBytes)
		assert(WorldEntity.register(exactRegistry, exactEntity))
	end)
	expect("canonical metadata accepts exact aggregate string-byte budget", exactAccepted)

	local atomicRegistry = WorldEntity.createRegistry()
	local existingEntity = WorldEntity.new({
		id = "entity:canonical-metadata-existing",
		kind = entityKind,
		origin = {
			worldId = worldIdValue,
			regionId = regionIdValue,
			generator = generatorName,
			generatorVersion = 1,
			recipeKey = "chair/canonical-metadata-existing",
		},
	})
	assert(WorldEntity.register(atomicRegistry, existingEntity))
	local existingRecord = WorldEntity.get(atomicRegistry, existingEntity.id)
	local beforeCount = WorldEntity.count(atomicRegistry)
	local overBudgetId = "entity:canonical-metadata-over-budget"

	local overBudgetAccepted = pcall(function()
		local overBudgetEntity = makeEntity(overBudgetId, exactRecipeKeyBytes + 1)
		assert(WorldEntity.register(atomicRegistry, overBudgetEntity))
	end)
	expect("canonical metadata rejects one byte beyond aggregate string-byte budget", not overBudgetAccepted)
	expect(
		"rejected canonical metadata preserves registry count",
		WorldEntity.count(atomicRegistry) == beforeCount
	)
	expect(
		"rejected canonical metadata preserves existing registry truth",
		WorldEntity.get(atomicRegistry, existingEntity.id) == existingRecord
	)
	expect(
		"rejected canonical metadata leaves no retained record",
		WorldEntity.get(atomicRegistry, overBudgetId) == nil
	)

	local directRegistry = WorldEntity.createRegistry()
	local directExistingEntity = WorldEntity.new({
		id = "entity:canonical-metadata-direct-existing",
		kind = entityKind,
		origin = {
			worldId = worldIdValue,
			regionId = regionIdValue,
			generator = generatorName,
			generatorVersion = 1,
			recipeKey = "chair/canonical-metadata-direct-existing",
		},
	})
	assert(WorldEntity.register(directRegistry, directExistingEntity))
	local directExistingRecord = WorldEntity.get(directRegistry, directExistingEntity.id)
	local directBeforeCount = WorldEntity.count(directRegistry)
	local directOverBudgetId = "entity:canonical-metadata-direct-over-budget"
	local directOverBudgetAccepted = pcall(function()
		assert(
			WorldEntity.register(
				directRegistry,
				makeMutableRecord(directOverBudgetId, exactRecipeKeyBytes + 1)
			)
		)
	end)
	expect(
		"direct registry ownership rejects one byte beyond aggregate metadata budget",
		not directOverBudgetAccepted
	)
	expect(
		"rejected direct metadata preserves registry count",
		WorldEntity.count(directRegistry) == directBeforeCount
	)
	expect(
		"rejected direct metadata preserves existing registry truth",
		WorldEntity.get(directRegistry, directExistingEntity.id) == directExistingRecord
	)
	expect(
		"rejected direct metadata leaves no retained record",
		WorldEntity.get(directRegistry, directOverBudgetId) == nil
	)

	return failures
end

return run
