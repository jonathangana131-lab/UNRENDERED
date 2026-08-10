--!strict

local StableId = require(script.Parent.Parent.Core.StableId)
local MaterialDNA = require(script.Parent.Parent.Materials.MaterialDNA)
local MaterialFixtures = require(script.Parent.Parent.Materials.MaterialFixtures)
local ObjectGenome = require(script.Parent.Parent.Objects.ObjectGenome)
local ObjectGenomeFixtures = require(script.Parent.Parent.Objects.ObjectGenomeFixtures)
local WorldEntity = require(script.Parent.Parent.Reality.WorldEntity)
local FidelityManager = require(script.Parent.FidelityManager)

local PhysicsLabRecipe = {}

PhysicsLabRecipe.SchemaVersion = 1
PhysicsLabRecipe.RecipeVersion = 1
PhysicsLabRecipe.StudsPerMeter = 25 / 7
PhysicsLabRecipe.GeneratorKey = "physics-lab.shell"
PhysicsLabRecipe.WorldId = StableId.fromParts("world", { "physics-lab", "hero-gate", "v1" })
PhysicsLabRecipe.RegionId =
	StableId.fromParts("region", { PhysicsLabRecipe.WorldId, "physics-lab-shell", "v1" })
PhysicsLabRecipe.RecipeId = StableId.fromParts("physics-lab", {
	PhysicsLabRecipe.WorldId,
	PhysicsLabRecipe.RegionId,
	tostring(PhysicsLabRecipe.RecipeVersion),
})

type WorldEntityRecord = WorldEntity.WorldEntityRecord
type FidelityLevel = FidelityManager.FidelityLevel
export type Genome = ObjectGenome.ObjectGenome
export type MechanismSpec = ObjectGenome.MechanismSpec

export type Vec3 = {
	x: number,
	y: number,
	z: number,
}

export type MaterialReference = {
	id: string,
	recipeVersion: number,
}

export type RepresentationKind =
	"static-box"
	| "dynamic-box"
	| "rolling-cart-proxy"
	| "static-wedge"
	| "hinged-panel"
	| "sliding-drawer-proxy"
	| "spawn-anchor"

export type LabElement = {
	key: string,
	role: string,
	entity: WorldEntityRecord,
	positionStuds: Vec3,
	sizeStuds: Vec3,
	yawDegrees: number,
	material: MaterialReference,
	representationKind: RepresentationKind,
	objectGenomeId: string?,
	mechanismKey: string?,
}

export type Recipe = {
	schemaVersion: number,
	recipeVersion: number,
	recipeId: string,
	worldId: string,
	regionId: string,
	elements: { LabElement },
}

local REQUIRED_ROLES: { [string]: boolean } = table.freeze({
	floor = true,
	ceiling = true,
	wall = true,
	door = true,
	chair = true,
	table = true,
	cart = true,
	cabinet = true,
	stairs = true,
	ramp = true,
	ledge = true,
	["spawn-anchor"] = true,
})

PhysicsLabRecipe.RequiredRoles = REQUIRED_ROLES

local function vec3(x: number, y: number, z: number): Vec3
	return table.freeze({ x = x, y = y, z = z })
end

local function materialReference(recipe: any): MaterialReference
	local reference = table.freeze({
		id = recipe.id,
		recipeVersion = recipe.recipeVersion,
	})
	assert(MaterialDNA.validateReference(reference).ok, `invalid Physics Lab material reference: {recipe.id}`)
	return reference
end

local WALL_MATERIAL = materialReference(MaterialFixtures.CommercialWallpaperDrywall)
local FLOOR_MATERIAL = materialReference(MaterialFixtures.LowPileCarpet)
local METAL_MATERIAL = materialReference(MaterialFixtures.PaintedMetal)

local GENOMES_BY_ID: { [string]: Genome } = table.freeze({
	[ObjectGenome.identityKey(ObjectGenomeFixtures.officeChair)] = ObjectGenomeFixtures.officeChair,
	[ObjectGenome.identityKey(ObjectGenomeFixtures.officeTable)] = ObjectGenomeFixtures.officeTable,
	[ObjectGenome.identityKey(ObjectGenomeFixtures.filingCabinet)] = ObjectGenomeFixtures.filingCabinet,
})

local function worldEntityId(key: string): string
	return StableId.fromParts("world-entity", {
		PhysicsLabRecipe.WorldId,
		PhysicsLabRecipe.RegionId,
		PhysicsLabRecipe.GeneratorKey,
		tostring(PhysicsLabRecipe.RecipeVersion),
		key,
	})
end

local function worldEntity(
	key: string,
	kind: string,
	fidelity: FidelityLevel,
	persistentState: any?
): WorldEntityRecord
	return WorldEntity.new({
		id = worldEntityId(key),
		kind = kind,
		origin = {
			worldId = PhysicsLabRecipe.WorldId,
			regionId = PhysicsLabRecipe.RegionId,
			generator = PhysicsLabRecipe.GeneratorKey,
			generatorVersion = PhysicsLabRecipe.RecipeVersion,
			recipeKey = key,
		},
		fidelity = fidelity,
		persistentState = persistentState or {},
	})
end

local function frozenElement(spec: LabElement): LabElement
	return table.freeze({
		key = spec.key,
		role = spec.role,
		entity = spec.entity,
		positionStuds = spec.positionStuds,
		sizeStuds = spec.sizeStuds,
		yawDegrees = spec.yawDegrees,
		material = spec.material,
		representationKind = spec.representationKind,
		objectGenomeId = spec.objectGenomeId,
		mechanismKey = spec.mechanismKey,
	})
end

local function genomeSizeStuds(genome: Genome): Vec3
	local scale = PhysicsLabRecipe.StudsPerMeter
	return vec3(genome.dimensionsM.x * scale, genome.dimensionsM.y * scale, genome.dimensionsM.z * scale)
end

local function objectElement(
	key: string,
	role: string,
	position: Vec3,
	genome: Genome,
	representationKind: RepresentationKind,
	mechanismKey: string?
): LabElement
	local size = genomeSizeStuds(genome)
	return frozenElement({
		key = key,
		role = role,
		entity = worldEntity(key, "object", "F3", ObjectGenome.defaultState(genome)),
		positionStuds = vec3(position.x, size.y / 2, position.z),
		sizeStuds = size,
		yawDegrees = 0,
		material = METAL_MATERIAL,
		representationKind = representationKind,
		objectGenomeId = ObjectGenome.identityKey(genome),
		mechanismKey = mechanismKey,
	})
end

local function add(
	elements: { LabElement },
	key: string,
	role: string,
	kind: string,
	position: Vec3,
	size: Vec3,
	yawDegrees: number,
	material: MaterialReference,
	representationKind: RepresentationKind,
	fidelity: FidelityLevel
): ()
	table.insert(
		elements,
		frozenElement({
			key = key,
			role = role,
			entity = worldEntity(key, kind, fidelity),
			positionStuds = position,
			sizeStuds = size,
			yawDegrees = yawDegrees,
			material = material,
			representationKind = representationKind,
			objectGenomeId = nil,
			mechanismKey = nil,
		})
	)
end

local function assertFinite(path: string, value: number): ()
	assert(value == value and value > -math.huge and value < math.huge, `{path} must be finite`)
end

function PhysicsLabRecipe.objectGenomeFor(element: LabElement): Genome?
	if element.objectGenomeId == nil then
		return nil
	end
	return GENOMES_BY_ID[element.objectGenomeId]
end

function PhysicsLabRecipe.mechanismFor(element: LabElement): MechanismSpec?
	if element.mechanismKey == nil then
		return nil
	end
	local genome = PhysicsLabRecipe.objectGenomeFor(element)
	assert(genome ~= nil, `{element.key} mechanism binding requires a known ObjectGenome`)
	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.key == element.mechanismKey then
			return mechanism
		end
	end
	error(`{element.key} references unknown ObjectGenome mechanism {element.mechanismKey}`)
end

function PhysicsLabRecipe.validate(recipe: Recipe): ()
	assert(recipe.schemaVersion == PhysicsLabRecipe.SchemaVersion, "Physics Lab schemaVersion mismatch")
	assert(recipe.recipeVersion == PhysicsLabRecipe.RecipeVersion, "Physics Lab recipeVersion mismatch")
	assert(recipe.recipeId == PhysicsLabRecipe.RecipeId, "Physics Lab recipeId mismatch")
	assert(recipe.worldId == PhysicsLabRecipe.WorldId, "Physics Lab worldId mismatch")
	assert(recipe.regionId == PhysicsLabRecipe.RegionId, "Physics Lab regionId mismatch")

	local seenKeys: { [string]: boolean } = {}
	local seenIds: { [string]: boolean } = {}
	local seenRoles: { [string]: boolean } = {}
	local registry = WorldEntity.createRegistry(#recipe.elements)
	local fidelity = FidelityManager.new()

	for index, element in recipe.elements do
		assert(element.key ~= "", `elements[{index}].key must not be empty`)
		assert(not seenKeys[element.key], `duplicate Physics Lab element key: {element.key}`)
		seenKeys[element.key] = true
		seenRoles[element.role] = true

		assert(WorldEntity.isId(element.entity.id), `invalid WorldEntityId for {element.key}`)
		assert(
			element.entity.id == worldEntityId(element.key),
			`{element.key} WorldEntityId derivation mismatch`
		)
		assert(not seenIds[element.entity.id], `duplicate Physics Lab WorldEntityId: {element.entity.id}`)
		seenIds[element.entity.id] = true
		assert(element.entity.origin.worldId == recipe.worldId, `{element.key} worldId mismatch`)
		assert(element.entity.origin.regionId == recipe.regionId, `{element.key} regionId mismatch`)
		assert(
			element.entity.origin.generator == PhysicsLabRecipe.GeneratorKey,
			`{element.key} generator mismatch`
		)
		assert(
			element.entity.origin.generatorVersion == recipe.recipeVersion,
			`{element.key} generatorVersion mismatch`
		)
		assert(element.entity.origin.recipeKey == element.key, `{element.key} recipeKey mismatch`)

		local registered = registry.register(element.entity)
		assert(registered, `WorldEntity registry rejected {element.key}`)
		fidelity:register(element.entity.id, element.entity.fidelity)
		assert(
			fidelity:getObservedLevel(element.entity.id) == element.entity.fidelity,
			`{element.key} fidelity mismatch`
		)

		assert(
			MaterialDNA.validateReference(element.material).ok,
			`{element.key} material reference is invalid`
		)
		for axis, value in pairs(element.positionStuds) do
			assertFinite(`{element.key}.positionStuds.{axis}`, value)
		end
		for axis, value in pairs(element.sizeStuds) do
			assertFinite(`{element.key}.sizeStuds.{axis}`, value)
			assert(value > 0, `{element.key}.sizeStuds.{axis} must be positive`)
		end
		assertFinite(`{element.key}.yawDegrees`, element.yawDegrees)
		if element.objectGenomeId ~= nil then
			assert(
				StableId.is(element.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE),
				`{element.key} objectGenomeId must satisfy ObjectGenome identity contract`
			)
			local genome = PhysicsLabRecipe.objectGenomeFor(element)
			assert(genome ~= nil, `{element.key} objectGenomeId must resolve through the production lab catalog`)
			assert(element.entity.kind == "object", `{element.key} fixture-backed entity kind must be object`)
			local objectState = element.entity.persistentState :: any
			assert(
				objectState.genomeId == element.objectGenomeId,
				`{element.key} persistent ObjectState must match objectGenomeId`
			)
			assert(
				ObjectGenome.inspectState(genome, element.entity.persistentState).ok,
				`{element.key} persistent ObjectState must validate against ObjectGenome`
			)
		elseif element.mechanismKey ~= nil then
			error(`{element.key} cannot bind a mechanism without an ObjectGenome`)
		end

		if element.mechanismKey ~= nil then
			local mechanism = PhysicsLabRecipe.mechanismFor(element)
			assert(mechanism ~= nil, `{element.key} mechanism binding failed`)
			local objectState = element.entity.persistentState :: any
			assert(
				objectState.mechanismPosition[element.mechanismKey] ~= nil,
				`{element.key} ObjectState must contain bound mechanism state`
			)
		end
	end

	assert(registry.count() == #recipe.elements, "Physics Lab registry count mismatch")
	for role in pairs(REQUIRED_ROLES) do
		assert(seenRoles[role], `Physics Lab recipe is missing required role: {role}`)
	end
end

function PhysicsLabRecipe.build(): Recipe
	local elements: { LabElement } = {}

	add(elements, "floor", "floor", "physics-lab.structure", vec3(0, -0.5, 0), vec3(48, 1, 36), 0, FLOOR_MATERIAL, "static-box", "F2")
	add(elements, "ceiling", "ceiling", "physics-lab.structure", vec3(0, 12.5, 0), vec3(48, 1, 36), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-north", "wall", "physics-lab.structure", vec3(0, 6, 18.5), vec3(48, 13, 1), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-west", "wall", "physics-lab.structure", vec3(-24.5, 6, 0), vec3(1, 13, 36), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-east", "wall", "physics-lab.structure", vec3(24.5, 6, 0), vec3(1, 13, 36), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-south-left", "wall", "physics-lab.structure", vec3(-17, 6, -18.5), vec3(14, 13, 1), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-south-right", "wall", "physics-lab.structure", vec3(9, 6, -18.5), vec3(30, 13, 1), 0, WALL_MATERIAL, "static-box", "F2")
	add(elements, "wall-south-lintel", "wall", "physics-lab.structure", vec3(-8, 10.5, -18.5), vec3(4, 4, 1), 0, WALL_MATERIAL, "static-box", "F2")

	-- The 4-stud structural opening retains explicit jamb/floor clearance so the
	-- hinged proxy begins without penetrating the wall or scraping the floor.
	add(elements, "door", "door", "physics-lab.door-proxy", vec3(-8, 4, -18), vec3(3.8, 7.8, 0.35), 0, METAL_MATERIAL, "hinged-panel", "F3")

	table.insert(elements, objectElement("chair", "chair", vec3(-5, 0, -2), ObjectGenomeFixtures.officeChair, "dynamic-box", nil))
	table.insert(elements, objectElement("table", "table", vec3(2, 0, -3), ObjectGenomeFixtures.officeTable, "dynamic-box", nil))
	table.insert(elements, objectElement("cabinet", "cabinet", vec3(19, 0, -12), ObjectGenomeFixtures.filingCabinet, "sliding-drawer-proxy", "slide-top"))

	add(elements, "cart", "cart", "physics-lab.cart-proxy", vec3(11, 1.6, -6), vec3(3.5, 3.2, 2.5), 0, METAL_MATERIAL, "rolling-cart-proxy", "F3")

	for stepIndex = 1, 4 do
		local height = stepIndex * 0.75
		add(elements, `stair-{stepIndex}`, "stairs", "physics-lab.structure", vec3(-16 + (stepIndex - 1) * 2, height / 2, 9), vec3(2, height, 6), 0, METAL_MATERIAL, "static-box", "F2")
	end
	add(elements, "ramp", "ramp", "physics-lab.structure", vec3(10, 1.5, 9), vec3(8, 3, 6), 0, METAL_MATERIAL, "static-wedge", "F2")
	add(elements, "ledge", "ledge", "physics-lab.structure", vec3(19, 3.25, 8), vec3(4, 0.5, 8), 0, METAL_MATERIAL, "static-box", "F2")
	add(elements, "character-spawn", "spawn-anchor", "physics-lab.spawn-anchor", vec3(0, 0.05, 12), vec3(2, 0.1, 2), 0, FLOOR_MATERIAL, "spawn-anchor", "F1")

	local recipe: Recipe = table.freeze({
		schemaVersion = PhysicsLabRecipe.SchemaVersion,
		recipeVersion = PhysicsLabRecipe.RecipeVersion,
		recipeId = PhysicsLabRecipe.RecipeId,
		worldId = PhysicsLabRecipe.WorldId,
		regionId = PhysicsLabRecipe.RegionId,
		elements = table.freeze(elements),
	})
	PhysicsLabRecipe.validate(recipe)
	return recipe
end

return table.freeze(PhysicsLabRecipe)
