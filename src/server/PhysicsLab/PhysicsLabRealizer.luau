--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local ObjectGenome = require(Shared.Objects.ObjectGenome)
local PhysicsLabRecipe = require(Shared.PhysicsLab.PhysicsLabRecipe)

type LabItem = PhysicsLabRecipe.LabItem
type Recipe = PhysicsLabRecipe.Recipe
type Vec3 = PhysicsLabRecipe.Vec3

local PhysicsLabRealizer = {}

PhysicsLabRealizer.ModelName = "UNRENDERED_PhysicsLab"

local function metersToStuds(recipe: Recipe, value: number): number
	return value / recipe.metersPerStud
end

local function sizeToStuds(recipe: Recipe, value: Vec3): Vector3
	return Vector3.new(
		metersToStuds(recipe, value.x),
		metersToStuds(recipe, value.y),
		metersToStuds(recipe, value.z)
	)
end

local function positionToStuds(recipe: Recipe, value: Vec3): Vector3
	return sizeToStuds(recipe, value)
end

local function toCFrame(recipe: Recipe, item: LabItem): CFrame
	local position = positionToStuds(recipe, item.transform.positionM)
	local rotation = item.transform.rotationDeg
	return CFrame.new(position)
		* CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
end

local function applyFallbackMaterial(part: BasePart, materialId: string?): ()
	if materialId == nil then
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(145, 145, 140)
	elseif string.find(materialId, "carpet", 1, true) ~= nil then
		part.Material = Enum.Material.Fabric
		part.Color = Color3.fromRGB(116, 106, 79)
	elseif string.find(materialId, "wallpaper", 1, true) ~= nil then
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(184, 173, 107)
	elseif string.find(materialId, "upholstery", 1, true) ~= nil then
		part.Material = Enum.Material.Fabric
		part.Color = Color3.fromRGB(63, 62, 58)
	elseif string.find(materialId, "polymer", 1, true) ~= nil then
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(48, 48, 46)
	elseif string.find(materialId, "laminate", 1, true) ~= nil then
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(167, 151, 118)
	elseif string.find(materialId, "metal", 1, true) ~= nil or string.find(materialId, "steel", 1, true) ~= nil then
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(119, 117, 110)
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(145, 145, 140)
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function applyEntityAttributes(instance: Instance, item: LabItem): ()
	instance:SetAttribute("UNRENDERED_WorldEntityId", item.entity.id)
	instance:SetAttribute("UNRENDERED_Fidelity", item.entity.fidelity)
	instance:SetAttribute("UNRENDERED_RecipeKey", item.entity.origin.recipeKey)
	instance:SetAttribute("UNRENDERED_Role", item.role)
	instance:SetAttribute("UNRENDERED_RepresentationKind", item.representationKind)
	if item.materialRef ~= nil then
		instance:SetAttribute("UNRENDERED_MaterialId", item.materialRef.id)
		instance:SetAttribute("UNRENDERED_MaterialRecipeVersion", item.materialRef.recipeVersion)
	end
end

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	anchored: boolean,
	materialId: string?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = anchored
	part.CanCollide = true
	applyFallbackMaterial(part, materialId)
	part.Parent = parent
	return part
end

local function realizeBlock(recipe: Recipe, parent: Model, item: LabItem): BasePart
	local materialId = if item.materialRef ~= nil then item.materialRef.id else nil
	local part = newPart(parent, item.key, sizeToStuds(recipe, item.dimensionsM), toCFrame(recipe, item), item.anchored, materialId)
	applyEntityAttributes(part, item)
	return part
end

local function realizeStairs(recipe: Recipe, parent: Model, item: LabItem): Model
	local stepCount = item.stepCount or 1
	local model = Instance.new("Model")
	model.Name = item.key
	applyEntityAttributes(model, item)
	model:SetAttribute("UNRENDERED_StepCount", stepCount)
	model.Parent = parent

	local base = toCFrame(recipe, item)
	local total = item.dimensionsM
	local stepHeightM = total.y / stepCount
	local stepDepthM = total.z / stepCount
	local materialId = if item.materialRef ~= nil then item.materialRef.id else nil
	for index = 1, stepCount do
		local heightM = stepHeightM * index
		local localYM = -total.y / 2 + heightM / 2
		local localZM = -total.z / 2 + stepDepthM * (index - 0.5)
		local size = sizeToStuds(recipe, { x = total.x, y = heightM, z = stepDepthM })
		local offset = CFrame.new(0, metersToStuds(recipe, localYM), metersToStuds(recipe, localZM))
		local step = newPart(model, `step-{index}`, size, base * offset, true, materialId)
		applyEntityAttributes(step, item)
	end
	return model
end

local function realizeSpawn(recipe: Recipe, parent: Model, item: LabItem): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = item.key
	spawn.Size = sizeToStuds(recipe, item.dimensionsM)
	spawn.CFrame = toCFrame(recipe, item)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.65
	spawn.Neutral = true
	spawn.Duration = 0
	applyFallbackMaterial(spawn, if item.materialRef ~= nil then item.materialRef.id else nil)
	applyEntityAttributes(spawn, item)
	spawn.Parent = parent
	return spawn
end

local function realizeDoorProbe(recipe: Recipe, parent: Model, item: LabItem): Model
	local model = Instance.new("Model")
	model.Name = item.key
	applyEntityAttributes(model, item)
	model:SetAttribute("UNRENDERED_Mechanism", "hinge-probe")
	model.Parent = parent

	local base = toCFrame(recipe, item)
	local size = sizeToStuds(recipe, item.dimensionsM)
	local materialId = if item.materialRef ~= nil then item.materialRef.id else nil
	local frameThickness = metersToStuds(recipe, 0.08)
	local frameDepth = math.max(size.Z * 1.8, metersToStuds(recipe, 0.12))
	local frameHeight = size.Y + metersToStuds(recipe, 0.10)

	local hingePost = newPart(
		model,
		"hinge-frame",
		Vector3.new(frameThickness, frameHeight, frameDepth),
		base * CFrame.new(-(size.X + frameThickness) / 2, 0, 0),
		true,
		materialId
	)
	local latchPost = newPart(
		model,
		"latch-frame",
		Vector3.new(frameThickness, frameHeight, frameDepth),
		base * CFrame.new((size.X + frameThickness) / 2, 0, 0),
		true,
		materialId
	)
	local header = newPart(
		model,
		"header-frame",
		Vector3.new(size.X + frameThickness * 2, frameThickness, frameDepth),
		base * CFrame.new(0, (size.Y + frameThickness) / 2, 0),
		true,
		materialId
	)
	local panel = newPart(model, "door-panel", size, base, false, materialId)
	applyEntityAttributes(hingePost, item)
	applyEntityAttributes(latchPost, item)
	applyEntityAttributes(header, item)
	applyEntityAttributes(panel, item)

	local frameAttachment = Instance.new("Attachment")
	frameAttachment.Name = "hinge-frame-attachment"
	frameAttachment.Position = Vector3.new(frameThickness / 2, 0, 0)
	frameAttachment.Axis = Vector3.new(0, 1, 0)
	frameAttachment.SecondaryAxis = Vector3.new(0, 0, 1)
	frameAttachment.Parent = hingePost

	local panelAttachment = Instance.new("Attachment")
	panelAttachment.Name = "hinge-panel-attachment"
	panelAttachment.Position = Vector3.new(-size.X / 2, 0, 0)
	panelAttachment.Axis = Vector3.new(0, 1, 0)
	panelAttachment.SecondaryAxis = Vector3.new(0, 0, 1)
	panelAttachment.Parent = panel

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "door-hinge"
	hinge.Attachment0 = frameAttachment
	hinge.Attachment1 = panelAttachment
	hinge.ActuatorType = Enum.ActuatorType.None
	hinge.LimitsEnabled = true
	hinge.LowerAngle = -110
	hinge.UpperAngle = 110
	hinge.Parent = model

	model.PrimaryPart = panel
	return model
end

local function weld(root: BasePart, part: BasePart, parent: Instance): WeldConstraint
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = parent
	return constraint
end

local function realizeCartProbe(recipe: Recipe, parent: Model, item: LabItem): Model
	local model = Instance.new("Model")
	model.Name = item.key
	applyEntityAttributes(model, item)
	model:SetAttribute("UNRENDERED_Mechanism", "four-wheel-hinge-probe")
	model.Parent = parent

	local base = toCFrame(recipe, item)
	local dimensions = item.dimensionsM
	local materialId = if item.materialRef ~= nil then item.materialRef.id else nil
	local chassis = newPart(
		model,
		"chassis",
		sizeToStuds(recipe, { x = dimensions.x * 0.92, y = 0.08, z = dimensions.z * 0.92 }),
		base * CFrame.new(0, metersToStuds(recipe, -dimensions.y * 0.32), 0),
		false,
		materialId
	)
	applyEntityAttributes(chassis, item)

	local rigidParts: { BasePart } = {}
	local shelfOffsetsM = { -dimensions.y * 0.16, dimensions.y * 0.34 }
	for index, offsetM in ipairs(shelfOffsetsM) do
		local shelf = newPart(
			model,
			`shelf-{index}`,
			sizeToStuds(recipe, { x = dimensions.x * 0.90, y = 0.05, z = dimensions.z * 0.90 }),
			base * CFrame.new(0, metersToStuds(recipe, offsetM), 0),
			false,
			materialId
		)
		applyEntityAttributes(shelf, item)
		table.insert(rigidParts, shelf)
	end

	for _, xSign in ipairs({ -1, 1 }) do
		for _, zSign in ipairs({ -1, 1 }) do
			local post = newPart(
				model,
				`post-{xSign}-{zSign}`,
				sizeToStuds(recipe, { x = 0.04, y = dimensions.y * 0.68, z = 0.04 }),
				base
					* CFrame.new(
						metersToStuds(recipe, xSign * dimensions.x * 0.40),
						metersToStuds(recipe, 0.02),
						metersToStuds(recipe, zSign * dimensions.z * 0.40)
					),
				false,
				materialId
			)
			applyEntityAttributes(post, item)
			table.insert(rigidParts, post)
		end
	end
	for _, part in ipairs(rigidParts) do
		weld(chassis, part, model)
	end

	local wheelRadiusM = 0.09
	local wheelWidthM = 0.045
	for _, xSign in ipairs({ -1, 1 }) do
		for _, zSign in ipairs({ -1, 1 }) do
			local wheelPosition = base
				* CFrame.new(
					metersToStuds(recipe, xSign * dimensions.x * 0.38),
					metersToStuds(recipe, -dimensions.y * 0.47),
					metersToStuds(recipe, zSign * dimensions.z * 0.36)
				)
			local wheel = newPart(
				model,
				`wheel-{xSign}-{zSign}`,
				sizeToStuds(recipe, { x = wheelWidthM, y = wheelRadiusM * 2, z = wheelRadiusM * 2 }),
				wheelPosition,
				false,
				"material.v1.chair-caster.polymer-rubber"
			)
			wheel.Shape = Enum.PartType.Cylinder
			applyEntityAttributes(wheel, item)

			local chassisAttachment = Instance.new("Attachment")
			chassisAttachment.Position = chassis.CFrame:PointToObjectSpace(wheel.Position)
			chassisAttachment.Axis = Vector3.new(1, 0, 0)
			chassisAttachment.SecondaryAxis = Vector3.new(0, 1, 0)
			chassisAttachment.Parent = chassis

			local wheelAttachment = Instance.new("Attachment")
			wheelAttachment.Axis = Vector3.new(1, 0, 0)
			wheelAttachment.SecondaryAxis = Vector3.new(0, 1, 0)
			wheelAttachment.Parent = wheel

			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = chassisAttachment
			hinge.Attachment1 = wheelAttachment
			hinge.ActuatorType = Enum.ActuatorType.None
			hinge.Parent = model
		end
	end

	model.PrimaryPart = chassis
	return model
end

local function mechanismAxis(mechanism: any): Vector3
	local axis = mechanism.axis
	if type(axis) ~= "table" then
		return Vector3.new(0, 0, -1)
	end
	local vector = Vector3.new(axis.x, axis.y, axis.z)
	if vector.Magnitude == 0 then
		return Vector3.new(0, 0, -1)
	end
	return vector.Unit
end

local function realizeObjectGenome(recipe: Recipe, parent: Model, item: LabItem): Model
	local genome = item.genome
	assert(genome ~= nil, `object-genome item {item.key} is missing genome`)
	local report = ObjectGenome.inspect(genome)
	assert(report.ok, `object-genome item {item.key} failed validation during realization`)

	local model = Instance.new("Model")
	model.Name = item.key
	applyEntityAttributes(model, item)
	model:SetAttribute("UNRENDERED_ObjectGenomeId", ObjectGenome.identityKey(genome))
	model:SetAttribute("UNRENDERED_ObjectGenomeFingerprint", ObjectGenome.recipeFingerprint(genome))
	model:SetAttribute("UNRENDERED_MechanismCount", #genome.mechanisms)
	model.Parent = parent

	local base = toCFrame(recipe, item)
	local componentParts: { [string]: BasePart } = {}
	local rootPart: BasePart? = nil
	local rootMass = -math.huge
	for _, component in ipairs(genome.components) do
		local localPosition = positionToStuds(recipe, component.localPositionM)
		local localRotation = component.localRotationDeg
		local componentCFrame = base
			* CFrame.new(localPosition)
			* CFrame.Angles(
				math.rad(localRotation.x),
				math.rad(localRotation.y),
				math.rad(localRotation.z)
			)
		local part = newPart(
			model,
			component.key,
			sizeToStuds(recipe, component.dimensionsM),
			componentCFrame,
			true,
			component.materialKey
		)
		part:SetAttribute("UNRENDERED_ComponentKey", component.key)
		part:SetAttribute("UNRENDERED_ComponentRole", component.role)
		part:SetAttribute("UNRENDERED_MaterialId", component.materialKey)
		part:SetAttribute("UNRENDERED_MaterialRecipeVersion", component.materialRecipeVersion)
		applyEntityAttributes(part, item)
		componentParts[component.key] = part
		if component.massKg > rootMass then
			rootMass = component.massKg
			rootPart = part
		end
	end
	assert(rootPart ~= nil, `object-genome item {item.key} has no realizable components`)

	local slideMoving: { [string]: boolean } = {}
	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.kind == "slide" then
			slideMoving[mechanism.movingComponentKey] = true
		end
	end
	for componentKey, part in pairs(componentParts) do
		if part ~= rootPart and not slideMoving[componentKey] then
			weld(rootPart, part, model)
		end
	end

	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.kind == "slide" then
			local moving = componentParts[mechanism.movingComponentKey]
			local frame = componentParts[mechanism.frameComponentKey]
			if moving ~= nil and frame ~= nil then
				local axis = mechanismAxis(mechanism)
				local frameAttachment = Instance.new("Attachment")
				frameAttachment.Name = `{mechanism.key}-frame`
				frameAttachment.Position = frame.CFrame:PointToObjectSpace(moving.Position)
				frameAttachment.Axis = axis
				frameAttachment.Parent = frame

				local movingAttachment = Instance.new("Attachment")
				movingAttachment.Name = `{mechanism.key}-moving`
				movingAttachment.Axis = axis
				movingAttachment.Parent = moving

				local slide = Instance.new("PrismaticConstraint")
				slide.Name = mechanism.key
				slide.Attachment0 = frameAttachment
				slide.Attachment1 = movingAttachment
				slide.ActuatorType = Enum.ActuatorType.None
				slide.LimitsEnabled = true
				slide.LowerLimit = metersToStuds(recipe, mechanism.minTravelM)
				slide.UpperLimit = metersToStuds(recipe, mechanism.maxTravelM)
				slide.Parent = model
			end
		end
	end

	for _, part in pairs(componentParts) do
		part.Anchored = item.anchored
	end
	model.PrimaryPart = rootPart
	return model
end

function PhysicsLabRealizer.realize(recipe: Recipe): Model
	assert(recipe.metersPerStud > 0, "Physics Lab metersPerStud must be positive")
	local existing = Workspace:FindFirstChild(PhysicsLabRealizer.ModelName)
	if existing ~= nil then
		existing:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = PhysicsLabRealizer.ModelName
	root:SetAttribute("UNRENDERED_WorldId", recipe.worldId)
	root:SetAttribute("UNRENDERED_RegionId", recipe.regionId)
	root:SetAttribute("UNRENDERED_RecipeVersion", recipe.recipeVersion)
	root:SetAttribute("UNRENDERED_GeneratorVersion", recipe.generatorVersion)
	root:SetAttribute("UNRENDERED_MetersPerStud", recipe.metersPerStud)
	root:SetAttribute("UNRENDERED_EntityCount", #recipe.items)
	root.Parent = Workspace

	for _, item in ipairs(recipe.items) do
		if item.representationKind == "block" or item.representationKind == "ramp" then
			realizeBlock(recipe, root, item)
		elseif item.representationKind == "stairs" then
			realizeStairs(recipe, root, item)
		elseif item.representationKind == "door-probe" then
			realizeDoorProbe(recipe, root, item)
		elseif item.representationKind == "cart-probe" then
			realizeCartProbe(recipe, root, item)
		elseif item.representationKind == "object-genome" then
			realizeObjectGenome(recipe, root, item)
		elseif item.representationKind == "spawn-anchor" then
			realizeSpawn(recipe, root, item)
		else
			error(`unknown Physics Lab representation kind: {item.representationKind}`)
		end
	end

	return root
end

return table.freeze(PhysicsLabRealizer)
