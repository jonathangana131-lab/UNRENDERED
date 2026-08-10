--!strict

-- Production-contract examples. Material keys are opaque references on purpose:
-- ObjectGenome must not own MaterialDNA's schema or Roblox asset bindings.
local Fixtures = {}

local zero = { x = 0, y = 0, z = 0 }

local chairComponents = {}
local chairMechanisms = {}
local casterPositions = {
	{ "front-left", -0.27, -0.22 },
	{ "front-right", 0.27, -0.22 },
	{ "rear-left", -0.27, 0.22 },
	{ "rear-right", 0.27, 0.22 },
	{ "center-rear", 0, 0.28 },
}
for _, caster in ipairs(casterPositions) do
	local key = `caster-{caster[1]}`
	table.insert(chairComponents, {
		key = key,
		role = "floor-contact caster",
		materialKey = "material:polymer-rubber.caster.v1",
		massKg = 0.35,
		localPositionM = { x = caster[2], y = -0.49, z = caster[3] },
		localRotationDeg = zero,
		dimensionsM = { x = 0.09, y = 0.08, z = 0.04 },
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
	materialKey = "material:painted-steel.black.v1",
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
	materialKey = "material:steel-mechanism.dark.v1",
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
	materialKey = "material:fabric-foam.charcoal.v1",
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
	materialKey = "material:fabric-foam.charcoal.v1",
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
		materialKey = "material:polypropylene.black.v1",
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

Fixtures.officeChair = {
	schemaVersion = 1,
	familyId = "office-chair.task",
	familyVersion = 1,
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
	centerOfMassM = { x = 0, y = -0.02, z = 0.01 },
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

local tableComponents = {}
for _, leg in ipairs({
	{ "front-left", -0.68, -0.30 },
	{ "front-right", 0.68, -0.30 },
	{ "rear-left", -0.68, 0.30 },
	{ "rear-right", 0.68, 0.30 },
}) do
	table.insert(tableComponents, {
		key = `leg-{leg[1]}`,
		role = "load-bearing leg",
		materialKey = "material:painted-steel.gray.v1",
		massKg = 2.4,
		localPositionM = { x = leg[2], y = -0.03, z = leg[3] },
		localRotationDeg = zero,
		dimensionsM = { x = 0.06, y = 0.70, z = 0.06 },
		supportKeys = {},
		externalSupport = "ground",
	})
end
local allLegs = { "leg-front-left", "leg-front-right", "leg-rear-left", "leg-rear-right" }
table.insert(tableComponents, {
	key = "crossbar",
	role = "anti-racking brace",
	materialKey = "material:painted-steel.gray.v1",
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
	materialKey = "material:laminate-particleboard.beige.v1",
	massKg = 15.4,
	localPositionM = { x = 0, y = 0.33, z = 0 },
	localRotationDeg = zero,
	dimensionsM = { x = 1.50, y = 0.10, z = 0.75 },
	supportKeys = allLegs,
	externalSupport = "none",
})
Fixtures.officeTable = {
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

local cabinetComponents = {
	{
		key = "shell",
		role = "load-bearing folded steel carcass",
		materialKey = "material:painted-steel.warm-gray.v1",
		massKg = 24.0,
		localPositionM = zero,
		localRotationDeg = zero,
		dimensionsM = { x = 0.48, y = 1.32, z = 0.62 },
		supportKeys = {},
		externalSupport = "ground",
	},
}
local cabinetMechanisms = {}
local cabinetAffordances = {}
for _, drawer in ipairs({
	{ "top", 0.38 },
	{ "middle", 0.05 },
	{ "bottom", -0.28 },
}) do
	local key = `drawer-{drawer[1]}`
	table.insert(cabinetComponents, {
		key = key,
		role = "document drawer",
		materialKey = "material:painted-steel.warm-gray.v1",
		massKg = 4.2,
		localPositionM = { x = 0, y = drawer[2], z = -0.01 },
		localRotationDeg = zero,
		dimensionsM = { x = 0.42, y = 0.28, z = 0.52 },
		supportKeys = { "shell" },
		externalSupport = "none",
	})
	table.insert(cabinetMechanisms, {
		key = `slide-{drawer[1]}`,
		kind = "slide",
		movingComponentKey = key,
		frameComponentKey = "shell",
		axis = { x = 0, y = 0, z = -1 },
		minTravelM = 0,
		maxTravelM = 0.44,
	})
	table.insert(cabinetAffordances, {
		key = `pull-{drawer[1]}`,
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
Fixtures.filingCabinet = {
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

return table.freeze(Fixtures)
