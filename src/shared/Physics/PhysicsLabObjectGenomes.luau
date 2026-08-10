--!strict

local ObjectGenome = require(script.Parent.Parent.Objects.ObjectGenome)
local ObjectGenomeOwnership = require(script.Parent.Parent.Objects.ObjectGenomeOwnership)

type Vec3 = ObjectGenome.Vec3
type ComponentSpec = ObjectGenome.ComponentSpec
type MechanismSpec = ObjectGenome.MechanismSpec
type AffordanceSpec = ObjectGenome.AffordanceSpec
type Genome = ObjectGenome.ObjectGenome

local zero: Vec3 = table.freeze({ x = 0, y = 0, z = 0 })

local doorComponents: { ComponentSpec } = {
	{
		key = "jamb-hinge",
		role = "ground-supported hinge-side commercial door jamb",
		materialKey = "material.v1.office-metal.warm-gray-enamel",
		materialRecipeVersion = 1,
		massKg = 6.5,
		localPositionM = { x = -0.55, y = -0.06, z = 0 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.08, y = 2.04, z = 0.12 },
		supportKeys = {},
		externalSupport = "ground",
	},
	{
		key = "jamb-strike",
		role = "ground-supported strike-side commercial door jamb",
		materialKey = "material.v1.office-metal.warm-gray-enamel",
		materialRecipeVersion = 1,
		massKg = 6.5,
		localPositionM = { x = 0.55, y = -0.06, z = 0 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.08, y = 2.04, z = 0.12 },
		supportKeys = {},
		externalSupport = "ground",
	},
	{
		key = "header",
		role = "commercial door frame header spanning both jambs",
		materialKey = "material.v1.office-metal.warm-gray-enamel",
		materialRecipeVersion = 1,
		massKg = 5,
		localPositionM = { x = 0, y = 1.02, z = 0 },
		localRotationDeg = zero,
		dimensionsM = { x = 1.18, y = 0.12, z = 0.12 },
		supportKeys = { "jamb-hinge", "jamb-strike" },
		externalSupport = "none",
	},
	{
		key = "leaf",
		role = "solid-core hinged door leaf",
		materialKey = "material.v1.office-metal.gray-painted-steel",
		materialRecipeVersion = 1,
		massKg = 26,
		localPositionM = { x = 0, y = -0.06, z = -0.025 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.92, y = 2.02, z = 0.045 },
		supportKeys = { "jamb-hinge" },
		externalSupport = "none",
	},
}

local doorMechanisms: { MechanismSpec } = {
	{
		key = "leaf-hinge",
		kind = "hinge",
		movingComponentKey = "leaf",
		frameComponentKey = "jamb-hinge",
		axis = { x = 0, y = 1, z = 0 },
		minDegrees = 0,
		maxDegrees = 105,
	},
}

local doorAffordances: { AffordanceSpec } = {
	{
		key = "pull-leaf",
		kind = "pull",
		componentKey = "leaf",
		localPointM = { x = 0.35, y = 0, z = -0.02 },
		radiusM = 0.06,
	},
}

local commercialDoor: Genome = {
	schemaVersion = ObjectGenome.SCHEMA_VERSION,
	familyId = "lab-door.commercial",
	familyVersion = 1,
	variantKey = "single-leaf",
	provenance = {
		manufacturerFamily = "Northfield Architectural Hardware",
		productLine = "Service 90",
		apparentEra = "1990-2000",
	},
	dimensionsM = { x = 1.18, y = 2.16, z = 0.14 },
	dimensionLimits = {
		minM = { x = 1.0, y = 2.0, z = 0.10 },
		maxM = { x = 1.35, y = 2.35, z = 0.20 },
	},
	massKg = 44,
	massLimitsKg = { min = 35, max = 60 },
	centerOfMassM = { x = 0, y = 0.063, z = -0.01 },
	components = doorComponents,
	mechanisms = doorMechanisms,
	affordances = doorAffordances,
}

local cartComponents: { ComponentSpec } = {}
local cartMechanisms: { MechanismSpec } = {}
local casterPositions = {
	{ name = "front-left", x = -0.34, z = -0.20 },
	{ name = "front-right", x = 0.34, z = -0.20 },
	{ name = "rear-left", x = -0.34, z = 0.20 },
	{ name = "rear-right", x = 0.34, z = 0.20 },
}

for _, caster in ipairs(casterPositions) do
	local key = `caster-{caster.name}`
	table.insert(cartComponents, {
		key = key,
		role = "floor-contact swivel caster",
		materialKey = "material.v1.chair-caster.polymer-rubber",
		materialRecipeVersion = 1,
		massKg = 0.4,
		localPositionM = { x = caster.x, y = -0.42, z = caster.z },
		localRotationDeg = zero,
		dimensionsM = { x = 0.10, y = 0.10, z = 0.05 },
		supportKeys = {},
		externalSupport = "ground",
	})
	table.insert(cartMechanisms, {
		key = `{key}-swivel`,
		kind = "caster",
		movingComponentKey = key,
		frameComponentKey = "chassis",
		wheelRadiusM = 0.035,
		swivelAxis = { x = 0, y = 1, z = 0 },
		rollAxis = { x = 1, y = 0, z = 0 },
	})
end

local casterKeys = {
	"caster-front-left",
	"caster-front-right",
	"caster-rear-left",
	"caster-rear-right",
}

table.insert(cartComponents, {
	key = "chassis",
	role = "load-bearing welded cart chassis",
	materialKey = "material.v1.office-metal.warm-gray-enamel",
	materialRecipeVersion = 1,
	massKg = 8,
	localPositionM = { x = 0, y = -0.33, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.80, y = 0.08, z = 0.50 },
	supportKeys = casterKeys,
	externalSupport = "none",
})

table.insert(cartComponents, {
	key = "lower-shelf",
	role = "lower utility shelf",
	materialKey = "material.v1.office-metal.warm-gray-enamel",
	materialRecipeVersion = 1,
	massKg = 3,
	localPositionM = { x = 0, y = -0.08, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.78, y = 0.05, z = 0.48 },
	supportKeys = { "chassis" },
	externalSupport = "none",
})

table.insert(cartComponents, {
	key = "upper-shelf",
	role = "upper utility shelf and push surface",
	materialKey = "material.v1.office-metal.warm-gray-enamel",
	materialRecipeVersion = 1,
	massKg = 3,
	localPositionM = { x = 0, y = 0.28, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.78, y = 0.05, z = 0.48 },
	supportKeys = { "chassis" },
	externalSupport = "none",
})

local cartAffordances: { AffordanceSpec } = {
	{
		key = "grip-upper-edge",
		kind = "grip",
		componentKey = "upper-shelf",
		localPointM = { x = 0.34, y = 0, z = 0.18 },
		radiusM = 0.07,
	},
}

local rollingCart: Genome = {
	schemaVersion = ObjectGenome.SCHEMA_VERSION,
	familyId = "lab-cart.utility",
	familyVersion = 1,
	variantKey = "two-shelf",
	provenance = {
		manufacturerFamily = "Keystone Institutional Equipment",
		productLine = "Transit 80",
		apparentEra = "1988-2001",
	},
	dimensionsM = { x = 0.90, y = 0.95, z = 0.58 },
	dimensionLimits = {
		minM = { x = 0.72, y = 0.75, z = 0.45 },
		maxM = { x = 1.05, y = 1.10, z = 0.72 },
	},
	massKg = 15.6,
	massLimitsKg = { min = 12, max = 24 },
	centerOfMassM = { x = 0, y = -0.12, z = 0 },
	components = cartComponents,
	mechanisms = cartMechanisms,
	affordances = cartAffordances,
}

return table.freeze({
	commercialDoor = ObjectGenomeOwnership.own(commercialDoor),
	rollingCart = ObjectGenomeOwnership.own(rollingCart),
})