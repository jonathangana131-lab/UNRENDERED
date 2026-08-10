local ProductionLoader = require("./support/ProductionLoader")

local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local PhysicsLabRecipe = ProductionLoader.requireShared("PhysicsLab/PhysicsLabRecipe")
local StableId = ProductionLoader.requireShared("Core/StableId")
local WorldEntity = ProductionLoader.requireShared("Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS physics_lab_recipe {name}`)
		else
			failures += 1
			print(`FAIL physics_lab_recipe {name}`)
		end
	end

	local first = PhysicsLabRecipe.build()
	local second = PhysicsLabRecipe.build()

	expect("schema version is explicit", first.schemaVersion == 1 and first.recipeVersion == 1)
	expect("scale contract is explicit", first.metersPerStud == 0.28)
	expect("lab world and region are stable", first.worldId == second.worldId and first.regionId == second.regionId)
	expect("lab has locked shell item count", #first.items == 17 and #second.items == 17)

	local requiredKinds = {
		["block"] = false,
		["ramp"] = false,
		["stairs"] = false,
		["door-probe"] = false,
		["cart-probe"] = false,
		["object-genome"] = false,
		["spawn-anchor"] = false,
	}
	local requiredKeys = {
		["floor"] = false,
		["ceiling"] = false,
		["door-probe"] = false,
		["office-chair"] = false,
		["office-table"] = false,
		["filing-cabinet"] = false,
		["rolling-cart-probe"] = false,
		["ramp"] = false,
		["stairs"] = false,
		["ledge"] = false,
		["physical-character-spawn"] = false,
	}
	local seenIds = {}

	for index, item in ipairs(first.items) do
		local repeatItem = second.items[index]
		expect(`item {item.key} has stable ordering`, repeatItem ~= nil and repeatItem.key == item.key)
		expect(
			`item {item.key} has deterministic WorldEntityId`,
			repeatItem ~= nil and repeatItem.entity.id == item.entity.id
		)
		expect(`item {item.key} uses WorldEntityId contract`, WorldEntity.isId(item.entity.id))
		expect(
			`item {item.key} uses project StableId namespace`,
			StableId.is(item.entity.id, PhysicsLabRecipe.WorldEntityNamespace)
		)
		expect(`item {item.key} has unique WorldEntityId`, seenIds[item.entity.id] == nil)
		seenIds[item.entity.id] = true
		expect(
			`item {item.key} origin binds lab recipe`,
			item.entity.origin.worldId == first.worldId
				and item.entity.origin.regionId == first.regionId
				and item.entity.origin.generator == first.generator
				and item.entity.origin.generatorVersion == first.generatorVersion
		)
		expect(
			`item {item.key} dimensions are positive`,
			item.dimensionsM.x > 0 and item.dimensionsM.y > 0 and item.dimensionsM.z > 0
		)

		requiredKinds[item.representationKind] = true
		if requiredKeys[item.key] ~= nil then
			requiredKeys[item.key] = true
		end

		if item.materialRef ~= nil then
			expect(
				`item {item.key} uses MaterialDNA reference contract`,
				MaterialDNA.validateReference(item.materialRef).ok
			)
		end

		if item.genome ~= nil then
			local report = ObjectGenome.inspect(item.genome)
			local identity = ObjectGenome.identityKey(item.genome)
			local fingerprint = ObjectGenome.recipeFingerprint(item.genome)
			expect(`item {item.key} ObjectGenome validates`, report.ok)
			expect(
				`item {item.key} persists ObjectGenome identity binding`,
				item.entity.persistentState.objectGenomeIdentity == identity
			)
			expect(
				`item {item.key} persists ObjectGenome recipe fingerprint`,
				item.entity.persistentState.objectGenomeRecipeFingerprint == fingerprint
			)
			expect(
				`item {item.key} persists valid default mutable state`,
				ObjectGenome.inspectState(item.genome, item.entity.persistentState.objectState).ok
			)
			for _, component in ipairs(item.genome.components) do
				expect(
					`item {item.key} component {component.key} uses MaterialDNA reference contract`,
					MaterialDNA.validateReference({
						id = component.materialKey,
						recipeVersion = component.materialRecipeVersion,
					}).ok
				)
			end
		end
	end

	for kind, present in pairs(requiredKinds) do
		expect(`lab includes representation kind {kind}`, present)
	end
	for key, present in pairs(requiredKeys) do
		expect(`lab includes required item {key}`, present)
	end

	return failures
end

return run
