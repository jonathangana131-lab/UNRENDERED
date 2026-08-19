--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local FidelityManager = require(Shared.Physics.FidelityManager)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local PhysicsLabRuntime = require(Shared.Physics.PhysicsLabRuntime)
local PhysicsLabScale = require(Shared.Physics.PhysicsLabScale)
local ResolvedRegionRecipe = require(Shared.Reality.ResolvedRegionRecipe)
local WorldEntity = require(Shared.Reality.WorldEntity)

local PhysicsLabRealizer = {}

local ROOT_NAME = "UNRENDERED_PhysicsLab"

export type RealizedLab = {
	model: Model,
	step: (
		entityId: string,
		inputs: FidelityManager.PolicyInputs,
		nowSeconds: number
	) -> (FidelityManager.StepResult, WorldEntity.WorldEntityRecord),
	getRecord: (entityId: string) -> WorldEntity.WorldEntityRecord,
	isRepresented: (entityId: string) -> boolean,
	ownsRepresentation: (entityId: string, candidate: Instance) -> boolean,
	destroy: () -> (),
}

type Appearance = {
	material: Enum.Material,
	color: Color3,
}

type RepresentationMap = { [string]: Instance? }

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

local function vectorMeters(value: PhysicsLabRecipe.Vec3): Vector3
	return Vector3.new(
		PhysicsLabScale.metersToStuds(value.x),
		PhysicsLabScale.metersToStuds(value.y),
		PhysicsLabScale.metersToStuds(value.z)
	)
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
	instance:SetAttribute("UNRENDERED_StateRevision", record.stateRevision)
end

local function realizePrimitive(
	parent: Instance,
	recipe: PhysicsLabRecipe.PrimitiveEntityRecipe,
	record: WorldEntity.WorldEntityRecord
): BasePart
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
	setEntityAttributes(part, record)
	part:SetAttribute("UNRENDERED_LabRole", recipe.role)
	part.Parent = parent
	return part
end

local function realizeObject(
	parent: Instance,
	recipe: PhysicsLabRecipe.ObjectEntityRecipe,
	record: WorldEntity.WorldEntityRecord
): Model
	local genome = PhysicsLabRecipe.objectGenome(recipe.genomeKey)
	local model = Instance.new("Model")
	model.Name = recipe.key
	setEntityAttributes(model, record)
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

local function findEntityRecipe(
	recipe: PhysicsLabRecipe.PhysicsLabRecipe,
	entityId: string
): PhysicsLabRecipe.EntityRecipe
	for _, entityRecipe in ipairs(recipe.entities) do
		if entityRecipe.entity.id == entityId then
			return entityRecipe
		end
	end
	error(`unknown Physics Lab recipe entity id: {entityId}`)
end

local function realizeEntity(
	parent: Instance,
	entityRecipe: PhysicsLabRecipe.EntityRecipe,
	record: WorldEntity.WorldEntityRecord
): Instance
	if entityRecipe.kind == "primitive" then
		return realizePrimitive(parent, entityRecipe, record)
	end
	return realizeObject(parent, entityRecipe, record)
end

local function representedCount(representations: RepresentationMap): number
	local count = 0
	for _, representation in pairs(representations) do
		if representation ~= nil then
			count += 1
		end
	end
	return count
end

local function syncMetrics(
	model: Model,
	runtime: PhysicsLabRuntime.Runtime,
	representations: RepresentationMap
): ()
	local snapshot = runtime:snapshot()
	model:SetAttribute("UNRENDERED_EntityCount", snapshot.registered)
	model:SetAttribute("UNRENDERED_RepresentedCount", representedCount(representations))
	model:SetAttribute("UNRENDERED_FidelityF0", snapshot.fidelity.counts.F0)
	model:SetAttribute("UNRENDERED_FidelityF1", snapshot.fidelity.counts.F1)
	model:SetAttribute("UNRENDERED_FidelityF2", snapshot.fidelity.counts.F2)
	model:SetAttribute("UNRENDERED_FidelityF3", snapshot.fidelity.counts.F3)
	model:SetAttribute("UNRENDERED_FidelityF4", snapshot.fidelity.counts.F4)
end

function PhysicsLabRealizer.realize(parent: Instance): RealizedLab
	local recipe = PhysicsLabRecipe.build()
	local resolvedRegion = PhysicsLabRecipe.RESOLVED_REGION
	local regionFingerprint = ResolvedRegionRecipe.fingerprint(resolvedRegion)
	local regionReproKey = ResolvedRegionRecipe.reproKey(resolvedRegion)
	local existing = parent:FindFirstChild(ROOT_NAME)
	if existing ~= nil then
		assert(
			existing:GetAttribute("UNRENDERED_PhysicsLabOwned") == true,
			`refusing to replace unrelated Instance named {ROOT_NAME}`
		)
		error("Physics Lab is already realized; destroy the existing RealizedLab before replacement")
	end

	-- Establish and validate canonical domain authority before allocating any
	-- physical representation. From this point onward, Instances are disposable
	-- views of the runtime-owned WorldEntity records. Keep runtime ownership local
	-- so callers cannot bypass representation-aware transition hooks.
	local runtime = PhysicsLabRuntime.new(recipe)
	local model = Instance.new("Model")
	local representations: RepresentationMap = {}

	local realized, realizationError = pcall(function()
		model.Name = ROOT_NAME
		model:SetAttribute("UNRENDERED_PhysicsLabOwned", true)
		model:SetAttribute("UNRENDERED_LabSchemaVersion", recipe.schemaVersion)
		model:SetAttribute("UNRENDERED_LabRecipeKey", recipe.recipeKey)
		model:SetAttribute("UNRENDERED_WorldId", recipe.worldId)
		model:SetAttribute("UNRENDERED_RegionId", recipe.regionId)
		model:SetAttribute("UNRENDERED_ResolvedRegionSchemaVersion", resolvedRegion.schemaVersion)
		model:SetAttribute("UNRENDERED_WorldSeedRef", resolvedRegion.worldSeedRef)
		model:SetAttribute("UNRENDERED_ResolvedRegionFingerprint", regionFingerprint)
		model:SetAttribute("UNRENDERED_ResolvedRegionReproKey", regionReproKey)

		for _, entityRecipe in ipairs(recipe.entities) do
			local entityId = entityRecipe.entity.id
			assert(representations[entityId] == nil, `duplicate Physics Lab representation id: {entityId}`)
			representations[entityId] = realizeEntity(model, entityRecipe, runtime:getRecord(entityId))
		end

		syncMetrics(model, runtime, representations)
		model.Parent = parent
	end)

	if not realized then
		model:Destroy()
		table.clear(representations)
		runtime:dispose()
		error(`failed to realize Physics Lab representation: {tostring(realizationError)}`)
	end

	local destroyed = false

	local function getRecord(entityId: string): WorldEntity.WorldEntityRecord
		assert(not destroyed, "Physics Lab has been destroyed")
		return runtime:getRecord(entityId)
	end

	local function isRepresented(entityId: string): boolean
		assert(not destroyed, "Physics Lab has been destroyed")
		local record = runtime:getRecord(entityId)
		local represented = representations[entityId] ~= nil
		if record.fidelity == "F0" then
			assert(not represented, `F0 Physics Lab entity still has physical representation: {entityId}`)
		elseif record.fidelity == "F2" then
			assert(represented, `F2 Physics Lab entity is missing physical representation: {entityId}`)
		else
			error(`Physics Lab F2 adapter cannot represent authoritative fidelity {record.fidelity}`)
		end
		return represented
	end

	local function ownsRepresentation(entityId: string, candidate: Instance): boolean
		assert(not destroyed, "Physics Lab has been destroyed")
		if not isRepresented(entityId) then
			return false
		end

		local representation = representations[entityId]
		return representation == candidate and candidate.Parent == model
	end

	local function captureState(record: WorldEntity.WorldEntityRecord): WorldEntity.PlainData
		assert(
			representations[record.id] ~= nil,
			`cannot capture absent Physics Lab representation: {record.id}`
		)
		-- The landed F2 representation is an anchored proxy with no mutable Roblox
		-- mechanism state. Preserve the authoritative plain domain state rather
		-- than scraping Workspace and accidentally making Instances canonical.
		return record.persistentState
	end

	local function observeTransition(
		before: WorldEntity.WorldEntityRecord,
		preview: WorldEntity.WorldEntityRecord,
		_reason: FidelityManager.PolicyReason
	): ()
		if before.fidelity == "F2" and preview.fidelity == "F0" then
			local representation = representations[before.id]
			assert(representation ~= nil, `owned F2 representation missing before demotion: {before.id}`)
			representation:Destroy()
			representations[before.id] = nil
			return
		end

		if before.fidelity == "F0" and preview.fidelity == "F2" then
			assert(representations[before.id] == nil, `F0 entity already has a representation: {before.id}`)
			local entityRecipe = findEntityRecipe(recipe, before.id)
			representations[before.id] = realizeEntity(model, entityRecipe, preview)
			return
		end

		error(`Physics Lab F2 adapter cannot realize transition {before.fidelity}->{preview.fidelity}`)
	end

	local function step(
		entityId: string,
		inputs: FidelityManager.PolicyInputs,
		nowSeconds: number
	): (FidelityManager.StepResult, WorldEntity.WorldEntityRecord)
		assert(not destroyed, "Physics Lab has been destroyed")
		local current = runtime:getRecord(entityId)
		local desired = FidelityManager.selectDesiredLevel(inputs, nil, current.fidelity)
		assert(
			desired == current.fidelity or desired == "F0" or desired == "F2",
			`Physics Lab F2 adapter cannot realize requested fidelity {desired}`
		)

		local result, record = runtime:step(entityId, inputs, nowSeconds, captureState, observeTransition)
		local representation = representations[entityId]
		if representation ~= nil then
			setEntityAttributes(representation, record)
		end

		if record.fidelity == "F0" then
			assert(representation == nil, `F0 transition left physical representation behind: {entityId}`)
		elseif record.fidelity == "F2" then
			assert(
				representation ~= nil,
				`F2 transition failed to rebuild physical representation: {entityId}`
			)
		else
			error(`Physics Lab runtime escaped F0/F2 adapter boundary at {record.fidelity}`)
		end
		syncMetrics(model, runtime, representations)
		return result, record
	end

	local function destroy(): ()
		if destroyed then
			return
		end
		destroyed = true
		model:Destroy()
		table.clear(representations)
		runtime:dispose()
	end

	return table.freeze({
		model = model,
		step = step,
		getRecord = getRecord,
		isRepresented = isRepresented,
		ownsRepresentation = ownsRepresentation,
		destroy = destroy,
	})
end

return table.freeze(PhysicsLabRealizer)