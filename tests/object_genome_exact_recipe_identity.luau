local ProductionLoader = require("./support/ProductionLoader")

local StableId = ProductionLoader.requireShared("Core/StableId")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function hasCode(report, code)
	for _, issue in ipairs(report.issues) do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function findComponent(genome, key)
	for _, component in ipairs(genome.components) do
		if component.key == key then
			return component
		end
	end
	return nil
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS object_genome_exact_recipe_identity {name}`)
		else
			failures += 1
			print(`FAIL object_genome_exact_recipe_identity {name}`)
		end
	end

	for name, genome in pairs({
		officeChair = Fixtures.officeChair,
		officeTable = Fixtures.officeTable,
		filingCabinet = Fixtures.filingCabinet,
	}) do
		local recipeId = ObjectGenome.recipeIdentityKey(genome)
		expect(
			name .. " exact recipe id uses project StableId",
			StableId.is(recipeId, ObjectGenome.RECIPE_ID_NAMESPACE)
		)
		expect(
			name .. " exact recipe id repeats deterministically",
			recipeId == ObjectGenome.recipeIdentityKey(genome)
		)

		local state = ObjectGenome.defaultState(genome)
		expect(name .. " default state binds exact recipe id", state.genomeId == recipeId)
		expect(name .. " default state validates", ObjectGenome.inspectState(genome, state).ok)
	end

	local base = Fixtures.filingCabinet
	local baseFamilyId = ObjectGenome.identityKey(base)
	local baseRecipeId = ObjectGenome.recipeIdentityKey(base)
	local baseState = ObjectGenome.defaultState(base)

	local provenanceChanged = deepCopy(base)
	provenanceChanged.provenance.productLine = "Recordsafe 300B"
	expect("provenance-only variant remains a valid recipe", ObjectGenome.inspect(provenanceChanged).ok)
	expect(
		"family identity remains stable across content-only change",
		ObjectGenome.identityKey(provenanceChanged) == baseFamilyId
	)
	expect(
		"exact recipe identity changes with provenance",
		ObjectGenome.recipeIdentityKey(provenanceChanged) ~= baseRecipeId
	)
	expect(
		"state cannot replay across provenance-only recipe change",
		hasCode(ObjectGenome.inspectState(provenanceChanged, baseState), "state.genome_id")
	)

	local materialChanged = deepCopy(base)
	local changedShell = findComponent(materialChanged, "shell")
	if changedShell ~= nil then
		changedShell.materialRecipeVersion += 1
	end
	expect(
		"material-revision variant remains a valid recipe",
		changedShell ~= nil and ObjectGenome.inspect(materialChanged).ok
	)
	expect(
		"exact recipe identity changes with material revision",
		changedShell ~= nil and ObjectGenome.recipeIdentityKey(materialChanged) ~= baseRecipeId
	)

	local transformChanged = deepCopy(base)
	local changedDrawer = findComponent(transformChanged, "drawer-middle")
	if changedDrawer ~= nil then
		changedDrawer.localPositionM.z += 0.005
	end
	expect(
		"transform variant remains a valid recipe",
		changedDrawer ~= nil and ObjectGenome.inspect(transformChanged).ok
	)
	expect(
		"exact recipe identity changes with transform",
		changedDrawer ~= nil and ObjectGenome.recipeIdentityKey(transformChanged) ~= baseRecipeId
	)

	local mechanismChanged = deepCopy(base)
	mechanismChanged.mechanisms[1].maxTravelM = 0.43
	expect("mechanism-parameter variant remains a valid recipe", ObjectGenome.inspect(mechanismChanged).ok)
	expect(
		"exact recipe identity changes with mechanism parameter",
		ObjectGenome.recipeIdentityKey(mechanismChanged) ~= baseRecipeId
	)

	local affordanceChanged = deepCopy(base)
	affordanceChanged.affordances[1].radiusM = 0.055
	expect("affordance variant remains a valid recipe", ObjectGenome.inspect(affordanceChanged).ok)
	expect(
		"exact recipe identity changes with affordance",
		ObjectGenome.recipeIdentityKey(affordanceChanged) ~= baseRecipeId
	)

	local supportOrderChanged = deepCopy(Fixtures.officeChair)
	local baseComponent = findComponent(supportOrderChanged, "base")
	if baseComponent ~= nil then
		local reversed = {}
		for index = #baseComponent.supportKeys, 1, -1 do
			table.insert(reversed, baseComponent.supportKeys[index])
		end
		baseComponent.supportKeys = reversed
	end
	expect(
		"support-key ordering does not churn semantic recipe identity",
		baseComponent ~= nil
			and ObjectGenome.inspect(supportOrderChanged).ok
			and ObjectGenome.recipeIdentityKey(supportOrderChanged)
				== ObjectGenome.recipeIdentityKey(Fixtures.officeChair)
	)

	local componentOrderChanged = deepCopy(Fixtures.officeTable)
	componentOrderChanged.components[1], componentOrderChanged.components[2] =
		componentOrderChanged.components[2], componentOrderChanged.components[1]
	expect(
		"component array ordering does not churn keyed recipe identity",
		ObjectGenome.inspect(componentOrderChanged).ok
			and ObjectGenome.recipeIdentityKey(componentOrderChanged)
				== ObjectGenome.recipeIdentityKey(Fixtures.officeTable)
	)

	local mechanismOrderChanged = deepCopy(base)
	mechanismOrderChanged.mechanisms[1], mechanismOrderChanged.mechanisms[2] =
		mechanismOrderChanged.mechanisms[2], mechanismOrderChanged.mechanisms[1]
	expect(
		"mechanism array ordering does not churn keyed recipe identity",
		ObjectGenome.inspect(mechanismOrderChanged).ok
			and ObjectGenome.recipeIdentityKey(mechanismOrderChanged) == baseRecipeId
	)

	return failures
end

return run
