--!strict

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialFixtureCatalog = require("../src/shared/Materials/MaterialFixtureCatalog")

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

	local topLevelReads = 0
	local topLevel: any = {}
	setmetatable(topLevel, {
		__index = function()
			topLevelReads += 1
			return nil
		end,
	})
	local topLevelResult = MaterialDNA.validateRecipe(topLevel)
	expect("metatable-backed recipe rejected", not topLevelResult.ok, "recipe unexpectedly validated")
	expect(
		"metatable-backed recipe is not indexed",
		topLevelReads == 0,
		`__index executed {topLevelReads} times`
	)

	local fixtures = MaterialFixtureCatalog.build(MaterialDNA)
	local nestedRecipe: any = table.clone(fixtures.CommercialWallpaperDrywall)
	local nestedReads = 0
	local metatableSubstrate: any = {}
	setmetatable(metatableSubstrate, {
		__index = function()
			nestedReads += 1
			return nil
		end,
	})
	nestedRecipe.substrate = metatableSubstrate
	local nestedResult = MaterialDNA.validateRecipe(nestedRecipe)
	expect(
		"metatable-backed nested record rejected",
		not nestedResult.ok,
		"nested record unexpectedly validated"
	)
	expect(
		"metatable-backed nested record is not indexed",
		nestedReads == 0,
		`__index executed {nestedReads} times`
	)

	local stateReads = 0
	local metatableState: any = {}
	setmetatable(metatableState, {
		__index = function()
			stateReads += 1
			return nil
		end,
	})
	local stateResult = MaterialDNA.validateState(metatableState)
	expect("metatable-backed state rejected", not stateResult.ok, "state unexpectedly validated")
	expect("metatable-backed state is not indexed", stateReads == 0, `__index executed {stateReads} times`)

	return failures
end

return run
