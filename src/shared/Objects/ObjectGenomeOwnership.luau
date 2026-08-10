--!strict

local ObjectGenome = require("./ObjectGenome")

type Genome = ObjectGenome.ObjectGenome

type StringSet = { [string]: boolean }

local ObjectGenomeOwnership = {}

local TOP_LEVEL_KEYS: StringSet = table.freeze({
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
})
local PROVENANCE_KEYS: StringSet = table.freeze({
	manufacturerFamily = true,
	productLine = true,
	apparentEra = true,
})
local VEC3_KEYS: StringSet = table.freeze({ x = true, y = true, z = true })
local DIMENSION_LIMIT_KEYS: StringSet = table.freeze({ minM = true, maxM = true })
local RANGE_KEYS: StringSet = table.freeze({ min = true, max = true })
local COMPONENT_KEYS: StringSet = table.freeze({
	key = true,
	role = true,
	materialKey = true,
	massKg = true,
	localPositionM = true,
	localRotationDeg = true,
	dimensionsM = true,
	supportKeys = true,
	externalSupport = true,
})
local AFFORDANCE_KEYS: StringSet = table.freeze({
	key = true,
	kind = true,
	componentKey = true,
	localPointM = true,
	radiusM = true,
})
local HINGE_KEYS: StringSet = table.freeze({
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minDegrees = true,
	maxDegrees = true,
})
local SLIDE_KEYS: StringSet = table.freeze({
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minTravelM = true,
	maxTravelM = true,
})
local CASTER_KEYS: StringSet = table.freeze({
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	wheelRadiusM = true,
	swivelAxis = true,
	rollAxis = true,
})
local TILT_KEYS: StringSet = HINGE_KEYS
local LATCH_KEYS: StringSet = table.freeze({
	key = true,
	kind = true,
	movingComponentKey = true,
	catchComponentKey = true,
	engagementDistanceM = true,
})

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function assertPlainRecord(value: any, allowed: StringSet, path: string): ()
	assert(type(value) == "table", `{path} must be a plain table`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)
	for key in pairs(value) do
		assert(type(key) == "string" and allowed[key] == true, `{path} contains unknown field {tostring(key)}`)
	end
end

local function assertDenseArray(value: any, path: string): number
	assert(type(value) == "table", `{path} must be a dense array`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)

	local count = 0
	local highest = 0
	for key in pairs(value) do
		assert(
			type(key) == "number" and key >= 1 and key % 1 == 0,
			`{path} must contain only positive integer keys`
		)
		count += 1
		highest = math.max(highest, key)
	end
	assert(count == highest, `{path} must be a dense 1-based array`)
	return highest
end

local function copyScalar(value: any, path: string): any
	local kind = type(value)
	assert(
		kind == "nil" or kind == "boolean" or kind == "string" or kind == "number",
		`{path} must contain only plain scalar data`
	)
	if kind == "number" then
		assert(isFinite(value), `{path} numbers must be finite`)
	end
	return value
end

local function copyVec3(value: any, path: string): any
	assertPlainRecord(value, VEC3_KEYS, path)
	return {
		x = copyScalar(value.x, `{path}.x`),
		y = copyScalar(value.y, `{path}.y`),
		z = copyScalar(value.z, `{path}.z`),
	}
end

local function copyStringArray(value: any, path: string): { any }
	local length = assertDenseArray(value, path)
	local result = {}
	for index = 1, length do
		result[index] = copyScalar(value[index], `{path}[{index}]`)
	end
	return result
end

local function copyComponents(value: any): { any }
	local length = assertDenseArray(value, "components")
	local result = {}
	for index = 1, length do
		local component = value[index]
		local path = `components[{index}]`
		assertPlainRecord(component, COMPONENT_KEYS, path)
		result[index] = {
			key = copyScalar(component.key, `{path}.key`),
			role = copyScalar(component.role, `{path}.role`),
			materialKey = copyScalar(component.materialKey, `{path}.materialKey`),
			massKg = copyScalar(component.massKg, `{path}.massKg`),
			localPositionM = copyVec3(component.localPositionM, `{path}.localPositionM`),
			localRotationDeg = copyVec3(component.localRotationDeg, `{path}.localRotationDeg`),
			dimensionsM = copyVec3(component.dimensionsM, `{path}.dimensionsM`),
			supportKeys = copyStringArray(component.supportKeys, `{path}.supportKeys`),
			externalSupport = copyScalar(component.externalSupport, `{path}.externalSupport`),
		}
	end
	return result
end

local function mechanismKeys(kind: any): StringSet
	if kind == "hinge" then
		return HINGE_KEYS
	elseif kind == "slide" then
		return SLIDE_KEYS
	elseif kind == "caster" then
		return CASTER_KEYS
	elseif kind == "tilt" then
		return TILT_KEYS
	elseif kind == "latch" then
		return LATCH_KEYS
	end
	error(`unsupported mechanism kind at ownership boundary: {tostring(kind)}`)
end

local function copyMechanisms(value: any): { any }
	local length = assertDenseArray(value, "mechanisms")
	local result = {}
	for index = 1, length do
		local mechanism = value[index]
		local path = `mechanisms[{index}]`
		assert(type(mechanism) == "table", `{path} must be a plain table`)
		local kind = mechanism.kind
		assertPlainRecord(mechanism, mechanismKeys(kind), path)

		if kind == "hinge" or kind == "tilt" then
			result[index] = {
				key = copyScalar(mechanism.key, `{path}.key`),
				kind = kind,
				movingComponentKey = copyScalar(mechanism.movingComponentKey, `{path}.movingComponentKey`),
				frameComponentKey = copyScalar(mechanism.frameComponentKey, `{path}.frameComponentKey`),
				axis = copyVec3(mechanism.axis, `{path}.axis`),
				minDegrees = copyScalar(mechanism.minDegrees, `{path}.minDegrees`),
				maxDegrees = copyScalar(mechanism.maxDegrees, `{path}.maxDegrees`),
			}
		elseif kind == "slide" then
			result[index] = {
				key = copyScalar(mechanism.key, `{path}.key`),
				kind = kind,
				movingComponentKey = copyScalar(mechanism.movingComponentKey, `{path}.movingComponentKey`),
				frameComponentKey = copyScalar(mechanism.frameComponentKey, `{path}.frameComponentKey`),
				axis = copyVec3(mechanism.axis, `{path}.axis`),
				minTravelM = copyScalar(mechanism.minTravelM, `{path}.minTravelM`),
				maxTravelM = copyScalar(mechanism.maxTravelM, `{path}.maxTravelM`),
			}
		elseif kind == "caster" then
			result[index] = {
				key = copyScalar(mechanism.key, `{path}.key`),
				kind = kind,
				movingComponentKey = copyScalar(mechanism.movingComponentKey, `{path}.movingComponentKey`),
				frameComponentKey = copyScalar(mechanism.frameComponentKey, `{path}.frameComponentKey`),
				wheelRadiusM = copyScalar(mechanism.wheelRadiusM, `{path}.wheelRadiusM`),
				swivelAxis = copyVec3(mechanism.swivelAxis, `{path}.swivelAxis`),
				rollAxis = copyVec3(mechanism.rollAxis, `{path}.rollAxis`),
			}
		else
			result[index] = {
				key = copyScalar(mechanism.key, `{path}.key`),
				kind = kind,
				movingComponentKey = copyScalar(mechanism.movingComponentKey, `{path}.movingComponentKey`),
				catchComponentKey = copyScalar(mechanism.catchComponentKey, `{path}.catchComponentKey`),
				engagementDistanceM = copyScalar(mechanism.engagementDistanceM, `{path}.engagementDistanceM`),
			}
		end
	end
	return result
end

local function copyAffordances(value: any): { any }
	local length = assertDenseArray(value, "affordances")
	local result = {}
	for index = 1, length do
		local affordance = value[index]
		local path = `affordances[{index}]`
		assertPlainRecord(affordance, AFFORDANCE_KEYS, path)
		result[index] = {
			key = copyScalar(affordance.key, `{path}.key`),
			kind = copyScalar(affordance.kind, `{path}.kind`),
			componentKey = copyScalar(affordance.componentKey, `{path}.componentKey`),
			localPointM = copyVec3(affordance.localPointM, `{path}.localPointM`),
			radiusM = copyScalar(affordance.radiusM, `{path}.radiusM`),
		}
	end
	return result
end

local function deepFreeze(value: any): any
	for _, child in pairs(value) do
		if type(child) == "table" and not table.isfrozen(child) then
			deepFreeze(child)
		end
	end
	return table.freeze(value)
end

function ObjectGenomeOwnership.own(value: any): Genome
	assertPlainRecord(value, TOP_LEVEL_KEYS, "ObjectGenome")
	assertPlainRecord(value.provenance, PROVENANCE_KEYS, "provenance")
	assertPlainRecord(value.dimensionLimits, DIMENSION_LIMIT_KEYS, "dimensionLimits")
	assertPlainRecord(value.massLimitsKg, RANGE_KEYS, "massLimitsKg")

	local owned = {
		schemaVersion = copyScalar(value.schemaVersion, "schemaVersion"),
		familyId = copyScalar(value.familyId, "familyId"),
		familyVersion = copyScalar(value.familyVersion, "familyVersion"),
		variantKey = copyScalar(value.variantKey, "variantKey"),
		provenance = {
			manufacturerFamily = copyScalar(value.provenance.manufacturerFamily, "provenance.manufacturerFamily"),
			productLine = copyScalar(value.provenance.productLine, "provenance.productLine"),
			apparentEra = copyScalar(value.provenance.apparentEra, "provenance.apparentEra"),
		},
		dimensionsM = copyVec3(value.dimensionsM, "dimensionsM"),
		dimensionLimits = {
			minM = copyVec3(value.dimensionLimits.minM, "dimensionLimits.minM"),
			maxM = copyVec3(value.dimensionLimits.maxM, "dimensionLimits.maxM"),
		},
		massKg = copyScalar(value.massKg, "massKg"),
		massLimitsKg = {
			min = copyScalar(value.massLimitsKg.min, "massLimitsKg.min"),
			max = copyScalar(value.massLimitsKg.max, "massLimitsKg.max"),
		},
		centerOfMassM = copyVec3(value.centerOfMassM, "centerOfMassM"),
		components = copyComponents(value.components),
		mechanisms = copyMechanisms(value.mechanisms),
		affordances = copyAffordances(value.affordances),
	}

	ObjectGenome.validate(owned)
	return deepFreeze(owned) :: Genome
end

return table.freeze(ObjectGenomeOwnership)
