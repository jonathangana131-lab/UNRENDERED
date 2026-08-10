local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialFixtureCatalog = require("../src/shared/Materials/MaterialFixtureCatalog")

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

local function run(): number
	local failures = 0

	local function expect(name, condition, detail)
		if condition then
			print(`PASS materialdna_metatable_failclosed {name}`)
		else
			failures += 1
			print(`FAIL materialdna_metatable_failclosed {name}: {detail or "condition was false"}`)
		end
	end

	local fixtures = MaterialFixtureCatalog.build(MaterialDNA)
	local recipe: any = deepCopy(fixtures.CommercialWallpaperDrywall)
	recipe.coherenceClass = nil

	local metamethodReads = 0
	setmetatable(recipe, {
		__index = function(_, key)
			metamethodReads += 1
			if key == "coherenceClass" then
				return "wallcovering.office"
			end
			return nil
		end,
	})

	local result = MaterialDNA.validateRecipe(recipe)
	expect("metatable-backed recipe is rejected", not result.ok, table.concat(result.errors, "; "))
	expect(
		"rejected metatable is never consulted",
		metamethodReads == 0,
		`metamethod executed {metamethodReads} times`
	)

	return failures
end

return run
