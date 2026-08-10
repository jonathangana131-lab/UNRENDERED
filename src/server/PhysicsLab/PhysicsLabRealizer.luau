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

local function componentSize(component: any): Vector3
	local scale = PhysicsLabRecipe.StudsPerMeter
	return Vector3.new(
		component.dimensionsM.x * scale,
		component.dimensionsM.y * scale,
		component.dimensionsM.z * scale
	)
end

local function componentCFrame(objectCFrame: CFrame, component: any): CFrame
	local scale = PhysicsLabRecipe.StudsPerMeter
	return objectCFrame
		* CFrame.new(
			component.localPositionM.x * scale,
			component.localPositionM.y * scale,
			component.localPositionM.z * scale
		)
		* CFrame.Angles(
			math.rad(component.localRotationDeg.x),
			math.rad(component.localRotationDeg.y),
			math.rad(component.localRotationDeg.z)
		)
end

local function findComponent(genome: Genome, componentKey: string): any
	for _, component in ipairs(genome.components) do
		if component.key == componentKey then
			return component
		end
	end
	error(`Physics Lab ObjectGenome references missing component {componentKey}`)
end

local function findMovingComponent(genome: Genome, mechanism: MechanismSpec): any
	local movingComponentKey = (mechanism :: any).movingComponentKey
	assert(type(movingComponentKey) == "string", "Physics Lab mechanism must identify a moving component")
	return findComponent(genome, movingComponentKey)
end

local function objectAxisInPart(objectCFrame: CFrame, part: BasePart, axis: any): Vector3
	local localAxis = Vector3.new(axis.x, axis.y, axis.z)
	assert(localAxis.Magnitude > 0, "Physics Lab mechanism axis must be non-zero")
	local worldAxis = objectCFrame:VectorToWorldSpace(localAxis.Unit)
	return part.CFrame:VectorToObjectSpace(worldAxis).Unit
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
	local genome = PhysicsLabRecipe.objectGenomeFor(element)
	assert(genome ~= nil, "Physics Lab rolling cart requires a bound ObjectGenome")
	local objectCFrame = cframeFor(element)
	local model = newEntityModel(element, parent)

	local casterComponents: { [string]: MechanismSpec } = {}
	for _, mechanism in ipairs(genome.mechanisms) do
		assert(mechanism.kind == "caster", "Physics Lab cart supports only authored caster mechanisms")
		casterComponents[mechanism.movingComponentKey] = mechanism
	end

	local chassisComponent = findComponent(genome, "chassis")
	local chassis = newPart(
		"chassis",
		componentSize(chassisComponent),
		componentCFrame(objectCFrame, chassisComponent),
		false,
		element.material,
		model
	)
	applyEntityDiagnostics(chassis, element)
	chassis:SetNetworkOwner(nil)

	for _, component in ipairs(genome.components) do
		if component.key ~= "chassis" and casterComponents[component.key] == nil then
			local part = newPart(
				component.key,
				componentSize(component),
				componentCFrame(objectCFrame, component),
				false,
				element.material,
				model
			)
			applyEntityDiagnostics(part, element)
			part:SetNetworkOwner(nil)

			local weld = Instance.new("WeldConstraint")
			weld.Name = `{component.key}-weld`
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = model
		end
	end

	for componentKey, mechanism in pairs(casterComponents) do
		assert(mechanism.kind == "caster", "Physics Lab caster mechanism type drifted")
		local component = findComponent(genome, componentKey)
		local wheelCFrame = componentCFrame(objectCFrame, component)
		local wheel = newPart(
			component.key,
			componentSize(component),
			wheelCFrame,
			false,
			element.material,
			model
		)
		wheel.Shape = Enum.PartType.Cylinder
		applyEntityDiagnostics(wheel, element)
		wheel:SetNetworkOwner(nil)

		local pivot = newPart(
			`{component.key}-swivel-pivot`,
			Vector3.new(0.05, 0.05, 0.05),
			wheelCFrame,
			false,
			element.material,
			model
		)
		pivot.Transparency = 1
		pivot.CanCollide = false
		pivot.CanQuery = false
		pivot.CanTouch = false
		pivot.Massless = true
		applyEntityDiagnostics(pivot, element)
		pivot:SetNetworkOwner(nil)

		local chassisSwivel = Instance.new("Attachment")
		chassisSwivel.Name = `{component.key}-chassis-swivel`
		chassisSwivel.Position = chassis.CFrame:PointToObjectSpace(wheelCFrame.Position)
		chassisSwivel.Axis = objectAxisInPart(objectCFrame, chassis, mechanism.swivelAxis)
		chassisSwivel.Parent = chassis

		local pivotSwivel = Instance.new("Attachment")
		pivotSwivel.Name = `{component.key}-pivot-swivel`
		pivotSwivel.Axis = objectAxisInPart(objectCFrame, pivot, mechanism.swivelAxis)
		pivotSwivel.Parent = pivot

		local swivel = Instance.new("HingeConstraint")
		swivel.Name = `{component.key}-swivel`
		swivel.Attachment0 = chassisSwivel
		swivel.Attachment1 = pivotSwivel
		swivel.Parent = model

		local pivotRoll = Instance.new("Attachment")
		pivotRoll.Name = `{component.key}-pivot-roll`
		pivotRoll.Axis = objectAxisInPart(objectCFrame, pivot, mechanism.rollAxis)
		pivotRoll.Parent = pivot

		local wheelRoll = Instance.new("Attachment")
		wheelRoll.Name = `{component.key}-wheel-roll`
		wheelRoll.Axis = objectAxisInPart(objectCFrame, wheel, mechanism.rollAxis)
		wheelRoll.Parent = wheel

		local roll = Instance.new("HingeConstraint")
		roll.Name = `{component.key}-roll`
		roll.Attachment0 = pivotRoll
		roll.Attachment1 = wheelRoll
		roll.Parent = model

		local chassisWheelNoCollision = Instance.new("NoCollisionConstraint")
		chassisWheelNoCollision.Name = `{component.key}-chassis-wheel-no-collision`
		chassisWheelNoCollision.Part0 = chassis
		chassisWheelNoCollision.Part1 = wheel
		chassisWheelNoCollision.Parent = model

		local chassisPivotNoCollision = Instance.new("NoCollisionConstraint")
		chassisPivotNoCollision.Name = `{component.key}-chassis-pivot-no-collision`
		chassisPivotNoCollision.Part0 = chassis
		chassisPivotNoCollision.Part1 = pivot
		chassisPivotNoCollision.Parent = model

		local pivotWheelNoCollision = Instance.new("NoCollisionConstraint")
		pivotWheelNoCollision.Name = `{component.key}-pivot-wheel-no-collision`
		pivotWheelNoCollision.Part0 = pivot
		pivotWheelNoCollision.Part1 = wheel
		pivotWheelNoCollision.Parent = model
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
	local genome = PhysicsLabRecipe.objectGenomeFor(element)
	assert(genome ~= nil, "Physics Lab door proxy requires a bound ObjectGenome")
	local mechanism = PhysicsLabRecipe.mechanismFor(element)
	assert(mechanism ~= nil and mechanism.kind == "hinge", "Physics Lab door proxy requires a hinge mechanism")

	local movingComponent = findMovingComponent(genome, mechanism)
	local frameComponent = findComponent(genome, mechanism.frameComponentKey)
	local objectCFrame = cframeFor(element)
	local model = newEntityModel(element, parent)
	local framePart: BasePart? = nil

	for _, component in ipairs(genome.components) do
		if component.key ~= movingComponent.key then
			local part = newPart(
				component.key,
				componentSize(component),
				componentCFrame(objectCFrame, component),
				true,
				element.material,
				model
			)
			applyEntityDiagnostics(part, element)
			if component.key == frameComponent.key then
				framePart = part
			end
		end
	end
	assert(framePart ~= nil, "Physics Lab door realization is missing hinge frame component")

	local panel = newPart(
		movingComponent.key,
		componentSize(movingComponent),
		componentCFrame(objectCFrame, movingComponent),
		false,
		element.material,
		model
	)
	applyEntityDiagnostics(panel, element)
	panel:SetNetworkOwner(nil)

	local hingeSide = if frameComponent.localPositionM.x < movingComponent.localPositionM.x then -1 else 1
	local scale = PhysicsLabRecipe.StudsPerMeter
	local hingeLocal = Vector3.new(
		(movingComponent.localPositionM.x + hingeSide * movingComponent.dimensionsM.x * 0.5) * scale,
		movingComponent.localPositionM.y * scale,
		movingComponent.localPositionM.z * scale
	)
	local hingeWorld = objectCFrame:PointToWorldSpace(hingeLocal)

	local frameAttachment = Instance.new("Attachment")
	frameAttachment.Name = "FrameAttachment"
	frameAttachment.Position = framePart.CFrame:PointToObjectSpace(hingeWorld)
	frameAttachment.Axis = objectAxisInPart(objectCFrame, framePart, mechanism.axis)
	frameAttachment.Parent = framePart

	local panelAttachment = Instance.new("Attachment")
	panelAttachment.Name = "PanelAttachment"
	panelAttachment.Position = panel.CFrame:PointToObjectSpace(hingeWorld)
	panelAttachment.Axis = objectAxisInPart(objectCFrame, panel, mechanism.axis)
	panelAttachment.Parent = panel

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = mechanism.key
	hinge.Attachment0 = frameAttachment
	hinge.Attachment1 = panelAttachment
	hinge.LimitsEnabled = true
	hinge.LowerAngle = mechanism.minDegrees
	hinge.UpperAngle = mechanism.maxDegrees
	hinge.Parent = model

	model.PrimaryPart = panel
	addStudioDiagnostic(panel, element)
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
	local drawerSize = componentSize(movingComponent)
	local drawerCFrame = componentCFrame(shellCFrame, movingComponent)

	-- A full collidable shell would begin by interpenetrating the dynamic drawer.
	-- Decompose the F3 carcass so the authored mechanism starts from a sane contact state.
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
		local part = newPart(
			spec.name,
			spec.size,
			shellCFrame * CFrame.new(spec.offset),
			true,
			element.material,
			model
		)
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

	local guideAttachment = Instance.new("Attachment")
	guideAttachment.Name = "ShellSlideAttachment"
	guideAttachment.Axis = objectAxisInPart(shellCFrame, guide, mechanism.axis)
	guideAttachment.Parent = guide

	local drawerAttachment = Instance.new("Attachment")
	drawerAttachment.Name = "DrawerSlideAttachment"
	drawerAttachment.Axis = objectAxisInPart(shellCFrame, drawer, mechanism.axis)
	drawerAttachment.Parent = drawer

	local slide = Instance.new("PrismaticConstraint")
	slide.Name = mechanism.key
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
