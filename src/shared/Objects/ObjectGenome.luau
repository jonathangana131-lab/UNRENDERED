--!strict

local SCHEMA_VERSION = 1
local ID_PREFIX = "og"
local MASS_TOLERANCE_RATIO = 0.02
local MASS_TOLERANCE_KG = 0.05
local BOUNDS_EPSILON_M = 0.05

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type DimensionsSpec = {
	sizeM: Vec3,
	plausibleMinM: Vec3,
	plausibleMaxM: Vec3,
}

export type ComponentSpec = {
	key: string,
	role: string,
	materialId: string,
	massKg: number,
	centerOfMassM: Vec3,
	supportKeys: { string },
	loadBearing: boolean,
}

export type MechanismKind = "hinge" | "slide" | "caster" | "tilt" | "latch"
export type MechanismUnit = "degrees" | "meters"

export type MechanismSpec = {
	key: string,
	kind: MechanismKind,
	anchorComponentKey: string,
	movingComponentKey: string,
	lowerLimit: number,
	upperLimit: number,
	unit: MechanismUnit,
	breakForceN: number?,
}

export type AffordanceKind = "grip" | "sit" | "push" | "pull" | "open" | "close" | "roll"

export type AffordanceRegion = {
	centerM: Vec3,
	halfExtentsM: Vec3,
}

export type AffordanceSpec = {
	key: string,
	kind: AffordanceKind,
	componentKey: string,
	region: AffordanceRegion,
	mechanismKey: string?,
}

export type ManufacturingIdentity = {
	manufacturerId: string,
	productLineId: string,
	apparentEra: string,
}

export type ObjectGenome = {
	id: string,
	schemaVersion: number,
	familyId: string,
	familyVersion: number,
	variantKey: string,
	manufacturing: ManufacturingIdentity,
	dimensions: DimensionsSpec,
	massKg: number,
	centerOfMassM: Vec3,
	components: { ComponentSpec },
	mechanisms: { MechanismSpec },
	affordances: { AffordanceSpec },
}

export type ObjectState = {
	wear01: number,
	damage01: number,
	detachedComponents: { [string]: boolean },
	mechanismPosition: { [string]: number },
}

export type ValidationIssue = {
	code: string,
	path: string,
	message: string,
}

local MECHANISM_UNITS: { [string]: MechanismUnit } = {
	hinge = "degrees",
	slide = "meters",
	caster = "degrees",
	tilt = "degrees",
	latch = "meters",
}

local AFFORDANCE_KINDS: { [string]: boolean } = {
	grip = true,
	sit = true,
	push = true,
	pull = true,
	open = true,
	close = true,
	roll = true,
}

local ObjectGenome = {
	SCHEMA_VERSION = SCHEMA_VERSION,
}

local function addIssue(issues: { ValidationIssue }, code: string, path: string, message: string)
	table.insert(issues, {
		code = code,
		path = path,
		message = message,
	})
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isPositiveInteger(value: number): boolean
	return isFinite(value) and value >= 1 and value % 1 == 0
end

local function isToken(value: string): boolean
	return string.match(value, "^[a-z0-9][a-z0-9_.-]*$") ~= nil
end

local function validateToken(issues: { ValidationIssue }, value: string, path: string)
	if value == "" then
		addIssue(issues, "required", path, "must not be empty")
	elseif not isToken(value) then
		addIssue(issues, "token", path, "must use lowercase a-z, 0-9, dot, underscore, or dash")
	end
end

local function validateFiniteVec3(issues: { ValidationIssue }, value: Vec3, path: string)
	if not isFinite(value.x) then
		addIssue(issues, "finite", path .. ".x", "must be finite")
	end
	if not isFinite(value.y) then
		addIssue(issues, "finite", path .. ".y", "must be finite")
	end
	if not isFinite(value.z) then
		addIssue(issues, "finite", path .. ".z", "must be finite")
	end
end

local function validatePositiveVec3(issues: { ValidationIssue }, value: Vec3, path: string)
	validateFiniteVec3(issues, value, path)
	if value.x <= 0 then
		addIssue(issues, "positive", path .. ".x", "must be positive")
	end
	if value.y <= 0 then
		addIssue(issues, "positive", path .. ".y", "must be positive")
	end
	if value.z <= 0 then
		addIssue(issues, "positive", path .. ".z", "must be positive")
	end
end

local function vecWithinBounds(point: Vec3, size: Vec3, epsilon: number): boolean
	return math.abs(point.x) <= size.x * 0.5 + epsilon
		and math.abs(point.y) <= size.y * 0.5 + epsilon
		and math.abs(point.z) <= size.z * 0.5 + epsilon
end

local function regionWithinBounds(region: AffordanceRegion, size: Vec3): boolean
	local maxX = math.abs(region.centerM.x) + region.halfExtentsM.x
	local maxY = math.abs(region.centerM.y) + region.halfExtentsM.y
	local maxZ = math.abs(region.centerM.z) + region.halfExtentsM.z
	return maxX <= size.x * 0.5 + BOUNDS_EPSILON_M
		and maxY <= size.y * 0.5 + BOUNDS_EPSILON_M
		and maxZ <= size.z * 0.5 + BOUNDS_EPSILON_M
end

local function mechanismLimitIsPlausible(mechanism: MechanismSpec): boolean
	if mechanism.unit == "meters" then
		return math.abs(mechanism.lowerLimit) <= 2 and math.abs(mechanism.upperLimit) <= 2
	end
	return math.abs(mechanism.lowerLimit) <= 360 and math.abs(mechanism.upperLimit) <= 360
end

function ObjectGenome.composeId(familyId: string, familyVersion: number, variantKey: string): string
	assert(isToken(familyId), "familyId must be a canonical token")
	assert(isPositiveInteger(familyVersion), "familyVersion must be a positive integer")
	assert(isToken(variantKey), "variantKey must be a canonical token")
	return string.format("%s:%s:v%d:%s", ID_PREFIX, familyId, familyVersion, variantKey)
end

function ObjectGenome.newState(): ObjectState
	return {
		wear01 = 0,
		damage01 = 0,
		detachedComponents = {},
		mechanismPosition = {},
	}
end

function ObjectGenome.validate(value: ObjectGenome): (boolean, { ValidationIssue })
	local issues: { ValidationIssue } = {}

	if value.schemaVersion ~= SCHEMA_VERSION then
		addIssue(
			issues,
			"schema_version",
			"schemaVersion",
			string.format("expected schema version %d", SCHEMA_VERSION)
		)
	end

	validateToken(issues, value.familyId, "familyId")
	if not isPositiveInteger(value.familyVersion) then
		addIssue(issues, "positive_integer", "familyVersion", "must be a positive integer")
	end
	validateToken(issues, value.variantKey, "variantKey")

	if isToken(value.familyId) and isPositiveInteger(value.familyVersion) and isToken(value.variantKey) then
		local expectedId = ObjectGenome.composeId(value.familyId, value.familyVersion, value.variantKey)
		if value.id ~= expectedId then
			addIssue(issues, "deterministic_id", "id", "must equal the canonical family/version/variant ID")
		end
	end

	validateToken(issues, value.manufacturing.manufacturerId, "manufacturing.manufacturerId")
	validateToken(issues, value.manufacturing.productLineId, "manufacturing.productLineId")
	if value.manufacturing.apparentEra == "" then
		addIssue(issues, "required", "manufacturing.apparentEra", "must not be empty")
	end

	validatePositiveVec3(issues, value.dimensions.sizeM, "dimensions.sizeM")
	validatePositiveVec3(issues, value.dimensions.plausibleMinM, "dimensions.plausibleMinM")
	validatePositiveVec3(issues, value.dimensions.plausibleMaxM, "dimensions.plausibleMaxM")

	local size = value.dimensions.sizeM
	local minSize = value.dimensions.plausibleMinM
	local maxSize = value.dimensions.plausibleMaxM
	if minSize.x > maxSize.x or minSize.y > maxSize.y or minSize.z > maxSize.z then
		addIssue(issues, "range", "dimensions", "plausible minimum must not exceed plausible maximum")
	end
	if
		size.x < minSize.x
		or size.x > maxSize.x
		or size.y < minSize.y
		or size.y > maxSize.y
		or size.z < minSize.z
		or size.z > maxSize.z
	then
		addIssue(issues, "plausibility", "dimensions.sizeM", "must be within the declared plausible range")
	end

	if not isFinite(value.massKg) or value.massKg <= 0 then
		addIssue(issues, "positive", "massKg", "must be a finite positive number")
	end
	validateFiniteVec3(issues, value.centerOfMassM, "centerOfMassM")
	if not vecWithinBounds(value.centerOfMassM, size, 0) then
		addIssue(issues, "bounds", "centerOfMassM", "must be inside the object bounds")
	end

	if #value.components == 0 then
		addIssue(issues, "required", "components", "at least one component is required")
	end

	local componentsByKey: { [string]: ComponentSpec } = {}
	local rootCount = 0
	local componentMassKg = 0
	for index, component in value.components do
		local path = string.format("components[%d]", index)
		validateToken(issues, component.key, path .. ".key")
		if componentsByKey[component.key] ~= nil then
			addIssue(issues, "duplicate", path .. ".key", "component keys must be unique")
		else
			componentsByKey[component.key] = component
		end
		if component.role == "" then
			addIssue(issues, "required", path .. ".role", "must not be empty")
		end
		if component.materialId == "" then
			addIssue(issues, "required", path .. ".materialId", "must reference a material domain ID")
		end
		if not isFinite(component.massKg) or component.massKg <= 0 then
			addIssue(issues, "positive", path .. ".massKg", "must be a finite positive number")
		else
			componentMassKg += component.massKg
		end
		validateFiniteVec3(issues, component.centerOfMassM, path .. ".centerOfMassM")
		if not vecWithinBounds(component.centerOfMassM, size, BOUNDS_EPSILON_M) then
			addIssue(issues, "bounds", path .. ".centerOfMassM", "must remain near the object bounds")
		end
		if #component.supportKeys == 0 then
			rootCount += 1
		end
	end

	if #value.components > 0 and rootCount == 0 then
		addIssue(issues, "support_root", "components", "support graph must contain at least one root component")
	end

	for index, component in value.components do
		local path = string.format("components[%d].supportKeys", index)
		local seenSupport: { [string]: boolean } = {}
		for supportIndex, supportKey in component.supportKeys do
			if supportKey == component.key then
				addIssue(issues, "self_support", path, "a component cannot support itself")
			elseif componentsByKey[supportKey] == nil then
				addIssue(
					issues,
					"missing_component",
					string.format("%s[%d]", path, supportIndex),
					"support component does not exist"
				)
			elseif seenSupport[supportKey] then
				addIssue(issues, "duplicate", path, "support keys must be unique per component")
			end
			seenSupport[supportKey] = true
		end
	end

	local visitState: { [string]: number } = {}
	local function visitComponent(key: string)
		local state = visitState[key]
		if state == 1 then
			addIssue(issues, "support_cycle", "components", "support graph must be acyclic")
			return
		elseif state == 2 then
			return
		end

		visitState[key] = 1
		local component = componentsByKey[key]
		if component ~= nil then
			for _, supportKey in component.supportKeys do
				if componentsByKey[supportKey] ~= nil then
					visitComponent(supportKey)
				end
			end
		end
		visitState[key] = 2
	end

	for key in componentsByKey do
		visitComponent(key)
	end

	if isFinite(value.massKg) and value.massKg > 0 then
		local tolerance = math.max(MASS_TOLERANCE_KG, value.massKg * MASS_TOLERANCE_RATIO)
		if math.abs(componentMassKg - value.massKg) > tolerance then
			addIssue(issues, "mass_balance", "components", "component masses must approximately sum to object mass")
		end
	end

	local mechanismsByKey: { [string]: MechanismSpec } = {}
	for index, mechanism in value.mechanisms do
		local path = string.format("mechanisms[%d]", index)
		validateToken(issues, mechanism.key, path .. ".key")
		if mechanismsByKey[mechanism.key] ~= nil then
			addIssue(issues, "duplicate", path .. ".key", "mechanism keys must be unique")
		else
			mechanismsByKey[mechanism.key] = mechanism
		end

		if componentsByKey[mechanism.anchorComponentKey] == nil then
			addIssue(issues, "missing_component", path .. ".anchorComponentKey", "anchor component does not exist")
		end
		if componentsByKey[mechanism.movingComponentKey] == nil then
			addIssue(issues, "missing_component", path .. ".movingComponentKey", "moving component does not exist")
		end
		if mechanism.anchorComponentKey == mechanism.movingComponentKey then
			addIssue(issues, "mechanism_pair", path, "anchor and moving component must differ")
		end

		if not isFinite(mechanism.lowerLimit) or not isFinite(mechanism.upperLimit) then
			addIssue(issues, "finite", path, "mechanism limits must be finite")
		elseif mechanism.lowerLimit > mechanism.upperLimit then
			addIssue(issues, "range", path, "lowerLimit must not exceed upperLimit")
		elseif not mechanismLimitIsPlausible(mechanism) then
			addIssue(issues, "plausibility", path, "mechanism travel exceeds the production contract bounds")
		end

		local expectedUnit = MECHANISM_UNITS[mechanism.kind]
		if expectedUnit == nil then
			addIssue(issues, "enum", path .. ".kind", "unsupported mechanism kind")
		elseif mechanism.unit ~= expectedUnit then
			addIssue(issues, "unit", path .. ".unit", "unit does not match mechanism kind")
		end
		if mechanism.breakForceN ~= nil and (not isFinite(mechanism.breakForceN) or mechanism.breakForceN <= 0) then
			addIssue(issues, "positive", path .. ".breakForceN", "must be positive when present")
		end
	end

	local affordanceKeys: { [string]: boolean } = {}
	for index, affordance in value.affordances do
		local path = string.format("affordances[%d]", index)
		validateToken(issues, affordance.key, path .. ".key")
		if affordanceKeys[affordance.key] then
			addIssue(issues, "duplicate", path .. ".key", "affordance keys must be unique")
		end
		affordanceKeys[affordance.key] = true

		if not AFFORDANCE_KINDS[affordance.kind] then
			addIssue(issues, "enum", path .. ".kind", "unsupported affordance kind")
		end
		if componentsByKey[affordance.componentKey] == nil then
			addIssue(issues, "missing_component", path .. ".componentKey", "affordance component does not exist")
		end
		if affordance.mechanismKey ~= nil and mechanismsByKey[affordance.mechanismKey] == nil then
			addIssue(issues, "missing_mechanism", path .. ".mechanismKey", "affordance mechanism does not exist")
		end

		validateFiniteVec3(issues, affordance.region.centerM, path .. ".region.centerM")
		validatePositiveVec3(issues, affordance.region.halfExtentsM, path .. ".region.halfExtentsM")
		if not regionWithinBounds(affordance.region, size) then
			addIssue(issues, "bounds", path .. ".region", "affordance region must remain near object bounds")
		end
	end

	return #issues == 0, issues
end

function ObjectGenome.validateState(genome: ObjectGenome, state: ObjectState): (boolean, { ValidationIssue })
	local issues: { ValidationIssue } = {}

	if not isFinite(state.wear01) or state.wear01 < 0 or state.wear01 > 1 then
		addIssue(issues, "unit_interval", "wear01", "must be in [0, 1]")
	end
	if not isFinite(state.damage01) or state.damage01 < 0 or state.damage01 > 1 then
		addIssue(issues, "unit_interval", "damage01", "must be in [0, 1]")
	end

	local componentsByKey: { [string]: boolean } = {}
	for _, component in genome.components do
		componentsByKey[component.key] = true
	end
	for componentKey in state.detachedComponents do
		if componentsByKey[componentKey] == nil then
			addIssue(issues, "missing_component", "detachedComponents." .. componentKey, "component does not exist")
		end
	end

	local mechanismsByKey: { [string]: MechanismSpec } = {}
	for _, mechanism in genome.mechanisms do
		mechanismsByKey[mechanism.key] = mechanism
	end
	for mechanismKey, position in state.mechanismPosition do
		local mechanism = mechanismsByKey[mechanismKey]
		if mechanism == nil then
			addIssue(issues, "missing_mechanism", "mechanismPosition." .. mechanismKey, "mechanism does not exist")
		elseif not isFinite(position) then
			addIssue(issues, "finite", "mechanismPosition." .. mechanismKey, "must be finite")
		elseif position < mechanism.lowerLimit or position > mechanism.upperLimit then
			addIssue(issues, "range", "mechanismPosition." .. mechanismKey, "must stay within mechanism limits")
		end
	end

	return #issues == 0, issues
end

function ObjectGenome.assertValid(value: ObjectGenome)
	local ok, issues = ObjectGenome.validate(value)
	if not ok then
		local messages = {}
		for _, issue in issues do
			table.insert(messages, string.format("%s (%s): %s", issue.path, issue.code, issue.message))
		end
		error("invalid ObjectGenome:\n- " .. table.concat(messages, "\n- "), 2)
	end
end

return table.freeze(ObjectGenome)
