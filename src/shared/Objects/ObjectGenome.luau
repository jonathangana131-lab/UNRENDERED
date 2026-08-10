--!strict

-- ObjectGenome is pure domain data. Coordinates are object-local meters with +Y up,
-- centered on the nominal object bounds. Runtime wear/damage/mechanism positions live
-- in ObjectState so representation teardown never mutates the manufacturing recipe.

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type NumberRange = {
	min: number,
	max: number,
}

export type Vec3Range = {
	min: Vec3,
	max: Vec3,
}

export type ProvenanceSpec = {
	manufacturerId: string,
	productLineId: string,
	modelId: string,
}

-- supportedBy points toward the lower/load-bearing side of the construction graph.
-- massFraction is the aggregate mass share for this component spec, including count.
export type ComponentSpec = {
	key: string,
	role: string,
	materialId: string,
	count: number,
	massFraction: number,
	supportedBy: { string },
}

export type MechanismKind = "hinge" | "slide" | "caster" | "tilt" | "latch"
export type MechanismUnit = "degrees" | "meters" | "normalized"

export type MechanismSpec = {
	key: string,
	kind: MechanismKind,
	movingComponentKey: string,
	frameComponentKey: string,
	axis: Vec3?,
	limit: NumberRange,
	unit: MechanismUnit,
}

export type GripRegionSpec = {
	key: string,
	componentKey: string,
	centerMeters: Vec3,
	sizeMeters: Vec3,
}

export type AffordanceSpec = {
	key: string,
	action: string,
	componentKey: string,
	gripRegionKeys: { string },
}

export type ObjectGenome = {
	id: string,
	schemaVersion: number,
	familyId: string,
	variantId: string,
	apparentEra: string,
	provenance: ProvenanceSpec,
	dimensionsMeters: Vec3,
	plausibleDimensionsMeters: Vec3Range,
	massKg: number,
	plausibleMassKg: NumberRange,
	centerOfMassMeters: Vec3,
	components: { ComponentSpec },
	mechanisms: { MechanismSpec },
	gripRegions: { GripRegionSpec },
	affordances: { AffordanceSpec },
}

export type ObjectState = {
	wear: number,
	damage: number,
	componentDamage: { [string]: number },
	mechanismPosition: { [string]: number },
}

local ObjectGenome = {}

local VALID_MECHANISM_KINDS = table.freeze({
	hinge = true,
	slide = true,
	caster = true,
	tilt = true,
	latch = true,
})

local function assertFinite(value: number, name: string)
	assert(value == value and value > -math.huge and value < math.huge, `{name} must be finite`)
end

local function assertPositive(value: number, name: string)
	assertFinite(value, name)
	assert(value > 0, `{name} must be positive`)
end

local function assertUnitInterval(value: number, name: string)
	assertFinite(value, name)
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function assertToken(value: string, name: string)
	assert(value ~= "", `{name} required`)
	assert(string.match(value, "^[a-z0-9][a-z0-9._-]*$") ~= nil, `{name} must be a lowercase stable token`)
end

local function assertVec3Finite(value: Vec3, name: string)
	assertFinite(value.x, `{name}.x`)
	assertFinite(value.y, `{name}.y`)
	assertFinite(value.z, `{name}.z`)
end

local function assertVec3Positive(value: Vec3, name: string)
	assertVec3Finite(value, name)
	assert(value.x > 0 and value.y > 0 and value.z > 0, `{name} must be positive on every axis`)
end

local function assertRange(value: NumberRange, name: string)
	assertFinite(value.min, `{name}.min`)
	assertFinite(value.max, `{name}.max`)
	assert(value.min <= value.max, `{name}.min must be <= max`)
end

local function assertVec3Range(value: Vec3Range, name: string)
	assertVec3Positive(value.min, `{name}.min`)
	assertVec3Positive(value.max, `{name}.max`)
	assert(value.min.x <= value.max.x, `{name}.x min must be <= max`)
	assert(value.min.y <= value.max.y, `{name}.y min must be <= max`)
	assert(value.min.z <= value.max.z, `{name}.z min must be <= max`)
end

local function vec3Within(value: Vec3, bounds: Vec3Range): boolean
	return value.x >= bounds.min.x
		and value.x <= bounds.max.x
		and value.y >= bounds.min.y
		and value.y <= bounds.max.y
		and value.z >= bounds.min.z
		and value.z <= bounds.max.z
end

local function isInsideDimensions(point: Vec3, dimensions: Vec3): boolean
	return math.abs(point.x) <= dimensions.x * 0.5
		and math.abs(point.y) <= dimensions.y * 0.5
		and math.abs(point.z) <= dimensions.z * 0.5
end

local function isRegionInsideDimensions(center: Vec3, size: Vec3, dimensions: Vec3): boolean
	return math.abs(center.x) + size.x * 0.5 <= dimensions.x * 0.5
		and math.abs(center.y) + size.y * 0.5 <= dimensions.y * 0.5
		and math.abs(center.z) + size.z * 0.5 <= dimensions.z * 0.5
end

local function assertAxis(axis: Vec3, name: string)
	assertVec3Finite(axis, name)
	local magnitudeSquared = axis.x * axis.x + axis.y * axis.y + axis.z * axis.z
	assert(magnitudeSquared > 0.000001, `{name} must be non-zero`)
end

local function assertUniqueStrings(values: { string }, name: string)
	local seen = {}
	for _, value in values do
		assert(value ~= "", `{name} entries must not be empty`)
		assert(not seen[value], `{name} contains duplicate '{value}'`)
		seen[value] = true
	end
end

function ObjectGenome.deriveId(
	schemaVersion: number,
	familyId: string,
	manufacturerId: string,
	productLineId: string,
	modelId: string,
	variantId: string
): string
	assert(schemaVersion > 0 and schemaVersion % 1 == 0, "schemaVersion must be a positive integer")
	assertToken(familyId, "familyId")
	assertToken(manufacturerId, "manufacturerId")
	assertToken(productLineId, "productLineId")
	assertToken(modelId, "modelId")
	assertToken(variantId, "variantId")
	return string.format(
		"object-genome:%d:%s:%s:%s:%s:%s",
		schemaVersion,
		familyId,
		manufacturerId,
		productLineId,
		modelId,
		variantId
	)
end

local function validateComponentGraph(components: { ComponentSpec }): { [string]: ComponentSpec }
	assert(#components > 0, "components required")

	local byKey: { [string]: ComponentSpec } = {}
	local totalMassFraction = 0
	local rootCount = 0

	for _, component in components do
		assertToken(component.key, "component.key")
		assert(component.role ~= "", `component '{component.key}' role required`)
		assert(component.materialId ~= "", `component '{component.key}' materialId required`)
		assert(
			component.count > 0 and component.count % 1 == 0,
			`component '{component.key}' count must be a positive integer`
		)
		assertUnitInterval(component.massFraction, `component '{component.key}' massFraction`)
		assert(component.massFraction > 0, `component '{component.key}' massFraction must be positive`)
		assertUniqueStrings(component.supportedBy, `component '{component.key}' supportedBy`)
		assert(byKey[component.key] == nil, `duplicate component key '{component.key}'`)
		byKey[component.key] = component
		totalMassFraction += component.massFraction
		if #component.supportedBy == 0 then
			rootCount += 1
		end
	end

	assert(math.abs(totalMassFraction - 1) <= 0.001, "component massFraction values must sum to 1")
	assert(rootCount > 0, "component graph requires at least one ground/root component")

	for _, component in components do
		for _, supportKey in component.supportedBy do
			assert(supportKey ~= component.key, `component '{component.key}' cannot support itself`)
			assert(byKey[supportKey] ~= nil, `component '{component.key}' references unknown support '{supportKey}'`)
		end
	end

	local visiting: { [string]: boolean } = {}
	local visited: { [string]: boolean } = {}

	local function visit(key: string)
		if visited[key] then
			return
		end
		assert(not visiting[key], `support cycle detected at component '{key}'`)
		visiting[key] = true
		for _, supportKey in byKey[key].supportedBy do
			visit(supportKey)
		end
		visiting[key] = false
		visited[key] = true
	end

	for key in byKey do
		visit(key)
	end

	return byKey
end

local function validateMechanisms(mechanisms: { MechanismSpec }, components: { [string]: ComponentSpec })
	local keys = {}
	for _, mechanism in mechanisms do
		assertToken(mechanism.key, "mechanism.key")
		assert(VALID_MECHANISM_KINDS[mechanism.kind] == true, `unsupported mechanism kind '{mechanism.kind}'`)
		assert(keys[mechanism.key] == nil, `duplicate mechanism key '{mechanism.key}'`)
		keys[mechanism.key] = true
		assert(
			components[mechanism.movingComponentKey] ~= nil,
			`mechanism '{mechanism.key}' moving component missing`
		)
		assert(
			components[mechanism.frameComponentKey] ~= nil,
			`mechanism '{mechanism.key}' frame component missing`
		)
		assert(
			mechanism.movingComponentKey ~= mechanism.frameComponentKey,
			`mechanism '{mechanism.key}' must connect two components`
		)
		assertRange(mechanism.limit, `mechanism '{mechanism.key}' limit`)

		if mechanism.kind == "hinge" or mechanism.kind == "caster" or mechanism.kind == "tilt" then
			assert(mechanism.unit == "degrees", `mechanism '{mechanism.key}' must use degrees`)
			assert(mechanism.axis ~= nil, `mechanism '{mechanism.key}' axis required`)
			assertAxis(mechanism.axis :: Vec3, `mechanism '{mechanism.key}' axis`)
		elseif mechanism.kind == "slide" then
			assert(mechanism.unit == "meters", `mechanism '{mechanism.key}' must use meters`)
			assert(mechanism.axis ~= nil, `mechanism '{mechanism.key}' axis required`)
			assertAxis(mechanism.axis :: Vec3, `mechanism '{mechanism.key}' axis`)
		else
			assert(mechanism.unit == "normalized", `mechanism '{mechanism.key}' must use normalized units`)
			assert(
				mechanism.limit.min >= 0 and mechanism.limit.max <= 1,
				`mechanism '{mechanism.key}' normalized limit must stay in [0, 1]`
			)
		end
	end
end

local function validateInteractionGeometry(
	gripRegions: { GripRegionSpec },
	affordances: { AffordanceSpec },
	components: { [string]: ComponentSpec },
	dimensions: Vec3
)
	local regionKeys = {}
	for _, region in gripRegions do
		assertToken(region.key, "gripRegion.key")
		assert(regionKeys[region.key] == nil, `duplicate grip region key '{region.key}'`)
		regionKeys[region.key] = true
		assert(components[region.componentKey] ~= nil, `grip region '{region.key}' component missing`)
		assertVec3Finite(region.centerMeters, `grip region '{region.key}' centerMeters`)
		assertVec3Positive(region.sizeMeters, `grip region '{region.key}' sizeMeters`)
		assert(
			isRegionInsideDimensions(region.centerMeters, region.sizeMeters, dimensions),
			`grip region '{region.key}' must fit inside object bounds`
		)
	end

	local affordanceKeys = {}
	for _, affordance in affordances do
		assertToken(affordance.key, "affordance.key")
		assert(affordance.action ~= "", `affordance '{affordance.key}' action required`)
		assert(components[affordance.componentKey] ~= nil, `affordance '{affordance.key}' component missing`)
		assert(affordanceKeys[affordance.key] == nil, `duplicate affordance key '{affordance.key}'`)
		affordanceKeys[affordance.key] = true
		assertUniqueStrings(affordance.gripRegionKeys, `affordance '{affordance.key}' gripRegionKeys`)
		for _, regionKey in affordance.gripRegionKeys do
			assert(
				regionKeys[regionKey] == true,
				`affordance '{affordance.key}' references unknown grip region '{regionKey}'`
			)
		end
	end
end

function ObjectGenome.validate(value: ObjectGenome): ()
	assert(value.schemaVersion > 0 and value.schemaVersion % 1 == 0, "schemaVersion must be a positive integer")
	assertToken(value.familyId, "familyId")
	assertToken(value.variantId, "variantId")
	assert(value.apparentEra ~= "", "apparentEra required")
	assertToken(value.provenance.manufacturerId, "provenance.manufacturerId")
	assertToken(value.provenance.productLineId, "provenance.productLineId")
	assertToken(value.provenance.modelId, "provenance.modelId")

	local expectedId = ObjectGenome.deriveId(
		value.schemaVersion,
		value.familyId,
		value.provenance.manufacturerId,
		value.provenance.productLineId,
		value.provenance.modelId,
		value.variantId
	)
	assert(value.id == expectedId, `id must equal deterministic identity '{expectedId}'`)

	assertVec3Positive(value.dimensionsMeters, "dimensionsMeters")
	assertVec3Range(value.plausibleDimensionsMeters, "plausibleDimensionsMeters")
	assert(
		vec3Within(value.dimensionsMeters, value.plausibleDimensionsMeters),
		"dimensionsMeters outside plausibility range"
	)

	assertPositive(value.massKg, "massKg")
	assertRange(value.plausibleMassKg, "plausibleMassKg")
	assert(value.plausibleMassKg.min > 0, "plausibleMassKg.min must be positive")
	assert(
		value.massKg >= value.plausibleMassKg.min and value.massKg <= value.plausibleMassKg.max,
		"massKg outside plausibility range"
	)

	assertVec3Finite(value.centerOfMassMeters, "centerOfMassMeters")
	assert(
		isInsideDimensions(value.centerOfMassMeters, value.dimensionsMeters),
		"centerOfMassMeters must be inside object bounds"
	)

	local components = validateComponentGraph(value.components)
	validateMechanisms(value.mechanisms, components)
	validateInteractionGeometry(value.gripRegions, value.affordances, components, value.dimensionsMeters)
end

function ObjectGenome.newState(): ObjectState
	return {
		wear = 0,
		damage = 0,
		componentDamage = {},
		mechanismPosition = {},
	}
end

function ObjectGenome.validateState(genome: ObjectGenome, state: ObjectState): ()
	ObjectGenome.validate(genome)
	assertUnitInterval(state.wear, "state.wear")
	assertUnitInterval(state.damage, "state.damage")

	local componentKeys = {}
	for _, component in genome.components do
		componentKeys[component.key] = true
	end
	for componentKey, damage in state.componentDamage do
		assert(
			componentKeys[componentKey] == true,
			`state.componentDamage references unknown component '{componentKey}'`
		)
		assertUnitInterval(damage, `state.componentDamage['{componentKey}']`)
	end

	local mechanismByKey = {}
	for _, mechanism in genome.mechanisms do
		mechanismByKey[mechanism.key] = mechanism
	end
	for mechanismKey, position in state.mechanismPosition do
		local mechanism = mechanismByKey[mechanismKey]
		assert(mechanism ~= nil, `state.mechanismPosition references unknown mechanism '{mechanismKey}'`)
		assertFinite(position, `state.mechanismPosition['{mechanismKey}']`)
		assert(
			position >= mechanism.limit.min and position <= mechanism.limit.max,
			`state.mechanismPosition['{mechanismKey}'] outside mechanism limit`
		)
	end
end

return table.freeze(ObjectGenome)
