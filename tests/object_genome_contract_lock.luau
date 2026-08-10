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