local ProductionLoader = require("./support/ProductionLoader")

local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local StableId = ProductionLoader.requireShared("Core/StableId")
local WorldEntity = ProductionLoader.requireShared("Reality/WorldEntity")

local function componentByKey(genome, key)
	for _, component in ipairs(genome.components) do
		if component.key == key then
			return component
		end
	end
	return nil
end

local function overlapsStrictlyOnAxis(positionA, sizeA, positionB, sizeB)
	return math.abs(positionA - positionB) * 2 < sizeA + sizeB - 1e-9
end

local function componentsVolumetricallyOverlap(left, right)
	return overlapsStrictlyOnAxis(
		left.localPositionM.x,
		left.dimensionsM.x,
		right.localPositionM.x,
		right.dimensionsM.x
	) and overlapsStrictlyOnAxis(
		left.localPositionM.y,
		left.dimensionsM.y,
		right.localPositionM.y,
		right.dimensionsM.y
	) and overlapsStrictlyOnAxis(
		left.localPositionM.z,
		left.dimensionsM.z,
		right.localPositionM.z,
		right.dimensionsM.z
	)
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL {name}`)
		else
			print(`PASS {name}`)
		end
	end

	local first = PhysicsLabRecipe.build()
	local second = PhysicsLabRecipe.build()

	expect("lab schema is explicit", first.schemaVersion == PhysicsLabRecipe.SCHEMA_VERSION)
	expect("lab recipe key is explicit", first.recipeKey == PhysicsLabRecipe.RECIPE_KEY)
	expect(
		"lab world id is deterministic",
		first.worldId == second.worldId and StableId.is(first.worldId, "world")
	)
	expect(
		"lab region id is deterministic",
		first.regionId == second.regionId and StableId.is(first.regionId, "region")
	)
	expect("lab entity count is deterministic", #first.entities == #second.entities and #first.entities == 20)

	local requiredKeys = {
		floor = true,
		ceiling = true,
		["wall-left"] = true,
		["wall-right"] = true,
		["wall-back"] = true,
		["wall-front-left"] = true,
		["wall-front-right"] = true,
		["wall-front-header"] = true,
		ramp = true,
		ledge = true,
		["stair-1"] = true,
		["stair-2"] = true,
		["stair-3"] = true,
		["stair-4"] = true,
		["character-spawn-anchor"] = true,
		["door-main"] = true,
		["chair-a"] = true,
		["table-a"] = true,
		["cabinet-a"] = true,
		["cart-a"] = true,
	}
	local seenKeys = {}
	local seenIds = {}
	local registry = WorldEntity.createRegistry()
	local deterministicEntries = true
	local allEntityIdsValid = true
	local allRegistrationsValid = true
	local allMaterialRefsValid = true
	local allObjectContractsValid = true
	local allInitialFidelityF2 = true

	for index, entityRecipe in ipairs(first.entities) do
		local comparison = second.entities[index]
		if
			comparison == nil
			or comparison.kind ~= entityRecipe.kind
			or comparison.key ~= entityRecipe.key
			or comparison.entity.id ~= entityRecipe.entity.id
		then
			deterministicEntries = false
		end

		seenKeys[entityRecipe.key] = true
		if seenIds[entityRecipe.entity.id] then
			allEntityIdsValid = false
		end
		seenIds[entityRecipe.entity.id] = true
		if not StableId.is(entityRecipe.entity.id, "entity") then
			allEntityIdsValid = false
		end
		if entityRecipe.entity.fidelity ~= "F2" then
			allInitialFidelityF2 = false
		end
		if
			entityRecipe.entity.origin.worldId ~= first.worldId
			or entityRecipe.entity.origin.regionId ~= first.regionId
			or entityRecipe.entity.origin.generator ~= "physics-lab.recipe"
			or entityRecipe.entity.origin.generatorVersion ~= PhysicsLabRecipe.GENERATOR_VERSION
		then
			allEntityIdsValid = false
		end

		local registered, duplicate = WorldEntity.register(registry, entityRecipe.entity)
		if not registered or duplicate ~= nil then
			allRegistrationsValid = false
		end

		if entityRecipe.kind == "primitive" then
			local materialReport = MaterialDNA.validateReference(entityRecipe.material)
			if not materialReport.ok then
				allMaterialRefsValid = false
			end
		else
			local genome = PhysicsLabRecipe.objectGenome(entityRecipe.genomeKey)
			local genomeReport = ObjectGenome.inspect(genome)
			local stateReport = ObjectGenome.inspectState(genome, entityRecipe.entity.persistentState)
			if
				not genomeReport.ok
				or not stateReport.ok
				or entityRecipe.genomeId ~= ObjectGenome.identityKey(genome)
				or entityRecipe.genomeRecipeFingerprint ~= ObjectGenome.recipeFingerprint(genome)
			then
				allObjectContractsValid = false
			end
		end
	end

	local allRequiredKeysPresent = true
	for key in pairs(requiredKeys) do
		if not seenKeys[key] then
			allRequiredKeysPresent = false
		end
	end

	expect("lab entity sequence is deterministic", deterministicEntries)
	expect("lab includes every required shell/object key", allRequiredKeysPresent)
	expect("lab WorldEntity ids are unique StableIds", allEntityIdsValid)
	expect(
		"lab WorldEntity registry accepts every entity once",
		allRegistrationsValid and WorldEntity.count(registry) == 20
	)
	expect("lab primitive material references satisfy MaterialDNA", allMaterialRefsValid)
	expect("lab object placements bind valid ObjectGenome recipes and default state", allObjectContractsValid)
	expect("lab shell starts as explicit F2 proxy fidelity", allInitialFidelityF2)

	local duplicateAccepted = WorldEntity.register(registry, first.entities[1].entity)
	expect("lab duplicate identity is detectable", duplicateAccepted == false)

	local door = PhysicsLabRecipe.objectGenome("commercialDoor")
	local hingeJamb = componentByKey(door, "hinge-jamb")
	local strikeJamb = componentByKey(door, "strike-jamb")
	local header = componentByKey(door, "header")
	local leaf = componentByKey(door, "leaf")
	expect(
		"door uses jamb/header construction instead of a solid frame slab",
		hingeJamb ~= nil
			and strikeJamb ~= nil
			and header ~= nil
			and leaf ~= nil
			and componentByKey(door, "frame") == nil
	)

	if hingeJamb ~= nil and strikeJamb ~= nil and header ~= nil and leaf ~= nil then
		local openingWidth = (strikeJamb.localPositionM.x - strikeJamb.dimensionsM.x * 0.5)
			- (hingeJamb.localPositionM.x + hingeJamb.dimensionsM.x * 0.5)
		local headerBottom = header.localPositionM.y - header.dimensionsM.y * 0.5
		local leafTop = leaf.localPositionM.y + leaf.dimensionsM.y * 0.5
		expect("door jambs preserve horizontal leaf clearance", openingWidth > leaf.dimensionsM.x)
		expect("door header preserves vertical leaf clearance", headerBottom - leafTop >= 0.005)

		local frameClearsLeaf = true
		for _, component in ipairs(door.components) do
			if component.key ~= "leaf" and componentsVolumetricallyOverlap(component, leaf) then
				frameClearsLeaf = false
				break
			end
		end
		expect("door closed leaf does not volumetrically overlap its frame", frameClearsLeaf)
	end

	local hingeUsesStructuralJamb = false
	for _, mechanism in ipairs(door.mechanisms) do
		if mechanism.kind == "hinge" and mechanism.key == "leaf-hinge" then
			hingeUsesStructuralJamb = mechanism.movingComponentKey == "leaf"
				and mechanism.frameComponentKey == "hinge-jamb"
			break
		end
	end
	expect("door hinge binds leaf to the structural hinge jamb", hingeUsesStructuralJamb)

	local authoredDoorMass = 0
	for _, component in ipairs(door.components) do
		authoredDoorMass += component.massKg
	end
	expect(
		"door component masses preserve the authored total mass",
		math.abs(authoredDoorMass - door.massKg) < 1e-9
	)

	return failures
end

return run
