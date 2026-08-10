local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
local Fixtures = require("../src/shared/Objects/ObjectGenomeFixtures")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function hasIssue(report, code)
	for _, issue in report.issues do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function run()
	local failures = 0

	local function expectTrue(name, value)
		if value then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local function expectEqual(name, actual, expected)
		if actual == expected then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}: expected {expected}, got {actual}`)
		end
	end

	for name, fixture in {
		officeChair = Fixtures.officeChair,
		workTable = Fixtures.workTable,
		filingCabinet = Fixtures.filingCabinet,
	} do
		local report = ObjectGenome.validate(fixture)
		expectTrue(`ObjectGenome fixture {name} validates`, report.ok)
	end

	local firstIdParts = ObjectGenome.stableIdParts("office-chair-task", 1, "charcoal-midback-a")
	local secondIdParts = ObjectGenome.stableIdParts("office-chair-task", 1, "charcoal-midback-a")
	expectEqual("ObjectGenome StableId namespace", firstIdParts.namespace, "objectgenome")
	expectEqual("ObjectGenome StableId family part", firstIdParts.parts[1], secondIdParts.parts[1])
	expectEqual("ObjectGenome StableId version part", firstIdParts.parts[2], secondIdParts.parts[2])
	expectEqual("ObjectGenome StableId variant part", firstIdParts.parts[3], secondIdParts.parts[3])

	local initialState = ObjectGenome.newState(Fixtures.officeChair)
	expectTrue("ObjectGenome initial mutable state validates", ObjectGenome.validateState(Fixtures.officeChair, initialState).ok)
	expectEqual("ObjectGenome initial component wear", initialState.componentState.seat.wear, 0)
	expectEqual("ObjectGenome initial component damage", initialState.componentState.seat.damage, 0)
	expectEqual("ObjectGenome initial mechanism position", initialState.mechanismState["seat-tilt"].position01, 0)

	local invalidMass = deepCopy(Fixtures.workTable)
	invalidMass.massKg = -4
	expectTrue("ObjectGenome rejects negative mass", hasIssue(ObjectGenome.validate(invalidMass), "invalid_mass"))

	local duplicateComponent = deepCopy(Fixtures.workTable)
	duplicateComponent.components[2].key = "top"
	expectTrue(
		"ObjectGenome rejects duplicate component keys",
		hasIssue(ObjectGenome.validate(duplicateComponent), "duplicate_component_key")
	)

	local unsupportedComponent = deepCopy(Fixtures.workTable)
	table.insert(unsupportedComponent.components, {
		key = "floating-brace",
		role = "invalid unsupported brace",
		materialKey = "material:painted-steel-beige",
		massKg = 0.5,
		nominalDimensionsM = { widthM = 0.4, heightM = 0.03, depthM = 0.03 },
	})
	expectTrue(
		"ObjectGenome rejects unsupported components",
		hasIssue(ObjectGenome.validate(unsupportedComponent), "unsupported_component")
	)

	local supportCycle = deepCopy(Fixtures.officeChair)
	table.insert(supportCycle.supportLinks, {
		supporterKey = "seat",
		supportedKey = "column",
		mode = "structural",
	})
	expectTrue("ObjectGenome rejects support cycles", hasIssue(ObjectGenome.validate(supportCycle), "support_cycle"))

	local invalidMechanism = deepCopy(Fixtures.filingCabinet)
	invalidMechanism.mechanisms[1].railComponentKey = "missing-rail"
	expectTrue(
		"ObjectGenome rejects mechanism references to missing components",
		hasIssue(ObjectGenome.validate(invalidMechanism), "unknown_mechanism_component")
	)

	local invalidDimensions = deepCopy(Fixtures.officeChair)
	invalidDimensions.dimensionsM.widthM = 1.5
	expectTrue(
		"ObjectGenome rejects dimensions outside family plausibility",
		hasIssue(ObjectGenome.validate(invalidDimensions), "implausible_dimension")
	)

	local invalidState = ObjectGenome.newState(Fixtures.officeChair)
	invalidState.componentState.seat.wear = 1.5
	expectTrue(
		"ObjectGenome rejects invalid mutable state",
		hasIssue(ObjectGenome.validateState(Fixtures.officeChair, invalidState), "invalid_component_state")
	)

	return failures
end

return run
