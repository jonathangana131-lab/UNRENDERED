--!strict

local ObjectGenome = require("./ObjectGenome")

type Vec3 = ObjectGenome.Vec3
type NumberRange = ObjectGenome.NumberRange
type DimensionLimits = ObjectGenome.DimensionLimits
type Provenance = ObjectGenome.Provenance
type ComponentSpec = ObjectGenome.ComponentSpec
type MechanismSpec = ObjectGenome.MechanismSpec
type AffordanceSpec = ObjectGenome.AffordanceSpec
type Genome = ObjectGenome.ObjectGenome

local ObjectGenomeOwnership = {}

local TOP_LEVEL_KEYS = {
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

local VEC3_KEYS = {
	x = true,
	y = true,
	z = true,
}

local RANGE_KEYS = {
	min = true,
	max = true,
}

local DIMENSION_LIMIT_KEYS = {
	minM = true,
	maxM = true,
}

local PROVENANCE_KEYS = {
	manufacturerFamily = true,
	productLine = true,
	apparentEra = true,
}

local COMPONENT_KEYS = {
	key = true,
	role = true,
	materialKey = true,
	massKg = true,
	localPositionM = true,
	localRotationDeg = true,
	dimensionsM = true,
	supportKeys = true,
	externalSupport = true,
}

local AFFORDANCE_KEYS = {
	key = true,
	kind = true,
	componentKey = true,
	localPointM = true,
	radiusM = true,
}

local HINGE_TILT_KEYS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minDegrees = true,
	maxDegrees = true,
}

local SLIDE_KEYS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	axis = true,
	minTravelM = true,
	maxTravelM = true,
}

local CASTER_KEYS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	frameComponentKey = true,
	wheelRadiusM = true,
	swivelAxis = true,
	rollAxis = true,
}

local LATCH_KEYS = {
	key = true,
	kind = true,
	movingComponentKey = true,
	catchComponentKey = true,
	engagementDistanceM = true,
}

local function assertRecordShape(value: any, allowedKeys: { [string]: boolean }, path: string): ()
	assert(type(value) == "table", `{path} must be a plain table`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)
	for key in pairs(value) do
		assert(type(key) == "string" and allowedKeys[key] == true, `{path} contains unknown schema key {tostring(key)}`)
	end
end

local function assertArrayShape(value: any, path: string): ()
	assert(type(value) == "table", `{path} must be a plain array`)
	assert(getmetatable(value) == nil, `{path} must not have a metatable`)
	for key in pairs(value) do
		assert(
			type(key) == "number" and key > 0 and key % 1 == 0,
			`{path} contains a non-array key {tostring(key)}`
		)
	end
end

local function assertVec3Shape(value: any, path: string): ()
	assertRecordShape(value, VEC3_KEYS, path)
end

local function assertCanonicalShape(value: any): ()
	assertRecordShape(value, TOP_LEVEL_KEYS, "$genome")
	assertRecordShape(value.provenance, PROVENANCE_KEYS, "$genome.provenance")
	assertVec3Shape(value.dimensionsM, "$genome.dimensionsM")
	assertRecordShape(value.dimensionLimits, DIMENSION_LIMIT_KEYS, "$genome.dimensionLimits")
	assertVec3Shape(value.dimensionLimits.minM, "$genome.dimensionLimits.minM")
	assertVec3Shape(value.dimensionLimits.maxM, "$genome.dimensionLimits.maxM")
	assertRecordShape(value.massLimitsKg, RANGE_KEYS, "$genome.massLimitsKg")
	assertVec3Shape(value.centerOfMassM, "$genome.centerOfMassM")

	assertArrayShape(value.components, "$genome.components")
	for index, component in ipairs(value.components) do
		local path = `$genome.components[{index}]`
		assertRecordShape(component, COMPONENT_KEYS, path)
		assertVec3Shape(component.localPositionM, path .. ".localPositionM")
		assertVec3Shape(component.localRotationDeg, path .. ".localRotationDeg")
		assertVec3Shape(component.dimensionsM, path .. ".dimensionsM")
		assertArrayShape(component.supportKeys, path .. ".supportKeys")
	end

	assertArrayShape(value.mechanisms, "$genome.mechanisms")
	for index, mechanism in ipairs(value.mechanisms) do
		local path = `$genome.mechanisms[{index}]`
		if mechanism.kind == "hinge" or mechanism.kind == "tilt" then
			assertRecordShape(mechanism, HINGE_TILT_KEYS, path)
			assertVec3Shape(mechanism.axis, path .. ".axis")
		elseif mechanism.kind == "slide" then
			assertRecordShape(mechanism, SLIDE_KEYS, path)
			assertVec3Shape(mechanism.axis, path .. ".axis")
		elseif mechanism.kind == "caster" then
			assertRecordShape(mechanism, CASTER_KEYS, path)
			assertVec3Shape(mechanism.swivelAxis, path .. ".swivelAxis")
			assertVec3Shape(mechanism.rollAxis, path .. ".rollAxis")
		elseif mechanism.kind == "latch" then
			assertRecordShape(mechanism, LATCH_KEYS, path)
		else
			error(`{path} has unsupported mechanism kind`)
		end
	end

	assertArrayShape(value.affordances, "$genome.affordances")
	for index, affordance in ipairs(value.affordances) do
		local path = `$genome.affordances[{index}]`
		assertRecordShape(affordance, AFFORDANCE_KEYS, path)
		assertVec3Shape(affordance.localPointM, path .. ".localPointM")
	end
end

local function cloneVec3(value: Vec3): Vec3
	return {
		x = value.x,
		y = value.y,
		z = value.z,
	}
end

local function cloneRange(value: NumberRange): NumberRange
	return {
		min = value.min,
		max = value.max,
	}
end

local function cloneDimensionLimits(value: DimensionLimits): DimensionLimits
	return {
		minM = cloneVec3(value.minM),
		maxM = cloneVec3(value.maxM),
	}
end

local function cloneProvenance(value: Provenance): Provenance
	return {
		manufacturerFamily = value.manufacturerFamily,
		productLine = value.productLine,
		apparentEra = value.apparentEra,
	}
end

local function cloneComponent(value: ComponentSpec): ComponentSpec
	local supportKeys: { string } = {}
	for _, supportKey in ipairs(value.supportKeys) do
		table.insert(supportKeys, supportKey)
	end
	return {
		key = value.key,
		role = value.role,
		materialKey = value.materialKey,
		massKg = value.massKg,
		localPositionM = cloneVec3(value.localPositionM),
		localRotationDeg = cloneVec3(value.localRotationDeg),
		dimensionsM = cloneVec3(value.dimensionsM),
		supportKeys = supportKeys,
		externalSupport = value.externalSupport,
	}
end

local function cloneMechanism(value: MechanismSpec): MechanismSpec
	if value.kind == "hinge" then
		return {
			key = value.key,
			kind = value.kind,
			movingComponentKey = value.movingComponentKey,
			frameComponentKey = value.frameComponentKey,
			axis = cloneVec3(value.axis),
			minDegrees = value.minDegrees,
			maxDegrees = value.maxDegrees,
		}
	elseif value.kind == "tilt" then
		return {
			key = value.key,
			kind = value.kind,
			movingComponentKey = value.movingComponentKey,
			frameComponentKey = value.frameComponentKey,
			axis = cloneVec3(value.axis),
			minDegrees = value.minDegrees,
			maxDegrees = value.maxDegrees,
		}
	elseif value.kind == "slide" then
		return {
			key = value.key,
			kind = value.kind,
			movingComponentKey = value.movingComponentKey,
			frameComponentKey = value.frameComponentKey,
			axis = cloneVec3(value.axis),
			minTravelM = value.minTravelM,
			maxTravelM = value.maxTravelM,
		}
	elseif value.kind == "caster" then
		return {
			key = value.key,
			kind = value.kind,
			movingComponentKey = value.movingComponentKey,
			frameComponentKey = value.frameComponentKey,
			wheelRadiusM = value.wheelRadiusM,
			swivelAxis = cloneVec3(value.swivelAxis),
			rollAxis = cloneVec3(value.rollAxis),
		}
	else
		return {
			key = value.key,
			kind = value.kind,
			movingComponentKey = value.movingComponentKey,
			catchComponentKey = value.catchComponentKey,
			engagementDistanceM = value.engagementDistanceM,
		}
	end
end

local function cloneAffordance(value: AffordanceSpec): AffordanceSpec
	return {
		key = value.key,
		kind = value.kind,
		componentKey = value.componentKey,
		localPointM = cloneVec3(value.localPointM),
		radiusM = value.radiusM,
	}
end

local function cloneGenome(value: Genome): Genome
	local components: { ComponentSpec } = {}
	for _, component in ipairs(value.components) do
		table.insert(components, cloneComponent(component))
	end

	local mechanisms: { MechanismSpec } = {}
	for _, mechanism in ipairs(value.mechanisms) do
		table.insert(mechanisms, cloneMechanism(mechanism))
	end

	local affordances: { AffordanceSpec } = {}
	for _, affordance in ipairs(value.affordances) do
		table.insert(affordances, cloneAffordance(affordance))
	end

	return {
		schemaVersion = value.schemaVersion,
		familyId = value.familyId,
		familyVersion = value.familyVersion,
		variantKey = value.variantKey,
		provenance = cloneProvenance(value.provenance),
		dimensionsM = cloneVec3(value.dimensionsM),
		dimensionLimits = cloneDimensionLimits(value.dimensionLimits),
		massKg = value.massKg,
		massLimitsKg = cloneRange(value.massLimitsKg),
		centerOfMassM = cloneVec3(value.centerOfMassM),
		components = components,
		mechanisms = mechanisms,
		affordances = affordances,
	}
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
	ObjectGenome.validate(value)
	assertCanonicalShape(value)

	local owned = cloneGenome(value :: Genome)
	ObjectGenome.validate(owned)
	return deepFreeze(owned) :: Genome
end

return table.freeze(ObjectGenomeOwnership)
