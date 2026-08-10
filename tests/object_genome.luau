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
			identity = "object-genome:1:office-chair.task:1:standard",
		},
		{
			name = "office table",
			genome = Fixtures.officeTable,
			identity = "object-genome:1:office-table.utility:1:rectangular",
		},
		{
			name = "filing cabinet",
			genome = Fixtures.filingCabinet,
			identity = "object-genome:1:filing-cabinet.vertical:1:three-drawer",
		},
	}

	for _, fixture in ipairs(fixtureCases) do
		local report = ObjectGenome.inspect(fixture.genome)
		expect(fixture.name .. " validates", report.ok)
		expect(
			fixture.name .. " stable identity",
			ObjectGenome.identityKey(fixture.genome) == fixture.identity
		)
		expect(
			fixture.name .. " repeat identity",
			ObjectGenome.identityKey(fixture.genome) == ObjectGenome.identityKey(fixture.genome)
		)

		local state = ObjectGenome.defaultState(fixture.genome)
		expect(
			fixture.name .. " default state is bound to exact genome identity",
			state.genomeId == ObjectGenome.identityKey(fixture.genome)
		)
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
		hasCode(ObjectGenome.inspect(badMaterial), "component.material_key")
	)

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

	local badMechanism = deepCopy(Fixtures.filingCabinet)
	badMechanism.mechanisms[1].frameComponentKey = "missing-frame"
	expect(
		"rejects mechanism with missing frame",
		hasCode(ObjectGenome.inspect(badMechanism), "mechanism.frame_component")
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

	local missingGenomeId = ObjectGenome.defaultState(Fixtures.officeChair)
	missingGenomeId.genomeId = nil
	expect(
		"rejects mutable state without genome identity",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, missingGenomeId), "state.genome_id")
	)

	local chairState = ObjectGenome.defaultState(Fixtures.officeChair)
	local compatibleDifferentRevision = deepCopy(Fixtures.officeChair)
	compatibleDifferentRevision.familyVersion += 1
	expect(
		"rejects state from a structurally compatible different genome revision",
		hasCode(ObjectGenome.inspectState(compatibleDifferentRevision, chairState), "state.genome_id")
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
