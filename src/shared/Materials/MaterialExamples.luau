--!strict

local function freezeDeep(value: any): any
	for _, nested in pairs(value) do
		if type(nested) == "table" and not table.isfrozen(nested) then
			freezeDeep(nested)
		end
	end
	return table.freeze(value)
end

local examples = {
	commercialWallpaper = {
		id = "material:office.wallcovering.yellow_1992",
		schemaVersion = 1,
		substrate = {
			family = "gypsum_board",
			thicknessMm = 15.9,
		},
		finish = {
			family = "vinyl_wallcovering",
			manufacturingProcess = "printed_embossed_vinyl",
			roughness = 0.72,
			porosity = 0.08,
		},
		installation = {
			method = "wallcovering_adhesive",
			batchKey = "fallback.office.yellow.a",
			seamPeriodM = 1.37,
		},
		apparentAgeYears = 31,
		maintenance = {
			care = 0.48,
			cleaningFrequency = 0.35,
			repairLevel = 0.2,
		},
		environment = {
			humidityExposure = 0.42,
			uvExposure = 0.05,
			contactExposure = 0.24,
		},
		events = {
			{
				kind = "water_staining",
				severity = 0.16,
				ageYearsAgo = 5,
			},
		},
		response = {
			visualFamily = "commercial_wallpaper.fallback.yellow",
			physicalClass = "wallboard_finished",
			acousticClass = "wallboard_damped",
		},
	},
	lowPileCarpet = {
		id = "material:office.carpet.lowpile_1990",
		schemaVersion = 1,
		substrate = {
			family = "concrete",
			thicknessMm = 101.6,
		},
		finish = {
			family = "low_pile_carpet",
			manufacturingProcess = "tufted_nylon_broadloom",
			roughness = 0.93,
			porosity = 0.68,
		},
		installation = {
			method = "broadloom_adhesive",
			batchKey = "fallback.office.carpet.olive_a",
			seamPeriodM = 3.66,
		},
		apparentAgeYears = 29,
		maintenance = {
			care = 0.41,
			cleaningFrequency = 0.52,
			repairLevel = 0.18,
		},
		environment = {
			humidityExposure = 0.34,
			uvExposure = 0.03,
			contactExposure = 0.82,
		},
		events = {
			{
				kind = "traffic_compaction",
				severity = 0.38,
				ageYearsAgo = 12,
			},
			{
				kind = "cleaning_discoloration",
				severity = 0.14,
				ageYearsAgo = 3,
			},
		},
		response = {
			visualFamily = "commercial_carpet.fallback.lowpile_olive",
			physicalClass = "soft_flooring",
			acousticClass = "absorptive_floor",
		},
	},
	paintedMetal = {
		id = "material:office.metal.paint_1988",
		schemaVersion = 1,
		substrate = {
			family = "steel",
			thicknessMm = 1.2,
		},
		finish = {
			family = "painted_metal",
			manufacturingProcess = "baked_enamel",
			roughness = 0.58,
			porosity = 0.02,
		},
		installation = {
			method = "mechanically_fastened",
			batchKey = "fallback.office.metal.beige_a",
		},
		apparentAgeYears = 35,
		maintenance = {
			care = 0.32,
			cleaningFrequency = 0.28,
			repairLevel = 0.12,
		},
		environment = {
			humidityExposure = 0.3,
			uvExposure = 0.04,
			contactExposure = 0.57,
		},
		events = {
			{
				kind = "edge_chipping",
				severity = 0.21,
				ageYearsAgo = 8,
			},
		},
		response = {
			visualFamily = "painted_metal.fallback.warm_beige",
			physicalClass = "painted_sheet_metal",
			acousticClass = "thin_metal_resonant",
		},
	},
}

return freezeDeep(examples)
