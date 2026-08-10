local ProductionLoader = require("./support/ProductionLoader")

local FidelityManager = ProductionLoader.requireShared("Physics/FidelityManager")
local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local ObjectGenomeFixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")
local PhysicsLabObjectGenomes = ProductionLoader.requireShared("Physics/PhysicsLabObjectGenomes")
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
	expect("lab door ObjectGenome validates", ObjectGenome.inspect(PhysicsLabObjectGenomes.commercialDoor).ok)
	expect("lab cart ObjectGenome validates", ObjectGenome.inspect(PhysicsLabObjectGenomes.rollingCart).ok)

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
				and element.mechanismKey == repeated.mechanismKey
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
			local genome = PhysicsLabRecipe.objectGenomeFor(element)
			expect(`element {index} fixture ObjectGenome resolves`, genome ~= nil)
			expect(
				`element {index} fixture ObjectState binds genome identity`,
				element.entity.persistentState.genomeId == element.objectGenomeId
			)
			expect(
				`element {index} fixture ObjectState validates`,
				genome ~= nil and ObjectGenome.inspectState(genome, element.entity.persistentState).ok
			)
			if genome ~= nil then
				local componentMaterialsValid = true
				for _, component in ipairs(genome.components) do
					if
						not MaterialDNA.validateReference({
							id = component.materialKey,
							recipeVersion = component.materialRecipeVersion,
						}).ok
					then
						componentMaterialsValid = false
						break
					end
				end
				expect(`element {index} ObjectGenome material refs validate`, componentMaterialsValid)
			end
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
		door = ObjectGenome.identityKey(PhysicsLabObjectGenomes.commercialDoor),
		chair = ObjectGenome.identityKey(ObjectGenomeFixtures.officeChair),
		table = ObjectGenome.identityKey(ObjectGenomeFixtures.officeTable),
		cart = ObjectGenome.identityKey(PhysicsLabObjectGenomes.rollingCart),
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

	local door = nil
	local cabinet = nil
	local cart = nil
	local stairCount = 0
	for _, element in first.elements do
		if element.role == "door" and element.representationKind == "hinged-panel" then
			door = element
		elseif element.role == "cabinet" and element.representationKind == "sliding-drawer-proxy" then
			cabinet = element
		elseif element.role == "cart" and element.representationKind == "rolling-cart-proxy" then
			cart = element
		elseif element.role == "stairs" then
			stairCount += 1
		end
	end

	expect("lab includes a hinged door representation contract", door ~= nil)
	expect(
		"door ObjectGenome frame has positive clearance inside authored 4.4-stud opening",
		door ~= nil and door.sizeStuds.x < 4.4 and door.sizeStuds.y < 8
	)
	if door ~= nil then
		local mechanism = PhysicsLabRecipe.mechanismFor(door)
		expect("door proxy binds the production leaf hinge", door.mechanismKey == "leaf-hinge")
		expect("door hinge resolves through ObjectGenome", mechanism ~= nil and mechanism.kind == "hinge")
		if mechanism ~= nil and mechanism.kind == "hinge" then
			expect(
				"door proxy keeps authored hinge axis and limits",
				mechanism.axis.x == 0
					and mechanism.axis.y == 1
					and mechanism.axis.z == 0
					and mechanism.minDegrees == 0
					and mechanism.maxDegrees == 105
			)
		end
	end

	expect("lab includes a drawer mechanism representation contract", cabinet ~= nil)
	expect("cabinet proxy binds the production top-drawer mechanism", cabinet ~= nil and cabinet.mechanismKey == "slide-top")
	if cabinet ~= nil then
		local mechanism = PhysicsLabRecipe.mechanismFor(cabinet)
		expect("cabinet mechanism resolves through ObjectGenome", mechanism ~= nil and mechanism.kind == "slide")
		if mechanism ~= nil and mechanism.kind == "slide" then
			expect(
				"cabinet proxy keeps authored slide axis and travel",
				mechanism.axis.x == 0
					and mechanism.axis.y == 0
					and mechanism.axis.z == -1
					and mechanism.minTravelM == 0
					and mechanism.maxTravelM == 0.44
			)
		end
	end

	expect("lab includes a four-caster rolling-cart representation contract", cart ~= nil)
	if cart ~= nil then
		local genome = PhysicsLabRecipe.objectGenomeFor(cart)
		local casterCount = 0
		if genome ~= nil then
			for _, mechanism in ipairs(genome.mechanisms) do
				if mechanism.kind == "caster" then
					casterCount += 1
					expect(
						`cart caster {mechanism.key} uses authored axes`,
						mechanism.swivelAxis.x == 0
							and mechanism.swivelAxis.y == 1
							and mechanism.swivelAxis.z == 0
							and mechanism.rollAxis.x == 1
							and mechanism.rollAxis.y == 0
							and mechanism.rollAxis.z == 0
					)
				end
			end
		end
		expect("cart proxy consumes four ObjectGenome caster mechanisms", casterCount == 4)
	end

	expect("lab stairs are actual stepped geometry", stairCount >= 4)

	local mutationAccepted = pcall(function()
		first.elements[1].positionStuds.x = 999
	end)
	expect("resolved lab recipe rejects nested mutation", not mutationAccepted)

	return failures
end

return run
