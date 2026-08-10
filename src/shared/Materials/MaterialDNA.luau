--!strict

export type MaterialId = string

export type SubstrateLayer = {
	family: string,
	thicknessMm: number,
}

export type FinishLayer = {
	family: string,
	manufacturingProcess: string,
	roughness: number,
	porosity: number,
}

export type InstallationLayer = {
	method: string,
	batchKey: string,
	seamPeriodM: number?,
}

export type MaintenanceLayer = {
	care: number,
	cleaningFrequency: number,
	repairLevel: number,
}

export type EnvironmentLayer = {
	humidityExposure: number,
	uvExposure: number,
	contactExposure: number,
}

export type MaterialEvent = {
	kind: string,
	severity: number,
	ageYearsAgo: number,
}

export type MaterialResponse = {
	visualFamily: string,
	physicalClass: string,
	acousticClass: string,
}

export type MaterialDNA = {
	id: MaterialId,
	schemaVersion: number,
	substrate: SubstrateLayer,
	finish: FinishLayer,
	installation: InstallationLayer,
	apparentAgeYears: number,
	maintenance: MaintenanceLayer,
	environment: EnvironmentLayer,
	events: { MaterialEvent },
	response: MaterialResponse,
}

export type MaterialSurfaceState = {
	wetness: number,
	wear: number,
	damage: number,
	dirt: number,
	temperatureC: number?,
}

export type ValidationIssue = {
	path: string,
	code: string,
	message: string,
}

local SCHEMA_VERSION = 1

local MaterialDNA = {
	SchemaVersion = SCHEMA_VERSION,
}

local WALL_SUBSTRATES = table.freeze({
	gypsum_board = true,
	plaster = true,
	concrete = true,
})

local CARPET_SUBSTRATES = table.freeze({
	concrete = true,
	plywood = true,
	raised_floor = true,
})

local METAL_SUBSTRATES = table.freeze({
	steel = true,
	aluminum = true,
})

local CARPET_INSTALLATION = table.freeze({
	broadloom_adhesive = true,
	carpet_tile_adhesive = true,
})

local function addIssue(issues: { ValidationIssue }, path: string, code: string, message: string): ()
	table.insert(issues, {
		path = path,
		code = code,
		message = message,
	})
end

local function validateNonEmptyString(path: string, value: unknown, issues: { ValidationIssue }): string?
	if type(value) ~= "string" or value == "" then
		addIssue(issues, path, "required", `{path} must be a non-empty string`)
		return nil
	end
	return value
end

local function validateFiniteNumber(path: string, value: unknown, issues: { ValidationIssue }): number?
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		addIssue(issues, path, "invalid_number", `{path} must be a finite number`)
		return nil
	end
	return value
end

local function validateUnitInterval(path: string, value: unknown, issues: { ValidationIssue }): number?
	local numberValue = validateFiniteNumber(path, value, issues)
	if numberValue == nil then
		return nil
	end
	if numberValue < 0 or numberValue > 1 then
		addIssue(issues, path, "out_of_range", `{path} must be in [0, 1]`)
		return nil
	end
	return numberValue
end

local function validateNonNegative(path: string, value: unknown, issues: { ValidationIssue }): number?
	local numberValue = validateFiniteNumber(path, value, issues)
	if numberValue == nil then
		return nil
	end
	if numberValue < 0 then
		addIssue(issues, path, "out_of_range", `{path} must be >= 0`)
		return nil
	end
	return numberValue
end

local function validateTable(path: string, value: unknown, issues: { ValidationIssue }): any?
	if type(value) ~= "table" then
		addIssue(issues, path, "required", `{path} must be a table`)
		return nil
	end
	return value :: any
end

local function validateSubstrate(value: unknown, issues: { ValidationIssue }): ()
	local substrate = validateTable("substrate", value, issues)
	if substrate == nil then
		return
	end

	validateNonEmptyString("substrate.family", substrate.family, issues)
	local thicknessMm = validateFiniteNumber("substrate.thicknessMm", substrate.thicknessMm, issues)
	if thicknessMm ~= nil and (thicknessMm <= 0 or thicknessMm > 1000) then
		addIssue(
			issues,
			"substrate.thicknessMm",
			"out_of_range",
			"substrate.thicknessMm must be > 0 and <= 1000"
		)
	end
end

local function validateFinish(value: unknown, issues: { ValidationIssue }): ()
	local finish = validateTable("finish", value, issues)
	if finish == nil then
		return
	end

	validateNonEmptyString("finish.family", finish.family, issues)
	validateNonEmptyString("finish.manufacturingProcess", finish.manufacturingProcess, issues)
	validateUnitInterval("finish.roughness", finish.roughness, issues)
	validateUnitInterval("finish.porosity", finish.porosity, issues)
end

local function validateInstallation(value: unknown, issues: { ValidationIssue }): ()
	local installation = validateTable("installation", value, issues)
	if installation == nil then
		return
	end

	validateNonEmptyString("installation.method", installation.method, issues)
	validateNonEmptyString("installation.batchKey", installation.batchKey, issues)
	if installation.seamPeriodM ~= nil then
		local seamPeriodM = validateFiniteNumber("installation.seamPeriodM", installation.seamPeriodM, issues)
		if seamPeriodM ~= nil and (seamPeriodM <= 0 or seamPeriodM > 100) then
			addIssue(
				issues,
				"installation.seamPeriodM",
				"out_of_range",
				"installation.seamPeriodM must be > 0 and <= 100"
			)
		end
	end
end

local function validateMaintenance(value: unknown, issues: { ValidationIssue }): ()
	local maintenance = validateTable("maintenance", value, issues)
	if maintenance == nil then
		return
	end

	validateUnitInterval("maintenance.care", maintenance.care, issues)
	validateUnitInterval("maintenance.cleaningFrequency", maintenance.cleaningFrequency, issues)
	validateUnitInterval("maintenance.repairLevel", maintenance.repairLevel, issues)
end

local function validateEnvironment(value: unknown, issues: { ValidationIssue }): ()
	local environment = validateTable("environment", value, issues)
	if environment == nil then
		return
	end

	validateUnitInterval("environment.humidityExposure", environment.humidityExposure, issues)
	validateUnitInterval("environment.uvExposure", environment.uvExposure, issues)
	validateUnitInterval("environment.contactExposure", environment.contactExposure, issues)
end

local function containsRawAssetId(value: string): boolean
	local lower = string.lower(value)
	return string.find(lower, "rbxassetid://", 1, true) ~= nil or string.match(value, "^%d+$") ~= nil
end

local function validateResponse(value: unknown, issues: { ValidationIssue }): ()
	local response = validateTable("response", value, issues)
	if response == nil then
		return
	end

	local visualFamily = validateNonEmptyString("response.visualFamily", response.visualFamily, issues)
	validateNonEmptyString("response.physicalClass", response.physicalClass, issues)
	validateNonEmptyString("response.acousticClass", response.acousticClass, issues)

	if visualFamily ~= nil and containsRawAssetId(visualFamily) then
		addIssue(
			issues,
			"response.visualFamily",
			"raw_asset_id",
			"response.visualFamily must be a project-owned family key, not a Roblox asset ID"
		)
	end
end

local function validateEvents(value: unknown, apparentAgeYears: number?, issues: { ValidationIssue }): ()
	local events = validateTable("events", value, issues)
	if events == nil then
		return
	end

	for index, eventValue in ipairs(events) do
		local path = `events[{index}]`
		local event = validateTable(path, eventValue, issues)
		if event ~= nil then
			validateNonEmptyString(path .. ".kind", event.kind, issues)
			validateUnitInterval(path .. ".severity", event.severity, issues)
			local ageYearsAgo = validateNonNegative(path .. ".ageYearsAgo", event.ageYearsAgo, issues)
			if ageYearsAgo ~= nil and apparentAgeYears ~= nil and ageYearsAgo > apparentAgeYears then
				addIssue(
					issues,
					path .. ".ageYearsAgo",
					"event_before_material",
					"material event cannot predate the material's apparent age"
				)
			end
		end
	end
end

local function validateCompatibility(recipe: any, issues: { ValidationIssue }): ()
	local substrateFamily = if type(recipe.substrate) == "table" then recipe.substrate.family else nil
	local finishFamily = if type(recipe.finish) == "table" then recipe.finish.family else nil
	local installationMethod = if type(recipe.installation) == "table"
		then recipe.installation.method
		else nil

	if finishFamily == "vinyl_wallcovering" then
		if type(substrateFamily) == "string" and not WALL_SUBSTRATES[substrateFamily] then
			addIssue(
				issues,
				"finish.family",
				"finish_substrate_mismatch",
				"vinyl wallcovering requires a wall-compatible substrate"
			)
		end
		if type(installationMethod) == "string" and installationMethod ~= "wallcovering_adhesive" then
			addIssue(
				issues,
				"installation.method",
				"finish_installation_mismatch",
				"vinyl wallcovering requires wallcovering_adhesive installation"
			)
		end
	elseif finishFamily == "low_pile_carpet" then
		if type(substrateFamily) == "string" and not CARPET_SUBSTRATES[substrateFamily] then
			addIssue(
				issues,
				"finish.family",
				"finish_substrate_mismatch",
				"low-pile carpet requires a floor-compatible substrate"
			)
		end
		if type(installationMethod) == "string" and not CARPET_INSTALLATION[installationMethod] then
			addIssue(
				issues,
				"installation.method",
				"finish_installation_mismatch",
				"low-pile carpet requires a supported carpet installation method"
			)
		end
	elseif finishFamily == "painted_metal" then
		if type(substrateFamily) == "string" and not METAL_SUBSTRATES[substrateFamily] then
			addIssue(
				issues,
				"finish.family",
				"finish_substrate_mismatch",
				"painted metal requires a metal substrate"
			)
		end
	end
end

function MaterialDNA.validateRecipe(value: unknown): { ValidationIssue }
	local issues: { ValidationIssue } = {}
	local recipe = validateTable("MaterialDNA", value, issues)
	if recipe == nil then
		return issues
	end

	local id = validateNonEmptyString("id", recipe.id, issues)
	if id ~= nil and string.match(id, "^[%w_.-]+:[%w_.-]+$") == nil then
		addIssue(issues, "id", "invalid_id", "id must use a stable namespace:value key")
	end

	local schemaVersion = validateFiniteNumber("schemaVersion", recipe.schemaVersion, issues)
	if schemaVersion ~= nil then
		if schemaVersion < 1 or schemaVersion % 1 ~= 0 then
			addIssue(issues, "schemaVersion", "invalid_version", "schemaVersion must be a positive integer")
		elseif schemaVersion ~= SCHEMA_VERSION then
			addIssue(
				issues,
				"schemaVersion",
				"unsupported_version",
				`schemaVersion {schemaVersion} is unsupported; expected {SCHEMA_VERSION}`
			)
		end
	end

	validateSubstrate(recipe.substrate, issues)
	validateFinish(recipe.finish, issues)
	validateInstallation(recipe.installation, issues)
	local apparentAgeYears = validateNonNegative("apparentAgeYears", recipe.apparentAgeYears, issues)
	validateMaintenance(recipe.maintenance, issues)
	validateEnvironment(recipe.environment, issues)
	validateEvents(recipe.events, apparentAgeYears, issues)
	validateResponse(recipe.response, issues)
	validateCompatibility(recipe, issues)

	return issues
end

function MaterialDNA.isValidRecipe(value: unknown): boolean
	return #MaterialDNA.validateRecipe(value) == 0
end

local function formatIssues(issues: { ValidationIssue }): string
	local messages = table.create(#issues)
	for index, issue in ipairs(issues) do
		messages[index] = `{issue.path} [{issue.code}]: {issue.message}`
	end
	return table.concat(messages, "; ")
end

function MaterialDNA.assertValidRecipe(value: unknown): MaterialDNA
	local issues = MaterialDNA.validateRecipe(value)
	assert(#issues == 0, "Invalid MaterialDNA: " .. formatIssues(issues))
	return value :: MaterialDNA
end

function MaterialDNA.validateSurfaceState(value: unknown): { ValidationIssue }
	local issues: { ValidationIssue } = {}
	local state = validateTable("MaterialSurfaceState", value, issues)
	if state == nil then
		return issues
	end

	validateUnitInterval("wetness", state.wetness, issues)
	validateUnitInterval("wear", state.wear, issues)
	validateUnitInterval("damage", state.damage, issues)
	validateUnitInterval("dirt", state.dirt, issues)

	if state.temperatureC ~= nil then
		local temperatureC = validateFiniteNumber("temperatureC", state.temperatureC, issues)
		if temperatureC ~= nil and (temperatureC < -100 or temperatureC > 200) then
			addIssue(issues, "temperatureC", "out_of_range", "temperatureC must be in [-100, 200]")
		end
	end

	return issues
end

function MaterialDNA.assertValidSurfaceState(value: unknown): MaterialSurfaceState
	local issues = MaterialDNA.validateSurfaceState(value)
	assert(#issues == 0, "Invalid MaterialSurfaceState: " .. formatIssues(issues))
	return value :: MaterialSurfaceState
end

return table.freeze(MaterialDNA)
