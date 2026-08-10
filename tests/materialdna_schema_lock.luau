--!strict

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialFixtures = require("../src/shared/Materials/MaterialFixtures")

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy: { [any]: any } = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function containsError(result: MaterialDNA.ValidationResult, needle: string): boolean
	for _, message in result.errors do
		if string.find(message, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function isDeepFrozen(value: any, seen: { [any]: boolean }?): boolean
	if type(value) ~= "table" then
		return true
	end

	local visited = seen or {}
	if visited[value] then
		return true
	end
	visited[value] = true

	if not table.isfrozen(value) then
		return false
	end
	for key, child in pairs(value) do
		if not isDeepFrozen(key, visited) or not isDeepFrozen(child, visited) then
			return false
		end
	end
	return true
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean): ()
		if condition then
			print(`PASS materialdna_schema_lock {name}`)
		else
			failures += 1
			print(`FAIL materialdna_schema_lock {name}`)
		end
	end

	local fixtureCases = {
		{
			name = "commercial wallpaper drywall",
			recipe = MaterialFixtures.CommercialWallpaperDrywall,
		},
		{
			name = "low pile carpet",
			recipe = MaterialFixtures.LowPileCarpet,
		},
		{
			name = "painted metal",
			recipe = MaterialFixtures.PaintedMetal,
		},
	}

	local fixtureIds: { [string]: boolean } = {}
	for _, fixture in fixtureCases do
		local validation = MaterialDNA.validateRecipe(fixture.recipe)
		expect(fixture.name .. " production fixture validates", validation.ok)
		expect(fixture.name .. " production fixture is deeply frozen", isDeepFrozen(fixture.recipe))
		expect(fixture.name .. " production fixture id is distinct", fixtureIds[fixture.recipe.id] ~= true)
		fixtureIds[fixture.recipe.id] = true
	end

	local unknownTopLevel: any = deepCopy(MaterialFixtures.CommercialWallpaperDrywall)
	unknownTopLevel.futureCanonicalField = "must-not-disappear"
	local unknownTopLevelResult = MaterialDNA.validateRecipe(unknownTopLevel)
	expect(
		"rejects unknown top-level v1 field",
		not unknownTopLevelResult.ok and containsError(unknownTopLevelResult, "unknown schema key futureCanonicalField")
	)

	local unknownNested: any = deepCopy(MaterialFixtures.LowPileCarpet)
	unknownNested.finish.futureCanonicalField = 0.5
	local unknownNestedResult = MaterialDNA.validateRecipe(unknownNested)
	expect(
		"rejects unknown nested v1 field",
		not unknownNestedResult.ok and containsError(unknownNestedResult, "finish contains unknown schema key")
	)

	local unknownHistory: any = deepCopy(MaterialFixtures.PaintedMetal)
	unknownHistory.historyEvents[1].futureCanonicalField = true
	local unknownHistoryResult = MaterialDNA.validateRecipe(unknownHistory)
	expect(
		"rejects unknown history-event v1 field",
		not unknownHistoryResult.ok and containsError(unknownHistoryResult, "historyEvents[1] contains unknown schema key")
	)

	local metatableRecipe: any = deepCopy(MaterialFixtures.CommercialWallpaperDrywall)
	setmetatable(metatableRecipe, {
		__index = function()
			return "forged"
		end,
	})
	local metatableRecipeResult = MaterialDNA.validateRecipe(metatableRecipe)
	expect(
		"rejects metatable-backed recipe",
		not metatableRecipeResult.ok and containsError(metatableRecipeResult, "plain table with no metatable")
	)

	local metatableNested: any = deepCopy(MaterialFixtures.LowPileCarpet)
	setmetatable(metatableNested.substrate, {
		__index = function()
			return "forged"
		end,
	})
	local metatableNestedResult = MaterialDNA.validateRecipe(metatableNested)
	expect(
		"rejects metatable-backed nested record",
		not metatableNestedResult.ok and containsError(metatableNestedResult, "substrate must be a plain table")
	)

	local freezeUnknown: any = deepCopy(MaterialFixtures.PaintedMetal)
	freezeUnknown.futureCanonicalField = "must-reject-before-copy"
	local freezeUnknownAccepted = pcall(function()
		MaterialDNA.freezeRecipe(freezeUnknown)
	end)
	expect("ownership boundary rejects lossy unknown field", not freezeUnknownAccepted)

	local mutableState = MaterialDNA.defaultState(MaterialFixtures.CommercialWallpaperDrywall.id)
	local mutableStateAccepted = pcall(function()
		mutableState.wear01 = 0.25
	end)
	expect("MaterialState remains intentionally mutable", mutableStateAccepted and mutableState.wear01 == 0.25)

	return failures
end

return run
