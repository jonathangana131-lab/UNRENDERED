local ProductionLoader = require("./support/ProductionLoader")

local StableId = ProductionLoader.requireShared("Core/StableId")
local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function hasCode(report, code)
	for _, issue in ipairs(report.issues) do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function findComponent(genome, key)
	for _, component in ipairs(genome.components) do
		if component.key == key then
			return component
		end
	end
	return nil
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL object_genome {name}`)
		else
			print(`PASS object_genome {name}`)
		end
	end

	local fixtureCases = {
		{
			name = "office chair",
			genome = Fixtures.officeChair,
			identity = "object-genome:v1:3eb84b8e4e34773f3b23b044f63b9166",
		},
		{
			name = "office table",
			genome = Fixtures.officeTable,
			identity = "object-genome:v1:708d218fae658150bbaa0dfa4436be5d",
		},
		{
			name = "filing cabinet",
			genome = Fixtures.filingCabinet,
			identity = "object-genome:v1:97e4e25c11f73d49300c4ad7bc0a30a2",
		},
	}

	for _, fixture in ipairs(fixtureCases) do
		local report = ObjectGenome.inspect(fixture.genome)
		expect(fixture.name .. " validates", report.ok)

		local identity = ObjectGenome.identityKey(fixture.genome)
		expect(fixture.name .. " locked stable identity", identity == fixture.identity)
		expect(
			fixture.name .. " uses project StableId",
			StableId.is(identity, ObjectGenome.STABLE_ID_NAMESPACE)
		)
		expect(fixture.name .. " repeat identity", identity == ObjectGenome.identityKey(fixture.genome))

		for _, component in ipairs(fixture.genome.components) do
			expect(
				fixture.name .. " component uses MaterialDNA-style project key",
				string.match(component.materialKey, "^material%.v1%.") ~= nil
			)
			expect(
				fixture.name .. " component pins a material recipe revision",
				component.materialRecipeVersion == 1
			)
			expect(
				fixture.name .. " component reference satisfies production MaterialDNA",
				MaterialDNA.validateReference({
					id = component.materialKey,
					recipeVersion = component.materialRecipeVersion,
				}).ok
			)
		end

		local state = ObjectGenome.defaultState(fixture.genome)
		expect(
			fixture.name .. " default mutable state validates",
			ObjectGenome.inspectState(fixture.genome, state).ok
		)
	end

	local badDimensions = deepCopy(Fixtures.officeTable)
	badDimensions.dimensionsM.x = 9
	expect(
		"rejects dimensions outside family limits",
		hasCode(ObjectGenome.inspect(badDimensions), "dimensions.out_of_family_range")
	)

	local badMass = deepCopy(Fixtures.officeTable)
	badMass.components[1].massKg = 40
	expect(
		"rejects implausible component mass sum",
		hasCode(ObjectGenome.inspect(badMass), "mass.component_sum")
	)

	local badMaterial = deepCopy(Fixtures.officeChair)
	badMaterial.components[1].materialKey = ""
	expect(
		"rejects missing material assignment",
		hasCode(ObjectGenome.inspect(badMaterial), "component.material_reference")
	)

	local badMaterialRevision = deepCopy(Fixtures.officeChair)
	badMaterialRevision.components[1].materialRecipeVersion = 0
	expect(
		"rejects missing material recipe revision",
		hasCode(ObjectGenome.inspect(badMaterialRevision), "component.material_reference")
	)

	local legacyMaterial = deepCopy(Fixtures.officeChair)
	legacyMaterial.components[1].materialKey = "material:polymer-rubber.caster.v1"
	expect(
		"rejects legacy material reference syntax",
		hasCode(ObjectGenome.inspect(legacyMaterial), "component.material_reference")
	)

	local revisedMaterial = deepCopy(Fixtures.filingCabinet)
	local revisedShell = findComponent(revisedMaterial, "shell")
	local canonicalShell = findComponent(Fixtures.filingCabinet, "shell")
	if revisedShell ~= nil then
		revisedShell.materialRecipeVersion += 1
	end
	expect(
		"material recipe revision is retained as canonical object recipe input",
		revisedShell ~= nil
			and canonicalShell ~= nil
			and revisedShell.materialKey == canonicalShell.materialKey
			and revisedShell.materialRecipeVersion ~= canonicalShell.materialRecipeVersion
			and ObjectGenome.inspect(revisedMaterial).ok
	)
	expect(
		"material recipe revision mechanically changes canonical genome identity",
		ObjectGenome.identityKey(revisedMaterial) ~= ObjectGenome.identityKey(Fixtures.filingCabinet)
	)

	local materialBoundaryCases = {
		{ name = "slash id", id = "material.v1/reference-probe", recipeVersion = 1 },
		{ name = "numeric-only id", id = "123", recipeVersion = 1 },
		{ name = "overlong id", id = "material.v1." .. string.rep("a", 151), recipeVersion = 1 },
		{ name = "max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483647 },
		{ name = "above max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483648 },
	}
	for _, materialCase in ipairs(materialBoundaryCases) do
		local reference = {
			id = materialCase.id,
			recipeVersion = materialCase.recipeVersion,
		}
		local expectedReferenceValidity = MaterialDNA.validateReference(reference).ok
		local boundaryGenome = deepCopy(Fixtures.officeChair)
		boundaryGenome.components[1].materialKey = reference.id
		boundaryGenome.components[1].materialRecipeVersion = reference.recipeVersion
		expect(
			"ObjectGenome matches MaterialDNA reference boundary: " .. materialCase.name,
			ObjectGenome.inspect(boundaryGenome).ok == expectedReferenceValidity
		)
	end

	local danglingSupport = deepCopy(Fixtures.filingCabinet)
	danglingSupport.components[2].supportKeys = { "missing-shell" }
	expect(
		"rejects dangling support graph edge",
		hasCode(ObjectGenome.inspect(danglingSupport), "component.support_missing")
	)

	local supportCycle = deepCopy(Fixtures.officeTable)
	supportCycle.components[1].externalSupport = "none"
	supportCycle.components[1].supportKeys = { "top" }
	expect("rejects cyclic load path", hasCode(ObjectGenome.inspect(supportCycle), "component.support_cycle"))

	local groundedCycle = deepCopy(Fixtures.officeTable)
	local groundedLeg = findComponent(groundedCycle, "leg-front-left")
	if groundedLeg ~= nil then
		groundedLeg.supportKeys = { "crossbar" }
	end
	expect(
		"rejects support cycle even when the cycle contains an externally supported component",
		groundedLeg ~= nil and hasCode(ObjectGenome.inspect(groundedCycle), "component.support_cycle")
	)

	local branchedCycle = deepCopy(Fixtures.officeTable)
	local branchedTop = findComponent(branchedCycle, "top")
	local branchedCrossbar = findComponent(branchedCycle, "crossbar")
	if branchedTop ~= nil and branchedCrossbar ~= nil then
		branchedTop.supportKeys = { "leg-front-left", "crossbar" }
		branchedCrossbar.supportKeys = { "top", "leg-front-right" }
	end
	expect(
		"rejects cyclic support branch even when another branch reaches ground",
		branchedTop ~= nil
			and branchedCrossbar ~= nil
			and hasCode(ObjectGenome.inspect(branchedCycle), "component.support_cycle")
	)

	local badMechanism = deepCopy(Fixtures.filingCabinet)
	badMechanism.mechanisms[1].frameComponentKey = "missing-frame"
	expect(
		"rejects mechanism with missing frame",
		hasCode(ObjectGenome.inspect(badMechanism), "mechanism.frame_component")
	)

	local nonUnitAxis = deepCopy(Fixtures.filingCabinet)
	nonUnitAxis.mechanisms[1].axis = { x = 0, y = 0, z = -2 }
	expect(
		"rejects non-unit mechanism axis",
		hasCode(ObjectGenome.inspect(nonUnitAxis), "mechanism.axis_unit")
	)

	local rotatedOutside = deepCopy(Fixtures.officeTable)
	local top = findComponent(rotatedOutside, "top")
	if top ~= nil then
		top.localRotationDeg = { x = 0, y = 90, z = 0 }
	end
	expect(
		"rotation-aware bounds reject a rotated non-cubic component that no longer fits",
		top ~= nil and hasCode(ObjectGenome.inspect(rotatedOutside), "component.outside_bounds")
	)

	local rotatedFits = deepCopy(Fixtures.officeTable)
	local crossbar = findComponent(rotatedFits, "crossbar")
	if crossbar ~= nil then
		crossbar.dimensionsM = { x = 0.70, y = 0.08, z = 1.30 }
		crossbar.localRotationDeg = { x = 0, y = 90, z = 0 }
	end
	expect(
		"rotation-aware bounds accept a rotated non-cubic component that fits after rotation",
		crossbar ~= nil and not hasCode(ObjectGenome.inspect(rotatedFits), "component.outside_bounds")
	)

	local mixedAxisOrder = deepCopy(Fixtures.officeTable)
	local mixedCrossbar = findComponent(mixedAxisOrder, "crossbar")
	if mixedCrossbar ~= nil then
		-- This geometry fits for fixed-axis XYZ (Rz * Ry * Rx), but not if matrix order
		-- is silently flipped to Rx * Ry * Rz. It therefore locks more than single-axis cases.
		mixedCrossbar.localRotationDeg = { x = 80, y = 25, z = 10 }
	end
	expect(
		"fixed-axis XYZ mixed rotation order is locked",
		mixedCrossbar ~= nil and not hasCode(ObjectGenome.inspect(mixedAxisOrder), "component.outside_bounds")
	)

	local outOfBoundsRotation = deepCopy(Fixtures.officeTable)
	local rotatedTop = findComponent(outOfBoundsRotation, "top")
	if rotatedTop ~= nil then
		rotatedTop.localRotationDeg = { x = 0, y = 270, z = 0 }
	end
	expect(
		"rejects rotation outside the v1 bounded representation",
		rotatedTop ~= nil and hasCode(ObjectGenome.inspect(outOfBoundsRotation), "component.rotation_range")
	)

	local badAffordance = deepCopy(Fixtures.officeChair)
	badAffordance.affordances[1].localPointM.x = 5
	expect(
		"rejects affordance outside component",
		hasCode(ObjectGenome.inspect(badAffordance), "affordance.outside_component")
	)

	local badState = ObjectGenome.defaultState(Fixtures.officeChair)
	badState.componentWear.seat = 1.25
	expect(
		"rejects mutable wear outside unit interval",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, badState), "state.unit_interval")
	)

	local unknownStateKey = ObjectGenome.defaultState(Fixtures.filingCabinet)
	unknownStateKey.componentDamage["ghost-component"] = 0.2
	expect(
		"rejects mutable state for unknown component",
		hasCode(ObjectGenome.inspectState(Fixtures.filingCabinet, unknownStateKey), "state.unknown_key")
	)

	local invalidForAssert = deepCopy(Fixtures.officeTable)
	invalidForAssert.massKg = -1
	local ok = pcall(function()
		ObjectGenome.validate(invalidForAssert)
	end)
	expect("asserting validator rejects malformed recipe", not ok)

	return failures
end

return run
