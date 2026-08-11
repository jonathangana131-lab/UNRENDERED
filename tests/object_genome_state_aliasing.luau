local ProductionLoader = require("./support/ProductionLoader")

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

local function makeAlignedComponentMechanismGenome()
	local genome = deepCopy(Fixtures.officeChair)
	genome.familyId = "office-chair.state-alias-test"
	genome.variantKey = "aligned-component-mechanism-keys"
	genome.mechanisms = {}

	for _, component in ipairs(genome.components) do
		local catchComponentKey = if component.key == "seat" then "back" else "seat"
		table.insert(genome.mechanisms, {
			key = component.key,
			kind = "latch",
			movingComponentKey = component.key,
			catchComponentKey = catchComponentKey,
			engagementDistanceM = 0.01,
		})
	end

	return genome
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS object_genome_state_aliasing {name}`)
		else
			failures += 1
			print(`FAIL object_genome_state_aliasing {name}`)
		end
	end

	local baselineState = ObjectGenome.defaultState(Fixtures.officeChair)
	expect(
		"default mutable state remains valid",
		ObjectGenome.inspectState(Fixtures.officeChair, baselineState).ok
	)

	local wearDamageAlias = ObjectGenome.defaultState(Fixtures.officeChair)
	wearDamageAlias.componentDamage = wearDamageAlias.componentWear
	local componentKey = Fixtures.officeChair.components[1].key
	wearDamageAlias.componentWear[componentKey] = 0.5

	expect(
		"test fixture establishes wear-damage alias coupling",
		wearDamageAlias.componentDamage[componentKey] == 0.5
	)
	expect(
		"rejects aliased wear and damage semantic maps",
		not ObjectGenome.inspectState(Fixtures.officeChair, wearDamageAlias).ok
	)

	local alignedGenome = makeAlignedComponentMechanismGenome()
	expect(
		"aligned component-mechanism key fixture is a valid genome",
		ObjectGenome.inspect(alignedGenome).ok
	)

	local wearMechanismAlias = ObjectGenome.defaultState(alignedGenome)
	wearMechanismAlias.componentWear = wearMechanismAlias.mechanismPosition
	local alignedKey = alignedGenome.components[1].key
	wearMechanismAlias.componentWear[alignedKey] = 1

	expect(
		"test fixture establishes wear-mechanism alias coupling in compatible value domains",
		wearMechanismAlias.mechanismPosition[alignedKey] == 1
	)
	expect(
		"rejects aliased wear and mechanism-position semantic maps",
		not ObjectGenome.inspectState(alignedGenome, wearMechanismAlias).ok
	)

	return failures
end

return run
