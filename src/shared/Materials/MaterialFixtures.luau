--!strict

local MaterialDNA = require(script.Parent.MaterialDNA)
local MaterialFixtureData = require(script.Parent.MaterialFixtureData)

local raw = MaterialFixtureData.build()

return table.freeze({
	CommercialWallpaperDrywall = MaterialDNA.freezeRecipe(raw.CommercialWallpaperDrywall),
	LowPileCarpet = MaterialDNA.freezeRecipe(raw.LowPileCarpet),
	PaintedMetal = MaterialDNA.freezeRecipe(raw.PaintedMetal),
})
