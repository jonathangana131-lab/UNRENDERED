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
	table.insert(tableComponents, {
		key = `leg-{leg.name}`,
		role = "load-bearing leg",
		materialKey = "material.v1.office-metal.gray-painted-steel",
		materialRecipeVersion = 1,
		massKg = 2.4,
		localPositionM = { x = leg.x, y = -0.03, z = leg.z },
		localRotationDeg = zero,
		dimensionsM = { x = 0.06, y = 0.70, z = 0.06 },
		supportKeys = {},
		externalSupport = "ground",
	})
end
local allLegs: { string } = { "leg-front-left", "leg-front-right", "leg-rear-left", "leg-rear-right" }
table.insert(tableComponents, {
	key = "crossbar",
	role = "anti-racking brace",
	materialKey = "material.v1.office-metal.gray-painted-steel",
	materialRecipeVersion = 1,
	massKg = 2.0,
	localPositionM = { x = 0, y = 0.15, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 1.30, y = 0.08, z = 0.06 },
	supportKeys = allLegs,
	externalSupport = "none",
})
table.insert(tableComponents, {
	key = "top",
	role = "laminated work surface",
	materialKey = "material.v1.laminate-particleboard.beige",
	materialRecipeVersion = 1,
	massKg = 15.4,
	localPositionM = { x = 0, y = 0.33, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 1.50, y = 0.10, z = 0.75 },
	supportKeys = allLegs,
	externalSupport = "none",
})
local officeTable: Genome = {
	schemaVersion = 1,
	familyId = "office-table.utility",
	familyVersion = 1,
	variantKey = "rectangular",
	provenance = {
		manufacturerFamily = "Northfield Contract Furnishings",
		productLine = "Municipal Utility Series",
		apparentEra = "1989-1998",
	},
	dimensionsM = { x = 1.50, y = 0.76, z = 0.75 },
	dimensionLimits = {
		minM = { x = 1.10, y = 0.70, z = 0.60 },
		maxM = { x = 1.90, y = 0.82, z = 0.90 },
	},
	massKg = 27.0,
	massLimitsKg = { min = 20.0, max = 36.0 },
	centerOfMassM = { x = 0, y = 0.08, z = 0 },
	components = tableComponents,
	mechanisms = {},
	affordances = {
		{
			key = "grip-left-edge",
			kind = "grip",
			componentKey = "top",
			localPointM = { x = -0.70, y = 0, z = 0 },
			radiusM = 0.08,
		},
	},
}

local cabinetComponents: { ComponentSpec } = {
	{
		key = "shell",
		role = "load-bearing folded steel carcass",
		materialKey = "material.v1.office-metal.warm-gray-enamel",
		materialRecipeVersion = 1,
		massKg = 24.0,
		localPositionM = zero,
		localRotationDeg = zero,
		dimensionsM = { x = 0.48, y = 1.32, z = 0.62 },
		supportKeys = {},
		externalSupport = "ground",
	},
}
local cabinetMechanisms: { MechanismSpec } = {}
local cabinetAffordances: { AffordanceSpec } = {}
local drawerPositions: { DrawerPosition } = {
	{ name = "top", y = 0.38 },
	{ name = "middle", y = 0.05 },
	{ name = "bottom", y = -0.28 },
}
for _, drawer in ipairs(drawerPositions) do
	local key = `drawer-{drawer.name}`
	table.insert(cabinetComponents, {
		key = key,
		role = "document drawer",
		materialKey = "material.v1.office-metal.warm-gray-enamel",
		materialRecipeVersion = 1,
		massKg = 4.2,
		localPositionM = { x = 0, y = drawer.y, z = -0.01 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.42, y = 0.28, z = 0.52 },
		supportKeys = { "shell" },
		externalSupport = "none",
	})
	table.insert(cabinetMechanisms, {
		key = `slide-{drawer.name}`,
		kind = "slide",
		movingComponentKey = key,
		frameComponentKey = "shell",
		axis = { x = 0, y = 0, z = -1 },
		minTravelM = 0,
		maxTravelM = 0.44,
	})
	table.insert(cabinetAffordances, {
		key = `pull-{drawer.name}`,
		kind = "pull",
		componentKey = key,
		localPointM = { x = 0, y = 0, z = -0.25 },
		radiusM = 0.06,
	})
end

table.insert(cabinetMechanisms, {
	key = "latch-top",
	kind = "latch",
	movingComponentKey = "drawer-top",
	catchComponentKey = "shell",
	engagementDistanceM = 0.008,
})
local filingCabinet: Genome = {
	schemaVersion = 1,
	familyId = "filing-cabinet.vertical",
	familyVersion = 1,
	variantKey = "three-drawer",
	provenance = {
		manufacturerFamily = "Keystone Office Systems",
		productLine = "Recordsafe 300",
		apparentEra = "1991-2004",
	},
	dimensionsM = { x = 0.48, y = 1.32, z = 0.62 },
	dimensionLimits = {
		minM = { x = 0.42, y = 1.15, z = 0.55 },
		maxM = { x = 0.55, y = 1.45, z = 0.72 },
	},
	massKg = 36.6,
	massLimitsKg = { min = 28.0, max = 48.0 },
	centerOfMassM = { x = 0, y = -0.06, z = 0.01 },
	components = cabinetComponents,
	mechanisms = cabinetMechanisms,
	affordances = cabinetAffordances,
}

return table.freeze({
	officeChair = ObjectGenomeOwnership.own(officeChair),
	officeTable = ObjectGenomeOwnership.own(officeTable),
	filingCabinet = ObjectGenomeOwnership.own(filingCabinet),
})
