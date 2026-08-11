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

local function hasCode(report, code)
	for _, issue in ipairs(report.issues) do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function makeAlignedComponentMechanismGenome()
	local genome = deepCopy(Fixtures.officeChair)
	genome.familyId = "office-chair.state-alias-g3"
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
			print(`PASS object_genome_generation3_boundaries {name}`)
		else
			failures += 1
			print(`FAIL object_genome_generation3_boundaries {name}`)
		end
	end

	local maxFamilyVersion = deepCopy(Fixtures.officeChair)
	maxFamilyVersion.familyVersion = 2147483647
	local maxFamilyReport = ObjectGenome.inspect(maxFamilyVersion)
	local maxIdentityOk, maxIdentity = pcall(ObjectGenome.identityKey, maxFamilyVersion)
	expect("accepts maximum canonical familyVersion", maxFamilyReport.ok)
	expect(
		"maximum familyVersion remains stable-id representable",
		maxIdentityOk and type(maxIdentity) == "string"
	)

	local oversizedFamilyVersion = deepCopy(Fixtures.officeChair)
	oversizedFamilyVersion.familyVersion = 2147483648
	local oversizedFamilyReport = ObjectGenome.inspect(oversizedFamilyVersion)
	local oversizedIdentityOk = pcall(ObjectGenome.identityKey, oversizedFamilyVersion)
	expect(
		"rejects first familyVersion outside canonical revision domain",
		not oversizedFamilyReport.ok and hasCode(oversizedFamilyReport, "genome.family_version")
	)
	expect("oversized familyVersion cannot construct identity", not oversizedIdentityOk)

	local maxSemanticKey = string.rep("a", 512)
	local maxKeyGenome = deepCopy(Fixtures.officeChair)
	maxKeyGenome.affordances[1].key = maxSemanticKey
	expect("accepts 512-byte nested semantic key", ObjectGenome.inspect(maxKeyGenome).ok)

	local oversizedSemanticKey = string.rep("a", 513)
	local oversizedComponentKey = deepCopy(Fixtures.officeChair)
	oversizedComponentKey.components[1].key = oversizedSemanticKey
	expect(
		"rejects 513-byte component key",
		hasCode(ObjectGenome.inspect(oversizedComponentKey), "component.key")
	)

	local oversizedSupportKey = deepCopy(Fixtures.officeChair)
	local supportTarget = nil
	for _, component in ipairs(oversizedSupportKey.components) do
		if #component.supportKeys > 0 then
			supportTarget = component
			break
		end
	end
	expect("fixture exposes a support edge for boundary test", supportTarget ~= nil)
	if supportTarget ~= nil then
		supportTarget.supportKeys[1] = oversizedSemanticKey
		expect(
			"rejects 513-byte support key",
			hasCode(ObjectGenome.inspect(oversizedSupportKey), "component.support_key")
		)
	end

	local oversizedMechanismKey = deepCopy(Fixtures.officeChair)
	oversizedMechanismKey.mechanisms[1].key = oversizedSemanticKey
	expect(
		"rejects 513-byte mechanism key",
		hasCode(ObjectGenome.inspect(oversizedMechanismKey), "mechanism.key")
	)

	local oversizedAffordanceKey = deepCopy(Fixtures.officeChair)
	oversizedAffordanceKey.affordances[1].key = oversizedSemanticKey
	expect(
		"rejects 513-byte affordance key",
		hasCode(ObjectGenome.inspect(oversizedAffordanceKey), "affordance.key")
	)

	local baselineState = ObjectGenome.defaultState(Fixtures.officeChair)
	expect(
		"default mutable state remains valid",
		ObjectGenome.inspectState(Fixtures.officeChair, baselineState).ok
	)
	expect(
		"default mutable state maps are independently owned",
		not rawequal(baselineState.componentWear, baselineState.componentDamage)
			and not rawequal(baselineState.componentWear, baselineState.mechanismPosition)
			and not rawequal(baselineState.componentWear, baselineState.detachedComponents)
			and not rawequal(baselineState.componentDamage, baselineState.mechanismPosition)
			and not rawequal(baselineState.componentDamage, baselineState.detachedComponents)
			and not rawequal(baselineState.mechanismPosition, baselineState.detachedComponents)
	)

	local wearDamageAlias = ObjectGenome.defaultState(Fixtures.officeChair)
	wearDamageAlias.componentDamage = wearDamageAlias.componentWear
	local componentKey = Fixtures.officeChair.components[1].key
	wearDamageAlias.componentWear[componentKey] = 0.5
	local wearDamageReport = ObjectGenome.inspectState(Fixtures.officeChair, wearDamageAlias)
	expect(
		"test fixture establishes wear-damage alias coupling",
		wearDamageAlias.componentDamage[componentKey] == 0.5
	)
	expect(
		"rejects aliased wear and damage semantic maps",
		not wearDamageReport.ok and hasCode(wearDamageReport, "state.collection_alias")
	)

	local alignedGenome = makeAlignedComponentMechanismGenome()
	expect("aligned component-mechanism key fixture is valid", ObjectGenome.inspect(alignedGenome).ok)
	local wearMechanismAlias = ObjectGenome.defaultState(alignedGenome)
	wearMechanismAlias.componentWear = wearMechanismAlias.mechanismPosition
	local alignedKey = alignedGenome.components[1].key
	wearMechanismAlias.componentWear[alignedKey] = 1
	local wearMechanismReport = ObjectGenome.inspectState(alignedGenome, wearMechanismAlias)
	expect(
		"test fixture establishes wear-mechanism alias coupling",
		wearMechanismAlias.mechanismPosition[alignedKey] == 1
	)
	expect(
		"rejects aliased wear and mechanism-position semantic maps",
		not wearMechanismReport.ok and hasCode(wearMechanismReport, "state.collection_alias")
	)

	local allAlias = ObjectGenome.defaultState(alignedGenome)
	allAlias.componentDamage = allAlias.componentWear
	allAlias.mechanismPosition = allAlias.componentWear
	allAlias.detachedComponents = allAlias.componentWear
	local allAliasReport = ObjectGenome.inspectState(alignedGenome, allAlias)
	expect(
		"rejects aliasing across every mutable semantic-map dimension",
		hasCode(allAliasReport, "state.collection_alias")
	)

	return failures
end

return run
