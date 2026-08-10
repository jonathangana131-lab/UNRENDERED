local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
local Examples = require("../src/shared/Objects/ObjectGenomeExamples")

local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = clone(child)
	end
	return result
end

local function issueCodes(issues)
	local codes = {}
	for _, issue in issues do
		codes[issue.code] = true
	end
	return codes
end

local function expectValid(name, genome)
	local ok, issues = ObjectGenome.validate(genome)
	if not ok then
		local lines = {}
		for _, issue in issues do
			table.insert(lines, `{issue.path} ({issue.code}): {issue.message}`)
		end
		error(`{name} should be valid:\n- {table.concat(lines, "\n- ")}`)
	end
	print(`PASS ObjectGenome valid fixture: {name}`)
end

for name, genome in Examples do
	expectValid(name, genome)
	local expectedId = ObjectGenome.composeId(genome.familyId, genome.familyVersion, genome.variantKey)
	assert(genome.id == expectedId, `{name} ID must be canonical and deterministic`)
end

local repeatA = ObjectGenome.composeId("office-chair", 1, "relay-task-a")
local repeatB = ObjectGenome.composeId("office-chair", 1, "relay-task-a")
local changed = ObjectGenome.composeId("office-chair", 1, "relay-task-b")
assert(repeatA == repeatB, "ObjectGenome.composeId must repeat exactly")
assert(repeatA ~= changed, "ObjectGenome.composeId must distinguish variant keys")
print("PASS ObjectGenome deterministic IDs")

local cycle = clone(Examples.officeTable)
cycle.components[1].supportKeys = { "top" }
local cycleOk, cycleIssues = ObjectGenome.validate(cycle)
local cycleCodes = issueCodes(cycleIssues)
assert(not cycleOk, "support cycle must be rejected")
assert(cycleCodes.support_cycle, "support cycle rejection must report support_cycle")
print("PASS ObjectGenome rejects support cycles")

local massMismatch = clone(Examples.filingCabinet)
massMismatch.components[1].massKg = 1
local massOk, massIssues = ObjectGenome.validate(massMismatch)
local massCodes = issueCodes(massIssues)
assert(not massOk, "mass mismatch must be rejected")
assert(massCodes.mass_balance, "mass mismatch must report mass_balance")
print("PASS ObjectGenome rejects mass mismatch")

local implausibleDimensions = clone(Examples.officeChair)
implausibleDimensions.dimensions.sizeM.x = 2.5
local dimensionsOk, dimensionsIssues = ObjectGenome.validate(implausibleDimensions)
local dimensionsCodes = issueCodes(dimensionsIssues)
assert(not dimensionsOk, "implausible dimensions must be rejected")
assert(dimensionsCodes.plausibility, "dimension rejection must report plausibility")
print("PASS ObjectGenome rejects implausible dimensions")

local brokenMechanism = clone(Examples.filingCabinet)
brokenMechanism.mechanisms[1].movingComponentKey = "missing-drawer"
local mechanismOk, mechanismIssues = ObjectGenome.validate(brokenMechanism)
local mechanismCodes = issueCodes(mechanismIssues)
assert(not mechanismOk, "missing mechanism component must be rejected")
assert(mechanismCodes.missing_component, "mechanism rejection must report missing_component")
print("PASS ObjectGenome rejects broken mechanisms")

local state = ObjectGenome.newState()
state.wear01 = 0.35
state.damage01 = 0.1
state.mechanismPosition["drawer-lower-slide"] = 0.2
local stateOk = ObjectGenome.validateState(Examples.filingCabinet, state)
assert(stateOk, "valid mutable state must be accepted")

state.mechanismPosition["drawer-lower-slide"] = 0.8
local badStateOk, badStateIssues = ObjectGenome.validateState(Examples.filingCabinet, state)
local badStateCodes = issueCodes(badStateIssues)
assert(not badStateOk, "mechanism state outside limits must be rejected")
assert(badStateCodes.range, "state rejection must report range")
print("PASS ObjectGenome mutable-state validation")

return true
