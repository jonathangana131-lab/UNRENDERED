--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local MaterialFixtures = require(Shared.Materials.MaterialFixtures)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)

local PhysicsLabRealizer = {}

PhysicsLabRealizer.ModelName = "UNRENDERED_PhysicsLab"

type Recipe = PhysicsLabRecipe.Recipe
type LabElement = PhysicsLabRecipe.LabElement
type MaterialReference = PhysicsLabRecipe.MaterialReference

local MATERIALS_BY_ID: { [string]: any } = table.freeze({
	[MaterialFixtures.CommercialWallpaperDrywall.id] = MaterialFixtures.CommercialWallpaperDrywall,
	[MaterialFixtures.LowPileCarpet.id] = MaterialFixtures.LowPileCarpet,
	[MaterialFixtures.PaintedMetal.id] = MaterialFixtures.PaintedMetal,
})

local function vector3(value: PhysicsLabRecipe.Vec3): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

local function metersVector3(value: any): Vector3
	local scale = PhysicsLabRecipe.StudsPerMeter
	return Vector3.new(value.x * scale, value.y * scale, value.z * scale)
end

local function cframeFor(element: LabElement): CFrame
	return CFrame.new(vector3(element.positionStuds)) * CFrame.Angles(0, math.rad(element.yawDegrees), 0)
end

local function materialFor(reference: MaterialReference): any
	local material = MATERIALS_BY_ID[reference.id]
	assert(material ~= nil, `Physics Lab realization missing material recipe: {reference.id}`)
	assert(
		material.recipeVersion == reference.recipeVersion,
		`Physics Lab material revision mismatch: {reference.id}`
	)
	return material
end

local function applyMaterial(part: BasePart, reference: MaterialReference): ()
	local material = materialFor(reference)
	part.Color = Color3.new(material.finish.color.r, material.finish.color.g, material.finish.color.b)

	if reference.id == MaterialFixtures.LowPileCarpet.id then
		part.Material = Enum.Material.Fabric
	elseif reference.id == MaterialFixtures.PaintedMetal.id then
		part.Material = Enum.Material.Metal
	else
		part.Material = Enum.Material.SmoothPlastic
	end

	part:SetAttribute("MaterialRecipeId", reference.id)
	part:SetAttribute("MaterialRecipeVersion", reference.recipeVersion)
	part:SetAttribute("MaterialPhysicalClass", material.physical.classKey)
	part:SetAttribute("MaterialAcousticClass", material.acoustic.classKey)
end

local function applyEntityDiagnostics(target: Instance, element: LabElement): ()
	target:SetAttribute("WorldEntityId", element.entity.id)
	target:SetAttribute("WorldEntityKind", element.entity.kind)
	target:SetAttribute("WorldId", element.entity.origin.worldId)
	target:SetAttribute("RegionId", element.entity.origin.regionId)
	target:SetAttribute("Fidelity", element.entity.fidelity)
	target:SetAttribute("RecipeKey", element.entity.origin.recipeKey)
	if element.objectGenomeId ~= nil then
		target:SetAttribute("ObjectGenomeId", element.objectGenomeId)
	end
end

local function addStudioDiagnostic(part: BasePart, element: LabElement): ()
	if not RunService:IsStudio() then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UNRENDERED_Diagnostic"
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(320, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(part.Size.Y * 0.5, 0.5) + 0.6, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 12
	label.TextWrapped = true
	label.Text = `{element.key} | {element.entity.fidelity}\n{element.entity.id}`
	label.Parent = billboard
end

local function newPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	anchored: boolean,
	material: MaterialReference,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = anchored
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	applyMaterial(part, material)
	part.Parent = parent
	return part
end

local function newWedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: MaterialReference,
	parent: Instance
): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	applyMaterial(part, material)
	part.Parent = parent
	return part
end

local function newEntityModel(element: LabElement, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = element.key
	applyEntityDiagnostics(model, element)
	model.Parent = parent
	return model
end

local function objectGenome(element: LabElement): any
	local genome = PhysicsLabRecipe.objectGenomeForElement(element)
	assert(genome ~= nil, `{element.key} representation requires an ObjectGenome`)
	return genome
end

local function componentByKey(genome: any, key: string): any
	for _, component in ipairs(genome.components) do
		if component.key == key then
			return component
		end
	end
	error(`ObjectGenome component not found: {key}`)
end

local function firstMechanism(genome: any, kind: string): any
	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.kind == kind then
			return mechanism
		end
	end
	error(`ObjectGenome mechanism not found: {kind}`)
end

local function realizeBox(element: LabElement, parent: Instance, anchored: boolean): ()
	local model = newEntityModel(element, parent)
	local part =
		newPart("Body", vector3(element.sizeStuds), cframeFor(element), anchored, element.material, model)
	applyEntityDiagnostics(part, element)
	if not anchored then
		part:SetNetworkOwner(nil)
	end
	model.PrimaryPart = part
	addStudioDiagnostic(part, element)
end

local function realizeRollingCart(element: LabElement, parent: Instance): ()
	local genome = objectGenome(element)
	local model = newEntityModel(element, parent)
	local objectCFrame = cframeFor(element)
	local chassisComponent = componentByKey(genome, "chassis")
	local chassis = newPart(
		"Chassis",
		metersVector3(chassisComponent.dimensionsM),
		objectCFrame * CFrame.new(metersVector3(chassisComponent.localPositionM)),
		false,
		element.material,
		model
	)
	applyEntityDiagnostics(chassis, element)
	chassis:SetNetworkOwner(nil)

	for _, component in ipairs(genome.components) do
		if component.key ~= "chassis" and string.sub(component.key, 1, 7) ~= "caster-" then
			local part = newPart(
				component.key,
				metersVector3(component.dimensionsM),
				objectCFrame * CFrame.new(metersVector3(component.localPositionM)),
				false,
				element.material,
				model
			)
			part.Massless = true
			part:SetNetworkOwner(nil)
			local weld = Instance.new("WeldConstraint")
			weld.Name = `Weld_{component.key}`
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = model
		end
	end

	local casterCount = 0
	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.kind == "caster" then
			casterCount += 1
			local component = componentByKey(genome, mechanism.movingComponentKey)
			local localOffset = metersVector3(component.localPositionM)
			local wheelRadius = mechanism.wheelRadiusM * PhysicsLabRecipe.StudsPerMeter
			local wheelWidth = math.max(
				0.08,
				component.dimensionsM.z * PhysicsLabRecipe.StudsPerMeter
			)
			local casterCFrame = objectCFrame * CFrame.new(localOffset)

			local hub = newPart(
				`Hub_{mechanism.key}`,
				Vector3.new(math.max(0.12, wheelWidth), math.max(0.12, wheelWidth), math.max(0.12, wheelWidth)),
				casterCFrame,
				false,
				element.material,
				model
			)
			hub.CanCollide = false
			hub.Massless = true
			hub:SetNetworkOwner(nil)

			local chassisAttachment = Instance.new("Attachment")
			chassisAttachment.Name = `Frame_{mechanism.key}`
			chassisAttachment.Position = metersVector3({
				x = component.localPositionM.x - chassisComponent.localPositionM.x,
				y = component.localPositionM.y - chassisComponent.localPositionM.y,
				z = component.localPositionM.z - chassisComponent.localPositionM.z,
			})
			chassisAttachment.Axis = Vector3.new(
				mechanism.swivelAxis.x,
				mechanism.swivelAxis.y,
				mechanism.swivelAxis.z
			)
			chassisAttachment.Parent = chassis

			local hubSwivelAttachment = Instance.new("Attachment")
			hubSwivelAttachment.Name = `Swivel_{mechanism.key}`
			hubSwivelAttachment.Axis = chassisAttachment.Axis
			hubSwivelAttachment.Parent = hub

			local swivel = Instance.new("HingeConstraint")
			swivel.Name = `Swivel_{mechanism.key}`
			swivel.Attachment0 = chassisAttachment
			swivel.Attachment1 = hubSwivelAttachment
			swivel:SetAttribute("ObjectGenomeMechanismKey", mechanism.key)
			swivel:SetAttribute("ObjectGenomeMechanismKind", mechanism.kind)
			swivel.Parent = model

			local wheel = newPart(
				`Wheel_{mechanism.key}`,
				Vector3.new(wheelWidth, wheelRadius * 2, wheelRadius * 2),
				casterCFrame,
				false,
				element.material,
				model
			)
			wheel.Shape = Enum.PartType.Cylinder
			wheel:SetNetworkOwner(nil)

			local hubRollAttachment = Instance.new("Attachment")
			hubRollAttachment.Name = `RollFrame_{mechanism.key}`
			hubRollAttachment.Axis = Vector3.new(
				mechanism.rollAxis.x,
				mechanism.rollAxis.y,
				mechanism.rollAxis.z
			)
			hubRollAttachment.Parent = hub

			local wheelAttachment = Instance.new("Attachment")
			wheelAttachment.Name = `RollWheel_{mechanism.key}`
			wheelAttachment.Axis = hubRollAttachment.Axis
			wheelAttachment.Parent = wheel

			local roll = Instance.new("HingeConstraint")
			roll.Name = `Roll_{mechanism.key}`
			roll.Attachment0 = hubRollAttachment
			roll.Attachment1 = wheelAttachment
			roll:SetAttribute("ObjectGenomeMechanismKey", mechanism.key)
			roll:SetAttribute("ObjectGenomeMechanismKind", mechanism.kind)
			roll.Parent = model
		end
	end
	assert(casterCount == 4, "Physics Lab rolling cart must realize four ObjectGenome casters")

	model.PrimaryPart = chassis
	addStudioDiagnostic(chassis, element)
end

local function realizeWedge(element: LabElement, parent: Instance): ()
	local model = newEntityModel(element, parent)
	local part = newWedge("Body", vector3(element.sizeStuds), cframeFor(element), element.material, model)
	applyEntityDiagnostics(part, element)
	model.PrimaryPart = part
	addStudioDiagnostic(part, element)
end

local function realizeHingedPanel(element: LabElement, parent: Instance): ()
	local genome = objectGenome(element)
	local hingeSpec = firstMechanism(genome, "hinge")
	local leafComponent = componentByKey(genome, hingeSpec.movingComponentKey)
	local model = newEntityModel(element, parent)
	local objectCFrame = cframeFor(element)
	local leafCFrame = objectCFrame * CFrame.new(metersVector3(leafComponent.localPositionM))
	local leafSize = metersVector3(leafComponent.dimensionsM)
	local panel = newPart("Panel", leafSize, leafCFrame, false, element.material, model)
	applyEntityDiagnostics(panel, element)
	panel:SetNetworkOwner(nil)

	local anchor = newPart(
		"HingeAnchor",
		Vector3.new(0.2, leafSize.Y, 0.2),
		leafCFrame * CFrame.new(-leafSize.X * 0.5, 0, 0),
		true,
		element.material,
		model
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	local frameAttachment = Instance.new("Attachment")
	frameAttachment.Name = "FrameAttachment"
	frameAttachment.Axis = Vector3.new(hingeSpec.axis.x, hingeSpec.axis.y, hingeSpec.axis.z)
	frameAttachment.Parent = anchor

	local panelAttachment = Instance.new("Attachment")
	panelAttachment.Name = "PanelAttachment"
	panelAttachment.Position = Vector3.new(-leafSize.X * 0.5, 0, 0)
	panelAttachment.Axis = frameAttachment.Axis
	panelAttachment.Parent = panel

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "DoorHinge"
	hinge.Attachment0 = frameAttachment
	hinge.Attachment1 = panelAttachment
	hinge.LimitsEnabled = true
	hinge.LowerAngle = hingeSpec.minDegrees
	hinge.UpperAngle = hingeSpec.maxDegrees
	hinge:SetAttribute("ObjectGenomeMechanismKey", hingeSpec.key)
	hinge:SetAttribute("ObjectGenomeMechanismKind", hingeSpec.kind)
	hinge.Parent = model

	model.PrimaryPart = panel
	addStudioDiagnostic(panel, element)
end

local function realizeDrawerProxy(element: LabElement, parent: Instance): ()
	local genome = objectGenome(element)
	local slideSpec = firstMechanism(genome, "slide")
	local shellComponent = componentByKey(genome, slideSpec.frameComponentKey)
	local drawerComponent = componentByKey(genome, slideSpec.movingComponentKey)
	local model = newEntityModel(element, parent)
	local objectCFrame = cframeFor(element)
	local shellCFrame = objectCFrame * CFrame.new(metersVector3(shellComponent.localPositionM))
	local shell = newPart(
		"Shell",
		metersVector3(shellComponent.dimensionsM),
		shellCFrame,
		true,
		element.material,
		model
	)
	applyEntityDiagnostics(shell, element)

	local drawer = newPart(
		"Drawer",
		metersVector3(drawerComponent.dimensionsM),
		objectCFrame * CFrame.new(metersVector3(drawerComponent.localPositionM)),
		false,
		element.material,
		model
	)
	drawer:SetNetworkOwner(nil)

	local shellAttachment = Instance.new("Attachment")
	shellAttachment.Name = "ShellSlideAttachment"
	shellAttachment.Position = metersVector3({
		x = drawerComponent.localPositionM.x - shellComponent.localPositionM.x,
		y = drawerComponent.localPositionM.y - shellComponent.localPositionM.y,
		z = drawerComponent.localPositionM.z - shellComponent.localPositionM.z,
	})
	shellAttachment.Axis = Vector3.new(slideSpec.axis.x, slideSpec.axis.y, slideSpec.axis.z)
	shellAttachment.Parent = shell

	local drawerAttachment = Instance.new("Attachment")
	drawerAttachment.Name = "DrawerSlideAttachment"
	drawerAttachment.Axis = shellAttachment.Axis
	drawerAttachment.Parent = drawer

	local slide = Instance.new("PrismaticConstraint")
	slide.Name = "DrawerSlide"
	slide.Attachment0 = shellAttachment
	slide.Attachment1 = drawerAttachment
	slide.LimitsEnabled = true
	slide.LowerLimit = slideSpec.minTravelM * PhysicsLabRecipe.StudsPerMeter
	slide.UpperLimit = slideSpec.maxTravelM * PhysicsLabRecipe.StudsPerMeter
	slide:SetAttribute("ObjectGenomeMechanismKey", slideSpec.key)
	slide:SetAttribute("ObjectGenomeMechanismKind", slideSpec.kind)
	slide.Parent = model

	model.PrimaryPart = shell
	addStudioDiagnostic(shell, element)
end

local function realizeSpawnAnchor(element: LabElement, parent: Instance): ()
	local model = newEntityModel(element, parent)
	local part =
		newPart("Anchor", vector3(element.sizeStuds), cframeFor(element), true, element.material, model)
	part.Transparency = 0.65
	part.CanCollide = false
	part.CanTouch = false
	part:SetAttribute("PhysicalCharacterSpawnAnchor", true)
	applyEntityDiagnostics(part, element)
	model.PrimaryPart = part
	addStudioDiagnostic(part, element)
end

local function realizeElement(element: LabElement, parent: Instance): ()
	if element.representationKind == "static-box" then
		realizeBox(element, parent, true)
	elseif element.representationKind == "dynamic-box" then
		realizeBox(element, parent, false)
	elseif element.representationKind == "rolling-cart-proxy" then
		realizeRollingCart(element, parent)
	elseif element.representationKind == "static-wedge" then
		realizeWedge(element, parent)
	elseif element.representationKind == "hinged-panel" then
		realizeHingedPanel(element, parent)
	elseif element.representationKind == "sliding-drawer-proxy" then
		realizeDrawerProxy(element, parent)
	elseif element.representationKind == "spawn-anchor" then
		realizeSpawnAnchor(element, parent)
	else
		error(`unsupported Physics Lab representation kind: {element.representationKind}`)
	end
end

function PhysicsLabRealizer.destroy(parent: Instance): ()
	local existing = parent:FindFirstChild(PhysicsLabRealizer.ModelName)
	if existing ~= nil then
		existing:Destroy()
	end
end

function PhysicsLabRealizer.realize(recipe: Recipe, parent: Instance): Folder
	PhysicsLabRecipe.validate(recipe)

	local root = Instance.new("Folder")
	root.Name = PhysicsLabRealizer.ModelName
	root:SetAttribute("RecipeId", recipe.recipeId)
	root:SetAttribute("RecipeVersion", recipe.recipeVersion)
	root:SetAttribute("WorldId", recipe.worldId)
	root:SetAttribute("RegionId", recipe.regionId)
	root:SetAttribute("PhysicalRepresentationOnly", true)

	local ok, realizationError = pcall(function()
		for _, element in recipe.elements do
			realizeElement(element, root)
		end
	end)
	if not ok then
		root:Destroy()
		error(realizationError)
	end

	PhysicsLabRealizer.destroy(parent)
	root.Parent = parent
	return root
end

return table.freeze(PhysicsLabRealizer)
