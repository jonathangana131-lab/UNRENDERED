--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local PhysicsLabScale = require(Shared.Physics.PhysicsLabScale)
local ValidationContract = require(Shared.Physics.PhysicsLabValidationContract)
local ResolvedRegionRecipe = require(Shared.Reality.ResolvedRegionRecipe)

local PhysicsLabValidation = {}

export type Snapshot = ValidationContract.Snapshot
export type Comparison = ValidationContract.Comparison

local ROOT_NAME = "UNRENDERED_PhysicsLab"
local OWNED_ATTRIBUTE = "UNRENDERED_PhysicsLabOwned"
local SCHEMA_ATTRIBUTE = "UNRENDERED_LabSchemaVersion"
local RECIPE_ATTRIBUTE = "UNRENDERED_LabRecipeKey"
local WORLD_ATTRIBUTE = "UNRENDERED_WorldId"
local REGION_ATTRIBUTE = "UNRENDERED_RegionId"
local RESOLVED_SCHEMA_ATTRIBUTE = "UNRENDERED_ResolvedRegionSchemaVersion"
local WORLD_SEED_REF_ATTRIBUTE = "UNRENDERED_WorldSeedRef"
local FINGERPRINT_ATTRIBUTE = "UNRENDERED_ResolvedRegionFingerprint"
local REPRO_KEY_ATTRIBUTE = "UNRENDERED_ResolvedRegionReproKey"
local ENTITY_ID_ATTRIBUTE = "UNRENDERED_WorldEntityId"
local FIDELITY_ATTRIBUTE = "UNRENDERED_Fidelity"
local ENTITY_RECIPE_ATTRIBUTE = "UNRENDERED_RecipeKey"
local LAB_ROLE_ATTRIBUTE = "UNRENDERED_LabRole"
local MATERIAL_KEY_ATTRIBUTE = "UNRENDERED_MaterialKey"
local MATERIAL_VERSION_ATTRIBUTE = "UNRENDERED_MaterialRecipeVersion"
local OBJECT_GENOME_KEY_ATTRIBUTE = "UNRENDERED_ObjectGenomeKey"
local OBJECT_GENOME_ID_ATTRIBUTE = "UNRENDERED_ObjectGenomeId"
local OBJECT_FINGERPRINT_ATTRIBUTE = "UNRENDERED_ObjectRecipeFingerprint"
local REPRESENTATION_CLASS_ATTRIBUTE = "UNRENDERED_RepresentationClass"
local COMPONENT_KEY_ATTRIBUTE = "UNRENDERED_ComponentKey"
local COMPONENT_ROLE_ATTRIBUTE = "UNRENDERED_ComponentRole"
local GEOMETRY_TOLERANCE = 1e-5

local function requiredStringAttribute(root: Instance, name: string): string
	local value = root:GetAttribute(name)
	assert(type(value) == "string" and value ~= "", `Physics Lab validation requires string attribute {name}`)
	return value
end

local function requiredPositiveIntegerAttribute(root: Instance, name: string): number
	local value = root:GetAttribute(name)
	assert(
		type(value) == "number" and value == value and value >= 1 and value % 1 == 0,
		`Physics Lab validation requires positive integer attribute {name}`
	)
	return value
end

local function freezeVec3(x: number, y: number, z: number): ValidationContract.Vec3
	return table.freeze({ x = x, y = y, z = z })
end

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

	-- ObjectGenome v1 owns fixed-axis/extrinsic XYZ as Rz * Ry * Rx.
	return CFrame.Angles(0, 0, z) * CFrame.Angles(0, y, 0) * CFrame.Angles(x, 0, 0)
end

local function transform(positionM: PhysicsLabRecipe.Vec3, rotationDeg: PhysicsLabRecipe.Vec3): CFrame
	return CFrame.new(vectorMeters(positionM)) * rotationExtrinsicXYZ(rotationDeg)
end

local function assertNearVector3(actual: Vector3, expected: Vector3, label: string): ()
	assert(
		(actual - expected).Magnitude <= GEOMETRY_TOLERANCE,
		`Physics Lab representation {label} geometry drifted`
	)
end

local function assertCanonicalPartGeometry(
	part: BasePart,
	expectedSize: Vector3,
	expectedCFrame: CFrame,
	expectedCollidable: boolean,
	expectedTouchable: boolean,
	expectedTransparency: number,
	label: string
): ()
	assert(part.Anchored, `Physics Lab representation {label} must remain anchored at F2`)
	assert(
		part.CanCollide == expectedCollidable,
		`Physics Lab representation {label} has the wrong CanCollide state`
	)
	assert(part.CanQuery, `Physics Lab representation {label} must remain queryable at F2`)
	assert(
		part.CanTouch == expectedTouchable,
		`Physics Lab representation {label} has the wrong CanTouch state`
	)
	assert(
		math.abs(part.Transparency - expectedTransparency) <= GEOMETRY_TOLERANCE,
		`Physics Lab representation {label} has the wrong transparency`
	)
	assertNearVector3(part.Size, expectedSize, `{label} size`)
	assertNearVector3(part.Position, expectedCFrame.Position, `{label} position`)
	assertNearVector3(part.CFrame.RightVector, expectedCFrame.RightVector, `{label} right-vector`)
	assertNearVector3(part.CFrame.UpVector, expectedCFrame.UpVector, `{label} up-vector`)
	assertNearVector3(part.CFrame.LookVector, expectedCFrame.LookVector, `{label} look-vector`)
end

local function assertCanonicalWorkspaceRoot(root: Model): ()
	assert(root.Parent == workspace, "Physics Lab validation requires the canonical direct Workspace root")

	local matchingRootCount = 0
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == ROOT_NAME then
			matchingRootCount += 1
			assert(child == root, "Physics Lab validation found a competing canonical root")
		end
	end
	assert(matchingRootCount == 1, "Physics Lab validation requires exactly one canonical Workspace root")
end

local function assertCanonicalRootIdentity(root: Model, recipe: PhysicsLabRecipe.PhysicsLabRecipe): ()
	assert(root.Name == ROOT_NAME, `Physics Lab validation expected root name {ROOT_NAME}`)
	assert(
		requiredPositiveIntegerAttribute(root, SCHEMA_ATTRIBUTE) == recipe.schemaVersion,
		"Physics Lab root schema version does not match the canonical recipe"
	)
	assert(
		requiredStringAttribute(root, RECIPE_ATTRIBUTE) == recipe.recipeKey,
		"Physics Lab root recipe key does not match the canonical recipe"
	)
	assert(
		requiredStringAttribute(root, WORLD_ATTRIBUTE) == recipe.worldId,
		"Physics Lab root WorldId does not match the canonical recipe"
	)
	assert(
		requiredStringAttribute(root, REGION_ATTRIBUTE) == recipe.regionId,
		"Physics Lab root RegionId does not match the canonical resolved region"
	)
	assert(
		requiredPositiveIntegerAttribute(root, RESOLVED_SCHEMA_ATTRIBUTE)
			== PhysicsLabRecipe.RESOLVED_REGION.schemaVersion,
		"Physics Lab root resolved-region schema version does not match canonical truth"
	)
	assert(
		requiredStringAttribute(root, WORLD_SEED_REF_ATTRIBUTE) == PhysicsLabRecipe.WORLD_SEED_REF,
		"Physics Lab root world-seed provenance does not match canonical truth"
	)

	local expectedFingerprint = ResolvedRegionRecipe.fingerprint(PhysicsLabRecipe.RESOLVED_REGION)
	local expectedReproKey = ResolvedRegionRecipe.reproKey(PhysicsLabRecipe.RESOLVED_REGION)
	assert(
		requiredStringAttribute(root, FINGERPRINT_ATTRIBUTE) == expectedFingerprint,
		"Physics Lab root resolved-region fingerprint does not match canonical truth"
	)
	assert(
		requiredStringAttribute(root, REPRO_KEY_ATTRIBUTE) == expectedReproKey,
		"Physics Lab root resolved-region repro key does not match canonical truth"
	)
end

local function assertCanonicalObjectComponents(model: Model, recipe: PhysicsLabRecipe.ObjectEntityRecipe): ()
	local genome = PhysicsLabRecipe.objectGenome(recipe.genomeKey)
	local seenComponentKeys: { [string]: boolean } = {}
	local objectTransform = transform(recipe.positionM, recipe.rotationDeg)

	for _, componentInstance in ipairs(model:GetChildren()) do
		assert(
			componentInstance:IsA("BasePart"),
			`Physics Lab object {recipe.key} has non-Part component representation {componentInstance.Name}`
		)
		local componentPart = componentInstance :: BasePart

		local componentKey = componentPart:GetAttribute(COMPONENT_KEY_ATTRIBUTE)
		assert(
			type(componentKey) == "string" and componentKey ~= "",
			`Physics Lab object {recipe.key} component {componentPart.Name} is missing {COMPONENT_KEY_ATTRIBUTE}`
		)
		assert(
			not seenComponentKeys[componentKey],
			`Physics Lab object {recipe.key} repeats component key {componentKey}`
		)
		seenComponentKeys[componentKey] = true

		local matched = false
		for _, expectedComponent in ipairs(genome.components) do
			if expectedComponent.key == componentKey then
				matched = true
				assert(
					componentPart.Name == expectedComponent.key,
					`Physics Lab object {recipe.key} component {componentKey} has the wrong Instance name`
				)
				assert(
					componentPart:GetAttribute(COMPONENT_ROLE_ATTRIBUTE) == expectedComponent.role,
					`Physics Lab object {recipe.key} component {componentKey} has the wrong component role`
				)
				assert(
					componentPart:GetAttribute(MATERIAL_KEY_ATTRIBUTE) == expectedComponent.materialKey,
					`Physics Lab object {recipe.key} component {componentKey} has the wrong MaterialDNA identity`
				)
				assert(
					componentPart:GetAttribute(MATERIAL_VERSION_ATTRIBUTE)
						== expectedComponent.materialRecipeVersion,
					`Physics Lab object {recipe.key} component {componentKey} has the wrong MaterialDNA recipe version`
				)
				assertCanonicalPartGeometry(
					componentPart,
					vectorMeters(expectedComponent.dimensionsM),
					objectTransform
						* CFrame.new(vectorMeters(expectedComponent.localPositionM))
						* rotationExtrinsicXYZ(expectedComponent.localRotationDeg),
					true,
					true,
					0,
					`{recipe.key}/{componentKey}`
				)
				break
			end
		end

		assert(matched, `Physics Lab object {recipe.key} has unexpected component key {componentKey}`)
	end

	for _, expectedComponent in ipairs(genome.components) do
		assert(
			seenComponentKeys[expectedComponent.key] == true,
			`Physics Lab object {recipe.key} is missing canonical component {expectedComponent.key}`
		)
	end
end

local function assertCanonicalRepresentationSet(
	root: Model,
	recipe: PhysicsLabRecipe.PhysicsLabRecipe,
	requireComplete: boolean
): ()
	local expectedByKey: { [string]: PhysicsLabRecipe.EntityRecipe } = {}
	local seenKeys: { [string]: boolean } = {}
	local seenIds: { [string]: string } = {}

	for _, entityRecipe in ipairs(recipe.entities) do
		assert(
			expectedByKey[entityRecipe.key] == nil,
			`canonical Physics Lab recipe repeats key {entityRecipe.key}`
		)
		expectedByKey[entityRecipe.key] = entityRecipe
	end

	for _, child in ipairs(root:GetChildren()) do
		local expected = expectedByKey[child.Name]
		assert(expected ~= nil, `Physics Lab validation found unexpected direct representation {child.Name}`)
		assert(
			not seenKeys[child.Name],
			`Physics Lab validation found duplicate representation key {child.Name}`
		)
		seenKeys[child.Name] = true

		local entityId = child:GetAttribute(ENTITY_ID_ATTRIBUTE)
		assert(
			type(entityId) == "string" and entityId ~= "",
			`Physics Lab representation {child.Name} is missing {ENTITY_ID_ATTRIBUTE}`
		)
		assert(
			entityId == expected.entity.id,
			`Physics Lab representation {child.Name} has the wrong WorldEntityId`
		)
		local priorKey = seenIds[entityId]
		assert(
			priorKey == nil,
			`Physics Lab validation found duplicate WorldEntityId {entityId} on {priorKey or "?"} and {child.Name}`
		)
		seenIds[entityId] = child.Name

		assert(
			child:GetAttribute(FIDELITY_ATTRIBUTE) == "F2",
			`Physics Lab representation {child.Name} is not an authoritative F2 proxy`
		)
		assert(
			child:GetAttribute(ENTITY_RECIPE_ATTRIBUTE) == expected.entity.origin.recipeKey,
			`Physics Lab representation {child.Name} has the wrong entity recipe key`
		)

		if expected.kind == "primitive" then
			assert(child:IsA("BasePart"), `Physics Lab primitive {child.Name} must realize as a BasePart`)
			local part = child :: BasePart
			assert(
				part:GetAttribute(LAB_ROLE_ATTRIBUTE) == expected.role,
				`Physics Lab primitive {part.Name} has the wrong lab role`
			)
			assert(
				part:GetAttribute(MATERIAL_KEY_ATTRIBUTE) == expected.material.id,
				`Physics Lab primitive {part.Name} has the wrong MaterialDNA identity`
			)
			assert(
				part:GetAttribute(MATERIAL_VERSION_ATTRIBUTE) == expected.material.recipeVersion,
				`Physics Lab primitive {part.Name} has the wrong MaterialDNA recipe version`
			)
			assertCanonicalPartGeometry(
				part,
				vectorMeters(expected.sizeM),
				transform(expected.positionM, expected.rotationDeg),
				expected.collidable,
				expected.collidable,
				expected.transparency,
				expected.key
			)
		else
			assert(child:IsA("Model"), `Physics Lab object {child.Name} must realize as a Model`)
			assert(
				child:GetAttribute(OBJECT_GENOME_KEY_ATTRIBUTE) == expected.genomeKey,
				`Physics Lab object {child.Name} has the wrong ObjectGenome key`
			)
			assert(
				child:GetAttribute(OBJECT_GENOME_ID_ATTRIBUTE) == expected.genomeId,
				`Physics Lab object {child.Name} has the wrong ObjectGenome identity`
			)
			assert(
				child:GetAttribute(OBJECT_FINGERPRINT_ATTRIBUTE) == expected.genomeRecipeFingerprint,
				`Physics Lab object {child.Name} has the wrong ObjectGenome recipe fingerprint`
			)
			assert(
				child:GetAttribute(REPRESENTATION_CLASS_ATTRIBUTE) == "F2-anchored-proxy",
				`Physics Lab object {child.Name} has the wrong representation class`
			)
			assertCanonicalObjectComponents(child, expected)
		end
	end

	if requireComplete then
		for _, expected in ipairs(recipe.entities) do
			assert(
				seenKeys[expected.key] == true,
				`Physics Lab full snapshot is missing canonical representation {expected.key}`
			)
		end
	end
end

local function captureInternal(root: Instance, requireComplete: boolean): Snapshot
	assert(root:IsA("Model"), "Physics Lab validation root must be the owned lab Model")
	assert(root:GetAttribute(OWNED_ATTRIBUTE) == true, "Physics Lab validation refuses an unowned root")

	local model = root :: Model
	assertCanonicalWorkspaceRoot(model)
	local recipe = PhysicsLabRecipe.build()
	assertCanonicalRootIdentity(model, recipe)
	assertCanonicalRepresentationSet(model, recipe, requireComplete)

	local counts = {
		instances = 0,
		models = 0,
		parts = 0,
		assemblies = 0,
		attachments = 0,
		constraints = 0,
		joints = 0,
	}
	local assemblyRoots: { [BasePart]: boolean } = {}
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local hasPart = false

	local function inspect(instance: Instance): ()
		counts.instances += 1
		if instance:IsA("Model") then
			counts.models += 1
		elseif instance:IsA("BasePart") then
			counts.parts += 1
			hasPart = true
			local half = instance.Size * 0.5
			for _, xSign in ipairs({ -1, 1 }) do
				for _, ySign in ipairs({ -1, 1 }) do
					for _, zSign in ipairs({ -1, 1 }) do
						local corner = instance.CFrame:PointToWorldSpace(
							Vector3.new(half.X * xSign, half.Y * ySign, half.Z * zSign)
						)
						minX = math.min(minX, corner.X)
						minY = math.min(minY, corner.Y)
						minZ = math.min(minZ, corner.Z)
						maxX = math.max(maxX, corner.X)
						maxY = math.max(maxY, corner.Y)
						maxZ = math.max(maxZ, corner.Z)
					end
				end
			end
			local assemblyRoot: BasePart? = (instance :: any).AssemblyRootPart
			assemblyRoots[if assemblyRoot == nil then instance else assemblyRoot] = true
		elseif instance:IsA("Attachment") then
			counts.attachments += 1
		elseif instance:IsA("Constraint") then
			counts.constraints += 1
		elseif instance:IsA("JointInstance") then
			counts.joints += 1
		end
	end

	inspect(root)
	for _, descendant in root:GetDescendants() do
		if descendant:GetAttribute(OWNED_ATTRIBUTE) == true then
			error("Physics Lab validation found a nested owned lab root")
		end
		inspect(descendant)
	end
	for _ in pairs(assemblyRoots) do
		counts.assemblies += 1
	end

	local envelope: ValidationContract.Envelope? = nil
	if hasPart then
		envelope = table.freeze({
			min = freezeVec3(minX, minY, minZ),
			max = freezeVec3(maxX, maxY, maxZ),
		})
	end

	local snapshot: Snapshot = table.freeze({
		rootName = root.Name,
		labSchemaVersion = requiredPositiveIntegerAttribute(root, SCHEMA_ATTRIBUTE),
		labRecipeKey = requiredStringAttribute(root, RECIPE_ATTRIBUTE),
		worldId = requiredStringAttribute(root, WORLD_ATTRIBUTE),
		regionId = requiredStringAttribute(root, REGION_ATTRIBUTE),
		resolvedRegionSchemaVersion = requiredPositiveIntegerAttribute(root, RESOLVED_SCHEMA_ATTRIBUTE),
		worldSeedRef = requiredStringAttribute(root, WORLD_SEED_REF_ATTRIBUTE),
		resolvedRegionFingerprint = requiredStringAttribute(root, FINGERPRINT_ATTRIBUTE),
		resolvedRegionReproKey = requiredStringAttribute(root, REPRO_KEY_ATTRIBUTE),
		counts = table.freeze(counts),
		envelopeStuds = envelope,
	})
	local valid, problem = ValidationContract.inspectSnapshot(snapshot)
	assert(
		valid,
		`captured Physics Lab validation snapshot is invalid: {problem or "unknown validation error"}`
	)
	return snapshot
end

function PhysicsLabValidation.capture(root: Instance): Snapshot
	-- Partial F0/F2 lifecycle snapshots are valid evidence. Any representation
	-- that is present must still match canonical recipe identity/material/object
	-- contracts and the physical F2 proxy geometry, but canonical F0 entities may
	-- be absent from the Instance tree.
	return captureInternal(root, false)
end

function PhysicsLabValidation.captureFull(root: Instance): Snapshot
	-- Full rebuild checkpoints must contain every canonical F2 representation and
	-- each present proxy must match canonical geometry/interaction properties.
	-- This closes the hole where a deterministically wrong shell could reproduce
	-- the same counts/envelope across every restart and still look stable.
	return captureInternal(root, true)
end

function PhysicsLabValidation.compare(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): Comparison
	return ValidationContract.compare(baseline, checkpoint, toleranceStuds)
end

function PhysicsLabValidation.assertFullLabEnvelope(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): ValidationContract.EnvelopeReport
	return ValidationContract.assertFullLabEnvelope(baseline, checkpoint, toleranceStuds)
end

return table.freeze(PhysicsLabValidation)
