--!strict

export type RGB = {
	r: number,
	g: number,
	b: number,
}

export type SubstrateLayer = {
	familyKey: string,
	thicknessM: number,
	porosity: number,
}

export type FinishLayer = {
	familyKey: string,
	processKey: string,
	coatingThicknessM: number,
	manufacturingVariation: number,
}

export type InstallationLayer = {
	methodKey: string,
	batchKey: string,
	orientationDegrees: number,
	seamSpacingM: number?,
}

export type ApparentAgeLayer = {
	eraKey: string,
	apparentYears: number,
}

export type MaintenanceLayer = {
	condition: number,
	cleaning: number,
	repairCount: number,
}

export type EnvironmentLayer = {
	humidityExposure: number,
	uvExposure: number,
	contactExposure: number,
}

export type HistoryEvent = {
	key: string,
	kindKey: string,
	intensity: number,
	yearsAgo: number,
}

export type VisualProfile = {
	familyKey: string,
	tint: RGB,
	roughness: number,
	metallic: number,
	normalStrength: number,
	patternScaleM: number,
}

export type PhysicalProfile = {
	classKey: string,
	densityKgM3: number,
	staticFriction: number,
	dynamicFriction: number,
	restitution: number,
	hardness: number,
}

export type AcousticProfile = {
	classKey: string,
	absorption: number,
	damping: number,
	impactFamilyKey: string,
	scrapeFamilyKey: string,
}

export type MaterialRecipe = {
	id: string,
	schemaVersion: number,
	recipeVersion: number,
	substrate: SubstrateLayer,
	finish: FinishLayer,
	installation: InstallationLayer,
	apparentAge: ApparentAgeLayer,
	maintenance: MaintenanceLayer,
	environment: EnvironmentLayer,
	events: { HistoryEvent },
	visual: VisualProfile,
	physical: PhysicalProfile,
	acoustic: AcousticProfile,
}

export type MaterialState = {
	wear: number,
	damage: number,
	wetness: number,
	soil: number,
}

export type MaterialStateInput = {
	wear: number?,
	damage: number?,
	wetness: number?,
	soil: number?,
}

export type MaterialDNA = {
	recipe: MaterialRecipe,
	state: MaterialState,
}

local SCHEMA_VERSION = 1
local MAX_KEY_LENGTH = 128
local MAX_MATERIAL_ID_LENGTH = 192
local EPSILON = 1e-6

local MaterialDNA = {}
MaterialDNA.SCHEMA_VERSION = SCHEMA_VERSION

local function assertFinite(name: string, value: number): ()
	assert(value == value and value ~= math.huge and value ~= -math.huge, `{name} must be finite`)
end

local function assertUnitInterval(name: string, value: number): ()
	assertFinite(name, value)
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function assertNonNegative(name: string, value: number): ()
	assertFinite(name, value)
	assert(value >= 0, `{name} must be non-negative`)
end

local function assertPositive(name: string, value: number): ()
	assertFinite(name, value)
	assert(value > 0, `{name} must be positive`)
end

local function assertPositiveInteger(name: string, value: number): ()
	assertFinite(name, value)
	assert(value >= 1 and value % 1 == 0, `{name} must be a positive integer`)
end

local function assertProjectKey(name: string, value: string): ()
	assert(value ~= "", `{name} required`)
	assert(#value <= MAX_KEY_LENGTH, `{name} must be <= {MAX_KEY_LENGTH} characters`)
	assert(string.match(value, "^[a-z][a-z0-9_./%-]*$") ~= nil, `{name} must be a lowercase project key`)
	assert(string.find(value, "rbxassetid://", 1, true) == nil, `{name} must not contain a Roblox asset ID`)
	assert(string.match(value, "^%d+$") == nil, `{name} must not be a raw numeric asset ID`)
end

local function assertMaterialId(value: string): ()
	assert(value ~= "", "MaterialRecipe.id required")
	assert(#value <= MAX_MATERIAL_ID_LENGTH, `MaterialRecipe.id must be <= {MAX_MATERIAL_ID_LENGTH} characters`)
	assert(string.find(value, "[%c]") == nil, "MaterialRecipe.id must not contain control characters")
end

local function validateRgb(name: string, value: RGB): ()
	assertUnitInterval(`{name}.r`, value.r)
	assertUnitInterval(`{name}.g`, value.g)
	assertUnitInterval(`{name}.b`, value.b)
end

function MaterialDNA.validateRecipe(value: MaterialRecipe): ()
	assertMaterialId(value.id)
	assert(value.schemaVersion == SCHEMA_VERSION, `unsupported MaterialDNA schemaVersion {value.schemaVersion}`)
	assertPositiveInteger("recipeVersion", value.recipeVersion)

	assertProjectKey("substrate.familyKey", value.substrate.familyKey)
	assertPositive("substrate.thicknessM", value.substrate.thicknessM)
	assert(value.substrate.thicknessM <= 2, "substrate.thicknessM exceeds the production plausibility bound")
	assertUnitInterval("substrate.porosity", value.substrate.porosity)

	assertProjectKey("finish.familyKey", value.finish.familyKey)
	assertProjectKey("finish.processKey", value.finish.processKey)
	assertNonNegative("finish.coatingThicknessM", value.finish.coatingThicknessM)
	assert(
		value.finish.coatingThicknessM <= value.substrate.thicknessM + EPSILON,
		"finish.coatingThicknessM cannot exceed substrate.thicknessM"
	)
	assertUnitInterval("finish.manufacturingVariation", value.finish.manufacturingVariation)

	assertProjectKey("installation.methodKey", value.installation.methodKey)
	assertProjectKey("installation.batchKey", value.installation.batchKey)
	assertFinite("installation.orientationDegrees", value.installation.orientationDegrees)
	assert(
		value.installation.orientationDegrees >= 0 and value.installation.orientationDegrees < 360,
		"installation.orientationDegrees must be in [0, 360)"
	)
	if value.installation.seamSpacingM ~= nil then
		assertPositive("installation.seamSpacingM", value.installation.seamSpacingM)
	end

	assertProjectKey("apparentAge.eraKey", value.apparentAge.eraKey)
	assertNonNegative("apparentAge.apparentYears", value.apparentAge.apparentYears)
	assert(value.apparentAge.apparentYears <= 250, "apparentAge.apparentYears exceeds the production plausibility bound")

	assertUnitInterval("maintenance.condition", value.maintenance.condition)
	assertUnitInterval("maintenance.cleaning", value.maintenance.cleaning)
	assertNonNegative("maintenance.repairCount", value.maintenance.repairCount)
	assert(value.maintenance.repairCount % 1 == 0, "maintenance.repairCount must be an integer")

	assertUnitInterval("environment.humidityExposure", value.environment.humidityExposure)
	assertUnitInterval("environment.uvExposure", value.environment.uvExposure)
	assertUnitInterval("environment.contactExposure", value.environment.contactExposure)

	local eventKeys: { [string]: boolean } = {}
	for index, event in value.events do
		assertProjectKey(`events[{index}].key`, event.key)
		assertProjectKey(`events[{index}].kindKey`, event.kindKey)
		assert(eventKeys[event.key] ~= true, `events[{index}].key duplicates {event.key}`)
		eventKeys[event.key] = true
		assertUnitInterval(`events[{index}].intensity`, event.intensity)
		assertNonNegative(`events[{index}].yearsAgo`, event.yearsAgo)
		assert(
			event.yearsAgo <= value.apparentAge.apparentYears + EPSILON,
			`events[{index}].yearsAgo cannot predate the material's apparent age`
		)
	end

	assertProjectKey("visual.familyKey", value.visual.familyKey)
	validateRgb("visual.tint", value.visual.tint)
	assertUnitInterval("visual.roughness", value.visual.roughness)
	assertUnitInterval("visual.metallic", value.visual.metallic)
	assertNonNegative("visual.normalStrength", value.visual.normalStrength)
	assert(value.visual.normalStrength <= 2, "visual.normalStrength must be <= 2")
	assertPositive("visual.patternScaleM", value.visual.patternScaleM)
	assert(value.visual.patternScaleM <= 100, "visual.patternScaleM exceeds the production plausibility bound")

	assertProjectKey("physical.classKey", value.physical.classKey)
	assertPositive("physical.densityKgM3", value.physical.densityKgM3)
	assert(value.physical.densityKgM3 <= 30000, "physical.densityKgM3 exceeds the production plausibility bound")
	assertNonNegative("physical.staticFriction", value.physical.staticFriction)
	assertNonNegative("physical.dynamicFriction", value.physical.dynamicFriction)
	assert(
		value.physical.dynamicFriction <= value.physical.staticFriction + EPSILON,
		"physical.dynamicFriction should not exceed physical.staticFriction"
	)
	assertUnitInterval("physical.restitution", value.physical.restitution)
	assertUnitInterval("physical.hardness", value.physical.hardness)

	assertProjectKey("acoustic.classKey", value.acoustic.classKey)
	assertUnitInterval("acoustic.absorption", value.acoustic.absorption)
	assertUnitInterval("acoustic.damping", value.acoustic.damping)
	assertProjectKey("acoustic.impactFamilyKey", value.acoustic.impactFamilyKey)
	assertProjectKey("acoustic.scrapeFamilyKey", value.acoustic.scrapeFamilyKey)
end

function MaterialDNA.validateState(value: MaterialState): ()
	assertUnitInterval("state.wear", value.wear)
	assertUnitInterval("state.damage", value.damage)
	assertUnitInterval("state.wetness", value.wetness)
	assertUnitInterval("state.soil", value.soil)
end

local function freezeRgb(value: RGB): RGB
	return table.freeze({
		r = value.r,
		g = value.g,
		b = value.b,
	})
end

local function freezeEvents(events: { HistoryEvent }): { HistoryEvent }
	local copy: { HistoryEvent } = {}
	for _, event in events do
		table.insert(
			copy,
			table.freeze({
				key = event.key,
				kindKey = event.kindKey,
				intensity = event.intensity,
				yearsAgo = event.yearsAgo,
			})
		)
	end
	return table.freeze(copy)
end

function MaterialDNA.freezeRecipe(value: MaterialRecipe): MaterialRecipe
	MaterialDNA.validateRecipe(value)

	local recipe: MaterialRecipe = {
		id = value.id,
		schemaVersion = value.schemaVersion,
		recipeVersion = value.recipeVersion,
		substrate = table.freeze({
			familyKey = value.substrate.familyKey,
			thicknessM = value.substrate.thicknessM,
			porosity = value.substrate.porosity,
		}),
		finish = table.freeze({
			familyKey = value.finish.familyKey,
			processKey = value.finish.processKey,
			coatingThicknessM = value.finish.coatingThicknessM,
			manufacturingVariation = value.finish.manufacturingVariation,
		}),
		installation = table.freeze({
			methodKey = value.installation.methodKey,
			batchKey = value.installation.batchKey,
			orientationDegrees = value.installation.orientationDegrees,
			seamSpacingM = value.installation.seamSpacingM,
		}),
		apparentAge = table.freeze({
			eraKey = value.apparentAge.eraKey,
			apparentYears = value.apparentAge.apparentYears,
		}),
		maintenance = table.freeze({
			condition = value.maintenance.condition,
			cleaning = value.maintenance.cleaning,
			repairCount = value.maintenance.repairCount,
		}),
		environment = table.freeze({
			humidityExposure = value.environment.humidityExposure,
			uvExposure = value.environment.uvExposure,
			contactExposure = value.environment.contactExposure,
		}),
		events = freezeEvents(value.events),
		visual = table.freeze({
			familyKey = value.visual.familyKey,
			tint = freezeRgb(value.visual.tint),
			roughness = value.visual.roughness,
			metallic = value.visual.metallic,
			normalStrength = value.visual.normalStrength,
			patternScaleM = value.visual.patternScaleM,
		}),
		physical = table.freeze({
			classKey = value.physical.classKey,
			densityKgM3 = value.physical.densityKgM3,
			staticFriction = value.physical.staticFriction,
			dynamicFriction = value.physical.dynamicFriction,
			restitution = value.physical.restitution,
			hardness = value.physical.hardness,
		}),
		acoustic = table.freeze({
			classKey = value.acoustic.classKey,
			absorption = value.acoustic.absorption,
			damping = value.acoustic.damping,
			impactFamilyKey = value.acoustic.impactFamilyKey,
			scrapeFamilyKey = value.acoustic.scrapeFamilyKey,
		}),
	}

	return table.freeze(recipe)
end

function MaterialDNA.newState(input: MaterialStateInput?): MaterialState
	local source = input or {}
	local state: MaterialState = {
		wear = source.wear or 0,
		damage = source.damage or 0,
		wetness = source.wetness or 0,
		soil = source.soil or 0,
	}
	MaterialDNA.validateState(state)
	return state
end

function MaterialDNA.new(recipe: MaterialRecipe, stateInput: MaterialStateInput?): MaterialDNA
	local record: MaterialDNA = {
		recipe = MaterialDNA.freezeRecipe(recipe),
		state = MaterialDNA.newState(stateInput),
	}
	return table.freeze(record)
end

function MaterialDNA.validate(value: MaterialDNA): ()
	MaterialDNA.validateRecipe(value.recipe)
	MaterialDNA.validateState(value.state)
end

return table.freeze(MaterialDNA)
