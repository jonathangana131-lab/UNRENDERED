local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialFixtures = require("../src/shared/Materials/MaterialFixtures")

local MaterialDnaTests = {}

local function expectThrows(name, callback)
	local ok = pcall(callback)
	assert(not ok, `expected {name} to reject invalid input`)
	print(`PASS {name}`)
end

local function expectValid(name, recipe)
	MaterialDNA.validateRecipe(recipe)
	local record = MaterialDNA.new(recipe)
	MaterialDNA.validate(record)
	assert(table.isfrozen(record), `{name} record envelope must be immutable`)
	assert(table.isfrozen(record.recipe), `{name} recipe must be immutable`)
	assert(table.isfrozen(record.recipe.visual), `{name} nested recipe layers must be immutable`)
	assert(not table.isfrozen(record.state), `{name} mutable state must remain writable`)
	record.state.wear = 0.25
	MaterialDNA.validateState(record.state)
	print(`PASS {name}`)
end

local function copyWallpaperRecipe()
	local source = MaterialFixtures.commercialWallpaper()
	return {
		id = source.id,
		schemaVersion = source.schemaVersion,
		recipeVersion = source.recipeVersion,
		substrate = table.clone(source.substrate),
		finish = table.clone(source.finish),
		installation = table.clone(source.installation),
		apparentAge = table.clone(source.apparentAge),
		maintenance = table.clone(source.maintenance),
		environment = table.clone(source.environment),
		events = {
			table.clone(source.events[1]),
		},
		visual = {
			familyKey = source.visual.familyKey,
			tint = table.clone(source.visual.tint),
			roughness = source.visual.roughness,
			metallic = source.visual.metallic,
			normalStrength = source.visual.normalStrength,
			patternScaleM = source.visual.patternScaleM,
		},
		physical = table.clone(source.physical),
		acoustic = table.clone(source.acoustic),
	}
end

function MaterialDnaTests.run()
	assert(MaterialDNA.SCHEMA_VERSION == 1, "MaterialDNA schema version changed unexpectedly")

	expectValid("commercial wallpaper fixture", MaterialFixtures.commercialWallpaper())
	expectValid("low-pile carpet fixture", MaterialFixtures.lowPileCarpet())
	expectValid("painted metal fixture", MaterialFixtures.paintedMetal())

	local assetCoupled = copyWallpaperRecipe()
	assetCoupled.visual.familyKey = "rbxassetid://123456789"
	expectThrows("raw Roblox asset ID rejection", function()
		MaterialDNA.validateRecipe(assetCoupled)
	end)

	local impossibleFriction = copyWallpaperRecipe()
	impossibleFriction.physical.dynamicFriction = impossibleFriction.physical.staticFriction + 0.2
	expectThrows("friction plausibility rejection", function()
		MaterialDNA.validateRecipe(impossibleFriction)
	end)

	local preInstallationEvent = copyWallpaperRecipe()
	preInstallationEvent.events[1].yearsAgo = preInstallationEvent.apparentAge.apparentYears + 1
	expectThrows("history chronology rejection", function()
		MaterialDNA.validateRecipe(preInstallationEvent)
	end)

	local duplicateEvent = copyWallpaperRecipe()
	table.insert(duplicateEvent.events, table.clone(duplicateEvent.events[1]))
	expectThrows("duplicate event key rejection", function()
		MaterialDNA.validateRecipe(duplicateEvent)
	end)

	local invalidState = MaterialDNA.newState()
	invalidState.wetness = 1.1
	expectThrows("mutable state bounds rejection", function()
		MaterialDNA.validateState(invalidState)
	end)
end

return table.freeze(MaterialDnaTests)
