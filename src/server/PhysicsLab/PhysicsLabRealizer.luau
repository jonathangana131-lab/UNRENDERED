--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local MaterialFixtures = require(Shared.Materials.MaterialFixtures)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)

local PhysicsLabRealizer = {}

PhysicsLabRealizer.ModelName = "UNRENDERED_PhysicsLab"
PhysicsLabRealizer.OwnershipAttribute = "UNRENDEREDPhysicsLabOwned"

type Recipe = PhysicsLabRecipe.Recipe
type LabElement = PhysicsLabRecipe.LabElement
type MaterialReference = PhysicsLabRecipe.MaterialReference
type Genome = PhysicsLabRecipe.Genome
type MechanismSpec = PhysicsLabRecipe.MechanismSpec

local MATERIALS_BY_ID: { [string]: any } = table.freeze({
	[MaterialFixtures.CommercialWallpaperDrywall.id] = MaterialFixtures.CommercialWallpaperDrywall,
	[MaterialFixtures.LowPileCarpet.id] = MaterialFixtures.LowPileCarpet,
	[MaterialFixtures.PaintedMetal.id] = MaterialFixtures.PaintedMetal,
})

local function vector3(value: PhysicsLabRecipe.Vec3): Vector3
	return Vector3.new(value.x, value.y, value.z)
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
	target:SetAttribute("StateRevision", element.entity.stateRevision)
	target:SetAttribute("RepresentationRevision", element.entity.representationRevision)
	if element.objectGenomeId ~= nil then
		target:SetAttribute("ObjectGenomeId", element.objectGenomeId)
	end
	if element.mechanismKey ~= nil then
		target:SetAttribute("MechanismKey", element.mechanismKey)
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

local function realizeBox(element: LabElement, parent: Instance, anchored: boolean): ()
	local model = newEntityModel(element, parent)
	local part =
		newPart("Body", vector3(element.sizeStuds), cframeFor(element), anchored, element.material, model)
	applyEntityDiagnostics(part, element)
	model.PrimaryPart = part
	addStudioDiagnostic(part, element)
end

local function realizeRollingCart(element: LabElement, parent: Instance): ()
	local model = newEntityModel(element, parent)
	local size = vector3(element.sizeStuds)
	local bodyCFrame = cframeFor(element)
	local chassisSize = Vector3.new(size.X, math.max(0.45, size.Y * 0.42), size.Z)
	local chassis = newPart("Chassis", chassisSize, bodyCFrame, false, element.material, model)
	applyEntityDiagnostics(chassis, element)
	chassis:SetNetworkOwner(nil)

	local wheelDiameter = math.max(0.65, math.min(size.X, size.Z) * 0.28)
	local wheelWidth = math.max(0.32, wheelDiameter * 0.42)
	local halfX = math.max(0.1, size.X * 0.5 - wheelWidth * 0.55)
	local halfZ = math.max(0.1, size.Z * 0.5 - wheelDiameter * 0.55)
	local wheelY = -chassisSize.Y * 0.5 + wheelDiameter * 0.15

	local wheelOffsets = {
		Vector3.new(-halfX, wheelY, -halfZ),
		Vector3.new(halfX, wheelY, -halfZ),
		Vector3.new(-halfX, wheelY, halfZ),
		Vector3.new(halfX, wheelY, halfZ),
	}
	for index, offset in ipairs(wheelOffsets) do
		local wheelCFrame = bodyCFrame * CFrame.new(offset)
		local wheel = newPart(
			`Wheel{index}`,
			Vector3.new(wheelWidth, wheelDiameter, wheelDiameter),
			wheelCFrame,
			false,
			element.material,
			model
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel:SetNetworkOwner(nil)
		applyEntityDiagnostics(wheel, element)

		local chassisAttachment = Instance.new("Attachment")
		chassisAttachment.Name = `WheelMount{index}`
		chassisAttachment.Position = offset
		chassisAttachment.Axis = Vector3.new(1, 0, 0)
		chassisAttachment.Parent = chassis

		local wheelAttachment = Instance.new("Attachment")
		wheelAttachment.Name = `WheelAxle{index}`
		wheelAttachment.Axis = Vector3.new(1, 0, 0)
		wheelAttachment.Parent = wheel

		local hinge = Instance.new("HingeConstraint")
		hinge.Name = `WheelHinge{index}`
		hinge.Attachment0 = chassisAttachment
		hinge.Attachment1 = wheelAttachment
		hinge.Parent = model

		local noCollision = Instance.new("NoCollisionConstraint")
		noCollision.Name = `WheelNoCollision{index}`
		noCollision.Part0 = chassis
		noCollision.Part1 = wheel
		noCollision.Parent = model
	end

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
	local model = newEntityModel(element, parent)
	local size = vector3(element.sizeStuds)
	local panelCFrame = cframeFor(element)
	local panel = newPart("Panel", size, panelCFrame, false, element.material, model)
	applyEntityDiagnostics(panel, element)
	panel:SetNetworkOwner(nil)

	local anchor = newPart(
		"HingeAnchor",
		Vector3.new(0.2, size.Y, 0.2),
		panelCFrame * CFrame.new(-size.X * 0.5, 0, 0),
		true,
		element.material,
		model
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	applyEntityDiagnostics(anchor, element)

	local frameAttachment = Instance.new("Attachment")
	frameAttachment.Name = "FrameAttachment"
	frameAttachment.Axis = Vector3.new(0, 1, 0)
	frameAttachment.Parent = anchor

	local panelAttachment = Instance.new("Attachment")
	panelAttachment.Name = "PanelAttachment"
	panelAttachment.Position = Vector3.new(-size.X * 0.5, 0, 0)
	panelAttachment.Axis = Vector3.new(0, 1, 0)
	panelAttachment.Parent = panel

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "DoorHinge"
	hinge.Attachment0 = frameAttachment
	hinge.Attachment1 = panelAttachment
	hinge.LimitsEnabled = true
	hinge.LowerAngle = 0
	hinge.UpperAngle = 105
	hinge.Parent = model

	model.PrimaryPart = panel
	addStudioDiagnostic(panel, element)
end

local function findMovingComponent(genome: Genome, mechanism: MechanismSpec): any
	local movingComponentKey = (mechanism :: any).movingComponentKey
	assert(type(movingComponentKey) == "string", "Physics Lab mechanism must identify a moving component")
	for _, component in ipairs(genome.components) do
		if component.key == movingComponentKey then
			return component
		end
	end
	error(`Physics Lab mechanism references missing component {movingComponentKey}`)
end

local function realizeDrawerProxy(element: LabElement, parent: Instance): ()
	local genome = PhysicsLabRecipe.objectGenomeFor(element)
	assert(genome ~= nil, "Physics Lab drawer proxy requires a bound ObjectGenome")
	local mechanism = PhysicsLabRecipe.mechanismFor(element)
	assert(mechanism ~= nil and mechanism.kind == "slide", "Physics Lab drawer proxy requires a slide mechanism")
	local movingComponent = findMovingComponent(genome, mechanism)
	local scale = PhysicsLabRecipe.StudsPerMeter

	local model = newEntityModel(element, parent)
	local size = vector3(element.sizeStuds)
	local shellCFrame = cframeFor(element)
	local drawerSize = Vector3.new(
		movingComponent.dimensionsM.x * scale,
		movingComponent.dimensionsM.y * scale,
		movingComponent.dimensionsM.z * scale
	)
	local drawerOffset = Vector3.new(
		movingComponent.localPositionM.x * scale,
		movingComponent.localPositionM.y * scale,
		movingComponent.localPositionM.z * scale
	)
	local drawerCFrame = shellCFrame * CFrame.new(drawerOffset)

	-- The cabinet carcass is deliberately decomposed instead of represented by
	-- one solid box. A full collidable shell would begin by interpenetrating the
	-- dynamic drawer and normalize an unstable mechanism test.
	local wallThickness = math.min(
		0.08,
		math.max(0.05, (size.X - drawerSize.X) * 0.4),
		math.max(0.05, (size.Z - drawerSize.Z) * 0.4)
	)
	local halfX = size.X * 0.5
	local halfY = size.Y * 0.5
	local halfZ = size.Z * 0.5

	local carcassSpecs = {
		{
			name = "SideLeft",
			size = Vector3.new(wallThickness, size.Y, size.Z),
			offset = Vector3.new(-halfX + wallThickness * 0.5, 0, 0),
		},
		{
			name = "SideRight",
			size = Vector3.new(wallThickness, size.Y, size.Z),
			offset = Vector3.new(halfX - wallThickness * 0.5, 0, 0),
		},
		{
			name = "Top",
			size = Vector3.new(size.X - wallThickness * 2, wallThickness, size.Z),
			offset = Vector3.new(0, halfY - wallThickness * 0.5, 0),
		},
		{
			name = "Bottom",
			size = Vector3.new(size.X - wallThickness * 2, wallThickness, size.Z),
			offset = Vector3.new(0, -halfY + wallThickness * 0.5, 0),
		},
		{
			name = "Back",
			size = Vector3.new(size.X - wallThickness * 2, size.Y - wallThickness * 2, wallThickness),
			offset = Vector3.new(0, 0, halfZ - wallThickness * 0.5),
		},
	}

	local primaryPart: BasePart? = nil
	for _, spec in ipairs(carcassSpecs) do
		local part = newPart(spec.name, spec.size, shellCFrame * CFrame.new(spec.offset), true, element.material, model)
		applyEntityDiagnostics(part, element)
		if spec.name == "Back" then
			primaryPart = part
		end
	end
	assert(primaryPart ~= nil, "Physics Lab cabinet carcass is missing its back panel")

	local drawer = newPart("Drawer", drawerSize, drawerCFrame, false, element.material, model)
	drawer:SetNetworkOwner(nil)
	applyEntityDiagnostics(drawer, element)

	local guide = newPart("SlideGuide", Vector3.new(0.05, 0.05, 0.05), drawerCFrame, true, element.material, model)
	guide.Transparency = 1
	guide.CanCollide = false
	guide.CanQuery = false
	guide.CanTouch = false
	applyEntityDiagnostics(guide, element)

	local slideAxis = Vector3.new(mechanism.axis.x, mechanism.axis.y, mechanism.axis.z)
	assert(slideAxis.Magnitude > 0, "Physics Lab slide axis must be non-zero")

	local guideAttachment = Instance.new("Attachment")
	guideAttachment.Name = "ShellSlideAttachment"
	guideAttachment.Axis = slideAxis.Unit
	guideAttachment.Parent = guide

	local drawerAttachment = Instance.new("Attachment")
	drawerAttachment.Name = "DrawerSlideAttachment"
	drawerAttachment.Axis = slideAxis.Unit
	drawerAttachment.Parent = drawer

	local slide = Instance.new("PrismaticConstraint")
	slide.Name = "DrawerSlide"
	slide.Attachment0 = guideAttachment
	slide.Attachment1 = drawerAttachment
	slide.LimitsEnabled = true
	slide.LowerLimit = mechanism.minTravelM * scale
	slide.UpperLimit = mechanism.maxTravelM * scale
	slide.Parent = model

	model.PrimaryPart = primaryPart
	addStudioDiagnostic(primaryPart, element)
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
	if existing == nil then
		return
	end
	assert(
		existing:GetAttribute(PhysicsLabRealizer.OwnershipAttribute) == true,
		`refusing to destroy unrelated content named {PhysicsLabRealizer.ModelName}`
	)
	existing:Destroy()
end

function PhysicsLabRealizer.realize(recipe: Recipe, parent: Instance): (Folder, { [string]: Instance })
	PhysicsLabRecipe.validate(recipe)
	PhysicsLabRealizer.destroy(parent)

	local root = Instance.new("Folder")
	root.Name = PhysicsLabRealizer.ModelName
	root:SetAttribute(PhysicsLabRealizer.OwnershipAttribute, true)
	root:SetAttribute("RecipeId", recipe.recipeId)
	root:SetAttribute("RecipeVersion", recipe.recipeVersion)
	root:SetAttribute("WorldId", recipe.worldId)
	root:SetAttribute("RegionId", recipe.regionId)
	root:SetAttribute("PhysicalRepresentationOnly", true)
	root.Parent = parent

	local representations: { [string]: Instance } = {}
	local ok, realizeError = pcall(function()
		for _, element in ipairs(recipe.elements) do
			realizeElement(element, root)
			local representation = root:FindFirstChild(element.key)
			assert(representation ~= nil, `Physics Lab realization missing model: {element.key}`)
			assert(
				representations[element.entity.id] == nil,
				`duplicate realized WorldEntityId: {element.entity.id}`
			)
			representations[element.entity.id] = representation
		end
	end)
	if not ok then
		root:Destroy()
		error(realizeError)
	end

	return root, representations
end

return table.freeze(PhysicsLabRealizer)
