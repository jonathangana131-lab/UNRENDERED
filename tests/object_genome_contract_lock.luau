local ProductionLoader = require("./support/ProductionLoader")

local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")
local ObjectGenomeOwnership = ProductionLoader.requireShared("Objects/ObjectGenomeOwnership")

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

	local maxIdentityFamily = deepCopy(Fixtures.officeChair)
	maxIdentityFamily.familyId = "a" .. string.rep("b", 511)
	local maxIdentityOk, maxIdentity = pcall(ObjectGenome.identityKey, maxIdentityFamily)
	expect(
		"accepts a 512-byte family identity part within StableId v1 bounds",
		#maxIdentityFamily.familyId == 512
			and ObjectGenome.inspect(maxIdentityFamily).ok
			and maxIdentityOk
			and type(maxIdentity) == "string"
	)

	local overlongFamily = deepCopy(Fixtures.officeChair)
	overlongFamily.familyId = "a" .. string.rep("b", 512)
	local overlongFamilyIdentityOk = pcall(ObjectGenome.identityKey, overlongFamily)
	expect(
		"rejects a family identity part beyond StableId v1 bounds during genome validation",
		#overlongFamily.familyId == 513
			and hasCode(ObjectGenome.inspect(overlongFamily), "genome.family_id")
			and not overlongFamilyIdentityOk
	)

	local overlongVariant = deepCopy(Fixtures.officeChair)
	overlongVariant.variantKey = "a" .. string.rep("b", 512)
	local overlongVariantIdentityOk = pcall(ObjectGenome.identityKey, overlongVariant)
	expect(
		"rejects a variant identity part beyond StableId v1 bounds during genome validation",
		#overlongVariant.variantKey == 513
			and hasCode(ObjectGenome.inspect(overlongVariant), "genome.variant_key")
			and not overlongVariantIdentityOk
	)

	local unknownTopLevelShape = deepCopy(Fixtures.officeChair)
	unknownTopLevelShape.futureField = true
	expect(
		"rejects undeclared top-level genome fields",
		hasCode(ObjectGenome.inspect(unknownTopLevelShape), "schema.unknown_field")
	)

	local unknownProvenance = deepCopy(Fixtures.officeChair)
	unknownProvenance.provenance.legacySku = "x"
	expect(
		"rejects undeclared provenance fields",
		hasCode(ObjectGenome.inspect(unknownProvenance), "schema.unknown_field")
	)

	local unknownVectorField = deepCopy(Fixtures.officeChair)
	unknownVectorField.dimensionsM.w = 1
	expect(
		"rejects undeclared vector fields",
		hasCode(ObjectGenome.inspect(unknownVectorField), "schema.unknown_field")
	)

	local unknownComponentField = deepCopy(Fixtures.officeChair)
	unknownComponentField.components[1].debugName = "seat"
	expect(
		"rejects undeclared component fields",
		hasCode(ObjectGenome.inspect(unknownComponentField), "schema.unknown_field")
	)

	local unknownMechanismField = deepCopy(Fixtures.officeChair)
	unknownMechanismField.mechanisms[1].futureLimit = 1
	expect(
		"rejects undeclared mechanism fields",
		hasCode(ObjectGenome.inspect(unknownMechanismField), "schema.unknown_field")
	)

	local unknownAffordanceField = deepCopy(Fixtures.officeChair)
	unknownAffordanceField.affordances[1].priority = 1
	expect(
		"rejects undeclared affordance fields",
		hasCode(ObjectGenome.inspect(unknownAffordanceField), "schema.unknown_field")
	)

	local metatableValidationGenome = deepCopy(Fixtures.officeChair)
	setmetatable(metatableValidationGenome.provenance, {
		__index = function()
			return "spoofed"
		end,
	})
	expect(
		"semantic validator rejects metatable-backed canonical records",
		hasCode(ObjectGenome.inspect(metatableValidationGenome), "schema.metatable")
	)

	local decoderFieldReads = 0
	local hostileDecoderMechanism = setmetatable({}, {
		__index = function(_, key)
			decoderFieldReads += 1
			if key == "kind" then
				return "caster"
			end
			return nil
		end,
	})
	local hostileDecoderOk = pcall(function()
		ObjectGenome.decodeMechanismPosition(hostileDecoderMechanism, 0.25)
	end)
	expect(
		"mechanism decoder rejects metatable-backed records before field reads",
		not hostileDecoderOk and decoderFieldReads == 0
	)

	local unknownStateField = ObjectGenome.defaultState(Fixtures.officeChair)
	unknownStateField.futureState = true
	expect(
		"rejects undeclared top-level ObjectState fields",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, unknownStateField), "state.unknown_field")
	)

	local metatableState = ObjectGenome.defaultState(Fixtures.officeChair)
	setmetatable(metatableState.componentWear, {
		__index = function()
			return 0
		end,
	})
	expect(
		"rejects metatable-backed mutable state maps",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, metatableState), "state.metatable")
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
	local originalOwnedMaterialRevision = ownedGenome.components[1].materialRecipeVersion
	callerGenome.components[1].massKg = originalOwnedMass + 1
	callerGenome.components[1].materialRecipeVersion = originalOwnedMaterialRevision + 1
	expect("ownership leaves caller input mutable", not table.isfrozen(callerGenome.components[1]))
	expect(
		"owned genome is detached from caller input",
		ownedGenome.components[1].massKg == originalOwnedMass
	)
	expect(
		"owned genome preserves exact material recipe revision",
		ownedGenome.components[1].materialRecipeVersion == originalOwnedMaterialRevision
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
	expect(
		"default state records exact genome identity",
		mutableState.genomeId == ObjectGenome.identityKey(ownedGenome)
	)
	expect(
		"mutated state still validates against its genome",
		ObjectGenome.inspectState(ownedGenome, mutableState).ok
	)

	local missingGenomeIdState = ObjectGenome.defaultState(Fixtures.officeChair)
	missingGenomeIdState.genomeId = nil
	expect(
		"rejects state without exact genome identity",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, missingGenomeIdState), "state.genome_id")
	)

	local revisedGenome = deepCopy(Fixtures.officeChair)
	revisedGenome.familyVersion += 1
	expect("cross-revision fixture remains a valid genome", ObjectGenome.inspect(revisedGenome).ok)
	expect(
		"cross-revision genome changes canonical identity",
		ObjectGenome.identityKey(revisedGenome) ~= ObjectGenome.identityKey(Fixtures.officeChair)
	)
	local priorRevisionState = ObjectGenome.defaultState(Fixtures.officeChair)
	expect(
		"rejects state replay against different genome revision with matching keys",
		hasCode(ObjectGenome.inspectState(revisedGenome, priorRevisionState), "state.genome_id")
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