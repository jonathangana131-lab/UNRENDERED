--!strict

local MaterialFixtureCatalog = {}

function MaterialFixtureCatalog.build(MaterialDNA: any): any
	local commercialWallpaperDrywall = MaterialDNA.freezeRecipe({
		id = "material.v1.office-wallpaper.yellow-vinyl",
		schemaVersion = MaterialDNA.SchemaVersion,
		recipeRevision = 1,
		coherenceClass = "interior.wallpapered-drywall",
		substrate = {
			classKey = "substrate.gypsum-board",
			thicknessMeters = 0.0127,
			porosity01 = 0.34,
		},
		finish = {
			classKey = "finish.vinyl-wallpaper",
			color = {
				r = 0.72,
				g = 0.68,
				b = 0.42,
			},
			roughness01 = 0.68,
			metallic01 = 0,
		},
		installation = {
			methodKey = "installation.pasted-wallpaper",
			batchKey = "batch.office-yellow-vinyl.a",
			quality01 = 0.82,
			seamPeriodMeters = 0.53,
		},
		apparentAgeYears = 14,
		maintenance = {
			careClassKey = "maintenance.light-commercial-cleaning",
			frequency01 = 0.58,
			cleanliness01 = 0.63,
			repairCount = 2,
		},
		environment = {
			humidity01 = 0.38,
			water01 = 0.08,
			uv01 = 0.02,
			grime01 = 0.24,
		},
		historyEvents = {
			{
				kindKey = "history.cabinet-shadow",
				causeKey = "cause.long-term-furniture-placement",
				severity01 = 0.16,
				coverage01 = 0.12,
			},
			{
				kindKey = "history.baseboard-moisture",
				causeKey = "cause.intermittent-cleaning-water",
				severity01 = 0.11,
				coverage01 = 0.08,
			},
		},
		visual = {
			familyKey = "fallback.commercial-wallpaper.yellow-vinyl",
			coherenceClass = "interior.wallpapered-drywall",
			metersPerRepeat = 0.53,
		},
		physical = {
			classKey = "physics.wallpapered-drywall",
			coherenceClass = "interior.wallpapered-drywall",
			densityKgPerM3 = 800,
			staticFriction = 0.58,
			dynamicFriction = 0.47,
			restitution01 = 0.04,
		},
		acoustic = {
			classKey = "acoustic.wallpapered-drywall",
			coherenceClass = "interior.wallpapered-drywall",
			absorptionLow01 = 0.05,
			absorptionMid01 = 0.09,
			absorptionHigh01 = 0.16,
			impactFamilyKey = "audio.impact.wallpapered-drywall",
			scrapeFamilyKey = "audio.scrape.vinyl-wallpaper",
		},
		response = {
			wetFrictionMultiplier = 0.86,
			wetDarkening01 = 0.18,
			damageResistance01 = 0.36,
			stainAffinity01 = 0.62,
		},
		anomalyModifiers = {},
	})

	local lowPileCarpet = MaterialDNA.freezeRecipe({
		id = "material.v1.office-carpet.low-pile-beige",
		schemaVersion = MaterialDNA.SchemaVersion,
		recipeRevision = 1,
		coherenceClass = "interior.low-pile-carpet",
		substrate = {
			classKey = "substrate.synthetic-carpet-backing",
			thicknessMeters = 0.008,
			porosity01 = 0.72,
		},
		finish = {
			classKey = "finish.olefin-low-pile",
			color = {
				r = 0.46,
				g = 0.42,
				b = 0.31,
			},
			roughness01 = 0.93,
			metallic01 = 0,
		},
		installation = {
			methodKey = "installation.glued-carpet-roll",
			batchKey = "batch.office-beige-carpet.b",
			quality01 = 0.76,
			seamPeriodMeters = 3.6576,
		},
		apparentAgeYears = 18,
		maintenance = {
			careClassKey = "maintenance.vacuum-and-spot-clean",
			frequency01 = 0.61,
			cleanliness01 = 0.49,
			repairCount = 1,
		},
		environment = {
			humidity01 = 0.44,
			water01 = 0.12,
			uv01 = 0.01,
			grime01 = 0.41,
		},
		historyEvents = {
			{
				kindKey = "history.traffic-wear",
				causeKey = "cause.repeated-foot-traffic",
				severity01 = 0.43,
				coverage01 = 0.31,
			},
			{
				kindKey = "history.spot-cleaning",
				causeKey = "cause.maintenance-response",
				severity01 = 0.19,
				coverage01 = 0.06,
			},
		},
		visual = {
			familyKey = "fallback.commercial-carpet.low-pile-beige",
			coherenceClass = "interior.low-pile-carpet",
			metersPerRepeat = 3.6576,
		},
		physical = {
			classKey = "physics.low-pile-carpet",
			coherenceClass = "interior.low-pile-carpet",
			densityKgPerM3 = 330,
			staticFriction = 0.96,
			dynamicFriction = 0.82,
			restitution01 = 0.02,
		},
		acoustic = {
			classKey = "acoustic.low-pile-carpet",
			coherenceClass = "interior.low-pile-carpet",
			absorptionLow01 = 0.14,
			absorptionMid01 = 0.43,
			absorptionHigh01 = 0.67,
			impactFamilyKey = "audio.impact.carpet-muted",
			scrapeFamilyKey = "audio.scrape.low-pile-carpet",
		},
		response = {
			wetFrictionMultiplier = 0.72,
			wetDarkening01 = 0.54,
			damageResistance01 = 0.47,
			stainAffinity01 = 0.79,
		},
		anomalyModifiers = {},
	})

	local paintedMetal = MaterialDNA.freezeRecipe({
		id = "material.v1.office-metal.warm-gray-enamel",
		schemaVersion = MaterialDNA.SchemaVersion,
		recipeRevision = 1,
		coherenceClass = "interior.painted-sheet-metal",
		substrate = {
			classKey = "substrate.cold-rolled-steel",
			thicknessMeters = 0.0012,
			porosity01 = 0.01,
		},
		finish = {
			classKey = "finish.baked-enamel-paint",
			color = {
				r = 0.47,
				g = 0.46,
				b = 0.43,
			},
			roughness01 = 0.42,
			metallic01 = 0.03,
		},
		installation = {
			methodKey = "installation.factory-coated-panel",
			batchKey = "batch.warm-gray-enamel.c",
			quality01 = 0.91,
			seamPeriodMeters = nil,
		},
		apparentAgeYears = 11,
		maintenance = {
			careClassKey = "maintenance.wipe-down-painted-metal",
			frequency01 = 0.46,
			cleanliness01 = 0.71,
			repairCount = 0,
		},
		environment = {
			humidity01 = 0.31,
			water01 = 0.03,
			uv01 = 0.04,
			grime01 = 0.18,
		},
		historyEvents = {
			{
				kindKey = "history.handle-zone-polish",
				causeKey = "cause.repeated-human-contact",
				severity01 = 0.22,
				coverage01 = 0.05,
			},
		},
		visual = {
			familyKey = "fallback.painted-metal.warm-gray-enamel",
			coherenceClass = "interior.painted-sheet-metal",
			metersPerRepeat = 1,
		},
		physical = {
			classKey = "physics.painted-sheet-metal",
			coherenceClass = "interior.painted-sheet-metal",
			densityKgPerM3 = 7850,
			staticFriction = 0.43,
			dynamicFriction = 0.31,
			restitution01 = 0.14,
		},
		acoustic = {
			classKey = "acoustic.painted-sheet-metal",
			coherenceClass = "interior.painted-sheet-metal",
			absorptionLow01 = 0.02,
			absorptionMid01 = 0.02,
			absorptionHigh01 = 0.03,
			impactFamilyKey = "audio.impact.painted-sheet-metal",
			scrapeFamilyKey = "audio.scrape.painted-sheet-metal",
		},
		response = {
			wetFrictionMultiplier = 0.61,
			wetDarkening01 = 0.04,
			damageResistance01 = 0.78,
			stainAffinity01 = 0.24,
		},
		anomalyModifiers = {},
	})

	return table.freeze({
		CommercialWallpaperDrywall = commercialWallpaperDrywall,
		LowPileCarpet = lowPileCarpet,
		PaintedMetal = paintedMetal,
	})
end

return table.freeze(MaterialFixtureCatalog)
