local ProductionLoader = require("./support/ProductionLoader")

local FidelityManager = ProductionLoader.requireShared("Physics/FidelityManager")
local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local ObjectGenomeFixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")
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

	expect("recipe validates through production contracts", pcall(PhysicsLabRecipe.validate, first))
	expect("recipe id uses dedicated stable namespace", StableId.is(first.recipeId, "physics-lab"))
	expect("world id is stable", StableId.is(first.worldId, "world"))
	expect("region id is stable", StableId.is(first.regionId, "region"))
	expect("recipe build has deterministic element count", #first.elements == #second.elements)
	expect("recipe includes substantial lab geometry", #first.elements >= 19)

	local requiredRoles = {}
	for role in pairs(PhysicsLabRecipe.RequiredRoles) do
		requiredRoles[role] = false
	end

	local ids = {}
	local manager = FidelityManager.new()
	for index, element in first.elements do
		local repeated = second.elements[index]
		expect(`element {index} key deterministic`, repeated ~= nil and element.key == repeated.key)
		expect(
			`element {index} id deterministic`,
			repeated ~= nil and element.entity.id == repeated.entity.id
		)
		expect(
			`element {index} transform deterministic`,
			repeated ~= nil
				and element.positionStuds.x == repeated.positionStuds.x
				and element.positionStuds.y == repeated.positionStuds.y
				and element.positionStuds.z == repeated.positionStuds.z
				and element.sizeStuds.x == repeated.sizeStuds.x
				and element.sizeStuds.y == repeated.sizeStuds.y
				and element.sizeStuds.z == repeated.sizeStuds.z
				and element.yawDegrees == repeated.yawDegrees
		)
		expect(`element {index} WorldEntityId valid`, WorldEntity.isId(element.entity.id))
		expect(`element {index} WorldEntityId unique`, ids[element.entity.id] == nil)
		ids[element.entity.id] = true
		expect(
			`element {index} exact MaterialDNA ref valid`,
			MaterialDNA.validateReference(element.material).ok
		)
		expect(`element {index} world origin bound`, element.entity.origin.worldId == first.worldId)
		expect(`element {index} region origin bound`, element.entity.origin.regionId == first.regionId)
		expect(`element {index} recipe key bound`, element.entity.origin.recipeKey == element.key)
		if element.objectGenomeId ~= nil then
			expect(
				`element {index} fixture ObjectState binds genome identity`,
				element.entity.persistentState.genomeId == element.objectGenomeId
			)
		else
			expect(`element {index} proxy state begins empty`, next(element.entity.persistentState) == nil)
		end
		expect(`element {index} state revision begins zero`, element.entity.stateRevision == 0)
		expect(
			`element {index} representation revision begins zero`,
			element.entity.representationRevision == 0
		)

		manager:register(element.entity.id, element.entity.fidelity)
		expect(
			`element {index} FidelityManager accepts WorldEntity contract`,
			manager:getObservedLevel(element.entity.id) == element.entity.fidelity
		)

		if requiredRoles[element.role] ~= nil then
			requiredRoles[element.role] = true
		end
	end

	for role, present in pairs(requiredRoles) do
		expect(`required lab role present: {role}`, present)
	end

	local expectedGenomeByRole = {
		chair = ObjectGenome.identityKey(ObjectGenomeFixtures.officeChair),
		table = ObjectGenome.identityKey(ObjectGenomeFixtures.officeTable),
		cabinet = ObjectGenome.identityKey(ObjectGenomeFixtures.filingCabinet),
	}
	for role, expectedGenomeId in pairs(expectedGenomeByRole) do
		local matched = nil
		for _, element in first.elements do
			if element.role == role then
				matched = element
				break
			end
		end
		expect(`${role} lab proxy exists`, matched ~= nil)
		expect(
			`${role} uses landed ObjectGenome identity and state`,
			matched ~= nil
				and matched.objectGenomeId == expectedGenomeId
				and StableId.is(matched.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE)
				and matched.entity.kind == "object"
				and matched.entity.persistentState.genomeId == expectedGenomeId
		)
	end

	local hasHingedDoor = false
	local hasDrawerProxy = false
	local stairCount = 0
	for _, element in first.elements do
		if element.role == "door" and element.representationKind == "hinged-panel" then
			hasHingedDoor = true
		elseif element.role == "cabinet" and element.representationKind == "sliding-drawer-proxy" then
			hasDrawerProxy = true
		elseif element.role == "stairs" then
			stairCount += 1
		end
	end
	expect("lab includes a hinged door representation contract", hasHingedDoor)
	expect("lab includes a drawer mechanism representation contract", hasDrawerProxy)
	expect("lab stairs are actual stepped geometry", stairCount >= 4)

	local mutationAccepted = pcall(function()
		first.elements[1].positionStuds.x = 999
	end)
	expect("resolved lab recipe rejects nested mutation", not mutationAccepted)

	return failures
end

return run
