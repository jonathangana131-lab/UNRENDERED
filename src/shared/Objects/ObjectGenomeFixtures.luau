--!strict

local ObjectGenome = require("./ObjectGenome")
local ObjectGenomeOwnership = require("./ObjectGenomeOwnership")

type Vec3 = ObjectGenome.Vec3
type ComponentSpec = ObjectGenome.ComponentSpec
type MechanismSpec = ObjectGenome.MechanismSpec
type AffordanceSpec = ObjectGenome.AffordanceSpec
type Genome = ObjectGenome.ObjectGenome

type PlanarPosition = {
	name: string,
	x: number,
	z: number,
}

type DrawerPosition = {
	name: string,
	y: number,
}

-- Production-contract examples pin an exact project material recipe id + revision.
-- ObjectGenome does not own MaterialDNA's schema implementation or Roblox asset bindings.
local zero: Vec3 = { x = 0, y = 0, z = 0 }

local chairComponents: { ComponentSpec } = {}
local chairMechanisms: { MechanismSpec } = {}
local casterPositions: { PlanarPosition } = {
	{ name = "front-left", x = -0.27, z = -0.22 },
	{ name = "front-right", x = 0.27, z = -0.22 },
	{ name = "rear-left", x = -0.27, z = 0.22 },
	{ name = "rear-right", x = 0.27, z = 0.22 },
	{ name = "center-rear", x = 0, z = 0.28 },
}
for _, caster in ipairs(casterPositions) do
	local key = `caster-{caster.name}`
	table.insert(chairComponents, {
		key = key,
		role = "floor-contact caster",
		materialKey = "material.v1.chair-caster.polymer-rubber",
		materialRecipeVersion = 1,
		massKg = 0.35,
		localPositionM = { x = caster.x, y = -0.495, z = caster.z },
		localRotationDeg = zero,
		dimensionsM = { x = 0.09, y = 0.09, z = 0.04 },
		supportKeys = {},
		externalSupport = "ground",
	})
	table.insert(chairMechanisms, {
		key = `{key}-swivel`,
		kind = "caster",
		movingComponentKey = key,
		frameComponentKey = "base",
		wheelRadiusM = 0.028,
		swivelAxis = { x = 0, y = 1, z = 0 },
		rollAxis = { x = 1, y = 0, z = 0 },
	})
end

table.insert(chairComponents, {
	key = "base",
	role = "five-star load-bearing base",
	materialKey = "material.v1.office-metal.black-painted-steel",
	materialRecipeVersion = 1,
	massKg = 1.8,
	localPositionM = { x = 0, y = -0.42, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.58, y = 0.06, z = 0.58 },
	supportKeys = {
		"caster-front-left",
		"caster-front-right",
		"caster-rear-left",
		"caster-rear-right",
		"caster-center-rear",
	},
	externalSupport = "none",
})
table.insert(chairComponents, {
	key = "lift-column",
	role = "height and tilt support column",
	materialKey = "material.v1.mechanism-steel.dark",
	materialRecipeVersion = 1,
	massKg = 1.4,
	localPositionM = { x = 0, y = -0.23, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.08, y = 0.38, z = 0.08 },
	supportKeys = { "base" },
	externalSupport = "none",
})
table.insert(chairComponents, {
	key = "seat",
	role = "upholstered seat pan",
	materialKey = "material.v1.upholstery.charcoal-fabric-foam",
	materialRecipeVersion = 1,
	massKg = 3.4,
	localPositionM = { x = 0, y = 0, z = -0.01 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.50, y = 0.09, z = 0.48 },
	supportKeys = { "lift-column" },
	externalSupport = "none",
})
table.insert(chairComponents, {
	key = "back",
	role = "upholstered back rest",
	materialKey = "material.v1.upholstery.charcoal-fabric-foam",
	materialRecipeVersion = 1,
	massKg = 2.0,
	localPositionM = { x = 0, y = 0.28, z = 0.20 },
	localRotationDeg = zero,
	dimensionsM = { x = 0.48, y = 0.48, z = 0.07 },
	supportKeys = { "seat" },
	externalSupport = "none",
})
for _, side in ipairs({ -1, 1 }) do
	table.insert(chairComponents, {
		key = if side < 0 then "arm-left" else "arm-right",
		role = "arm support",
		materialKey = "material.v1.polypropylene.black",
		materialRecipeVersion = 1,
		massKg = 0.75,
		localPositionM = { x = side * 0.27, y = 0.12, z = 0.02 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.06, y = 0.20, z = 0.38 },
		supportKeys = { "seat" },
		externalSupport = "none",
	})
end

table.insert(chairMechanisms, {
	key = "seat-tilt",
	kind = "tilt",
	movingComponentKey = "seat",
	frameComponentKey = "lift-column",
	axis = { x = 1, y = 0, z = 0 },
	minDegrees = -8,
	maxDegrees = 14,
})

local officeChair: Genome = {
	schemaVersion = 1,
	familyId = "office-chair.task",
	familyVersion = 2,
	variantKey = "standard",
	provenance = {
		manufacturerFamily = "Northfield Contract Furnishings",
		productLine = "Civic Task 94",
		apparentEra = "1994-2002",
	},
	dimensionsM = { x = 0.68, y = 1.08, z = 0.68 },
	dimensionLimits = {
		minM = { x = 0.58, y = 0.90, z = 0.58 },
		maxM = { x = 0.78, y = 1.25, z = 0.78 },
	},
	massKg = 11.85,
	massLimitsKg = { min = 9.0, max = 18.0 },
	centerOfMassM = { x = 0, y = -0.10162447257383965, z = 0.04168776371308017 },
	components = chairComponents,
	mechanisms = chairMechanisms,
	affordances = {
		{
			key = "sit-seat",
			kind = "sit",
			componentKey = "seat",
			localPointM = { x = 0, y = 0.04, z = 0 },
			radiusM = 0.20,
		},
		{
			key = "grip-back-top",
			kind = "grip",
			componentKey = "back",
			localPointM = { x = 0, y = 0.20, z = 0 },
			radiusM = 0.08,
		},
	},
}

local tableComponents: { ComponentSpec } = {}
local tableLegPositions: { PlanarPosition } = {
	{ name = "front-left", x = -0.68, z = -0.30 },
	{ name = "front-right", x = 0.68, z = -0.30 },
	{ name = "rear-left", x = -0.68, z = 0.30 },
	{ name = "rear-right", x = 0.68, z = 0.30 },
}
for _, leg in ipairs(tableLegPositions) do
	table.insert(chairComponents, {})
end
