local ProductionLoader = require("./support/ProductionLoader")

local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
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

	local authoredDoorMass = 0
	local weightedDoorX = 0
	local weightedDoorY = 0
	local weightedDoorZ = 0
	for _, component in ipairs(doorGenome.components) do
		authoredDoorMass += component.massKg
		weightedDoorX += component.massKg * component.localPositionM.x
		weightedDoorY += component.massKg * component.localPositionM.y
		weightedDoorZ += component.massKg * component.localPositionM.z
	end
	local doorMassMatchesComponents = math.abs(authoredDoorMass - doorGenome.massKg) < 1e-9
	local doorCenterOfMassMatchesComponents = false
	if authoredDoorMass > 0 then
		doorCenterOfMassMatchesComponents = math.abs(
			doorGenome.centerOfMassM.x - weightedDoorX / authoredDoorMass
		) < 1e-9 and math.abs(doorGenome.centerOfMassM.y - weightedDoorY / authoredDoorMass) < 1e-9 and math.abs(
			doorGenome.centerOfMassM.z - weightedDoorZ / authoredDoorMass
		) < 1e-9
	end

	expect("lab commercial door frame revision is explicit", doorGenome.familyVersion == 3)
	expect("lab commercial door F2 frame leaves a real aperture", frameIsHollow)
	expect("lab commercial door F2 leaf has positive proxy clearance", leafHasPositiveClearance)
	expect("lab commercial door hinge references the structural jamb", hingeUsesJamb)
	expect("lab commercial door component masses match authored total", doorMassMatchesComponents)
	expect(
		"lab commercial door center of mass matches component mass distribution",
		doorCenterOfMassMatchesComponents
	)

	local cartGenome = PhysicsLabRecipe.objectGenome("rollingCart")
	local cartGroundY = -cartGenome.dimensionsM.y / 2
	local cartComponentsByKey = {}
	for _, component in ipairs(cartGenome.components) do
		cartComponentsByKey[component.key] = component
	end
	local cartChassis = cartComponentsByKey.chassis
	local cartGroundSupportsTouch = true
	local cartGroundSupportCount = 0
	local cartCasterChassisSupportsTouch = cartChassis ~= nil
	local cartChassisSupportCount = 0
	local authoredCartMass = 0
	local weightedCartX = 0
	local weightedCartY = 0
	local weightedCartZ = 0
	for _, component in ipairs(cartGenome.components) do
		authoredCartMass += component.massKg
		weightedCartX += component.massKg * component.localPositionM.x
		weightedCartY += component.massKg * component.localPositionM.y
		weightedCartZ += component.massKg * component.localPositionM.z
		if component.externalSupport == "ground" then
			cartGroundSupportCount += 1
			local componentBottom = component.localPositionM.y - component.dimensionsM.y / 2
			if math.abs(componentBottom - cartGroundY) >= 1e-9 then
				cartGroundSupportsTouch = false
			end
		end
	end
	if cartChassis ~= nil then
		local chassisBottom = cartChassis.localPositionM.y - cartChassis.dimensionsM.y / 2
		for _, supportKey in ipairs(cartChassis.supportKeys) do
			cartChassisSupportCount += 1
			local caster = cartComponentsByKey[supportKey]
			if caster == nil or caster.externalSupport ~= "ground" then
				cartCasterChassisSupportsTouch = false
			else
				local casterTop = caster.localPositionM.y + caster.dimensionsM.y / 2
				if math.abs(casterTop - chassisBottom) >= 1e-9 then
					cartCasterChassisSupportsTouch = false
				end
			end
		end
	end
	local cartMassMatchesComponents = math.abs(authoredCartMass - cartGenome.massKg) < 1e-9
	local cartCenterOfMassMatchesComponents = false
	if authoredCartMass > 0 then
		cartCenterOfMassMatchesComponents = math.abs(
			cartGenome.centerOfMassM.x - weightedCartX / authoredCartMass
		) < 1e-9 and math.abs(cartGenome.centerOfMassM.y - weightedCartY / authoredCartMass) < 1e-9 and math.abs(
			cartGenome.centerOfMassM.z - weightedCartZ / authoredCartMass
		) < 1e-9
	end

	expect("lab rolling cart geometry revision is explicit", cartGenome.familyVersion == 2)
	expect(
		"lab rolling cart ground-supported casters contact the authored ground plane",
		cartGroundSupportCount == 4 and cartGroundSupportsTouch
	)
	expect(
		"lab rolling cart caster supports contact the authored chassis underside",
		cartChassisSupportCount == 4 and cartCasterChassisSupportsTouch
	)
	expect("lab rolling cart component masses match authored total", cartMassMatchesComponents)
	expect(
		"lab rolling cart center of mass matches component mass distribution",
		cartCenterOfMassMatchesComponents
	)

	local duplicateAccepted = WorldEntity.register(registry, first.entities[1].entity)
	expect("lab duplicate identity is detectable", duplicateAccepted == false)

	return failures
end

return run
