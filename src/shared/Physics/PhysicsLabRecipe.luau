--!strict

local StableId = require(script.Parent.Parent.Core.StableId)
local MaterialDNA = require(script.Parent.Parent.Materials.MaterialDNA)
local ObjectGenome = require(script.Parent.Parent.Objects.ObjectGenome)
local ObjectGenomeFixtures = require(script.Parent.Parent.Objects.ObjectGenomeFixtures)
local ResolvedRegionRecipe = require(script.Parent.Parent.Reality.ResolvedRegionRecipe)
local WorldEntity = require(script.Parent.Parent.Reality.WorldEntity)
local PhysicsLabObjectGenomes = require(script.Parent.PhysicsLabObjectGenomes)

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type MaterialReference = {
	id: string,
	recipeVersion: number,
}

export type PrimitiveEntityRecipe = {
	kind: "primitive",
	key: string,
	entity: WorldEntity.WorldEntityRecord,
	role: string,
	sizeM: Vec3,
	positionM: Vec3,
	rotationDeg: Vec3,
	material: MaterialReference,
	collidable: boolean,
	transparency: number,
}

export type ObjectGenomeKey =
	"officeChair"
	| "officeTable"
	| "filingCabinet"
	| "commercialDoor"
	| "rollingCart"

export type ObjectEntityRecipe = {
	kind: "object",
	key: string,
	entity: WorldEntity.WorldEntityRecord,
	genomeKey: ObjectGenomeKey,
	genomeId: string,
	genomeRecipeFingerprint: string,
	positionM: Vec3,
	rotationDeg: Vec3,
}

export type EntityRecipe = PrimitiveEntityRecipe | ObjectEntityRecipe

export type PhysicsLabRecipe = {
	schemaVersion: number,
	recipeKey: string,
	worldId: string,
	regionId: string,
	resolvedRegion: ResolvedRegionRecipe.Recipe,
	entities: { EntityRecipe },
}

local PhysicsLabRecipe = {}

PhysicsLabRecipe.SCHEMA_VERSION = 2
PhysicsLabRecipe.GENERATOR_VERSION = 2
PhysicsLabRecipe.RECIPE_KEY = "physics-lab.hero-gate.v2"

local WORLD_ID = StableId.fromParts("world", { "physics-lab", "hero-gate", "v1" })
-- This is established lab truth, so generator versions are pinned explicitly instead of
-- consulting currentGeneratorVersions() and silently drifting when future generators land.
local RESOLVED_REGION = ResolvedRegionRecipe.lock({
	worldSeedRef = "physics-lab.hero-gate.world-seed.v1",
	regionAddress = {
		x = 0,
		z = 0,
		layer = 0,
	},
	generatorVersions = {
		reality = 1,
		topology = 1,
		material = 1,
		object = 1,
		entity = 1,
	},
	semanticIntentKey = "physics-lab.hero-gate.office-bay.v1",
	topologyAnchors = {
		"front-threshold/door-main",
	},
	canonicalContentKeys = {
		"floor",
		"ceiling",
		"wall-left",
		"wall-right",
		"wall-back",
		"wall-front-left",
		"wall-front-right",
		"wall-front-header",
		"ramp",
		"ledge",
		"stair-1",
		"stair-2",
		"stair-3",
		"stair-4",
		"character-spawn-anchor",
		"door-main",
		"chair-a",
		"table-a",
		"cabinet-a",
		"cart-a",
	},
})

local WALL_MATERIAL: MaterialReference = table.freeze({
	id = "material.v1.office-wallpaper.yellow-vinyl",
	recipeVersion = 1,
})
local FLOOR_MATERIAL: MaterialReference = table.freeze({
	id = "material.v1.office-carpet.low-pile-beige",
	recipeVersion = 1,
})
local METAL_MATERIAL: MaterialReference = table.freeze({
	id = "material.v1.office-metal.warm-gray-enamel",
	recipeVersion = 1,
})

local OBJECT_GENOMES: { [ObjectGenomeKey]: ObjectGenome.ObjectGenome } = table.freeze({
	officeChair = ObjectGenomeFixtures.officeChair,
	officeTable = ObjectGenomeFixtures.officeTable,
	filingCabinet = ObjectGenomeFixtures.filingCabinet,
	commercialDoor = PhysicsLabObjectGenomes.commercialDoor,
	rollingCart = PhysicsLabObjectGenomes.rollingCart,
})

local function vec3(x: number, y: number, z: number): Vec3
	return table.freeze({ x = x, y = y, z = z })
end

local ZERO = vec3(0, 0, 0)

local function entityId(key: string): string
	return StableId.fromParts("entity", { "physics-lab", "v1", key })
end

local function originFor(key: string): WorldEntity.GenerationOrigin
	return {
		worldId = WORLD_ID,
		regionId = RESOLVED_REGION.regionId,
		generator = "physics-lab.recipe",
		generatorVersion = PhysicsLabRecipe.GENERATOR_VERSION,
		recipeKey = `{PhysicsLabRecipe.RECIPE_KEY}/{key}`,
	}
end

local function primitive(
	key: string,
	role: string,
	sizeM: Vec3,
	positionM: Vec3,
	rotationDeg: Vec3,
	material: MaterialReference,
	collidable: boolean,
	transparency: number?
): PrimitiveEntityRecipe
	local materialValidation = MaterialDNA.validateReference(material)
	assert(
		materialValidation.ok,
		`invalid Physics Lab primitive material reference: {table.concat(materialValidation.errors, "; ")}`
	)
	local resolvedTransparency = transparency or 0
	assert(
		resolvedTransparency >= 0 and resolvedTransparency <= 1,
		"Physics Lab primitive transparency must be in [0, 1]"
	)
	local recipe: PrimitiveEntityRecipe = {
		kind = "primitive",
		key = key,
		entity = WorldEntity.new({
			id = entityId(key),
			kind = "physics-lab-primitive",
			origin = originFor(key),
			fidelity = "F2",
			persistentState = {},
		}),
		role = role,
		sizeM = sizeM,
		positionM = positionM,
		rotationDeg = rotationDeg,
		material = material,
		collidable = collidable,
		transparency = resolvedTransparency,
	}
	return table.freeze(recipe)
end

local function objectEntity(
	key: string,
	genomeKey: ObjectGenomeKey,
	positionM: Vec3,
	rotationDeg: Vec3
): ObjectEntityRecipe
	local genome = OBJECT_GENOMES[genomeKey]
	assert(genome ~= nil, `unknown Physics Lab ObjectGenome key {genomeKey}`)
	ObjectGenome.validate(genome)
	local defaultState = ObjectGenome.defaultState(genome)
	local recipe: ObjectEntityRecipe = {
		kind = "object",
		key = key,
		entity = WorldEntity.new({
			id = entityId(key),
			kind = `object/{genome.familyId}`,
			origin = originFor(key),
			fidelity = "F2",
			-- WorldEntity.new owns and runtime-validates this plain ObjectGenome state.
			-- ObjectState's static shape is intentionally richer than PlainData's alias.
			persistentState = defaultState :: any,
		}),
		genomeKey = genomeKey,
		genomeId = ObjectGenome.identityKey(genome),
		genomeRecipeFingerprint = ObjectGenome.recipeFingerprint(genome),
		positionM = positionM,
		rotationDeg = rotationDeg,
	}
	return table.freeze(recipe)
end

function PhysicsLabRecipe.objectGenome(key: ObjectGenomeKey): ObjectGenome.ObjectGenome
	local genome = OBJECT_GENOMES[key]
	assert(genome ~= nil, `unknown Physics Lab ObjectGenome key {key}`)
	return genome
end

function PhysicsLabRecipe.build(): PhysicsLabRecipe
	local entities: { EntityRecipe } = {
		primitive(
			"floor",
			"collidable carpeted floor",
			vec3(12, 0.20, 10),
			vec3(0, -0.10, 0),
			ZERO,
			FLOOR_MATERIAL,
			true
		),
		primitive(
			"ceiling",
			"ceiling collision/reference plane",
			vec3(12, 0.16, 10),
			vec3(0, 4.08, 0),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-left",
			"left perimeter wall",
			vec3(0.18, 4, 10),
			vec3(-6.09, 2, 0),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-right",
			"right perimeter wall",
			vec3(0.18, 4, 10),
			vec3(6.09, 2, 0),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-back",
			"rear perimeter wall",
			vec3(12, 4, 0.18),
			vec3(0, 2, 5.09),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-front-left",
			"front wall left of door opening",
			vec3(5.40, 4, 0.18),
			vec3(-3.30, 2, -5.09),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-front-right",
			"front wall right of door opening",
			vec3(5.40, 4, 0.18),
			vec3(3.30, 2, -5.09),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"wall-front-header",
			"front wall header over door opening",
			vec3(1.20, 1.75, 0.18),
			vec3(0, 3.125, -5.09),
			ZERO,
			WALL_MATERIAL,
			true
		),
		primitive(
			"ramp",
			"incline contact test",
			vec3(3.0, 0.20, 1.25),
			vec3(-3.6, 0.42, 2.3),
			vec3(0, 0, -14),
			METAL_MATERIAL,
			true
		),
		primitive(
			"ledge",
			"step-off and collision ledge",
			vec3(2.2, 0.65, 1.8),
			vec3(3.6, 0.325, 2.8),
			ZERO,
			METAL_MATERIAL,
			true
		),
		primitive(
			"stair-1",
			"stair contact test step 1",
			vec3(1.5, 0.18, 0.42),
			vec3(2.5, 0.09, -1.9),
			ZERO,
			METAL_MATERIAL,
			true
		),
		primitive(
			"stair-2",
			"stair contact test step 2",
			vec3(1.5, 0.36, 0.42),
			vec3(2.5, 0.18, -1.48),
			ZERO,
			METAL_MATERIAL,
			true
		),
		primitive(
			"stair-3",
			"stair contact test step 3",
			vec3(1.5, 0.54, 0.42),
			vec3(2.5, 0.27, -1.06),
			ZERO,
			METAL_MATERIAL,
			true
		),
		primitive(
			"stair-4",
			"stair contact test step 4",
			vec3(1.5, 0.72, 0.42),
			vec3(2.5, 0.36, -0.64),
			ZERO,
			METAL_MATERIAL,
			true
		),
		primitive(
			"character-spawn-anchor",
			"physical-character test spawn anchor",
			vec3(0.50, 0.04, 0.50),
			vec3(0, 0.02, 3.7),
			ZERO,
			METAL_MATERIAL,
			false,
			0.55
		),
		objectEntity("door-main", "commercialDoor", vec3(0, 1.08, -4.96), ZERO),
		objectEntity("chair-a", "officeChair", vec3(-2.25, 0.54, 0.65), vec3(0, 22, 0)),
		objectEntity("table-a", "officeTable", vec3(-0.60, 0.38, 0.80), ZERO),
		objectEntity("cabinet-a", "filingCabinet", vec3(4.85, 0.66, 3.90), vec3(0, 180, 0)),
		objectEntity("cart-a", "rollingCart", vec3(3.65, 0.475, -3.00), vec3(0, -18, 0)),
	}

	return table.freeze({
		schemaVersion = PhysicsLabRecipe.SCHEMA_VERSION,
		recipeKey = PhysicsLabRecipe.RECIPE_KEY,
		worldId = WORLD_ID,
		regionId = RESOLVED_REGION.regionId,
		resolvedRegion = RESOLVED_REGION,
		entities = table.freeze(entities),
	})
end

return table.freeze(PhysicsLabRecipe)
