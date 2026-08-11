local ProductionLoader = require("./support/ProductionLoader")

local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")

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

	local aliasedState = ObjectGenome.defaultState(Fixtures.officeChair)
	aliasedState.componentDamage = aliasedState.componentWear
	local componentKey = Fixtures.officeChair.components[1].key
	aliasedState.componentWear[componentKey] = 0.5

	expect(
		"test fixture establishes wear-damage alias coupling",
		aliasedState.componentDamage[componentKey] == 0.5
	)
	expect(
		"rejects aliased wear and damage semantic maps",
		not ObjectGenome.inspectState(Fixtures.officeChair, aliasedState).ok
	)

	return failures
end

return run
