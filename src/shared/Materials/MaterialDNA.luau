--!strict

local SCHEMA_VERSION = 1
local MAX_HISTORY_EVENTS = 32
local MAX_ANOMALY_MODIFIERS = 8
local MAX_KEY_LENGTH = 160

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

-- Compatibility alias: MaterialDNA is the immutable recipe, not mutable surface state.
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

local WALL_SUBSTRATES = table.freeze({
	["substrate.gypsum-board"] = true,
	["substrate.plaster"] = true,
	["substrate.concrete"] = true,
})

local CARPET_SUBSTRATES = table.freeze({
	["substrate.synthetic-carpet-backing"] = true,
	["substrate.rubber-carpet-backing"] = true,
})

local METAL_SUBSTRATES = table.freeze({
	["substrate.cold-rolled-steel"] = true,
	["substrate.aluminum-sheet"] = true,
})

local CARPET_INSTALLATIONS = table.freeze({
	["installation.glued-carpet-roll"] = true,
	["installation.carpet-tile-adhesive"] = true,
})

local RECIPE_KEYS = table.freeze({
	id = true,
	schemaVersion = true,
	coherenceClass = true,
	substrate = true,
	finish = true,
	installation = true,
	apparentAgeYears = true,
	maintenance = true,
	environment = true,
	historyEvents = true,
	visual = true,
	physical = true,
	acoustic = true,
	response = true,
	anomalyModifiers = true,
})
local COLOR_KEYS = table.freeze({ r = true, g = true, b = true })
local SUBSTRATE_KEYS = table.freeze({ classKey = true, thicknessMeters = true, porosity01 = true })
local FINISH_KEYS = table.freeze({ classKey = true, color = true, roughness01 = true, metallic01 = true })
local INSTALLATION_KEYS = table.freeze({
	methodKey = true,
	batchKey = true,
	quality01 = true,
	seamPeriodMeters = true,
})
local MAINTENANCE_KEYS = table.freeze({
	careClassKey = true,
	frequency01 = true,
	cleanliness01 = true,
	repairCount = true,
})
local ENVIRONMENT_KEYS = table.freeze({ humidity01 = true, water01 = true, uv01 = true, grime01 = true })
local HISTORY_EVENT_KEYS = table.freeze({
	kindKey = true,
	causeKey = true,
	severity01 = true,
	coverage01 = true,
})
local VISUAL_KEYS = table.freeze({ familyKey = true, coherenceClass = true, metersPerRepeat = true })
local PHYSICAL_KEYS = table.freeze({
	classKey = true,
	coherenceClass = true,
	densityKgPerM3 = true,
	staticFriction = true,
	dynamicFriction = true,
	restitution01 = true,
})
local ACOUSTIC_KEYS = table.freeze({
	classKey = true,
	coherenceClass = true,
	absorptionLow01 = true,
	absorptionMid01 = true,
	absorptionHigh01 = true,
	impactFamilyKey = true,
	scrapeFamilyKey = true,
})
local RESPONSE_KEYS = table.freeze({
	wetFrictionMultiplier = true,
	wetDarkening01 = true,
	damageResistance01 = true,
	stainAffinity01 = true,
})
local STATE_KEYS = table.freeze({
	recipeId = true,
	schemaVersion = true,
	wear01 = true,
	damage01 = true,
	wetness01 = true,
	soil01 = true,
})

local function appendError(errors: { string }, message: string): ()
	table.insert(errors, message)
end

local function asTable(errors: { string }, path: string, value: unknown): any?
	if type(value) ~= "table" then
		appendError(errors, `{path} must be a table`)
		return nil
	end
	return value :: any
end

local function validateKnownKeys(
	errors: { string },
	path: string,
	value: { [any]: any },
	allowed: { [string]: boolean }
): ()
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			appendError(errors, `{path} contains unknown field {tostring(key)}`)
		end
	end
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateFiniteRange(
	errors: { string },
	path: string,
	value: unknown,
	minimum: number,
	maximum: number
): number?
	if type(value) ~= "number" or not isFinite(value) or value < minimum or value > maximum then
		appendError(errors, `{path} must be finite and in [{minimum}, {maximum}]`)
		return nil
	end
	return value
end

local function validatePositive(errors: { string }, path: string, value: unknown, maximum: number): number?
	if type(value) ~= "number" or not isFinite(value) or value <= 0 or value > maximum then
		appendError(errors, `{path} must be finite and in (0, {maximum}]`)
		return nil
	end
	return value
end

local function validateNonNegativeInteger(errors: { string }, path: string, value: unknown): number?
	if type(value) ~= "number" or not isFinite(value) or value < 0 or math.floor(value) ~= value then
		appendError(errors, `{path} must be a finite non-negative integer`)
		return nil
	end
	return value
end

local function looksLikeExternalAssetReference(value: string): boolean
	return string.find(value, "://", 1, true) ~= nil or string.match(value, "^%d+$") ~= nil
end

local function validateProjectKey(errors: { string }, path: string, value: unknown): string?
	if type(value) ~= "string" or value == "" then
		appendError(errors, `{path} must be a non-empty project-owned semantic key`)
		return nil
	end
	if #value > MAX_KEY_LENGTH then
		appendError(errors, `{path} cannot exceed {MAX_KEY_LENGTH} bytes`)
		return nil
	end
	if looksLikeExternalAssetReference(value) then
		appendError(errors, `{path} must be a project-owned semantic key, not an asset/URL reference`)
		return nil
	end
	if string.match(value, "^[a-z0-9][a-z0-9._/%-]*$") == nil then
		appendError(errors, `{path} must use lowercase stable-key characters [a-z0-9._/-]`)
		return nil
	end
	return value
end

local function validateColor(errors: { string }, path: string, value: unknown): ()
	local color = asTable(errors, path, value)
	if color == nil then
		return
	end
	validateKnownKeys(errors, path, color, COLOR_KEYS)
	validateFiniteRange(errors, `{path}.r`, color.r, 0, 1)
	validateFiniteRange(errors, `{path}.g`, color.g, 0, 1)
	validateFiniteRange(errors, `{path}.b`, color.b, 0, 1)
end

local function validateDenseArray(errors: { string }, path: string, value: unknown, maximum: number): any?
	local array = asTable(errors, path, value)
	if array == nil then
		return nil
	end

	local count = 0
	local highest = 0
	local keyed = false
	for key in pairs(array) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			keyed = true
		else
			count += 1
			if key > highest then
				highest = key
			end
		end
	end

	if keyed then
		appendError(errors, `{path} must be a dense 1-based array with no keyed entries`)
		return nil
	end
	if highest ~= count then
		appendError(errors, `{path} must be a dense 1-based array with no sparse entries`)
		return nil
	end
	if count > maximum then
		appendError(errors, `{path} cannot exceed {maximum} entries`)
		return nil
	end
	return array
end

local function validateSubstrate(errors: { string }, value: unknown): string?
	local substrate = asTable(errors, "substrate", value)
	if substrate == nil then
		return nil
	end
	validateKnownKeys(errors, "substrate", substrate, SUBSTRATE_KEYS)
	local classKey = validateProjectKey(errors, "substrate.classKey", substrate.classKey)
	validatePositive(errors, "substrate.thicknessMeters", substrate.thicknessMeters, 5)
	validateFiniteRange(errors, "substrate.porosity01", substrate.porosity01, 0, 1)
	return classKey
end

local function validateFinish(errors: { string }, value: unknown): string?
	local finish = asTable(errors, "finish", value)
	if finish == nil then
		return nil
	end
	validateKnownKeys(errors, "finish", finish, FINISH_KEYS)
	local classKey = validateProjectKey(errors, "finish.classKey", finish.classKey)
	validateColor(errors, "finish.color", finish.color)
	validateFiniteRange(errors, "finish.roughness01", finish.roughness01, 0, 1)
	validateFiniteRange(errors, "finish.metallic01", finish.metallic01, 0, 1)
	return classKey
end

local function validateInstallation(errors: { string }, value: unknown): string?
	local installation = asTable(errors, "installation", value)
	if installation == nil then
		return nil
	end
	validateKnownKeys(errors, "installation", installation, INSTALLATION_KEYS)
	local methodKey = validateProjectKey(errors, "installation.methodKey", installation.methodKey)
	validateProjectKey(errors, "installation.batchKey", installation.batchKey)
	validateFiniteRange(errors, "installation.quality01", installation.quality01, 0, 1)
	if installation.seamPeriodMeters ~= nil then
		validatePositive(errors, "installation.seamPeriodMeters", installation.seamPeriodMeters, 100)
	end
	return methodKey
end

local function validateMaintenance(errors: { string }, value: unknown): ()
	local maintenance = asTable(errors, "maintenance", value)
	if maintenance == nil then
		return
	end
	validateKnownKeys(errors, "maintenance", maintenance, MAINTENANCE_KEYS)
	validateProjectKey(errors, "maintenance.careClassKey", maintenance.careClassKey)
	validateFiniteRange(errors, "maintenance.frequency01", maintenance.frequency01, 0, 1)
	validateFiniteRange(errors, "maintenance.cleanliness01", maintenance.cleanliness01, 0, 1)
	validateNonNegativeInteger(errors, "maintenance.repairCount", maintenance.repairCount)
end

local function validateEnvironment(errors: { string }, value: unknown): ()
	local environment = asTable(errors, "environment", value)
	if environment == nil then
		return
	end
	validateKnownKeys(errors, "environment", environment, ENVIRONMENT_KEYS)
	validateFiniteRange(errors, "environment.humidity01", environment.humidity01, 0, 1)
	validateFiniteRange(errors, "environment.water01", environment.water01, 0, 1)
	validateFiniteRange(errors, "environment.uv01", environment.uv01, 0, 1)
	validateFiniteRange(errors, "environment.grime01", environment.grime01, 0, 1)
end

local function validateHistoryEvents(errors: { string }, value: unknown): ()
	local events = validateDenseArray(errors, "historyEvents", value, MAX_HISTORY_EVENTS)
	if events == nil then
		return
	end
	for index = 1, #events do
		local path = `historyEvents[{index}]`
		local event = asTable(errors, path, events[index])
		if event ~= nil then
			validateKnownKeys(errors, path, event, HISTORY_EVENT_KEYS)
			validateProjectKey(errors, `{path}.kindKey`, event.kindKey)
			validateProjectKey(errors, `{path}.causeKey`, event.causeKey)
			validateFiniteRange(errors, `{path}.severity01`, event.severity01, 0, 1)
			validateFiniteRange(errors, `{path}.coverage01`, event.coverage01, 0, 1)
		end
	end
end

local function validateVisual(errors: { string }, value: unknown, coherenceClass: string?): ()
	local visual = asTable(errors, "visual", value)
	if visual == nil then
		return
	end
	validateKnownKeys(errors, "visual", visual, VISUAL_KEYS)
	validateProjectKey(errors, "visual.familyKey", visual.familyKey)
	local visualCoherence = validateProjectKey(errors, "visual.coherenceClass", visual.coherenceClass)
	if coherenceClass ~= nil and visualCoherence ~= nil and visualCoherence ~= coherenceClass then
		appendError(errors, "visual.coherenceClass must match MaterialRecipe.coherenceClass")
	end
	validatePositive(errors, "visual.metersPerRepeat", visual.metersPerRepeat, 100)
end

local function validatePhysical(errors: { string }, value: unknown, coherenceClass: string?): ()
	local physical = asTable(errors, "physical", value)
	if physical == nil then
		return
	end
	validateKnownKeys(errors, "physical", physical, PHYSICAL_KEYS)
	validateProjectKey(errors, "physical.classKey", physical.classKey)
	local physicalCoherence = validateProjectKey(errors, "physical.coherenceClass", physical.coherenceClass)
	if coherenceClass ~= nil and physicalCoherence ~= nil and physicalCoherence ~= coherenceClass then
		appendError(errors, "physical.coherenceClass must match MaterialRecipe.coherenceClass")
	end
	validatePositive(errors, "physical.densityKgPerM3", physical.densityKgPerM3, 25000)
	local staticFriction = validateFiniteRange(errors, "physical.staticFriction", physical.staticFriction, 0, 4)
	local dynamicFriction = validateFiniteRange(errors, "physical.dynamicFriction", physical.dynamicFriction, 0, 4)
	if staticFriction ~= nil and dynamicFriction ~= nil and dynamicFriction > staticFriction then
		appendError(errors, "physical.dynamicFriction cannot exceed physical.staticFriction")
	end
	validateFiniteRange(errors, "physical.restitution01", physical.restitution01, 0, 1)
end

local function validateAcoustic(errors: { string }, value: unknown, coherenceClass: string?): ()
	local acoustic = asTable(errors, "acoustic", value)
	if acoustic == nil then
		return
	end
	validateKnownKeys(errors, "acoustic", acoustic, ACOUSTIC_KEYS)
	validateProjectKey(errors, "acoustic.classKey", acoustic.classKey)
	local acousticCoherence = validateProjectKey(errors, "acoustic.coherenceClass", acoustic.coherenceClass)
	if coherenceClass ~= nil and acousticCoherence ~= nil and acousticCoherence ~= coherenceClass then
		appendError(errors, "acoustic.coherenceClass must match MaterialRecipe.coherenceClass")
	end
	validateFiniteRange(errors, "acoustic.absorptionLow01", acoustic.absorptionLow01, 0, 1)
	validateFiniteRange(errors, "acoustic.absorptionMid01", acoustic.absorptionMid01, 0, 1)
	validateFiniteRange(errors, "acoustic.absorptionHigh01", acoustic.absorptionHigh01, 0, 1)
	validateProjectKey(errors, "acoustic.impactFamilyKey", acoustic.impactFamilyKey)
	validateProjectKey(errors, "acoustic.scrapeFamilyKey", acoustic.scrapeFamilyKey)
end

local function validateResponse(errors: { string }, value: unknown): ()
	local response = asTable(errors, "response", value)
	if response == nil then
		return
	end
	validateKnownKeys(errors, "response", response, RESPONSE_KEYS)
	validateFiniteRange(errors, "response.wetFrictionMultiplier", response.wetFrictionMultiplier, 0, 2)
	validateFiniteRange(errors, "response.wetDarkening01", response.wetDarkening01, 0, 1)
	validateFiniteRange(errors, "response.damageResistance01", response.damageResistance01, 0, 1)
	validateFiniteRange(errors, "response.stainAffinity01", response.stainAffinity01, 0, 1)
end

local function validateAnomalyModifiers(errors: { string }, value: unknown): ()
	local modifiers = validateDenseArray(errors, "anomalyModifiers", value, MAX_ANOMALY_MODIFIERS)
	if modifiers == nil then
		return
	end
	for index = 1, #modifiers do
		validateProjectKey(errors, `anomalyModifiers[{index}]`, modifiers[index])
	end
end

local function validateCompatibility(
	errors: { string },
	substrateClass: string?,
	finishClass: string?,
	installationMethod: string?
): ()
	if finishClass == "finish.vinyl-wallpaper" then
		if substrateClass ~= nil and not WALL_SUBSTRATES[substrateClass] then
			appendError(errors, "finish.vinyl-wallpaper requires a wall-compatible substrate")
		end
		if installationMethod ~= nil and installationMethod ~= "installation.pasted-wallpaper" then
			appendError(errors, "finish.vinyl-wallpaper requires installation.pasted-wallpaper")
		end
	elseif finishClass == "finish.olefin-low-pile" then
		if substrateClass ~= nil and not CARPET_SUBSTRATES[substrateClass] then
			appendError(errors, "finish.olefin-low-pile requires a carpet-backing substrate")
		end
		if installationMethod ~= nil and not CARPET_INSTALLATIONS[installationMethod] then
			appendError(errors, "finish.olefin-low-pile requires a supported carpet installation method")
		end
	elseif finishClass == "finish.baked-enamel-paint" then
		if substrateClass ~= nil and not METAL_SUBSTRATES[substrateClass] then
			appendError(errors, "finish.baked-enamel-paint requires a sheet-metal substrate")
		end
		if installationMethod ~= nil and installationMethod ~= "installation.factory-coated-panel" then
			appendError(errors, "finish.baked-enamel-paint requires installation.factory-coated-panel")
		end
	end
end

function MaterialDNA.validateRecipe(value: unknown): ValidationResult
	local errors: { string } = {}
	local recipe = asTable(errors, "MaterialRecipe", value)
	if recipe == nil then
		return {
			ok = false,
			errors = errors,
		}
	end

	validateKnownKeys(errors, "MaterialRecipe", recipe, RECIPE_KEYS)
	validateProjectKey(errors, "id", recipe.id)
	if type(recipe.schemaVersion) ~= "number" or recipe.schemaVersion ~= SCHEMA_VERSION then
		appendError(errors, `schemaVersion must be {SCHEMA_VERSION}`)
	end
	local coherenceClass = validateProjectKey(errors, "coherenceClass", recipe.coherenceClass)
	local substrateClass = validateSubstrate(errors, recipe.substrate)
	local finishClass = validateFinish(errors, recipe.finish)
	local installationMethod = validateInstallation(errors, recipe.installation)
	validateFiniteRange(errors, "apparentAgeYears", recipe.apparentAgeYears, 0, 250)
	validateMaintenance(errors, recipe.maintenance)
	validateEnvironment(errors, recipe.environment)
	validateHistoryEvents(errors, recipe.historyEvents)
	validateVisual(errors, recipe.visual, coherenceClass)
	validatePhysical(errors, recipe.physical, coherenceClass)
	validateAcoustic(errors, recipe.acoustic, coherenceClass)
	validateResponse(errors, recipe.response)
	validateAnomalyModifiers(errors, recipe.anomalyModifiers)
	validateCompatibility(errors, substrateClass, finishClass, installationMethod)

	return {
		ok = #errors == 0,
		errors = errors,
	}
end

function MaterialDNA.assertValidRecipe(value: unknown): MaterialRecipe
	local result = MaterialDNA.validateRecipe(value)
	assert(result.ok, table.concat(result.errors, "; "))
	return value :: MaterialRecipe
end

function MaterialDNA.validateState(value: unknown): ValidationResult
	local errors: { string } = {}
	local state = asTable(errors, "MaterialState", value)
	if state == nil then
		return {
			ok = false,
			errors = errors,
		}
	end

	validateKnownKeys(errors, "MaterialState", state, STATE_KEYS)
	validateProjectKey(errors, "recipeId", state.recipeId)
	if type(state.schemaVersion) ~= "number" or state.schemaVersion ~= SCHEMA_VERSION then
		appendError(errors, `schemaVersion must be {SCHEMA_VERSION}`)
	end
	validateFiniteRange(errors, "wear01", state.wear01, 0, 1)
	validateFiniteRange(errors, "damage01", state.damage01, 0, 1)
	validateFiniteRange(errors, "wetness01", state.wetness01, 0, 1)
	validateFiniteRange(errors, "soil01", state.soil01, 0, 1)

	return {
		ok = #errors == 0,
		errors = errors,
	}
end

function MaterialDNA.assertValidState(value: unknown): MaterialState
	local result = MaterialDNA.validateState(value)
	assert(result.ok, table.concat(result.errors, "; "))
	return value :: MaterialState
end

local function freezeColor(value: Color01): Color01
	return table.freeze({
		r = value.r,
		g = value.g,
		b = value.b,
	})
end

local function freezeHistoryEvents(value: { HistoryEvent }): { HistoryEvent }
	local events: { HistoryEvent } = {}
	for index, event in value do
		events[index] = table.freeze({
			kindKey = event.kindKey,
			causeKey = event.causeKey,
			severity01 = event.severity01,
			coverage01 = event.coverage01,
		})
	end
	return table.freeze(events)
end

local function freezeKeys(value: { string }): { string }
	local keys: { string } = table.clone(value)
	return table.freeze(keys)
end

function MaterialDNA.freezeRecipe(value: unknown): MaterialRecipe
	local source = MaterialDNA.assertValidRecipe(value)
	local recipe: MaterialRecipe = {
		id = source.id,
		schemaVersion = source.schemaVersion,
		coherenceClass = source.coherenceClass,
		substrate = table.freeze({
			classKey = source.substrate.classKey,
			thicknessMeters = source.substrate.thicknessMeters,
			porosity01 = source.substrate.porosity01,
		}),
		finish = table.freeze({
			classKey = source.finish.classKey,
			color = freezeColor(source.finish.color),
			roughness01 = source.finish.roughness01,
			metallic01 = source.finish.metallic01,
		}),
		installation = table.freeze({
			methodKey = source.installation.methodKey,
			batchKey = source.installation.batchKey,
			quality01 = source.installation.quality01,
			seamPeriodMeters = source.installation.seamPeriodMeters,
		}),
		apparentAgeYears = source.apparentAgeYears,
		maintenance = table.freeze({
			careClassKey = source.maintenance.careClassKey,
			frequency01 = source.maintenance.frequency01,
			cleanliness01 = source.maintenance.cleanliness01,
			repairCount = source.maintenance.repairCount,
		}),
		environment = table.freeze({
			humidity01 = source.environment.humidity01,
			water01 = source.environment.water01,
			uv01 = source.environment.uv01,
			grime01 = source.environment.grime01,
		}),
		historyEvents = freezeHistoryEvents(source.historyEvents),
		visual = table.freeze({
			familyKey = source.visual.familyKey,
			coherenceClass = source.visual.coherenceClass,
			metersPerRepeat = source.visual.metersPerRepeat,
		}),
		physical = table.freeze({
			classKey = source.physical.classKey,
			coherenceClass = source.physical.coherenceClass,
			densityKgPerM3 = source.physical.densityKgPerM3,
			staticFriction = source.physical.staticFriction,
			dynamicFriction = source.physical.dynamicFriction,
			restitution01 = source.physical.restitution01,
		}),
		acoustic = table.freeze({
			classKey = source.acoustic.classKey,
			coherenceClass = source.acoustic.coherenceClass,
			absorptionLow01 = source.acoustic.absorptionLow01,
			absorptionMid01 = source.acoustic.absorptionMid01,
			absorptionHigh01 = source.acoustic.absorptionHigh01,
			impactFamilyKey = source.acoustic.impactFamilyKey,
			scrapeFamilyKey = source.acoustic.scrapeFamilyKey,
		}),
		response = table.freeze({
			wetFrictionMultiplier = source.response.wetFrictionMultiplier,
			wetDarkening01 = source.response.wetDarkening01,
			damageResistance01 = source.response.damageResistance01,
			stainAffinity01 = source.response.stainAffinity01,
		}),
		anomalyModifiers = freezeKeys(source.anomalyModifiers),
	}
	return table.freeze(recipe)
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

-- Bootstrap compatibility: validation remains assertion-style for already-typed callers.
function MaterialDNA.validate(value: unknown): ()
	MaterialDNA.assertValidRecipe(value)
end

return table.freeze(MaterialDNA)
