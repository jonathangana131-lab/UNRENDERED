local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
local Fixtures = require("../src/shared/Objects/ObjectGenomeFixtures")
local ObjectGenomeOwnership = require("../src/shared/Objects/ObjectGenomeOwnership")

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

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS object_genome_contract_lock {name}`)
		else
			failures += 1
			print(`FAIL object_genome_contract_lock {name}`)
		end
	end

	local futureSchema = deepCopy(Fixtures.officeChair)
	futureSchema.schemaVersion = ObjectGenome.SCHEMA_VERSION + 1
	expect(
		"rejects unsupported object schema version",
		hasCode(ObjectGenome.inspect(futureSchema), "genome.schema_version")
	)

	local sparseComponents = deepCopy(Fixtures.officeChair)
	sparseComponents.components[3] = sparseComponents.components[2]
	sparseComponents.components[2] = nil
	expect("rejects sparse component arrays", hasCode(ObjectGenome.inspect(sparseComponents), "array.shape"))

	local sparseSupportKeys = deepCopy(Fixtures.officeChair)
	sparseSupportKeys.components[1].supportKeys = { [2] = "seat" }
	expect(
		"rejects sparse support-key arrays",
		hasCode(ObjectGenome.inspect(sparseSupportKeys), "array.shape")
	)

	local keyedMechanisms = deepCopy(Fixtures.officeChair)
	keyedMechanisms.mechanisms.debug = keyedMechanisms.mechanisms[1]
	expect("rejects keyed mechanism entries", hasCode(ObjectGenome.inspect(keyedMechanisms), "array.shape"))

	local keyedAffordances = deepCopy(Fixtures.officeChair)
	keyedAffordances.affordances.debug = keyedAffordances.affordances[1]
	expect("rejects keyed affordance entries", hasCode(ObjectGenome.inspect(keyedAffordances), "array.shape"))

	expect(
		"locks local rotation convention",
		ObjectGenome.LOCAL_ROTATION_CONVENTION == "v1-right-handed-fixed-xyz-degrees"
	)
	expect(
		"locks mechanism axis convention",
		ObjectGenome.MECHANISM_AXIS_CONVENTION == "v1-object-local-unit-vector"
	)

	local nonUnitAxis = deepCopy(Fixtures.officeChair)
	local foundTilt = false
	for _, mechanism in ipairs(nonUnitAxis.mechanisms) do
		if mechanism.key == "seat-tilt" then
			mechanism.axis = { x = 2, y = 0, z = 0 }
			foundTilt = true
			break
		end
	end
	expect("fixture exposes seat tilt for axis regression", foundTilt)
	expect("rejects non-unit mechanism axis", hasCode(ObjectGenome.inspect(nonUnitAxis), "mechanism.axis"))

	local unrotatedBack = deepCopy(Fixtures.officeChair)
	local foundBack = false
	for _, component in ipairs(unrotatedBack.components) do
		if component.key == "back" then
			component.localRotationDeg = { x = 0, y = 0, z = 0 }
			foundBack = true
			break
		end
	end
	expect("fixture exposes non-cubic back for rotation regression", foundBack)
	expect(
		"unrotated back remains inside object envelope",
		not hasCode(ObjectGenome.inspect(unrotatedBack), "component.outside_bounds")
	)

	local rotatedBack = deepCopy(unrotatedBack)
	for _, component in ipairs(rotatedBack.components) do
		if component.key == "back" then
			component.localRotationDeg = { x = 0, y = 90, z = 0 }
			break
		end
	end
	expect(
		"rotation-aware bounds reject back extending outside envelope",
		hasCode(ObjectGenome.inspect(rotatedBack), "component.outside_bounds")
	)

	-- Independent golden for fixed-parent XYZ order. For dimensions (0.6, 0.4, 0.2)
	-- at (30, 45, 60) degrees, Rz * Ry * Rx gives half-extents approximately
	-- (0.29463057, 0.35958452, 0.34407996). The alternative intrinsic XYZ
	-- composition gives (0.29925118, 0.33875364, 0.25535121), so these two
	-- envelopes intentionally distinguish the two non-commuting conventions.
	local mixedRotationGenome = {
		schemaVersion = ObjectGenome.SCHEMA_VERSION,
		familyId = "transform-golden",
		familyVersion = 1,
		variantKey = "fixed-xyz",
		provenance = {
			manufacturerFamily = "Contract Test",
			productLine = "Rotation Golden",
			apparentEra = "v1",
		},
		dimensionsM = { x = 0.58, y = 0.72, z = 0.69 },
		dimensionLimits = {
			minM = { x = 0.50, y = 0.50, z = 0.50 },
			maxM = { x = 0.80, y = 0.80, z = 0.80 },
		},
		massKg = 1,
		massLimitsKg = { min = 0.5, max = 2 },
		centerOfMassM = { x = 0, y = 0, z = 0 },
		components = {
			{
				key = "golden-box",
				role = "rotation-order probe",
				materialKey = "material:test.rotation-golden.v1",
				massKg = 1,
				localPositionM = { x = 0, y = 0, z = 0 },
				localRotationDeg = { x = 30, y = 45, z = 60 },
				dimensionsM = { x = 0.6, y = 0.4, z = 0.2 },
				supportKeys = {},
				externalSupport = "ground",
			},
		},
		mechanisms = {},
		affordances = {},
	}
	expect(
		"mixed-axis golden accepts fixed-parent XYZ extents",
		not hasCode(ObjectGenome.inspect(mixedRotationGenome), "component.outside_bounds")
	)

	local mixedRotationOrderProbe = deepCopy(mixedRotationGenome)
	mixedRotationOrderProbe.dimensionsM = { x = 0.61, y = 0.70, z = 0.70 }
	expect(
		"mixed-axis golden rejects alternate rotation order",
		hasCode(ObjectGenome.inspect(mixedRotationOrderProbe), "component.outside_bounds")
	)

	local fixtureCases = {
		{ name = "office chair", genome = Fixtures.officeChair },
		{ name = "office table", genome = Fixtures.officeTable },
		{ name = "filing cabinet", genome = Fixtures.filingCabinet },
	}
	for _, fixture in ipairs(fixtureCases) do
		expect(fixture.name .. " fixture root is frozen", table.isfrozen(fixture.genome))
		expect(fixture.name .. " fixture components are frozen", table.isfrozen(fixture.genome.components))
		expect(
			fixture.name .. " fixture nested component is frozen",
			table.isfrozen(fixture.genome.components[1])
		)
		expect(
			fixture.name .. " fixture nested transform is frozen",
			table.isfrozen(fixture.genome.components[1].dimensionsM)
		)
	end

	local callerGenome = deepCopy(Fixtures.officeChair)
	local ownedGenome = ObjectGenomeOwnership.own(callerGenome)
	local originalOwnedMass = ownedGenome.components[1].massKg
	callerGenome.components[1].massKg = originalOwnedMass + 1
	expect("ownership leaves caller input mutable", not table.isfrozen(callerGenome.components[1]))
	expect(
		"owned genome is detached from caller input",
		ownedGenome.components[1].massKg == originalOwnedMass
	)
	expect("owned genome root is frozen", table.isfrozen(ownedGenome))
	expect("owned genome component array is frozen", table.isfrozen(ownedGenome.components))
	expect("owned genome nested component is frozen", table.isfrozen(ownedGenome.components[1]))
	local nestedMutationOk = pcall(function()
		ownedGenome.components[1].massKg = originalOwnedMass + 2
	end)
	expect("owned genome rejects nested mutation", not nestedMutationOk)

	local unknownTopLevel = deepCopy(Fixtures.officeChair)
	unknownTopLevel.debugRuntime = function() end
	local unknownTopLevelOk = pcall(function()
		ObjectGenomeOwnership.own(unknownTopLevel)
	end)
	expect("ownership rejects unknown non-plain top-level field", not unknownTopLevelOk)

	local unknownNested = deepCopy(Fixtures.officeChair)
	unknownNested.components[1].debugRepresentation = "MeshPart"
	local unknownNestedOk = pcall(function()
		ObjectGenomeOwnership.own(unknownNested)
	end)
	expect("ownership rejects unknown nested schema field", not unknownNestedOk)

	local metatableGenome = deepCopy(Fixtures.officeChair)
	setmetatable(metatableGenome.provenance, {})
	local metatableOwnershipOk = pcall(function()
		ObjectGenomeOwnership.own(metatableGenome)
	end)
	expect("ownership rejects metatable-bearing canonical data", not metatableOwnershipOk)

	local cyclicGenome = deepCopy(Fixtures.officeChair)
	cyclicGenome.debugCycle = cyclicGenome
	local cyclicOwnershipOk = pcall(function()
		ObjectGenomeOwnership.own(cyclicGenome)
	end)
	expect("ownership rejects cyclic unknown data", not cyclicOwnershipOk)

	local componentKey = Fixtures.officeChair.components[1].key
	local mutableState = ObjectGenome.defaultState(ownedGenome)
	local stateMutationOk = pcall(function()
		mutableState.componentWear[componentKey] = 0.5
	end)
	expect(
		"default mutable state remains writable",
		stateMutationOk and mutableState.componentWear[componentKey] == 0.5
	)

	local missingComponentState = ObjectGenome.defaultState(Fixtures.officeChair)
	missingComponentState.componentWear[componentKey] = nil
	expect(
		"rejects missing component mutable state",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, missingComponentState), "state.missing_key")
	)

	local mechanismKey = Fixtures.officeChair.mechanisms[1].key
	local missingMechanismState = ObjectGenome.defaultState(Fixtures.officeChair)
	missingMechanismState.mechanismPosition[mechanismKey] = nil
	expect(
		"rejects missing mechanism mutable state",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, missingMechanismState), "state.missing_key")
	)

	local missingDetachedState = ObjectGenome.defaultState(Fixtures.officeChair)
	missingDetachedState.detachedComponents[componentKey] = nil
	expect(
		"rejects missing detached-component state",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, missingDetachedState), "state.missing_key")
	)

	return failures
end

return run