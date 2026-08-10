--!strict

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialFixtureCatalog = require("../src/shared/Materials/MaterialFixtureCatalog")

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean, detail: string): ()
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}: {detail}`)
		end
	end

	local fixtures = MaterialFixtureCatalog.build(MaterialDNA)
	local wallpaper = fixtures.CommercialWallpaperDrywall

	local recipeCallbackCount = 0
	local metatableRecipe: any = deepCopy(wallpaper)
	metatableRecipe.id = nil
	setmetatable(metatableRecipe, {
		__index = function(_self: any, key: any): any
			recipeCallbackCount += 1
			if key == "id" then
				return wallpaper.id
			end
			return nil
		end,
	})
	local recipeResult = MaterialDNA.validateRecipe(metatableRecipe)
	expect(
		"top-level metatable recipe rejected",
		not recipeResult.ok,
		table.concat(recipeResult.errors, "; ")
	)
	expect(
		"top-level recipe metatable callback never executes",
		recipeCallbackCount == 0,
		`callback executed {recipeCallbackCount} times`
	)

	local nestedCallbackCount = 0
	local nestedMetatableRecipe: any = deepCopy(wallpaper)
	nestedMetatableRecipe.finish.classKey = nil
	setmetatable(nestedMetatableRecipe.finish, {
		__index = function(_self: any, key: any): any
			nestedCallbackCount += 1
			if key == "classKey" then
				return wallpaper.finish.classKey
			end
			return nil
		end,
	})
	local nestedResult = MaterialDNA.validateRecipe(nestedMetatableRecipe)
	expect(
		"nested metatable recipe record rejected",
		not nestedResult.ok,
		table.concat(nestedResult.errors, "; ")
	)
	expect(
		"nested recipe metatable callback never executes",
		nestedCallbackCount == 0,
		`callback executed {nestedCallbackCount} times`
	)

	local stateCallbackCount = 0
	local metatableState: any = MaterialDNA.defaultState(wallpaper)
	metatableState.recipeId = nil
	setmetatable(metatableState, {
		__index = function(_self: any, key: any): any
			stateCallbackCount += 1
			if key == "recipeId" then
				return wallpaper.id
			end
			return nil
		end,
	})
	local stateResult = MaterialDNA.validateState(metatableState)
	expect("metatable material state rejected", not stateResult.ok, table.concat(stateResult.errors, "; "))
	expect(
		"material state metatable callback never executes",
		stateCallbackCount == 0,
		`callback executed {stateCallbackCount} times`
	)

	local referenceCallbackCount = 0
	local metatableReference: any = {
		recipeVersion = wallpaper.recipeVersion,
	}
	setmetatable(metatableReference, {
		__index = function(_self: any, key: any): any
			referenceCallbackCount += 1
			if key == "id" then
				return wallpaper.id
			end
			return nil
		end,
	})
	local referenceResult = MaterialDNA.validateReference(metatableReference)
	expect(
		"metatable material reference rejected",
		not referenceResult.ok,
		table.concat(referenceResult.errors, "; ")
	)
	expect(
		"material reference metatable callback never executes",
		referenceCallbackCount == 0,
		`callback executed {referenceCallbackCount} times`
	)

	return failures
end

return run
