local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
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

	local unknownTopLevel = deepCopy(Fixtures.officeChair)
	unknownTopLevel.futureField = true
	expect(
		"rejects undeclared top-level genome fields",
		hasCode(ObjectGenome.inspect(unknownTopLevel), "schema.unknown_field")
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

	return failures
end

return run
