local ProductionLoader = require("./support/ProductionLoader")

local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local StableId = ProductionLoader.requireShared("Core/StableId")
local WorldEntity = ProductionLoader.requireShared("Reality/WorldEntity")

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
	expect("lab region id is owned by resolved-region truth", first.regionId == first.resolvedRegion.regionId)
	expect(
		"lab resolved-region recipe is deterministic",
		ResolvedRegionRecipe.equal(first.resolvedRegion, second.resolvedRegion)
	)
	local reconstructedRegion =
		ResolvedRegionRecipe.deserialize(ResolvedRegionRecipe.serialize(first.resolvedRegion))
	expect(
		"lab resolved-region recipe reconstructs exactly",
		ResolvedRegionRecipe.equal(first.resolvedRegion, reconstructedRegion)
	)
	expect(
		"lab resolved-region repro identity is deterministic",
		ResolvedRegionRecipe.reproKey(first.resolvedRegion)
			== ResolvedRegionRecipe.reproKey(second.resolvedRegion)
	)
	expect(
		"lab resolved-region versions are explicitly locked",
		first.resolvedRegion.generatorVersions.reality == 1
			and first.resolvedRegion.generatorVersions.topology == 1
			and first.resolvedRegion.generatorVersions.material == 1
			and first.resolvedRegion.generatorVersions.object == 1
			and first.resolvedRegion.generatorVersions.entity == 1
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
	local resolvedContentKeys = {}
	for _, key in ipairs(first.resolvedRegion.canonicalContentKeys) do
		resolvedContentKeys[key] = true
	end
	local allEntitiesBelongToResolvedBase = true
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
		if not resolvedContentKeys[entityRecipe.key] then
			allEntitiesBelongToResolvedBase = false
		end
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
	expect(
		"lab resolved-region base accounts for every placed entity",
		allEntitiesBelongToResolvedBase and #first.resolvedRegion.canonicalContentKeys == #first.entities
	)
	expect("lab WorldEntity ids are unique StableIds", allEntityIdsValid)
	expect(
		"lab WorldEntity registry accepts every entity once",
		allRegistrationsValid and WorldEntity.count(registry) == 20
	)
	expect("lab primitive material references satisfy MaterialDNA", allMaterialRefsValid)
	expect("lab object placements bind valid ObjectGenome recipes and default state", allObjectContractsValid)
	expect("lab shell starts as explicit F2 proxy fidelity", allInitialFidelityF2)

	local doorGenome = PhysicsLabRecipe.objectGenome("commercialDoor")
	local doorComponents = {}
	for _, component in ipairs(doorGenome.components) do
		doorComponents[component.key] = component
	end
	local hingeJamb = doorComponents["hinge-jamb"]
	local latchJamb = doorComponents["latch-jamb"]
	local header = doorComponents.header
	local leaf = doorComponents.leaf
	local frameIsHollow = doorComponents.frame == nil
		and hingeJamb ~= nil
		and latchJamb ~= nil
		and header ~= nil
		and leaf ~= nil
		and hingeJamb.dimensionsM.x < doorGenome.dimensionsM.x / 4
		and latchJamb.dimensionsM.x < doorGenome.dimensionsM.x / 4
		and header.dimensionsM.y < doorGenome.dimensionsM.y / 4
	local leafHasPositiveClearance = false
	if frameIsHollow then
		local leafLeft = leaf.localPositionM.x - leaf.dimensionsM.x / 2
		local leafRight = leaf.localPositionM.x + leaf.dimensionsM.x / 2
		local leafBottom = leaf.localPositionM.y - leaf.dimensionsM.y / 2
		local leafTop = leaf.localPositionM.y + leaf.dimensionsM.y / 2
		local hingeInner = hingeJamb.localPositionM.x + hingeJamb.dimensionsM.x / 2
		local latchInner = latchJamb.localPositionM.x - latchJamb.dimensionsM.x / 2
		local headerBottom = header.localPositionM.y - header.dimensionsM.y / 2
		local frameBottom = -doorGenome.dimensionsM.y / 2
		local hingeClearance = leafLeft - hingeInner
		local latchClearance = latchInner - leafRight
		local floorClearance = leafBottom - frameBottom
		local headerClearance = headerBottom - leafTop
		local maximumProxyGap = 0.01
		leafHasPositiveClearance = hingeClearance > 0
			and hingeClearance <= maximumProxyGap
			and latchClearance > 0
			and latchClearance <= maximumProxyGap
			and floorClearance > 0
			and floorClearance <= maximumProxyGap
			and headerClearance > 0
			and headerClearance <= maximumProxyGap
	end
	local hingeUsesJamb = false
	for _, mechanism in ipairs(doorGenome.mechanisms) do
		if mechanism.key == "leaf-hinge" then
			hingeUsesJamb = mechanism.kind == "hinge" and mechanism.frameComponentKey == "hinge-jamb"
		end
	end
	expect("lab commercial door frame revision is explicit", doorGenome.familyVersion == 2)
	expect("lab commercial door F2 frame leaves a real aperture", frameIsHollow)
	expect("lab commercial door F2 leaf has positive proxy clearance", leafHasPositiveClearance)
	expect("lab commercial door hinge references the structural jamb", hingeUsesJamb)

	local duplicateAccepted = WorldEntity.register(registry, first.entities[1].entity)
	expect("lab duplicate identity is detectable", duplicateAccepted == false)

	return failures
end

return run
