--!strict

local MaterialFixtures = {}

function MaterialFixtures.commercialWallpaper()
	return {
		id = "material.fixture.office_wallpaper.v1",
		schemaVersion = 1,
		recipeVersion = 1,
		substrate = {
			familyKey = "substrate.gypsum_board.standard",
			thicknessM = 0.0127,
			porosity = 0.32,
		},
		finish = {
			familyKey = "finish.vinyl_wallcovering.low_sheen",
			processKey = "process.printed_vinyl.embossed",
			coatingThicknessM = 0.00055,
			manufacturingVariation = 0.18,
		},
		installation = {
			methodKey = "install.wallcovering.adhesive",
			batchKey = "batch.fixture.wallpaper.01",
			orientationDegrees = 0,
			seamSpacingM = 0.91,
		},
		apparentAge = {
			eraKey = "era.commercial.1990s",
			apparentYears = 29,
		},
		maintenance = {
			condition = 0.62,
			cleaning = 0.58,
			repairCount = 2,
		},
		environment = {
			humidityExposure = 0.38,
			uvExposure = 0.08,
			contactExposure = 0.21,
		},
		events = {
			{
				key = "event.fixture.wallpaper.patch_01",
				kindKey = "history.patch_repair",
				intensity = 0.24,
				yearsAgo = 8,
			},
		},
		visual = {
			familyKey = "surface.office.wallpaper.low_sheen",
			tint = { r = 0.72, g = 0.69, b = 0.54 },
			roughness = 0.68,
			metallic = 0,
			normalStrength = 0.45,
			patternScaleM = 0.32,
		},
		physical = {
			classKey = "physics.wall.gypsum_faced",
			densityKgM3 = 760,
			staticFriction = 0.55,
			dynamicFriction = 0.46,
			restitution = 0.08,
			hardness = 0.37,
		},
		acoustic = {
			classKey = "acoustic.wall.hollow_panel",
			absorption = 0.17,
			damping = 0.36,
			impactFamilyKey = "sound.impact.gypsum_wall",
			scrapeFamilyKey = "sound.scrape.vinyl_wallcovering",
		},
	}
end

function MaterialFixtures.lowPileCarpet()
	return {
		id = "material.fixture.office_carpet.v1",
		schemaVersion = 1,
		recipeVersion = 1,
		substrate = {
			familyKey = "substrate.carpet.tile_backing",
			thicknessM = 0.0075,
			porosity = 0.48,
		},
		finish = {
			familyKey = "finish.carpet.low_pile_nylon",
			processKey = "process.carpet.tufted",
			coatingThicknessM = 0.004,
			manufacturingVariation = 0.27,
		},
		installation = {
			methodKey = "install.carpet.pressure_adhesive",
			batchKey = "batch.fixture.carpet.03",
			orientationDegrees = 90,
			seamSpacingM = 0.61,
		},
		apparentAge = {
			eraKey = "era.commercial.1990s",
			apparentYears = 22,
		},
		maintenance = {
			condition = 0.54,
			cleaning = 0.67,
			repairCount = 4,
		},
		environment = {
			humidityExposure = 0.31,
			uvExposure = 0.03,
			contactExposure = 0.78,
		},
		events = {
			{
				key = "event.fixture.carpet_replacement_01",
				kindKey = "history.partial_replacement",
				intensity = 0.32,
				yearsAgo = 6,
			},
		},
		visual = {
			familyKey = "surface.office.carpet.low_pile",
			tint = { r = 0.42, g = 0.37, b = 0.22 },
			roughness = 0.94,
			metallic = 0,
			normalStrength = 0.72,
			patternScaleM = 0.61,
		},
		physical = {
			classKey = "physics.floor.soft_fibrous",
			densityKgM3 = 330,
			staticFriction = 0.86,
			dynamicFriction = 0.74,
			restitution = 0.03,
			hardness = 0.12,
		},
		acoustic = {
			classKey = "acoustic.floor.soft_porous",
			absorption = 0.58,
			damping = 0.82,
			impactFamilyKey = "sound.impact.carpet_soft",
			scrapeFamilyKey = "sound.scrape.carpet_fiber",
		},
	}
end

function MaterialFixtures.paintedMetal()
	return {
		id = "material.fixture.painted_metal.v1",
		schemaVersion = 1,
		recipeVersion = 1,
		substrate = {
			familyKey = "substrate.steel.cold_rolled",
			thicknessM = 0.0012,
			porosity = 0.01,
		},
		finish = {
			familyKey = "finish.paint.powder_coat",
			processKey = "process.paint.electrostatic_powder",
			coatingThicknessM = 0.00009,
			manufacturingVariation = 0.09,
		},
		installation = {
			methodKey = "install.panel.fastened",
			batchKey = "batch.fixture.metal.02",
			orientationDegrees = 0,
			seamSpacingM = nil,
		},
		apparentAge = {
			eraKey = "era.commercial.1990s",
			apparentYears = 18,
		},
		maintenance = {
			condition = 0.71,
			cleaning = 0.49,
			repairCount = 1,
		},
		environment = {
			humidityExposure = 0.43,
			uvExposure = 0.06,
			contactExposure = 0.57,
		},
		events = {
			{
				key = "event.fixture.metal_chip_01",
				kindKey = "history.coating_chip",
				intensity = 0.17,
				yearsAgo = 3,
			},
		},
		visual = {
			familyKey = "surface.office.metal.powder_coated",
			tint = { r = 0.53, g = 0.55, b = 0.52 },
			roughness = 0.52,
			metallic = 0.12,
			normalStrength = 0.22,
			patternScaleM = 0.08,
		},
		physical = {
			classKey = "physics.metal.thin_sheet",
			densityKgM3 = 7850,
			staticFriction = 0.48,
			dynamicFriction = 0.39,
			restitution = 0.21,
			hardness = 0.79,
		},
		acoustic = {
			classKey = "acoustic.metal.thin_resonant",
			absorption = 0.05,
			damping = 0.19,
			impactFamilyKey = "sound.impact.painted_sheet_metal",
			scrapeFamilyKey = "sound.scrape.powder_coated_metal",
		},
	}
end

return table.freeze(MaterialFixtures)
