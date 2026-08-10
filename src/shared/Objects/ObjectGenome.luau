--!strict

local StableId = require(script.Parent.Parent.Core.StableId)

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type NumberRange = {
	min: number,
	max: number,
}

export type DimensionLimits = {
	minM: Vec3,
	maxM: Vec3,
}

export type ExternalSupport = "none" | "ground" | "wall" | "ceiling"

export type ComponentSpec = {
	key: string,
	role: string,
	materialKey: string,
	materialRecipeVersion: number,
	massKg: number,
	localPositionM: Vec3,
	localRotationDeg: Vec3,
	dimensionsM: Vec3,
	supportKeys: { string },
	externalSupport: ExternalSupport,
}

export type HingeMechanism = {
	key: string,
	kind: "hinge",
	movingComponentKey: string,
	frameComponentKey: string,
	axis: Vec3,
	minDegrees: number,
	maxDegrees: number,
}

export type SlideMechanism = {
	key: string,
	kind: "slide",
	movingComponentKey: string,
	frameComponentKey: string,
	axis: Vec3,
	minTravelM: number,
	maxTravelM: number,
}

export type CasterMechanism = {
	key: string,
	kind: "caster",
	movingComponentKey: string,
	frameComponentKey: string,
	wheelRadiusM: number,
	swivelAxis: Vec3,
	rollAxis: Vec3,
}

export type TiltMechanism = {
	key: string,
	kind: "tilt",
	movingComponentKey: string,
	frameComponentKey: string,
	axis: Vec3,
	minDegrees: number,
	maxDegrees: number,
}

export type LatchMechanism = {
	key: string,
	kind: "latch",
	movingComponentKey: string,
	catchComponentKey: string,
	engagementDistanceM: number,
}

export type MechanismSpec = HingeMechanism | SlideMechanism | CasterMechanism | TiltMechanism | LatchMechanism

export type AffordanceKind = "grip" | "push" | "pull" | "sit" | "open" | "close"

export type AffordanceSpec = {
	key: string,
	kind: AffordanceKind,
	componentKey: string,
	localPointM: Vec3,
	radiusM: number,
}

export type Provenance = {
	manufacturerFamily: string,
	productLine: string,
	apparentEra: string,
}

export type ObjectGenome = {
	schemaVersion: number,
	familyId: string,
	familyVersion: number,
	variantKey: string,
	provenance: Provenance,
	dimensionsM: Vec3,
	dimensionLimits: DimensionLimits,
	massKg: number,
	massLimitsKg: NumberRange,
	centerOfMassM: Vec3,
	components: { ComponentSpec },
	mechanisms: { MechanismSpec },
	affordances: { AffordanceSpec },
}

export type ObjectState = {
	stateSchemaVersion: number,
	genomeId: string,
	componentWear: { [string]: number },
	componentDamage: { [string]: number },
	mechanismPosition: { [string]: number },
	detachedComponents: { [string]: boolean },
}

export type ValidationIssue = {
	code: string,
	path: string,
	message: string,
}

export type ValidationResult = {
	ok: boolean,
	issues: { ValidationIssue },
}

local ObjectGenome = {}

ObjectGenome.SCHEMA_VERSION = 1
ObjectGenome.STATE_SCHEMA_VERSION = 1
ObjectGenome.STABLE_ID_NAMESPACE = "object-genome"
ObjectGenome.LOCAL_ROTATION_ORDER = "XYZ"
ObjectGenome.LOCAL_ROTATION_HANDEDNESS = "right"

local MASS_TOLERANCE_FRACTION = 0.05
local BOUNDS_TOLERANCE_M = 0.005
local AXIS_UNIT_TOLERANCE = 0.0001
local ROTATION_LIMIT_DEG = 180

local AFFORDANCE_KINDS = {
	grip = true,
	push = true,
	pull = true,
	sit = true,
	open = true,
	close = true,
}

local EXTERNAL_SUPPORTS = {
	none = true,
	ground = true,
	wall = true,
	ceiling = true,
}

local MECHANISM_KINDS = {
	hinge = true,
	slide = true,
	caster = true,
	tilt = true,
	latch = true,
}

local GENOME_FIELDS = {
	schemaVersion = true,
	familyId = true,
	familyVersion = true,
	variantKey = true,
	provenance = true,
	dimensionsM = true,
	dimensionLimits = true,
	massKg = true,
	massLimitsKg = true,
	centerOfMassM = true,
	components = true,
	mechanisms = true,
	affordances = true,
}

local PROVENANCE_FIELDS = {
	manufacturerFamily = true,
	productLine = true,
	apparentEra = true,
}

local VEC3_FIELDS = {
	x = true,
	y = true,
	z = true,
}

local RANGE_FIELDS = {
	min = true,
	max = true,
}

local DIMENSION_LIMIT_FIELDS = {
	minM = true,
	maxM = true,
}

local COMPONENT_FIELDS = {
	key = true,
	role = true,
	materialKey = true,
	materialRecipeVersion = true,
	massKg = true,
	localPositionM = true,
	localRotationDeg = true,
	dimensionsM = true,
	supportKeys = true,
	externalSupport = true,
}

local HINGE_FIELDS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minDegrees = true,
	maxDegrees = true,
}

local SLIDE_FIELDS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minTravelM = true,
	maxTravelM = true,
}

local CASTER_FIELDS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	wheelRadiusM = true,
	swivelAxis = true,
	rollAxis = true,
}

local TILT_FIELDS = HINGE_FIELDS

local LATCH_FIELDS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	catchComponentKey = true,
	engagementDistanceM = true,
}

local MECHANISM_FIELDS_BY_KIND = {
	hinge = HINGE_FIELDS,
	slide = SLIDE_FIELDS,
	caster = CASTER_FIELDS,
	tilt = TILT_FIELDS,
	latch = LATCH_FIELDS,
}

local AFFORDANCE_FIELDS = {
	key = true,
	kind = true,
	componentKey = true,
	localPointM = true,
	radiusM = true,
}

local STATE_FIELDS = {
	stateSchemaVersion = true,
	genomeId = true,
	componentWear = true,
	componentDamage = true,
	mechanismPosition = true,
	detachedComponents = true,
}

local function addIssue(issues: { ValidationIssue }, code: string, path: string, message: string): ()
	table.insert(issues, {
		code = code,
		path = path,
		message = message,
	})
end

local function safeKeyLabel(key: any): string
	local keyType = type(key)
	if keyType == "string" then
		return key
	elseif keyType == "number" or keyType == "boolean" then
		return tostring(key)
	end
	return `<{keyType}>`
end

local function rejectMetatable(issues: { ValidationIssue }, path: string, value: any): boolean
	if type(value) == "table" and getmetatable(value) ~= nil then
		addIssue(issues, "schema.metatable", path, "canonical plain-data tables must not have metatables")
		return true
	end
	return false
end

local function validatePlainGenomeTables(issues: { ValidationIssue }, value: any): boolean
	local valid = true

	local function check(path: string, candidate: any): boolean
		if rejectMetatable(issues, path, candidate) then
			valid = false
			return false
		end
		return true
	end

	if not check("$", value) then
		return false
	end

	check("provenance", rawget(value, "provenance"))
	check("dimensionsM", rawget(value, "dimensionsM"))

	local dimensionLimits = rawget(value, "dimensionLimits")
	if check("dimensionLimits", dimensionLimits) and type(dimensionLimits) == "table" then
		check("dimensionLimits.minM", rawget(dimensionLimits, "minM"))
		check("dimensionLimits.maxM", rawget(dimensionLimits, "maxM"))
	end

	check("massLimitsKg", rawget(value, "massLimitsKg"))
	check("centerOfMassM", rawget(value, "centerOfMassM"))

	local components = rawget(value, "components")
	if check("components", components) and type(components) == "table" then
		for index, component in next, components do
			if type(index) == "number" and type(component) == "table" then
				local componentPath = `components[{index}]`
				if check(componentPath, component) then
					check(componentPath .. ".localPositionM", rawget(component, "localPositionM"))
					check(componentPath .. ".localRotationDeg", rawget(component, "localRotationDeg"))
					check(componentPath .. ".dimensionsM", rawget(component, "dimensionsM"))
					check(componentPath .. ".supportKeys", rawget(component, "supportKeys"))
				end
			end
		end
	end

	local mechanisms = rawget(value, "mechanisms")
	if check("mechanisms", mechanisms) and type(mechanisms) == "table" then
		for index, mechanism in next, mechanisms do
			if type(index) == "number" and type(mechanism) == "table" then
				local mechanismPath = `mechanisms[{index}]`
				if check(mechanismPath, mechanism) then
					local kind = rawget(mechanism, "kind")
					if kind == "hinge" or kind == "slide" or kind == "tilt" then
						check(mechanismPath .. ".axis", rawget(mechanism, "axis"))
					elseif kind == "caster" then
						check(mechanismPath .. ".swivelAxis", rawget(mechanism, "swivelAxis"))
						check(mechanismPath .. ".rollAxis", rawget(mechanism, "rollAxis"))
					end
				end
			end
		end
	end

	local affordances = rawget(value, "affordances")
	if check("affordances", affordances) and type(affordances) == "table" then
		for index, affordance in next, affordances do
			if type(index) == "number" and type(affordance) == "table" then
				local affordancePath = `affordances[{index}]`
				if check(affordancePath, affordance) then
					check(affordancePath .. ".localPointM", rawget(affordance, "localPointM"))
				end
			end
		end
	end

	return valid
end

local function validateRecordShape(
	issues: { ValidationIssue },
	path: string,
	value: any,
	allowedFields: { [string]: boolean }
): ()
	if type(value) ~= "table" then
		return
	end

	for key in pairs(value) do
		if type(key) ~= "string" or not allowedFields[key] then
			local childPath = if path == "$" then `$.{safeKeyLabel(key)}` else `{path}.{safeKeyLabel(key)}`
			addIssue(
				issues,
				"schema.unknown_field",
				childPath,
				"field is not declared by ObjectGenome schema v1"
			)
		end
	end
end

local function validateGenomeShape(issues: { ValidationIssue }, value: any): ()
	validateRecordShape(issues, "$", value, GENOME_FIELDS)
	validateRecordShape(issues, "provenance", value.provenance, PROVENANCE_FIELDS)
	validateRecordShape(issues, "dimensionsM", value.dimensionsM, VEC3_FIELDS)
	validateRecordShape(issues, "dimensionLimits", value.dimensionLimits, DIMENSION_LIMIT_FIELDS)
	if type(value.dimensionLimits) == "table" then
		validateRecordShape(issues, "dimensionLimits.minM", value.dimensionLimits.minM, VEC3_FIELDS)
		validateRecordShape(issues, "dimensionLimits.maxM", value.dimensionLimits.maxM, VEC3_FIELDS)
	end
	validateRecordShape(issues, "massLimitsKg", value.massLimitsKg, RANGE_FIELDS)
	validateRecordShape(issues, "centerOfMassM", value.centerOfMassM, VEC3_FIELDS)

	if type(value.components) == "table" then
		for index, component in pairs(value.components) do
			if type(index) == "number" and type(component) == "table" then
				local path = `components[{index}]`
				validateRecordShape(issues, path, component, COMPONENT_FIELDS)
				validateRecordShape(issues, path .. ".localPositionM", component.localPositionM, VEC3_FIELDS)
				validateRecordShape(
					issues,
					path .. ".localRotationDeg",
					component.localRotationDeg,
					VEC3_FIELDS
				)
				validateRecordShape(issues, path .. ".dimensionsM", component.dimensionsM, VEC3_FIELDS)
			end
		end
	end

	if type(value.mechanisms) == "table" then
		for index, mechanism in pairs(value.mechanisms) do
			if type(index) == "number" and type(mechanism) == "table" then
				local path = `mechanisms[{index}]`
				local allowedFields = MECHANISM_FIELDS_BY_KIND[mechanism.kind]
				if allowedFields ~= nil then
					validateRecordShape(issues, path, mechanism, allowedFields)
				end
				if mechanism.kind == "hinge" or mechanism.kind == "slide" or mechanism.kind == "tilt" then
					validateRecordShape(issues, path .. ".axis", mechanism.axis, VEC3_FIELDS)
				elseif mechanism.kind == "caster" then
					validateRecordShape(issues, path .. ".swivelAxis", mechanism.swivelAxis, VEC3_FIELDS)
					validateRecordShape(issues, path .. ".rollAxis", mechanism.rollAxis, VEC3_FIELDS)
				end
			end
		end
	end

	if type(value.affordances) == "table" then
		for index, affordance in pairs(value.affordances) do
			if type(index) == "number" and type(affordance) == "table" then
				local path = `affordances[{index}]`
				validateRecordShape(issues, path, affordance, AFFORDANCE_FIELDS)
				validateRecordShape(issues, path .. ".localPointM", affordance.localPointM, VEC3_FIELDS)
			end
		end
	end
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isPositiveFinite(value: any): boolean
	return isFinite(value) and value > 0
end

local function isUnitInterval(value: any): boolean
	return isFinite(value) and value >= 0 and value <= 1
end

local function isPositiveInteger(value: any): boolean
	return isPositiveFinite(value) and value % 1 == 0
end

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

local function isSemanticKey(value: any): boolean
	return type(value) == "string" and string.match(value, "^[a-z0-9][a-z0-9._-]*$") ~= nil
end

local function isVec3(value: any): boolean
	return type(value) == "table" and isFinite(value.x) and isFinite(value.y) and isFinite(value.z)
end

local function isPositiveVec3(value: any): boolean
	return isVec3(value) and value.x > 0 and value.y > 0 and value.z > 0
end

local function vectorMagnitude(value: any): number
	return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
end

local function validateDenseArray(issues: { ValidationIssue }, path: string, value: any): (boolean, number)
	if type(value) ~= "table" then
		addIssue(issues, "array.shape", path, "collection must be a dense 1-based array")
		return false, 0
	end

	local numericKeyCount = 0
	local maxIndex = 0
	local validShape = true
	for key in pairs(value) do
		if type(key) ~= "number" or not isPositiveInteger(key) then
			validShape = false
		else
			numericKeyCount += 1
			maxIndex = math.max(maxIndex, key)
		end
	end

	if validShape and numericKeyCount ~= maxIndex then
		validShape = false
	end

	if not validShape then
		addIssue(issues, "array.shape", path, "collection must contain only contiguous 1-based integer keys")
		return false, 0
	end

	return true, maxIndex
end

local function validateAxis(issues: { ValidationIssue }, path: string, value: any): ()
	if not isVec3(value) then
		addIssue(issues, "mechanism.axis", path, "axis must be a finite plain-data Vec3")
		return
	end

	local magnitude = vectorMagnitude(value)
	if magnitude <= 0.000001 then
		addIssue(issues, "mechanism.axis", path, "axis must be non-zero")
	elseif math.abs(magnitude - 1) > AXIS_UNIT_TOLERANCE then
		addIssue(
			issues,
			"mechanism.axis_unit",
			path,
			`axis must be unit length within {AXIS_UNIT_TOLERANCE}; got magnitude {magnitude}`
		)
	end
end

local function validateRange(issues: { ValidationIssue }, path: string, value: any, positiveOnly: boolean): ()
	if type(value) ~= "table" or not isFinite(value.min) or not isFinite(value.max) then
		addIssue(issues, "range.invalid", path, "range requires finite min/max")
		return
	end
	if positiveOnly and value.min <= 0 then
		addIssue(issues, "range.invalid", path, "range minimum must be positive")
	end
	if value.min > value.max then
		addIssue(issues, "range.invalid", path, "range minimum must not exceed maximum")
	end
end

local function validateDimensionLimits(issues: { ValidationIssue }, value: any): ()
	if type(value) ~= "table" or not isPositiveVec3(value.minM) or not isPositiveVec3(value.maxM) then
		addIssue(
			issues,
			"dimensions.limits",
			"dimensionLimits",
			"dimensionLimits requires positive finite minM/maxM vectors"
		)
		return
	end
	if value.minM.x > value.maxM.x or value.minM.y > value.maxM.y or value.minM.z > value.maxM.z then
		addIssue(
			issues,
			"dimensions.limits",
			"dimensionLimits",
			"dimension minimums must not exceed maximums"
		)
	end
end

local function validateLocalRotation(issues: { ValidationIssue }, path: string, value: any): boolean
	if not isVec3(value) then
		addIssue(issues, "component.rotation", path, "localRotationDeg must be a finite Vec3")
		return false
	end

	if
		math.abs(value.x) > ROTATION_LIMIT_DEG
		or math.abs(value.y) > ROTATION_LIMIT_DEG
		or math.abs(value.z) > ROTATION_LIMIT_DEG
	then
		addIssue(
			issues,
			"component.rotation_range",
			path,
			`v1 local rotation components must be bounded degrees in [-{ROTATION_LIMIT_DEG}, {ROTATION_LIMIT_DEG}]`
		)
		return false
	end

	return true
end

local function rotatedHalfExtents(dimensions: Vec3, rotationDeg: Vec3): Vec3
	-- V1 uses right-handed fixed-axis rotations around the object-local +X, then +Y, then +Z basis axes.
	-- For column vectors this is Rz * Ry * Rx. Absolute matrix coefficients produce
	-- the axis-aligned half extents required for envelope validation without Roblox CFrame.
	local x = math.rad(rotationDeg.x)
	local y = math.rad(rotationDeg.y)
	local z = math.rad(rotationDeg.z)
	local sx, cx = math.sin(x), math.cos(x)
	local sy, cy = math.sin(y), math.cos(y)
	local sz, cz = math.sin(z), math.cos(z)

	local r11 = cz * cy
	local r12 = cz * sy * sx - sz * cx
	local r13 = cz * sy * cx + sz * sx
	local r21 = sz * cy
	local r22 = sz * sy * sx + cz * cx
	local r23 = sz * sy * cx - cz * sx
	local r31 = -sy
	local r32 = cy * sx
	local r33 = cy * cx

	local hx = dimensions.x * 0.5
	local hy = dimensions.y * 0.5
	local hz = dimensions.z * 0.5

	return {
		x = math.abs(r11) * hx + math.abs(r12) * hy + math.abs(r13) * hz,
		y = math.abs(r21) * hx + math.abs(r22) * hy + math.abs(r23) * hz,
		z = math.abs(r31) * hx + math.abs(r32) * hy + math.abs(r33) * hz,
	}
end

local function componentFitsEnvelope(component: any, envelope: any): boolean
	if
		not isVec3(component.localPositionM)
		or not isVec3(component.localRotationDeg)
		or not isPositiveVec3(component.dimensionsM)
		or not isPositiveVec3(envelope)
	then
		return true
	end

	local rotatedHalf = rotatedHalfExtents(component.dimensionsM, component.localRotationDeg)
	local halfEnvelopeX = envelope.x * 0.5 + BOUNDS_TOLERANCE_M
	local halfEnvelopeY = envelope.y * 0.5 + BOUNDS_TOLERANCE_M
	local halfEnvelopeZ = envelope.z * 0.5 + BOUNDS_TOLERANCE_M

	return math.abs(component.localPositionM.x) + rotatedHalf.x <= halfEnvelopeX
		and math.abs(component.localPositionM.y) + rotatedHalf.y <= halfEnvelopeY
		and math.abs(component.localPositionM.z) + rotatedHalf.z <= halfEnvelopeZ
end

local function reportResult(issues: { ValidationIssue }): ValidationResult
	return {
		ok = #issues == 0,
		issues = issues,
	}
end

local function formatIssues(issues: { ValidationIssue }): string
	local messages = table.create(#issues)
	for index, issue in ipairs(issues) do
		messages[index] = `{issue.code} at {issue.path}: {issue.message}`
	end
	return table.concat(messages, "; ")
end

function ObjectGenome.identityParts(value: ObjectGenome): { string }
	return {
		tostring(value.schemaVersion),
		value.familyId,
		tostring(value.familyVersion),
		value.variantKey,
	}
end

function ObjectGenome.identityKey(value: ObjectGenome): string
	ObjectGenome.validate(value)
	return StableId.fromParts(ObjectGenome.STABLE_ID_NAMESPACE, ObjectGenome.identityParts(value))
end

function ObjectGenome.inspect(value: any): ValidationResult
	local issues: { ValidationIssue } = {}

	if type(value) ~= "table" then
		addIssue(issues, "genome.type", "$", "ObjectGenome must be a plain table")
		return reportResult(issues)
	end

	if not validatePlainGenomeTables(issues, value) then
		return reportResult(issues)
	end

	validateGenomeShape(issues, value)

	if value.schemaVersion ~= ObjectGenome.SCHEMA_VERSION then
		addIssue(
			issues,
			"genome.schema_version",
			"schemaVersion",
			`unsupported ObjectGenome schema version; expected {ObjectGenome.SCHEMA_VERSION}`
		)
	end
	if not isSemanticKey(value.familyId) then
		addIssue(issues, "genome.family_id", "familyId", "familyId must be a stable lowercase semantic key")
	end
	if not isPositiveInteger(value.familyVersion) then
		addIssue(issues, "genome.family_version", "familyVersion", "familyVersion must be a positive integer")
	end
	if not isSemanticKey(value.variantKey) then
		addIssue(
			issues,
			"genome.variant_key",
			"variantKey",
			"variantKey must be a stable lowercase semantic key"
		)
	end

	if type(value.provenance) ~= "table" then
		addIssue(issues, "provenance.required", "provenance", "provenance is required")
	else
		if not isNonEmptyString(value.provenance.manufacturerFamily) then
			addIssue(
				issues,
				"provenance.manufacturer",
				"provenance.manufacturerFamily",
				"manufacturerFamily required"
			)
		end
		if not isNonEmptyString(value.provenance.productLine) then
			addIssue(issues, "provenance.product_line", "provenance.productLine", "productLine required")
		end
		if not isNonEmptyString(value.provenance.apparentEra) then
			addIssue(issues, "provenance.apparent_era", "provenance.apparentEra", "apparentEra required")
		end
	end

	if not isPositiveVec3(value.dimensionsM) then
		addIssue(issues, "dimensions.invalid", "dimensionsM", "dimensionsM must be positive finite meters")
	end
	validateDimensionLimits(issues, value.dimensionLimits)
	if
		isPositiveVec3(value.dimensionsM)
		and type(value.dimensionLimits) == "table"
		and isPositiveVec3(value.dimensionLimits.minM)
		and isPositiveVec3(value.dimensionLimits.maxM)
	then
		local dimensions = value.dimensionsM
		local minimum = value.dimensionLimits.minM
		local maximum = value.dimensionLimits.maxM
		if
			dimensions.x < minimum.x
			or dimensions.x > maximum.x
			or dimensions.y < minimum.y
			or dimensions.y > maximum.y
			or dimensions.z < minimum.z
			or dimensions.z > maximum.z
		then
			addIssue(
				issues,
				"dimensions.out_of_family_range",
				"dimensionsM",
				"chosen dimensions fall outside family limits"
			)
		end
	end

	if not isPositiveFinite(value.massKg) then
		addIssue(issues, "mass.invalid", "massKg", "massKg must be positive finite kilograms")
	end
	validateRange(issues, "massLimitsKg", value.massLimitsKg, true)
	if
		isPositiveFinite(value.massKg)
		and type(value.massLimitsKg) == "table"
		and isFinite(value.massLimitsKg.min)
		and isFinite(value.massLimitsKg.max)
		and (value.massKg < value.massLimitsKg.min or value.massKg > value.massLimitsKg.max)
	then
		addIssue(issues, "mass.out_of_family_range", "massKg", "massKg falls outside family limits")
	end

	if not isVec3(value.centerOfMassM) then
		addIssue(
			issues,
			"mass.center_of_mass",
			"centerOfMassM",
			"centerOfMassM must be a finite plain-data Vec3"
		)
	elseif isPositiveVec3(value.dimensionsM) then
		if
			math.abs(value.centerOfMassM.x) > value.dimensionsM.x * 0.5
			or math.abs(value.centerOfMassM.y) > value.dimensionsM.y * 0.5
			or math.abs(value.centerOfMassM.z) > value.dimensionsM.z * 0.5
		then
			addIssue(
				issues,
				"mass.center_of_mass",
				"centerOfMassM",
				"center of mass must lie inside the object envelope"
			)
		end
	end

	local componentsDense, componentCount = validateDenseArray(issues, "components", value.components)
	if not componentsDense or componentCount == 0 then
		if componentCount == 0 then
			addIssue(issues, "component.required", "components", "at least one component is required")
		end
		return reportResult(issues)
	end

	local componentsByKey: { [string]: any } = {}
	local supportArraysValid: { [number]: boolean } = {}
	local componentMassKg = 0
	for index, component in ipairs(value.components) do
		local path = `components[{index}]`
		if type(component) ~= "table" then
			addIssue(issues, "component.type", path, "component must be a table")
			continue
		end

		if not isSemanticKey(component.key) then
			addIssue(
				issues,
				"component.key",
				path .. ".key",
				"component key must be a stable lowercase semantic key"
			)
		elseif componentsByKey[component.key] ~= nil then
			addIssue(
				issues,
				"component.duplicate_key",
				path .. ".key",
				`duplicate component key {component.key}`
			)
		else
			componentsByKey[component.key] = component
		end

		if not isNonEmptyString(component.role) then
			addIssue(issues, "component.role", path .. ".role", "component role required")
		end
		if not isSemanticKey(component.materialKey) then
			addIssue(
				issues,
				"component.material_key",
				path .. ".materialKey",
				"materialKey must be the stable lowercase MaterialDNA recipe id"
			)
		end
		if not isPositiveInteger(component.materialRecipeVersion) then
			addIssue(
				issues,
				"component.material_recipe_version",
				path .. ".materialRecipeVersion",
				"materialRecipeVersion must be a positive integer"
			)
		end
		if not isPositiveFinite(component.massKg) then
			addIssue(
				issues,
				"component.mass",
				path .. ".massKg",
				"component mass must be positive finite kilograms"
			)
		else
			componentMassKg += component.massKg
		end
		if not isVec3(component.localPositionM) then
			addIssue(
				issues,
				"component.position",
				path .. ".localPositionM",
				"localPositionM must be a finite Vec3"
			)
		end
		validateLocalRotation(issues, path .. ".localRotationDeg", component.localRotationDeg)
		if not isPositiveVec3(component.dimensionsM) then
			addIssue(
				issues,
				"component.dimensions",
				path .. ".dimensionsM",
				"component dimensions must be positive meters"
			)
		elseif not componentFitsEnvelope(component, value.dimensionsM) then
			addIssue(
				issues,
				"component.outside_bounds",
				path,
				"component rotated bounds exceed the object envelope"
			)
		end

		local supportKeysDense = validateDenseArray(issues, path .. ".supportKeys", component.supportKeys)
		supportArraysValid[index] = supportKeysDense
		if not EXTERNAL_SUPPORTS[component.externalSupport] then
			addIssue(
				issues,
				"component.external_support",
				path .. ".externalSupport",
				"unknown external support mode"
			)
		end
	end

	if isPositiveFinite(value.massKg) and componentMassKg > 0 then
		local tolerance = math.max(0.01, value.massKg * MASS_TOLERANCE_FRACTION)
		if math.abs(componentMassKg - value.massKg) > tolerance then
			addIssue(
				issues,
				"mass.component_sum",
				"components",
				`component masses total {componentMassKg}kg but genome mass is {value.massKg}kg`
			)
		end
	end

	for index, component in ipairs(value.components) do
		if type(component) == "table" and supportArraysValid[index] and isSemanticKey(component.key) then
			local seenSupport: { [string]: boolean } = {}
			for supportIndex, supportKey in ipairs(component.supportKeys) do
				local path = `components[{index}].supportKeys[{supportIndex}]`
				if not isSemanticKey(supportKey) then
					addIssue(
						issues,
						"component.support_key",
						path,
						"support key must be a stable semantic key"
					)
				elseif supportKey == component.key then
					addIssue(issues, "component.self_support", path, "component cannot support itself")
				elseif seenSupport[supportKey] then
					addIssue(issues, "component.duplicate_support", path, "support key duplicated")
				elseif componentsByKey[supportKey] == nil then
					addIssue(
						issues,
						"component.support_missing",
						path,
						`unknown support component {supportKey}`
					)
				end
				seenSupport[supportKey] = true
			end
		end
	end

	local supportMemo: { [string]: boolean } = {}
	local visiting: { [string]: boolean } = {}
	local cycleReported: { [string]: boolean } = {}
	local function reachesExternalSupport(componentKey: string): boolean
		local memoized = supportMemo[componentKey]
		if memoized ~= nil then
			return memoized
		end
		if visiting[componentKey] then
			if not cycleReported[componentKey] then
				addIssue(
					issues,
					"component.support_cycle",
					`components.{componentKey}`,
					"support graph contains a cycle"
				)
				cycleReported[componentKey] = true
			end
			return false
		end

		local component = componentsByKey[componentKey]
		if component == nil then
			return false
		end
		visiting[componentKey] = true
		if component.externalSupport ~= "none" and EXTERNAL_SUPPORTS[component.externalSupport] then
			visiting[componentKey] = nil
			supportMemo[componentKey] = true
			return true
		end

		if type(component.supportKeys) == "table" then
			for _, supportKey in ipairs(component.supportKeys) do
				if componentsByKey[supportKey] ~= nil and reachesExternalSupport(supportKey) then
					visiting[componentKey] = nil
					supportMemo[componentKey] = true
					return true
				end
			end
		end

		visiting[componentKey] = nil
		supportMemo[componentKey] = false
		return false
	end

	for componentKey in pairs(componentsByKey) do
		if not reachesExternalSupport(componentKey) then
			addIssue(
				issues,
				"component.unsupported",
				`components.{componentKey}`,
				"component has no path to an external support"
			)
		end
	end

	local mechanismsByKey: { [string]: boolean } = {}
	local mechanismsDense = validateDenseArray(issues, "mechanisms", value.mechanisms)
	if mechanismsDense then
		for index, rawMechanism in ipairs(value.mechanisms) do
			local mechanism: any = rawMechanism
			local path = `mechanisms[{index}]`
			if type(mechanism) ~= "table" then
				addIssue(issues, "mechanism.type", path, "mechanism must be a table")
				continue
			end
			if not isSemanticKey(mechanism.key) then
				addIssue(
					issues,
					"mechanism.key",
					path .. ".key",
					"mechanism key must be a stable lowercase semantic key"
				)
			elseif mechanismsByKey[mechanism.key] then
				addIssue(issues, "mechanism.duplicate_key", path .. ".key", "duplicate mechanism key")
			else
				mechanismsByKey[mechanism.key] = true
			end
			if not MECHANISM_KINDS[mechanism.kind] then
				addIssue(issues, "mechanism.kind", path .. ".kind", "unknown mechanism kind")
				continue
			end
			if componentsByKey[mechanism.movingComponentKey] == nil then
				addIssue(
					issues,
					"mechanism.moving_component",
					path .. ".movingComponentKey",
					"unknown moving component"
				)
			end

			if mechanism.kind == "latch" then
				if componentsByKey[mechanism.catchComponentKey] == nil then
					addIssue(
						issues,
						"mechanism.catch_component",
						path .. ".catchComponentKey",
						"unknown catch component"
					)
				end
				if mechanism.catchComponentKey == mechanism.movingComponentKey then
					addIssue(
						issues,
						"mechanism.self_reference",
						path,
						"latch cannot catch on its moving component"
					)
				end
				if not isPositiveFinite(mechanism.engagementDistanceM) then
					addIssue(
						issues,
						"mechanism.engagement",
						path .. ".engagementDistanceM",
						"engagement distance must be positive meters"
					)
				end
			else
				if componentsByKey[mechanism.frameComponentKey] == nil then
					addIssue(
						issues,
						"mechanism.frame_component",
						path .. ".frameComponentKey",
						"unknown frame component"
					)
				end
				if mechanism.frameComponentKey == mechanism.movingComponentKey then
					addIssue(
						issues,
						"mechanism.self_reference",
						path,
						"mechanism frame and moving component must differ"
					)
				end
			end

			if mechanism.kind == "hinge" or mechanism.kind == "tilt" then
				validateAxis(issues, path .. ".axis", mechanism.axis)
				if
					not isFinite(mechanism.minDegrees)
					or not isFinite(mechanism.maxDegrees)
					or mechanism.minDegrees >= mechanism.maxDegrees
				then
					addIssue(
						issues,
						"mechanism.angular_limits",
						path,
						"angular limits require finite minDegrees < maxDegrees"
					)
				end
			elseif mechanism.kind == "slide" then
				validateAxis(issues, path .. ".axis", mechanism.axis)
				if
					not isFinite(mechanism.minTravelM)
					or not isFinite(mechanism.maxTravelM)
					or mechanism.minTravelM >= mechanism.maxTravelM
				then
					addIssue(
						issues,
						"mechanism.linear_limits",
						path,
						"slide limits require finite minTravelM < maxTravelM"
					)
				end
			elseif mechanism.kind == "caster" then
				if not isPositiveFinite(mechanism.wheelRadiusM) then
					addIssue(
						issues,
						"mechanism.caster_radius",
						path .. ".wheelRadiusM",
						"caster wheel radius must be positive meters"
					)
				end
				validateAxis(issues, path .. ".swivelAxis", mechanism.swivelAxis)
				validateAxis(issues, path .. ".rollAxis", mechanism.rollAxis)
			end
		end
	end

	local affordancesByKey: { [string]: boolean } = {}
	local affordancesDense = validateDenseArray(issues, "affordances", value.affordances)
	if affordancesDense then
		for index, affordance in ipairs(value.affordances) do
			local path = `affordances[{index}]`
			if type(affordance) ~= "table" then
				addIssue(issues, "affordance.type", path, "affordance must be a table")
				continue
			end
			if not isSemanticKey(affordance.key) then
				addIssue(
					issues,
					"affordance.key",
					path .. ".key",
					"affordance key must be a stable lowercase semantic key"
				)
			elseif affordancesByKey[affordance.key] then
				addIssue(issues, "affordance.duplicate_key", path .. ".key", "duplicate affordance key")
			else
				affordancesByKey[affordance.key] = true
			end
			if not AFFORDANCE_KINDS[affordance.kind] then
				addIssue(issues, "affordance.kind", path .. ".kind", "unknown affordance kind")
			end
			local component = componentsByKey[affordance.componentKey]
			if component == nil then
				addIssue(
					issues,
					"affordance.component",
					path .. ".componentKey",
					"unknown affordance component"
				)
			end
			if not isVec3(affordance.localPointM) then
				addIssue(
					issues,
					"affordance.point",
					path .. ".localPointM",
					"localPointM must be a finite Vec3"
				)
			elseif component ~= nil and isPositiveVec3(component.dimensionsM) then
				if
					math.abs(affordance.localPointM.x)
						> component.dimensionsM.x * 0.5 + BOUNDS_TOLERANCE_M
					or math.abs(affordance.localPointM.y) > component.dimensionsM.y * 0.5 + BOUNDS_TOLERANCE_M
					or math.abs(affordance.localPointM.z)
						> component.dimensionsM.z * 0.5 + BOUNDS_TOLERANCE_M
				then
					addIssue(
						issues,
						"affordance.outside_component",
						path .. ".localPointM",
						"affordance point lies outside component bounds"
					)
				end
			end
			if not isPositiveFinite(affordance.radiusM) then
				addIssue(
					issues,
					"affordance.radius",
					path .. ".radiusM",
					"affordance radius must be positive meters"
				)
			end
		end
	end

	return reportResult(issues)
end

function ObjectGenome.validate(value: ObjectGenome): ()
	local result = ObjectGenome.inspect(value)
	assert(result.ok, formatIssues(result.issues))
end

function ObjectGenome.defaultState(value: ObjectGenome): ObjectState
	ObjectGenome.validate(value)
	local componentWear: { [string]: number } = {}
	local componentDamage: { [string]: number } = {}
	local detachedComponents: { [string]: boolean } = {}
	for _, component in ipairs(value.components) do
		componentWear[component.key] = 0
		componentDamage[component.key] = 0
		detachedComponents[component.key] = false
	end

	local mechanismPosition: { [string]: number } = {}
	for _, mechanism in ipairs(value.mechanisms) do
		mechanismPosition[mechanism.key] = 0
	end

	return {
		stateSchemaVersion = ObjectGenome.STATE_SCHEMA_VERSION,
		genomeId = ObjectGenome.identityKey(value),
		componentWear = componentWear,
		componentDamage = componentDamage,
		mechanismPosition = mechanismPosition,
		detachedComponents = detachedComponents,
	}
end

function ObjectGenome.inspectState(genome: ObjectGenome, state: any): ValidationResult
	local issues: { ValidationIssue } = {}
	local genomeResult = ObjectGenome.inspect(genome)
	if not genomeResult.ok then
		addIssue(
			issues,
			"state.genome_invalid",
			"$",
			"cannot validate mutable state against an invalid genome"
		)
		return reportResult(issues)
	end
	if type(state) ~= "table" then
		addIssue(issues, "state.type", "$", "ObjectState must be a plain table")
		return reportResult(issues)
	end
	if getmetatable(state) ~= nil then
		addIssue(issues, "state.metatable", "$", "ObjectState must not have a metatable")
		return reportResult(issues)
	end
	for key in next, state do
		if type(key) ~= "string" or not STATE_FIELDS[key] then
			addIssue(
				issues,
				"state.unknown_field",
				`$.{safeKeyLabel(key)}`,
				"field is not declared by ObjectState schema v1"
			)
		end
	end
	if state.stateSchemaVersion ~= ObjectGenome.STATE_SCHEMA_VERSION then
		addIssue(
			issues,
			"state.schema_version",
			"stateSchemaVersion",
			"unsupported ObjectState schema version"
		)
	end

	local expectedGenomeId = ObjectGenome.identityKey(genome)
	if state.genomeId ~= expectedGenomeId then
		addIssue(
			issues,
			"state.genome_id",
			"genomeId",
			"ObjectState genomeId must match the exact canonical genome identity"
		)
	end

	local componentKeys: { [string]: boolean } = {}
	for _, component in ipairs(genome.components) do
		componentKeys[component.key] = true
	end
	local mechanismKeys: { [string]: boolean } = {}
	for _, mechanism in ipairs(genome.mechanisms) do
		mechanismKeys[mechanism.key] = true
	end

	local function validateUnitMap(fieldName: string, mapValue: any, knownKeys: { [string]: boolean }): ()
		if type(mapValue) ~= "table" then
			addIssue(issues, "state.collection", fieldName, `{fieldName} must be a table`)
			return
		end
		if getmetatable(mapValue) ~= nil then
			addIssue(issues, "state.metatable", fieldName, `{fieldName} must not have a metatable`)
			return
		end
		for key in pairs(knownKeys) do
			if mapValue[key] == nil then
				addIssue(
					issues,
					"state.missing_key",
					`{fieldName}.{key}`,
					"state is missing a required genome key"
				)
			end
		end
		for key, amount in pairs(mapValue) do
			if type(key) ~= "string" or not knownKeys[key] then
				addIssue(
					issues,
					"state.unknown_key",
					`{fieldName}.{safeKeyLabel(key)}`,
					"state references an unknown genome key"
				)
			elseif not isUnitInterval(amount) then
				addIssue(issues, "state.unit_interval", `{fieldName}.{key}`, "state value must be in [0, 1]")
			end
		end
	end

	validateUnitMap("componentWear", state.componentWear, componentKeys)
	validateUnitMap("componentDamage", state.componentDamage, componentKeys)
	validateUnitMap("mechanismPosition", state.mechanismPosition, mechanismKeys)

	if type(state.detachedComponents) ~= "table" then
		addIssue(issues, "state.collection", "detachedComponents", "detachedComponents must be a table")
	elseif getmetatable(state.detachedComponents) ~= nil then
		addIssue(
			issues,
			"state.metatable",
			"detachedComponents",
			"detachedComponents must not have a metatable"
		)
	else
		for key in pairs(componentKeys) do
			if state.detachedComponents[key] == nil then
				addIssue(
					issues,
					"state.missing_key",
					`detachedComponents.{key}`,
					"state is missing a required component key"
				)
			end
		end
		for key, detached in pairs(state.detachedComponents) do
			if type(key) ~= "string" or not componentKeys[key] then
				addIssue(
					issues,
					"state.unknown_key",
					`detachedComponents.{safeKeyLabel(key)}`,
					"state references an unknown component"
				)
			elseif type(detached) ~= "boolean" then
				addIssue(
					issues,
					"state.detached_value",
					`detachedComponents.{key}`,
					"detached state must be boolean"
				)
			end
		end
	end

	return reportResult(issues)
end

function ObjectGenome.validateState(genome: ObjectGenome, state: ObjectState): ()
	local result = ObjectGenome.inspectState(genome, state)
	assert(result.ok, formatIssues(result.issues))
end

return table.freeze(ObjectGenome)
