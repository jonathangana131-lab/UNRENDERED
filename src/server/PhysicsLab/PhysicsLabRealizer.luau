--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local FidelityManager = require(Shared.Physics.FidelityManager)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local WorldEntity = require(Shared.Reality.WorldEntity)

local PhysicsLabRealizer = {}

local ROOT_NAME = "UNRENDERED_PhysicsLab"
-- Roblox standard physics units: 1 stud = 0.28 meters.
local STUDS_PER_METER = 1 / 0.28

export type RealizedLab = {
	model: Model,
	registry: WorldEntity.Registry,
	fidelityManager: FidelityManager.Manager,
	destroy: () -> (),
}

type Appearance = {
	material: Enum.Material,
	color: Color3,
}

local APPEARANCE_BY_MATERIAL: { [string]: Appearance } = {
	["material.v1.office-wallpaper.yellow-vinyl"] = {
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(184, 174, 107),
	},
	["material.v1.office-carpet.low-pile-beige"] = {
		material = Enum.Material.Fabric,
		color = Color3.fromRGB(117, 107, 79),
	},
	["material.v1.office-metal.warm-gray-enamel"] = {
		material = Enum.Material.Metal,
		color = Color3.fromRGB(120, 117, 110),
	},
	["material.v1.office-metal.gray-painted-steel"] = {
		material = Enum.Material.Metal,
		color = Color3.fromRGB(105, 108, 106),
	},
	["material.v1.office-metal.black-painted-steel"] = {
		material = Enum.Material.Metal,
		color = Color3.fromRGB(42, 43, 43),
	},
	["material.v1.mechanism-steel.dark"] = {
		material = Enum.Material.Metal,
		color = Color3.fromRGB(54, 56, 58),
	},
	["material.v1.upholstery.charcoal-fabric-foam"] = {
		material = Enum.Material.Fabric,
		color = Color3.fromRGB(58, 59, 58),
	},
	["material.v1.polypropylene.black"] = {
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(30, 31, 31),
	},
	["material.v1.chair-caster.polymer-rubber"] = {
		material = Enum.Material.Rubber,
		color = Color3.fromRGB(35, 35, 36),
	},
	["material.v1.laminate-particleboard.beige"] = {
		material = Enum.Material.Wood,
		color = Color3.fromRGB(166, 150, 112),
	},
}

table.freeze(APPEARANCE_BY_MATERIAL)

local DEFAULT_APPEARANCE: Appearance = table.freeze({
	material = Enum.Material.SmoothPlastic,
	color = Color3.fromRGB(140, 140, 140),
})

local function meters(value: number): number
	return value * STUDS_PER_METER
end

local function vectorMeters(value: PhysicsLabRecipe.Vec3): Vector3
	return Vector3.new(meters(value.x), meters(value.y), meters(value.z))
end

local function rotationExtrinsicXYZ(rotationDeg: PhysicsLabRecipe.Vec3): CFrame
	local x = math.rad(rotationDeg.x)
	local y = math.rad(rotationDeg.y)
	local z = math.rad(rotationDeg.z)

	-- ObjectGenome v1 owns fixed-axis/extrinsic XYZ as Rz * Ry * Rx. Do not
	-- replace this with CFrame.Angles(x, y, z), whose engine order is Rx * Ry * Rz.
	return CFrame.Angles(0, 0, z) * CFrame.Angles(0, y, 0) * CFrame.Angles(x, 0, 0)
end

local function transform(positionM: PhysicsLabRecipe.Vec3, rotationDeg: PhysicsLabRecipe.Vec3): CFrame
	return CFrame.new(vectorMeters(positionM)) * rotationExtrinsicXYZ(rotationDeg)
end

local function applyAppearance(part: BasePart, materialKey: string, materialRecipeVersion: number): ()
	local appearance = APPEARANCE_BY_MATERIAL[materialKey] or DEFAULT_APPEARANCE
	part.Material = appearance.material
	part.Color = appearance.color
	part:SetAttribute("UNRENDERED_MaterialKey", materialKey)
	part:SetAttribute("UNRENDERED_MaterialRecipeVersion", materialRecipeVersion)
end

local function setEntityAttributes(instance: Instance, record: WorldEntity.WorldEntityRecord): ()
	instance:SetAttribute("UNRENDERED_WorldEntityId", record.id)
	instance:SetAttribute("UNRENDERED_Fidelity", record.fidelity)
	instance:SetAttribute("UNRENDERED_RecipeKey", record.origin.recipeKey)
	instance:SetAttribute("UNRENDERED_RepresentationRevision", record.representationRevision)
end

local function realizePrimitive(parent: Instance, recipe: PhysicsLabRecipe.PrimitiveEntityRecipe): BasePart
	local part = Instance.new("Part")
	part.Name = recipe.key
	part.Anchored = true
	part.CanCollide = recipe.collidable
	part.CanQuery = true
	part.CanTouch = recipe.collidable
	part.Size = vectorMeters(recipe.sizeM)
	part.CFrame = transform(recipe.positionM, recipe.rotationDeg)
	part.Transparency = recipe.transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	applyAppearance(part, recipe.material.id, recipe.material.recipeVersion)
	setEntityAttributes(part, recipe.entity)
	part:SetAttribute("UNRENDERED_LabRole", recipe.role)
	part.Parent = parent
	return part
end

local function realizeObject(parent: Instance, recipe: PhysicsLabRecipe.ObjectEntityRecipe): Model
	local genome = PhysicsLabRecipe.objectGenome(recipe.genomeKey)
	local model = Instance.new("Model")
	model.Name = recipe.key
	setEntityAttributes(model, recipe.entity)
	model:SetAttribute("UNRENDERED_ObjectGenomeKey", recipe.genomeKey)
	model:SetAttribute("UNRENDERED_ObjectGenomeId", recipe.genomeId)
	model:SetAttribute("UNRENDERED_ObjectRecipeFingerprint", recipe.genomeRecipeFingerprint)
	model:SetAttribute("UNRENDERED_RepresentationClass", "F2-anchored-proxy")

	local objectTransform = transform(recipe.positionM, recipe.rotationDeg)
	for _, component in ipairs(genome.components) do
		local part = Instance.new("Part")
		part.Name = component.key
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = true
		part.Size = vectorMeters(component.dimensionsM)
		part.CFrame = objectTransform
			* CFrame.new(vectorMeters(component.localPositionM))
			* rotationExtrinsicXYZ(component.localRotationDeg)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		applyAppearance(part, component.materialKey, component.materialRecipeVersion)
		part:SetAttribute("UNRENDERED_ComponentKey", component.key)
		part:SetAttribute("UNRENDERED_ComponentRole", component.role)
		part:SetAttribute("UNRENDERED_ComponentMassKg", component.massKg)
		part.Parent = model
	end

	model.Parent = parent
	return model
end

function PhysicsLabRealizer.realize(parent: Instance): RealizedLab
	local recipe = PhysicsLabRecipe.build()
	local existing = parent:FindFirstChild(ROOT_NAME)
	if existing ~= nil then
		assert(
			existing:GetAttribute("UNRENDERED_PhysicsLabOwned") == true,
			`refusing to replace unrelated Instance named {ROOT_NAME}`
		)
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = ROOT_NAME
	model:SetAttribute("UNRENDERED_PhysicsLabOwned", true)
	model:SetAttribute("UNRENDERED_LabSchemaVersion", recipe.schemaVersion)
	model:SetAttribute("UNRENDERED_LabRecipeKey", recipe.recipeKey)
	model:SetAttribute("UNRENDERED_WorldId", recipe.worldId)
	model:SetAttribute("UNRENDERED_RegionId", recipe.regionId)
	model:SetAttribute("UNRENDERED_ResolvedRegionFingerprint", recipe.resolvedRegion.recipeFingerprint)
	model:SetAttribute("UNRENDERED_ResolvedRegionWorldSeedRef", recipe.resolvedRegion.worldSeedRef)
	model:SetAttribute(
		"UNRENDERED_ResolvedRegionAddress",
		string.format(
			"%d,%d,%d",
			recipe.resolvedRegion.regionAddress.x,
			recipe.resolvedRegion.regionAddress.z,
			recipe.resolvedRegion.regionAddress.layer
		)
	)

	local registry = WorldEntity.createRegistry()
	local fidelityManager = FidelityManager.new()

	for _, entityRecipe in ipairs(recipe.entities) do
		local registered, duplicate = WorldEntity.register(registry, entityRecipe.entity)
		assert(registered, `duplicate Physics Lab WorldEntityId: {entityRecipe.entity.id}`)
		assert(duplicate == nil, "successful Physics Lab registration must not emit a duplicate diagnostic")
		fidelityManager:register(entityRecipe.entity.id, entityRecipe.entity.fidelity)

		if entityRecipe.kind == "primitive" then
			realizePrimitive(model, entityRecipe)
		else
			realizeObject(model, entityRecipe)
		end
	end

	local metrics = fidelityManager:getMetrics()
	model:SetAttribute("UNRENDERED_EntityCount", WorldEntity.count(registry))
	model:SetAttribute("UNRENDERED_FidelityF0", metrics.counts.F0)
	model:SetAttribute("UNRENDERED_FidelityF1", metrics.counts.F1)
	model:SetAttribute("UNRENDERED_FidelityF2", metrics.counts.F2)
	model:SetAttribute("UNRENDERED_FidelityF3", metrics.counts.F3)
	model:SetAttribute("UNRENDERED_FidelityF4", metrics.counts.F4)
	model.Parent = parent

	local destroyed = false
	local function destroy(): ()
		if destroyed then
			return
		end
		destroyed = true
		model:Destroy()
	end

	return table.freeze({
		model = model,
		registry = registry,
		fidelityManager = fidelityManager,
		destroy = destroy,
	})
end

return table.freeze(PhysicsLabRealizer)
