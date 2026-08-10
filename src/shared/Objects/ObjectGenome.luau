--!strict

-- ObjectGenome is immutable manufactured-object recipe data. Mutable wear, damage,
-- and mechanism position live in ObjectState so representation unload/reload never
-- requires mutating the canonical genome.

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type Dimensions3 = {
	widthM: number,
	heightM: number,
	depthM: number,
}

export type NumberRange = {
	min: number,
	max: number,
}

export type PlausibilitySpec = {
	widthM: NumberRange,
	heightM: NumberRange,
	depthM: NumberRange,
	massKg: NumberRange,
}

export type ManufacturerSpec = {
	manufacturerFamily: string,
	productLine: string,
	apparentEra: string,
}

export type ComponentSpec = {
	key: string,
	role: string,
	materialKey: string,
	massKg: number,
	nominalDimensionsM: Dimensions3,
}

export type SupportMode = "structural" | "attached" | "suspended"

export type SupportLink = {
	supporterKey: string,
	supportedKey: string,
	mode: SupportMode,
	maxLoadKg: number?,
}

export type HingeMechanism = {
	key: string,
	kind: "hinge",
	movingComponentKey: string,
	anchorComponentKey: string,
	axis: Vec3,
	minAngleDeg: number,
	maxAngleDeg: number,
	damping: number,
}

export type SlideMechanism = {
	key: string,
	kind: "slide",
	movingComponentKey: string,
	railComponentKey: string,
	travelM: number,
	damping: number,
}

export type CasterMechanism = {
	key: string,
	kind: "caster",
	wheelComponentKey: string,
	mountComponentKey: string,
	radiusM: number,
	widthM: number,
	swivel: boolean,
	brake: boolean,
}

export type TiltMechanism = {
	key: string,
	kind: "tilt",
	movingComponentKey: string,
	supportComponentKey: string,
	minAngleDeg: number,
	maxAngleDeg: number,
	springStrength: number,
	damping: number,
}

export type LatchMechanism = {
	key: string,
	kind: "latch",
	movingComponentKey: string,
	keeperComponentKey: string,
	breakForceN: number,
	defaultLatched: boolean,
}

export type MechanismSpec = HingeMechanism | SlideMechanism | CasterMechanism | TiltMechanism | LatchMechanism

export type AffordanceKind = "grip" | "sit" | "push" | "pull" | "carry" | "open" | "close"

export type AffordanceSpec = {
	key: string,
	kind: AffordanceKind,
	componentKey: string,
	-- Component-local normalized box. center01 is in [0, 1]; size01 is in (0, 1].
	center01: Vec3,
	size01: Vec3,
}

export type ObjectGenome = {
	id: string,
	schemaVersion: number,
	familyId: string,
	familyVersion: number,
	variantKey: string,
	manufacturer: ManufacturerSpec,
	dimensionsM: Dimensions3,
	plausibility: PlausibilitySpec,
	massKg: number,
	-- Object-local coordinates with the origin at the nominal bounding-box center.
	centerOfMassM: Vec3,
	components: { ComponentSpec },
	supportLinks: { SupportLink },
	mechanisms: { MechanismSpec },
	affordances: { AffordanceSpec },
}

export type ComponentState = {
	wear: number,
	damage: number,
}

export type MechanismState = {
	position01: number,
	locked: boolean,
}

export type ObjectState = {
	stateVersion: number,
	componentState: { [string]: ComponentState },
	mechanismState: { [string]: MechanismState },
}

export type ValidationIssue = {
	code: string,
	path: string,
	message: string,
}

export type ValidationReport = {
	ok: boolean,
	issues: { ValidationIssue },
}

export type StableIdParts = {
	namespace: string,
	parts: { string },
}

local ObjectGenome = {}

ObjectGenome.SCHEMA_VERSION = 1
ObjectGenome.STATE_VERSION = 1
ObjectGenome.STABLE_ID_NAMESPACE = "objectgenome"
ObjectGenome.GROUND_KEY = "$ground"
ObjectGenome.MASS_TOLERANCE_FRACTION = 0.15

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isPositive(value: number): boolean
	return isFinite(value) and value > 0
end

local function isUnitInterval(value: number): boolean
	return isFinite(value) and value >= 0 and value <= 1
end

local function isPositiveDimensions(value: Dimensions3): boolean
	return isPositive(value.widthM) and isPositive(value.heightM) and isPositive(value.depthM)
end

local function addIssue(issues: { ValidationIssue }, code: string, path: string, message: string): ()
	table.insert(issues, {
		code = code,
		path = path,
		message = message,
	})
end

local function validateRange(issues: { ValidationIssue }, path: string, value: NumberRange): boolean
	if not isPositive(value.min) or not isPositive(value.max) then
		addIssue(issues, "invalid_range", path, "range bounds must be finite and positive")
		return false
	end
	if value.min > value.max then
		addIssue(issues, "invalid_range", path, "range min must not exceed max")
		return false
	end
	return true
end

local function inRange(value: number, bounds: NumberRange): boolean
	return value >= bounds.min and value <= bounds.max
end

local function vecMagnitudeSquared(value: Vec3): number
	return value.x * value.x + value.y * value.y + value.z * value.z
end

local function normalizedRegionCoordinate(value: Vec3): boolean
	return isUnitInterval(value.x) and isUnitInterval(value.y) and isUnitInterval(value.z)
end

local function positiveNormalizedRegionSize(value: Vec3): boolean
	return isFinite(value.x)
		and isFinite(value.y)
		and isFinite(value.z)
		and value.x > 0
		and value.x <= 1
		and value.y > 0
		and value.y <= 1
		and value.z > 0
		and value.z <= 1
end

local function mechanismComponentKeys(mechanism: MechanismSpec): { string }
	if mechanism.kind == "hinge" then
		return { mechanism.movingComponentKey, mechanism.anchorComponentKey }
	elseif mechanism.kind == "slide" then
		return { mechanism.movingComponentKey, mechanism.railComponentKey }
	elseif mechanism.kind == "caster" then
		return { mechanism.wheelComponentKey, mechanism.mountComponentKey }
	elseif mechanism.kind == "tilt" then
		return { mechanism.movingComponentKey, mechanism.supportComponentKey }
	else
		return { mechanism.movingComponentKey, mechanism.keeperComponentKey }
	end
end

-- StableId owns canonical hashing/encoding. ObjectGenome only owns the semantic
-- namespace and ordered parts so this module does not create a competing ID scheme.
function ObjectGenome.stableIdParts(familyId: string, familyVersion: number, variantKey: string): StableIdParts
	assert(familyId ~= "", "familyId required")
	assert(familyVersion >= 1 and familyVersion % 1 == 0, "familyVersion must be a positive integer")
	assert(variantKey ~= "", "variantKey required")
	return {
		namespace = ObjectGenome.STABLE_ID_NAMESPACE,
		parts = { familyId, tostring(familyVersion), variantKey },
	}
end

function ObjectGenome.validate(value: ObjectGenome): ValidationReport
	local issues = {} :: { ValidationIssue }

	if value.id == "" then
		addIssue(issues, "missing_id", "id", "ObjectGenome.id is required")
	end
	if value.schemaVersion ~= ObjectGenome.SCHEMA_VERSION then
		addIssue(
			issues,
			"unsupported_schema_version",
			"schemaVersion",
			`expected object schema version {ObjectGenome.SCHEMA_VERSION}`
		)
	end
	if value.familyId == "" then
		addIssue(issues, "missing_family_id", "familyId", "familyId is required")
	end
	if value.familyVersion < 1 or value.familyVersion % 1 ~= 0 then
		addIssue(issues, "invalid_family_version", "familyVersion", "familyVersion must be a positive integer")
	end
	if value.variantKey == "" then
		addIssue(issues, "missing_variant_key", "variantKey", "variantKey is required")
	end

	if value.manufacturer.manufacturerFamily == "" then
		addIssue(issues, "missing_manufacturer", "manufacturer.manufacturerFamily", "manufacturer family is required")
	end
	if value.manufacturer.productLine == "" then
		addIssue(issues, "missing_product_line", "manufacturer.productLine", "product line is required")
	end
	if value.manufacturer.apparentEra == "" then
		addIssue(issues, "missing_apparent_era", "manufacturer.apparentEra", "apparent era is required")
	end

	if not isPositiveDimensions(value.dimensionsM) then
		addIssue(issues, "invalid_dimensions", "dimensionsM", "all object dimensions must be finite and positive")
	end
	if not isPositive(value.massKg) then
		addIssue(issues, "invalid_mass", "massKg", "massKg must be finite and positive")
	end

	local widthRangeValid = validateRange(issues, "plausibility.widthM", value.plausibility.widthM)
	local heightRangeValid = validateRange(issues, "plausibility.heightM", value.plausibility.heightM)
	local depthRangeValid = validateRange(issues, "plausibility.depthM", value.plausibility.depthM)
	local massRangeValid = validateRange(issues, "plausibility.massKg", value.plausibility.massKg)

	if widthRangeValid and not inRange(value.dimensionsM.widthM, value.plausibility.widthM) then
		addIssue(issues, "implausible_dimension", "dimensionsM.widthM", "width is outside family plausibility bounds")
	end
	if heightRangeValid and not inRange(value.dimensionsM.heightM, value.plausibility.heightM) then
		addIssue(issues, "implausible_dimension", "dimensionsM.heightM", "height is outside family plausibility bounds")
	end
	if depthRangeValid and not inRange(value.dimensionsM.depthM, value.plausibility.depthM) then
		addIssue(issues, "implausible_dimension", "dimensionsM.depthM", "depth is outside family plausibility bounds")
	end
	if massRangeValid and not inRange(value.massKg, value.plausibility.massKg) then
		addIssue(issues, "implausible_mass", "massKg", "mass is outside family plausibility bounds")
	end

	if isPositiveDimensions(value.dimensionsM) then
		local halfWidth = value.dimensionsM.widthM * 0.5
		local halfHeight = value.dimensionsM.heightM * 0.5
		local halfDepth = value.dimensionsM.depthM * 0.5
		local center = value.centerOfMassM
		if
			not isFinite(center.x)
			or not isFinite(center.y)
			or not isFinite(center.z)
			or math.abs(center.x) > halfWidth
			or math.abs(center.y) > halfHeight
			or math.abs(center.z) > halfDepth
		then
			addIssue(issues, "invalid_center_of_mass", "centerOfMassM", "center of mass must lie inside object bounds")
		end
	end

	if #value.components == 0 then
		addIssue(issues, "missing_components", "components", "at least one component is required")
	end

	local componentByKey = {} :: { [string]: ComponentSpec }
	local totalComponentMass = 0
	for index, component in value.components do
		local path = `components[{index}]`
		if component.key == "" then
			addIssue(issues, "missing_component_key", path .. ".key", "component key is required")
		elseif component.key == ObjectGenome.GROUND_KEY then
			addIssue(issues, "reserved_component_key", path .. ".key", "component key collides with ground sentinel")
		elseif componentByKey[component.key] ~= nil then
			addIssue(issues, "duplicate_component_key", path .. ".key", `duplicate component key {component.key}`)
		else
			componentByKey[component.key] = component
		end
		if component.role == "" then
			addIssue(issues, "missing_component_role", path .. ".role", "component role is required")
		end
		if component.materialKey == "" then
			addIssue(issues, "missing_material_key", path .. ".materialKey", "indirect material key is required")
		end
		if not isPositive(component.massKg) then
			addIssue(issues, "invalid_component_mass", path .. ".massKg", "component mass must be finite and positive")
		else
			totalComponentMass += component.massKg
		end
		if not isPositiveDimensions(component.nominalDimensionsM) then
			addIssue(issues, "invalid_component_dimensions", path .. ".nominalDimensionsM", "component dimensions must be positive")
		end
	end

	if isPositive(value.massKg) and totalComponentMass > 0 then
		local differenceFraction = math.abs(totalComponentMass - value.massKg) / value.massKg
		if differenceFraction > ObjectGenome.MASS_TOLERANCE_FRACTION then
			addIssue(
				issues,
				"component_mass_mismatch",
				"components",
				`component masses differ from massKg by more than {ObjectGenome.MASS_TOLERANCE_FRACTION * 100}%`
			)
		end
	end

	local adjacency = {} :: { [string]: { string } }
	for key in componentByKey do
		adjacency[key] = {}
	end

	for index, link in value.supportLinks do
		local path = `supportLinks[{index}]`
		local supporterValid = link.supporterKey == ObjectGenome.GROUND_KEY or componentByKey[link.supporterKey] ~= nil
		local supportedValid = componentByKey[link.supportedKey] ~= nil
		if not supporterValid then
			addIssue(issues, "unknown_supporter", path .. ".supporterKey", `unknown supporter {link.supporterKey}`)
		end
		if not supportedValid then
			addIssue(issues, "unknown_supported_component", path .. ".supportedKey", `unknown component {link.supportedKey}`)
		end
		if link.supporterKey == link.supportedKey then
			addIssue(issues, "self_support", path, "a component cannot support itself")
		end
		if link.maxLoadKg ~= nil and not isPositive(link.maxLoadKg) then
			addIssue(issues, "invalid_max_load", path .. ".maxLoadKg", "maxLoadKg must be finite and positive when provided")
		end
		if supporterValid and supportedValid and link.supporterKey ~= ObjectGenome.GROUND_KEY and link.supporterKey ~= link.supportedKey then
			table.insert(adjacency[link.supporterKey], link.supportedKey)
		end
	end

	local visiting = {} :: { [string]: boolean }
	local visited = {} :: { [string]: boolean }
	local cycleReported = false
	local function visit(key: string): ()
		if visiting[key] == true then
			if not cycleReported then
				cycleReported = true
				addIssue(issues, "support_cycle", "supportLinks", `support graph contains a cycle involving {key}`)
			end
			return
		end
		if visited[key] == true then
			return
		end
		visiting[key] = true
		local children = adjacency[key]
		if children ~= nil then
			for _, childKey in children do
				visit(childKey)
			end
		end
		visiting[key] = false
		visited[key] = true
	end
	for key in componentByKey do
		visit(key)
	end

	local reachable = {} :: { [string]: boolean }
	local changed = true
	while changed do
		changed = false
		for _, link in value.supportLinks do
			if componentByKey[link.supportedKey] ~= nil then
				local supporterReached = link.supporterKey == ObjectGenome.GROUND_KEY or reachable[link.supporterKey] == true
				if supporterReached and reachable[link.supportedKey] ~= true then
					reachable[link.supportedKey] = true
					changed = true
				end
			end
		end
	end
	for key in componentByKey do
		if reachable[key] ~= true then
			addIssue(issues, "unsupported_component", "supportLinks", `component {key} has no support path to ground`)
		end
	end

	local mechanismByKey = {} :: { [string]: MechanismSpec }
	for index, mechanism in value.mechanisms do
		local path = `mechanisms[{index}]`
		if mechanism.key == "" then
			addIssue(issues, "missing_mechanism_key", path .. ".key", "mechanism key is required")
		elseif mechanismByKey[mechanism.key] ~= nil then
			addIssue(issues, "duplicate_mechanism_key", path .. ".key", `duplicate mechanism key {mechanism.key}`)
		else
			mechanismByKey[mechanism.key] = mechanism
		end
		for _, componentKey in mechanismComponentKeys(mechanism) do
			if componentByKey[componentKey] == nil then
				addIssue(issues, "unknown_mechanism_component", path, `mechanism references unknown component {componentKey}`)
			end
		end

		if mechanism.kind == "hinge" then
			if vecMagnitudeSquared(mechanism.axis) <= 0 or not isFinite(vecMagnitudeSquared(mechanism.axis)) then
				addIssue(issues, "invalid_hinge_axis", path .. ".axis", "hinge axis must be finite and non-zero")
			end
			if mechanism.minAngleDeg > mechanism.maxAngleDeg then
				addIssue(issues, "invalid_hinge_range", path, "hinge minAngleDeg must not exceed maxAngleDeg")
			end
			if not isFinite(mechanism.damping) or mechanism.damping < 0 then
				addIssue(issues, "invalid_damping", path .. ".damping", "damping must be finite and non-negative")
			end
		elseif mechanism.kind == "slide" then
			if not isPositive(mechanism.travelM) then
				addIssue(issues, "invalid_slide_travel", path .. ".travelM", "slide travel must be finite and positive")
			end
			if not isFinite(mechanism.damping) or mechanism.damping < 0 then
				addIssue(issues, "invalid_damping", path .. ".damping", "damping must be finite and non-negative")
			end
		elseif mechanism.kind == "caster" then
			if not isPositive(mechanism.radiusM) or not isPositive(mechanism.widthM) then
				addIssue(issues, "invalid_caster_dimensions", path, "caster radius and width must be finite and positive")
			end
		elseif mechanism.kind == "tilt" then
			if mechanism.minAngleDeg > mechanism.maxAngleDeg then
				addIssue(issues, "invalid_tilt_range", path, "tilt minAngleDeg must not exceed maxAngleDeg")
			end
			if not isFinite(mechanism.springStrength) or mechanism.springStrength < 0 then
				addIssue(issues, "invalid_spring_strength", path .. ".springStrength", "springStrength must be finite and non-negative")
			end
			if not isFinite(mechanism.damping) or mechanism.damping < 0 then
				addIssue(issues, "invalid_damping", path .. ".damping", "damping must be finite and non-negative")
			end
		else
			if not isPositive(mechanism.breakForceN) then
				addIssue(issues, "invalid_break_force", path .. ".breakForceN", "breakForceN must be finite and positive")
			end
		end
	end

	local affordanceKeys = {} :: { [string]: boolean }
	for index, affordance in value.affordances do
		local path = `affordances[{index}]`
		if affordance.key == "" then
			addIssue(issues, "missing_affordance_key", path .. ".key", "affordance key is required")
		elseif affordanceKeys[affordance.key] == true then
			addIssue(issues, "duplicate_affordance_key", path .. ".key", `duplicate affordance key {affordance.key}`)
		else
			affordanceKeys[affordance.key] = true
		end
		if componentByKey[affordance.componentKey] == nil then
			addIssue(issues, "unknown_affordance_component", path .. ".componentKey", `unknown component {affordance.componentKey}`)
		end
		if not normalizedRegionCoordinate(affordance.center01) then
			addIssue(issues, "invalid_affordance_center", path .. ".center01", "affordance center must be finite and in [0, 1]")
		end
		if not positiveNormalizedRegionSize(affordance.size01) then
			addIssue(issues, "invalid_affordance_size", path .. ".size01", "affordance size must be finite and in (0, 1]")
		end
	end

	return {
		ok = #issues == 0,
		issues = issues,
	}
end

function ObjectGenome.assertValid(value: ObjectGenome): ()
	local report = ObjectGenome.validate(value)
	if not report.ok then
		local first = report.issues[1]
		error(`invalid ObjectGenome [{first.code}] {first.path}: {first.message}`, 2)
	end
end

function ObjectGenome.newState(value: ObjectGenome): ObjectState
	local componentState = {} :: { [string]: ComponentState }
	for _, component in value.components do
		componentState[component.key] = {
			wear = 0,
			damage = 0,
		}
	end
	local mechanismState = {} :: { [string]: MechanismState }
	for _, mechanism in value.mechanisms do
		mechanismState[mechanism.key] = {
			position01 = 0,
			locked = if mechanism.kind == "latch" then mechanism.defaultLatched else false,
		}
	end
	return {
		stateVersion = ObjectGenome.STATE_VERSION,
		componentState = componentState,
		mechanismState = mechanismState,
	}
end

function ObjectGenome.validateState(value: ObjectGenome, state: ObjectState): ValidationReport
	local issues = {} :: { ValidationIssue }
	if state.stateVersion ~= ObjectGenome.STATE_VERSION then
		addIssue(issues, "unsupported_state_version", "stateVersion", `expected state version {ObjectGenome.STATE_VERSION}`)
	end

	local expectedComponents = {} :: { [string]: boolean }
	for _, component in value.components do
		expectedComponents[component.key] = true
		local componentState = state.componentState[component.key]
		if componentState == nil then
			addIssue(issues, "missing_component_state", "componentState", `missing state for component {component.key}`)
		elseif not isUnitInterval(componentState.wear) or not isUnitInterval(componentState.damage) then
			addIssue(issues, "invalid_component_state", `componentState.{component.key}`, "wear and damage must be in [0, 1]")
		end
	end
	for key in state.componentState do
		if expectedComponents[key] ~= true then
			addIssue(issues, "unknown_component_state", `componentState.{key}`, "state references a component not present in the genome")
		end
	end

	local expectedMechanisms = {} :: { [string]: boolean }
	for _, mechanism in value.mechanisms do
		expectedMechanisms[mechanism.key] = true
		local mechanismState = state.mechanismState[mechanism.key]
		if mechanismState == nil then
			addIssue(issues, "missing_mechanism_state", "mechanismState", `missing state for mechanism {mechanism.key}`)
		elseif not isUnitInterval(mechanismState.position01) then
			addIssue(issues, "invalid_mechanism_state", `mechanismState.{mechanism.key}.position01`, "position01 must be in [0, 1]")
		end
	end
	for key in state.mechanismState do
		if expectedMechanisms[key] ~= true then
			addIssue(issues, "unknown_mechanism_state", `mechanismState.{key}`, "state references a mechanism not present in the genome")
		end
	end

	return {
		ok = #issues == 0,
		issues = issues,
	}
end

return table.freeze(ObjectGenome)
