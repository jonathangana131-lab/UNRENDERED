local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
local ObjectGenomeOwnership = require("../src/shared/Objects/ObjectGenomeOwnership")
local Fixtures = require("../src/shared/Objects/ObjectGenomeFixtures")

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
	expect(
		"rejects sparse component arrays",
		hasCode(ObjectGenome.inspect(sparseComponents), "array.shape")
	)

	local sparseSupportKeys = deepCopy(Fixtures.officeChair)
	sparseSupportKeys.components[1].supportKeys = { [2] = "seat" }
	expect(
		"rejects sparse support-key arrays",
		hasCode(ObjectGenome.inspect(sparseSupportKeys), "array.shape")
	)

	local keyedMechanisms = deepCopy(Fixtures.officeChair)
	keyedMechanisms.mechanisms.debug = keyedMechanisms.mechanisms[1]
	expect(
		"rejects keyed mechanism entries",
		hasCode(ObjectGenome.inspect(keyedMechanisms), "array.shape")
	)

	local keyedAffordances = deepCopy(Fixtures.officeChair)
	keyedAffordances.affordances.debug = keyedAffordances.affordances[1]
	expect(
		"rejects keyed affordance entries",
		hasCode(ObjectGenome.inspect(keyedAffordances), "array.shape")
	)

	local componentKey = Fixtures.officeChair.components[1].key
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

	local mutableState = ObjectGenome.defaultState(Fixtures.officeChair)
	local mutableStateOk = pcall(function()
		mutableState.componentWear[componentKey] = 0.25
	end)
	expect(
		"keeps ObjectState intentionally mutable",
		mutableStateOk
			and mutableState.componentWear[componentKey] == 0.25
			and ObjectGenome.inspectState(Fixtures.officeChair, mutableState).ok
	)

	local sourceGenome = deepCopy(Fixtures.officeChair)
	local sealedGenome = ObjectGenomeOwnership.seal(sourceGenome)
	local sealedMass = sealedGenome.components[1].massKg
	sourceGenome.components[1].massKg = sealedMass + 1
	expect(
		"ownership boundary defensively copies source recipe",
		sealedGenome.components[1].massKg == sealedMass
	)

	local nestedMutationOk = pcall(function()
		Fixtures.officeChair.components[1].massKg = sealedMass + 1
	end)
	expect(
		"production fixture nested recipe is immutable",
		not nestedMutationOk and Fixtures.officeChair.components[1].massKg == sealedMass
	)

	return failures
end

return run
