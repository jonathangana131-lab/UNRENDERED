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
