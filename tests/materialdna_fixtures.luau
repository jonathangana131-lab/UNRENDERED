--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local MaterialDNA = require("../src/shared/Materials/MaterialDNA")

local FIXTURE_SOURCE_PATH = "src/shared/Materials/MaterialFixtures.luau"
local ROBLOX_REQUIRE = "local MaterialDNA = require(script.Parent.MaterialDNA)"
local TEST_REQUIRE = "local MaterialDNA = __MaterialDNA"

local function loadProductionFixtures(): any
	local source = fs.readFile(FIXTURE_SOURCE_PATH)
	local requireStart, requireEnd = string.find(source, ROBLOX_REQUIRE, 1, true)
	if requireStart == nil or requireEnd == nil then
		error("MaterialFixtures production dependency boundary changed; update the test loader explicitly")
	end

	local head = string.sub(source, 1, requireStart - 1)
	local tail = string.sub(source, requireEnd + 1)
	local testSource = head .. TEST_REQUIRE .. tail
	local chunk = luau.load(testSource, {
		debugName = "MaterialFixtures production catalog",
		environment = {
			__MaterialDNA = MaterialDNA,
		},
		injectGlobals = true,
	})
	return chunk()
end

local function isRecursivelyFrozen(value: any, visited: { [any]: boolean }): boolean
	if type(value) ~= "table" then
		return true
	end
	if visited[value] then
		return true
	end
	visited[value] = true
	if not table.isfrozen(value) then
		return false
	end
	for _, child in pairs(value) do
		if not isRecursivelyFrozen(child, visited) then
			return false
		end
	end
	return true
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

	local catalog = loadProductionFixtures()
	local wallpaper = catalog.CommercialWallpaperDrywall
	local carpet = catalog.LowPileCarpet
	local paintedMetal = catalog.PaintedMetal
	local fixtures = {
		wallpaper,
		carpet,
		paintedMetal,
	}

	expect("production material fixture catalog is frozen", table.isfrozen(catalog), "catalog accepted mutation")
	expect(
		"wallpaper fixture keeps stable id",
		wallpaper.id == "material.v1.office-wallpaper.yellow-vinyl",
		tostring(wallpaper.id)
	)
	expect(
		"carpet fixture keeps stable id",
		carpet.id == "material.v1.office-carpet.low-pile-beige",
		tostring(carpet.id)
	)
	expect(
		"painted metal fixture keeps stable id",
		paintedMetal.id == "material.v1.office-metal.warm-gray-enamel",
		tostring(paintedMetal.id)
	)
	expect(
		"production material fixture ids remain distinct",
		wallpaper.id ~= carpet.id and wallpaper.id ~= paintedMetal.id and carpet.id ~= paintedMetal.id,
		"fixture ids collided"
	)

	for index, recipe in fixtures do
		local result = MaterialDNA.validateRecipe(recipe)
		expect(
			`production material fixture {index} validates`,
			result.ok,
			table.concat(result.errors, "; ")
		)
		expect(
			`production material fixture {index} is recursively frozen`,
			isRecursivelyFrozen(recipe, {}),
			"canonical fixture contains a mutable nested table"
		)
	end

	return failures
end

return run
