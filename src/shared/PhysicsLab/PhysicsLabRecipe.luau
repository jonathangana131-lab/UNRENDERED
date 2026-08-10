--!strict

local StableId = require("../Core/StableId")
local MaterialDNA = require("../Materials/MaterialDNA")
local ObjectGenome = require("../Objects/ObjectGenome")
local ObjectGenomeFixtures = require("../Objects/ObjectGenomeFixtures")
local WorldEntity = require("../Reality/WorldEntity")

local PhysicsLabRecipe = {}

export type Vec3 = { x: number, y: number, z: number }
export type Transform = { positionM: Vec3, rotationDeg: Vec3 }
export type MaterialReference = { id: string, recipeVersion: number }
export type RepresentationKind =
	"block"
	| "ramp"
	| "stairs"
	| "door-probe"
	| "cart-probe"
	| "object-genome"
	| "spawn-anchor"
export type LabItem = {
	key: string,
	role: string,
	entity: WorldEntity.WorldEntityRecord,
	representationKind: RepresentationKind,
	transform: Transform,
	dimensionsM: Vec3,
	anchored: boolean,
	materialRef: MaterialReference?,
	genomeKey: string?,
	genome: ObjectGenome.ObjectGenome?,
	stepCount: number?,
}
export type Recipe = {
	schemaVersion: number,
	recipeVersion: number,
	worldId: string,
	regionId: string,
	metersPerStud: number,
	generator: string,
	generatorVersion: number,
	items: { LabItem },
}

PhysicsLabRecipe.SchemaVersion = 1
PhysicsLabRecipe.RecipeVersion = 1
PhysicsLabRecipe.GeneratorVersion = 1
PhysicsLabRecipe.WorldId = "world.dev.physics-lab"
PhysicsLabRecipe.RegionId = "region.dev.physics-lab.shell"
PhysicsLabRecipe.Generator = "physics-lab-shell"
PhysicsLabRecipe.MetersPerStud = 0.28
PhysicsLabRecipe.WorldEntityNamespace = "world-entity"

local ZERO: Vec3 = table.freeze({ x = 0, y = 0, z = 0 })
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

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function vec3(x: number, y: number, z: number): Vec3
	assert(finite(x) and finite(y) and finite(z), "lab vector values must be finite")
	return table.freeze({ x = x, y = y, z = z })
end

local function transform(positionM: Vec3, rotationDeg: Vec3?): Transform
	return table.freeze({ positionM = positionM, rotationDeg = rotationDeg or ZERO })
end

local function validateDimensions(dimensionsM: Vec3): ()
	assert(
		finite(dimensionsM.x)
			and finite(dimensionsM.y)
			and finite(dimensionsM.z)
			and dimensionsM.x > 0
			and dimensionsM.y > 0
			and dimensionsM.z > 0,
		"Physics Lab dimensions must be finite and positive"
	)
end

local function ownMaterialReference(reference: MaterialReference?): MaterialReference?
	if reference == nil then
		return nil
	end
	local report = MaterialDNA.validateReference(reference)
	assert(report.ok, `invalid Physics Lab MaterialDNA reference: {reference.id}`)
	return table.freeze({ id = reference.id, recipeVersion = reference.recipeVersion })
end

local function entityId(itemKey: string): string
	return StableId.fromParts(PhysicsLabRecipe.WorldEntityNamespace, {
		PhysicsLabRecipe.WorldId,
		PhysicsLabRecipe.RegionId,
		PhysicsLabRecipe.Generator,
		tostring(PhysicsLabRecipe.GeneratorVersion),
		itemKey,
	})
end

local function makeEntity(
	itemKey: string,
	role: string,
	fidelity: WorldEntity.Fidelity,
	genome: ObjectGenome.ObjectGenome?
): WorldEntity.WorldEntityRecord
	local persistentState: { [string]: unknown } = {}
	if genome ~= nil then
		local report = ObjectGenome.inspect(genome)
		assert(report.ok, `Physics Lab ObjectGenome fixture is invalid: {itemKey}`)
		persistentState.objectGenomeIdentity = ObjectGenome.identityKey(genome)
		persistentState.objectGenomeRecipeFingerprint = ObjectGenome.recipeFingerprint(genome)
		persistentState.objectState = ObjectGenome.defaultState(genome)
	end

	return WorldEntity.new({
		id = entityId(itemKey),
		kind = role,
		origin = {
			worldId = PhysicsLabRecipe.WorldId,
			regionId = PhysicsLabRecipe.RegionId,
			generator = PhysicsLabRecipe.Generator,
			generatorVersion = PhysicsLabRecipe.GeneratorVersion,
			recipeKey = `physics-lab/{itemKey}`,
		},
		fidelity = fidelity,
		persistentState = persistentState,
	})
end

local function makeItem(spec: {
	key: string,
	role: string,
	representationKind: RepresentationKind,
	positionM: Vec3,
	rotationDeg: Vec3?,
	dimensionsM: Vec3,
	anchored: boolean,
	fidelity: WorldEntity.Fidelity,
	materialRef: MaterialReference?,
	genomeKey: string?,
	genome: ObjectGenome.ObjectGenome?,
	stepCount: number?,
}): LabItem
	assert(spec.key ~= "" and string.find(spec.key, "%c") == nil, "lab item key must be a stable semantic key")
	assert(spec.role ~= "" and string.find(spec.role, "%c") == nil, "lab item role must be a stable semantic role")
	validateDimensions(spec.dimensionsM)
	if spec.stepCount ~= nil then
		assert(spec.stepCount >= 1 and spec.stepCount == math.floor(spec.stepCount), "stepCount must be a positive integer")
	end
	if spec.genome ~= nil then
		assert(spec.genomeKey ~= nil and spec.genomeKey ~= "", "ObjectGenome lab items require genomeKey")
		assert(spec.representationKind == "object-genome", "ObjectGenome lab items must use object-genome realization")
	else
		assert(spec.genomeKey == nil, "genomeKey requires a genome")
	end

	return table.freeze({
		key = spec.key,
		role = spec.role,
		entity = makeEntity(spec.key, spec.role, spec.fidelity, spec.genome),
		representationKind = spec.representationKind,
		transform = transform(spec.positionM, spec.rotationDeg),
		dimensionsM = spec.dimensionsM,
		anchored = spec.anchored,
		materialRef = ownMaterialReference(spec.materialRef),
		genomeKey = spec.genomeKey,
		genome = spec.genome,
		stepCount = spec.stepCount,
	})
end

local function buildItems(): { LabItem }
	local items: { LabItem } = {
		makeItem({ key = "floor", role = "structure.floor", representationKind = "block", positionM = vec3(0, -0.05, 0), dimensionsM = vec3(12, 0.10, 8), anchored = true, fidelity = "F2", materialRef = FLOOR_MATERIAL }),
		makeItem({ key = "ceiling", role = "structure.ceiling", representationKind = "block", positionM = vec3(0, 3.05, 0), dimensionsM = vec3(12, 0.10, 8), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-back", role = "structure.wall", representationKind = "block", positionM = vec3(0, 1.5, 4.05), dimensionsM = vec3(12, 3, 0.10), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-left", role = "structure.wall", representationKind = "block", positionM = vec3(-6.05, 1.5, 0), dimensionsM = vec3(0.10, 3, 8), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-right", role = "structure.wall", representationKind = "block", positionM = vec3(6.05, 1.5, 0), dimensionsM = vec3(0.10, 3, 8), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-front-left", role = "structure.wall", representationKind = "block", positionM = vec3(-3.25, 1.5, -4.05), dimensionsM = vec3(5.5, 3, 0.10), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-front-right", role = "structure.wall", representationKind = "block", positionM = vec3(3.25, 1.5, -4.05), dimensionsM = vec3(5.5, 3, 0.10), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "wall-front-header", role = "structure.wall", representationKind = "block", positionM = vec3(0, 2.62, -4.05), dimensionsM = vec3(1.0, 0.76, 0.10), anchored = true, fidelity = "F2", materialRef = WALL_MATERIAL }),
		makeItem({ key = "door-probe", role = "mechanism.door-probe", representationKind = "door-probe", positionM = vec3(0, 1.05, -3.98), dimensionsM = vec3(0.95, 2.10, 0.08), anchored = false, fidelity = "F3", materialRef = METAL_MATERIAL }),
		makeItem({ key = "office-chair", role = "object.office-chair", representationKind = "object-genome", positionM = vec3(0.9, 0.50, 0.4), dimensionsM = vec3(0.68, 1.08, 0.68), anchored = false, fidelity = "F3", genomeKey = "officeChair", genome = ObjectGenomeFixtures.officeChair }),
		makeItem({ key = "office-table", role = "object.office-table", representationKind = "object-genome", positionM = vec3(2.2, 0.38, 1.5), dimensionsM = vec3(1.50, 0.76, 0.75), anchored = false, fidelity = "F3", genomeKey = "officeTable", genome = ObjectGenomeFixtures.officeTable }),
		makeItem({ key = "filing-cabinet", role = "object.filing-cabinet", representationKind = "object-genome", positionM = vec3(4.5, 0.66, 2.8), dimensionsM = vec3(0.48, 1.32, 0.62), anchored = false, fidelity = "F3", genomeKey = "filingCabinet", genome = ObjectGenomeFixtures.filingCabinet }),
		makeItem({ key = "rolling-cart-probe", role = "mechanism.rolling-cart-probe", representationKind = "cart-probe", positionM = vec3(4.0, 0.52, -1.6), dimensionsM = vec3(0.82, 1.00, 1.10), anchored = false, fidelity = "F3", materialRef = METAL_MATERIAL }),
		makeItem({ key = "ramp", role = "structure.ramp", representationKind = "ramp", positionM = vec3(-3.8, 0.28, -1.8), rotationDeg = vec3(-12, 0, 0), dimensionsM = vec3(1.6, 0.14, 2.6), anchored = true, fidelity = "F2", materialRef = FLOOR_MATERIAL }),
		makeItem({ key = "stairs", role = "structure.stairs", representationKind = "stairs", positionM = vec3(-3.9, 0.40, 1.6), dimensionsM = vec3(1.6, 0.80, 1.8), anchored = true, fidelity = "F2", materialRef = FLOOR_MATERIAL, stepCount = 4 }),
		makeItem({ key = "ledge", role = "structure.ledge", representationKind = "block", positionM = vec3(-5.0, 1.05, 3.1), dimensionsM = vec3(1.8, 0.18, 1.1), anchored = true, fidelity = "F2", materialRef = METAL_MATERIAL }),
		makeItem({ key = "physical-character-spawn", role = "lab.spawn-anchor", representationKind = "spawn-anchor", positionM = vec3(0, 0.12, -2.4), dimensionsM = vec3(1.2, 0.20, 1.2), anchored = true, fidelity = "F2", materialRef = FLOOR_MATERIAL }),
	}

	local seenKeys: { [string]: boolean } = {}
	local seenIds: { [string]: boolean } = {}
	for _, item in ipairs(items) do
		assert(not seenKeys[item.key], `duplicate Physics Lab item key: {item.key}`)
		assert(not seenIds[item.entity.id], `duplicate Physics Lab WorldEntityId: {item.entity.id}`)
		seenKeys[item.key] = true
		seenIds[item.entity.id] = true
	end
	return table.freeze(items)
end

function PhysicsLabRecipe.build(): Recipe
	return table.freeze({
		schemaVersion = PhysicsLabRecipe.SchemaVersion,
		recipeVersion = PhysicsLabRecipe.RecipeVersion,
		worldId = PhysicsLabRecipe.WorldId,
		regionId = PhysicsLabRecipe.RegionId,
		metersPerStud = PhysicsLabRecipe.MetersPerStud,
		generator = PhysicsLabRecipe.Generator,
		generatorVersion = PhysicsLabRecipe.GeneratorVersion,
		items = buildItems(),
	})
end

return table.freeze(PhysicsLabRecipe)
