--!strict

local SCHEMA_VERSION = 1
local MAX_HISTORY_EVENTS = 32
local MAX_ANOMALY_MODIFIERS = 8

export type MaterialId = string

export type Color01 = {
	r: number,
	g: number,
	b: number,
}

export type SubstrateSpec = {
	classKey: string,
	thicknessMeters: number,
	porosity01: number,
}

export type FinishSpec = {
	classKey: string,
	color: Color01,
	roughness01: number,
	metallic01: number,
}

export type InstallationSpec = {
	methodKey: string,
	batchKey: string,
	quality01: number,
	seamPeriodMeters: number?,
}

export type MaintenanceSpec = {
	careClassKey: string,
	frequency01: number,
	cleanliness01: number,
	repairCount: number,
}

export type EnvironmentExposure = {
	humidity01: number,
	water01: number,
	uv01: number,
	grime01: number,
}

export type HistoryEvent = {
	kindKey: string,
	causeKey: string,
	severity01: number,
	coverage01: number,
}

export type VisualSpec = {
	familyKey: string,
	coherenceClass: string,
	metersPerRepeat: number,
}

export type PhysicalSpec = {
	classKey: string,
	coherenceClass: string,
	densityKgPerM3: number,
	staticFriction: number,
	dynamicFriction: number,
	restitution01: number,
}

export type AcousticSpec = {
	classKey: string,
	coherenceClass: string,
	absorptionLow01: number,
	absorptionMid01: number,
	absorptionHigh01: number,
	impactFamilyKey: string,
	scrapeFamilyKey: string,
}

export type ResponseSpec = {
	wetFrictionMultiplier: number,
	wetDarkening01: number,
	damageResistance01: number,
	stainAffinity01: number,
}

export type MaterialRecipe = {
	id: MaterialId,
	schemaVersion: number,
	coherenceClass: string,
	substrate: SubstrateSpec,
	finish: FinishSpec,
	installation: InstallationSpec,
	apparentAgeYears: number,
	maintenance: MaintenanceSpec,
	environment: EnvironmentExposure,
	historyEvents: { HistoryEvent },
	visual: VisualSpec,
	physical: PhysicalSpec,
	acoustic: AcousticSpec,
	response: ResponseSpec,
	anomalyModifiers: { string },
}

-- Compatibility alias for callers that treat the immutable recipe as MaterialDNA.
export type MaterialDNA = MaterialRecipe

export type MaterialState = {
	recipeId: MaterialId,
	schemaVersion: number,
	wear01: number,
	damage01: number,
	wetness01: number,
	soil01: number,
}

export type ValidationResult = {
	ok: boolean,
	errors: { string },
}

local MaterialDNA = {
	SchemaVersion = SCHEMA_VERSION,
}

local function appendError(errors: { string }, message: string): ()
	table.insert(errors, message)
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateFiniteRange(
	errors: { string },
	name: string,
	value: number,
	minimum: number,
	maximum: number
): ()
	if not isFinite(value) or value < minimum or value > maximum then
		appendError(errors, `{name} must be finite and in [{minimum}, {maximum}]`)
	end
end

local function validatePositive(errors: { string }, name: string, value: number, maximum: number): ()
	if not isFinite(value) or value <= 0 or value > maximum then
		appendError(errors, `{name} must be finite and in (0, {maximum}]`)
	end
end

local function isStableKey(value: string): boolean
	return value ~= "" and string.match(value, "^[a-z0-9][a-z0-9._/%-]*$") ~= nil
end

local function looksLikeExternalAssetReference(value: string): boolean
	local lowered = string.lower(value)
	return string.find(lowered, "rbxassetid://", 1, true) ~= nil
		or string.find(lowered, "http://", 1, true) ~= nil
		or string.find(lowered, "https://", 1, true) ~= nil
end

local function validateProjectKey(errors: { string }, name: string, value: string): ()
	if looksLikeExternalAssetReference(value) then
		appendError(errors, `{name} must be a project-owned semantic key, not an asset/URL reference`)
	elseif not isStableKey(value) then
		appendError(errors, `{name} must use lowercase stable-key characters [a-z0-9._/-]`)
	end
end

local function validateColor(errors: { string }, name: string, value: Color01): ()
	validateFiniteRange(errors, `{name}.r`, value.r, 0, 1)
	validateFiniteRange(errors, `{name}.g`, value.g, 0, 1)
	validateFiniteRange(errors, `{name}.b`, value.b, 0, 1)
end

function MaterialDNA.validateRecipe(value: MaterialRecipe): ValidationResult
	local errors: { string } = {}

	if value.schemaVersion ~= SCHEMA_VERSION then
		appendError(errors, `schemaVersion must be {SCHEMA_VERSION}`)
	end

	validateProjectKey(errors, "id", value.id)
	validateProjectKey(errors, "coherenceClass", value.coherenceClass)
	validateProjectKey(errors, "substrate.classKey", value.substrate.classKey)
	validateProjectKey(errors, "finish.classKey", value.finish.classKey)
	validateProjectKey(errors, "installation.methodKey", value.installation.methodKey)
	validateProjectKey(errors, "installation.batchKey", value.installation.batchKey)
	validateProjectKey(errors, "maintenance.careClassKey", value.maintenance.careClassKey)
	validateProjectKey(errors, "visual.familyKey", value.visual.familyKey)
	validateProjectKey(errors, "visual.coherenceClass", value.visual.coherenceClass)
	validateProjectKey(errors, "physical.classKey", value.physical.classKey)
	validateProjectKey(errors, "physical.coherenceClass", value.physical.coherenceClass)
	validateProjectKey(errors, "acoustic.classKey", value.acoustic.classKey)
	validateProjectKey(errors, "acoustic.coherenceClass", value.acoustic.coherenceClass)
	validateProjectKey(errors, "acoustic.impactFamilyKey", value.acoustic.impactFamilyKey)
	validateProjectKey(errors, "acoustic.scrapeFamilyKey", value.acoustic.scrapeFamilyKey)

	validatePositive(errors, "substrate.thicknessMeters", value.substrate.thicknessMeters, 5)
	validateFiniteRange(errors, "substrate.porosity01", value.substrate.porosity01, 0, 1)
	validateColor(errors, "finish.color", value.finish.color)
	validateFiniteRange(errors, "finish.roughness01", value.finish.roughness01, 0, 1)
	validateFiniteRange(errors, "finish.metallic01", value.finish.metallic01, 0, 1)
	validateFiniteRange(errors, "installation.quality01", value.installation.quality01, 0, 1)
	if value.installation.seamPeriodMeters ~= nil then
		validatePositive(errors, "installation.seamPeriodMeters", value.installation.seamPeriodMeters, 100)
	end
	validateFiniteRange(errors, "apparentAgeYears", value.apparentAgeYears, 0, 250)
	validateFiniteRange(errors, "maintenance.frequency01", value.maintenance.frequency01, 0, 1)
	validateFiniteRange(errors, "maintenance.cleanliness01", value.maintenance.cleanliness01, 0, 1)
	if not isFinite(value.maintenance.repairCount)
		or value.maintenance.repairCount < 0
		or math.floor(value.maintenance.repairCount) ~= value.maintenance.repairCount
	then
		appendError(errors, "maintenance.repairCount must be a finite non-negative integer")
	end
	validateFiniteRange(errors, "environment.humidity01", value.environment.humidity01, 0, 1)
	validateFiniteRange(errors, "environment.water01", value.environment.water01, 0, 1)
	validateFiniteRange(errors, "environment.uv01", value.environment.uv01, 0, 1)
	validateFiniteRange(errors, "environment.grime01", value.environment.grime01, 0, 1)

	if #value.historyEvents > MAX_HISTORY_EVENTS then
		appendError(errors, `historyEvents cannot exceed {MAX_HISTORY_EVENTS} entries`)
	end
	for index, event in ipairs(value.historyEvents) do
		validateProjectKey(errors, `historyEvents[{index}].kindKey`, event.kindKey)
		validateProjectKey(errors, `historyEvents[{index}].causeKey`, event.causeKey)
		validateFiniteRange(errors, `historyEvents[{index}].severity01`, event.severity01, 0, 1)
		validateFiniteRange(errors, `historyEvents[{index}].coverage01`, event.coverage01, 0, 1)
	end

	if value.visual.coherenceClass ~= value.coherenceClass then
		appendError(errors, "visual.coherenceClass must match MaterialRecipe.coherenceClass")
	end
	if value.physical.coherenceClass ~= value.coherenceClass then
		appendError(errors, "physical.coherenceClass must match MaterialRecipe.coherenceClass")
	end
	if value.acoustic.coherenceClass ~= value.coherenceClass then
		appendError(errors, "acoustic.coherenceClass must match MaterialRecipe.coherenceClass")
	end

	validatePositive(errors, "visual.metersPerRepeat", value.visual.metersPerRepeat, 100)
	validatePositive(errors, "physical.densityKgPerM3", value.physical.densityKgPerM3, 25000)
	validateFiniteRange(errors, "physical.staticFriction", value.physical.staticFriction, 0, 4)
	validateFiniteRange(errors, "physical.dynamicFriction", value.physical.dynamicFriction, 0, 4)
	if isFinite(value.physical.staticFriction)
		and isFinite(value.physical.dynamicFriction)
		and value.physical.dynamicFriction > value.physical.staticFriction
	then
		appendError(errors, "physical.dynamicFriction cannot exceed physical.staticFriction")
	end
	validateFiniteRange(errors, "physical.restitution01", value.physical.restitution01, 0, 1)
	validateFiniteRange(errors, "acoustic.absorptionLow01", value.acoustic.absorptionLow01, 0, 1)
	validateFiniteRange(errors, "acoustic.absorptionMid01", value.acoustic.absorptionMid01, 0, 1)
	validateFiniteRange(errors, "acoustic.absorptionHigh01", value.acoustic.absorptionHigh01, 0, 1)
	validateFiniteRange(errors, "response.wetFrictionMultiplier", value.response.wetFrictionMultiplier, 0, 2)
	validateFiniteRange(errors, "response.wetDarkening01", value.response.wetDarkening01, 0, 1)
	validateFiniteRange(errors, "response.damageResistance01", value.response.damageResistance01, 0, 1)
	validateFiniteRange(errors, "response.stainAffinity01", value.response.stainAffinity01, 0, 1)

	if #value.anomalyModifiers > MAX_ANOMALY_MODIFIERS then
		appendError(errors, `anomalyModifiers cannot exceed {MAX_ANOMALY_MODIFIERS} entries`)
	end
	for index, modifierKey in ipairs(value.anomalyModifiers) do
		validateProjectKey(errors, `anomalyModifiers[{index}]`, modifierKey)
	end

	return {
		ok = #errors == 0,
		errors = errors,
	}
end

function MaterialDNA.assertValidRecipe(value: MaterialRecipe): ()
	local result = MaterialDNA.validateRecipe(value)
	assert(result.ok, table.concat(result.errors, "; "))
end

function MaterialDNA.validateState(value: MaterialState): ValidationResult
	local errors: { string } = {}

	if value.schemaVersion ~= SCHEMA_VERSION then
		appendError(errors, `schemaVersion must be {SCHEMA_VERSION}`)
	end
	validateProjectKey(errors, "recipeId", value.recipeId)
	validateFiniteRange(errors, "wear01", value.wear01, 0, 1)
	validateFiniteRange(errors, "damage01", value.damage01, 0, 1)
	validateFiniteRange(errors, "wetness01", value.wetness01, 0, 1)
	validateFiniteRange(errors, "soil01", value.soil01, 0, 1)

	return {
		ok = #errors == 0,
		errors = errors,
	}
end

function MaterialDNA.assertValidState(value: MaterialState): ()
	local result = MaterialDNA.validateState(value)
	assert(result.ok, table.concat(result.errors, "; "))
end

function MaterialDNA.defaultState(recipeId: MaterialId): MaterialState
	local state: MaterialState = {
		recipeId = recipeId,
		schemaVersion = SCHEMA_VERSION,
		wear01 = 0,
		damage01 = 0,
		wetness01 = 0,
		soil01 = 0,
	}
	MaterialDNA.assertValidState(state)
	return state
end

-- Legacy assertion name retained while bootstrap consumers migrate to the explicit recipe API.
function MaterialDNA.validate(value: MaterialRecipe): ()
	MaterialDNA.assertValidRecipe(value)
end

return table.freeze(MaterialDNA)
