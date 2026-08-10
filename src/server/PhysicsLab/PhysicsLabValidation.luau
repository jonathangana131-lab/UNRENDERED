--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local ValidationContract = require(Shared.Physics.PhysicsLabValidationContract)

local PhysicsLabValidation = {}

export type Snapshot = ValidationContract.Snapshot
export type Comparison = ValidationContract.Comparison

local OWNED_ATTRIBUTE = "UNRENDERED_PhysicsLabOwned"
local SCHEMA_ATTRIBUTE = "UNRENDERED_LabSchemaVersion"
local RECIPE_ATTRIBUTE = "UNRENDERED_LabRecipeKey"
local WORLD_ATTRIBUTE = "UNRENDERED_WorldId"
local REGION_ATTRIBUTE = "UNRENDERED_RegionId"
local FINGERPRINT_ATTRIBUTE = "UNRENDERED_ResolvedRegionFingerprint"
local REPRO_KEY_ATTRIBUTE = "UNRENDERED_ResolvedRegionReproKey"
local ENTITY_COUNT_ATTRIBUTE = "UNRENDERED_EntityCount"
local REPRESENTED_COUNT_ATTRIBUTE = "UNRENDERED_RepresentedCount"
local ENTITY_ID_ATTRIBUTE = "UNRENDERED_WorldEntityId"
local ENTITY_FIDELITY_ATTRIBUTE = "UNRENDERED_Fidelity"
local ENTITY_RECIPE_ATTRIBUTE = "UNRENDERED_RecipeKey"

local VALID_FIDELITIES = table.freeze({
	F0 = true,
	F1 = true,
	F2 = true,
	F3 = true,
	F4 = true,
})

local function requiredStringAttribute(root: Instance, name: string): string
	local value = root:GetAttribute(name)
	assert(type(value) == "string" and value ~= "", `Physics Lab validation requires string attribute {name}`)
	return value
end

local function requiredNonNegativeIntegerAttribute(root: Instance, name: string): number
	local value = root:GetAttribute(name)
	assert(
		type(value) == "number" and value == value and value >= 0 and value % 1 == 0,
		`Physics Lab validation requires non-negative integer attribute {name}`
	)
	return value
end

local function requiredSchemaVersion(root: Instance): number
	local value = requiredNonNegativeIntegerAttribute(root, SCHEMA_ATTRIBUTE)
	assert(value >= 1, `Physics Lab validation requires positive integer attribute {SCHEMA_ATTRIBUTE}`)
	return value
end

local function freezeVec3(x: number, y: number, z: number): ValidationContract.Vec3
	return table.freeze({ x = x, y = y, z = z })
end

local function captureEntityEvidence(
	instance: Instance,
	seenEntityIds: { [string]: boolean },
	entities: { ValidationContract.EntityEvidence }
): ()
	local entityId = instance:GetAttribute(ENTITY_ID_ATTRIBUTE)
	if entityId == nil then
		return
	end
	assert(
		type(entityId) == "string" and entityId ~= "",
		`Physics Lab representation has invalid {ENTITY_ID_ATTRIBUTE}`
	)
	assert(not seenEntityIds[entityId], `Physics Lab validation found duplicate represented WorldEntity id: {entityId}`)
	seenEntityIds[entityId] = true

	local fidelity = instance:GetAttribute(ENTITY_FIDELITY_ATTRIBUTE)
	assert(
		type(fidelity) == "string" and VALID_FIDELITIES[fidelity] == true,
		`Physics Lab representation {entityId} has invalid {ENTITY_FIDELITY_ATTRIBUTE}`
	)
	assert(fidelity ~= "F0", `Physics Lab representation {entityId} cannot exist at F0`)
	local recipeKey = instance:GetAttribute(ENTITY_RECIPE_ATTRIBUTE)
	assert(
		type(recipeKey) == "string" and recipeKey ~= "",
		`Physics Lab representation {entityId} has invalid {ENTITY_RECIPE_ATTRIBUTE}`
	)

	table.insert(entities, table.freeze({
		id = entityId,
		fidelity = fidelity,
		recipeKey = recipeKey,
	}))
end

function PhysicsLabValidation.capture(root: Instance): Snapshot
	assert(root:IsA("Model"), "Physics Lab validation root must be the owned lab Model")
	assert(root:GetAttribute(OWNED_ATTRIBUTE) == true, "Physics Lab validation refuses an unowned root")

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
	local seenEntityIds: { [string]: boolean } = {}
	local entities: { ValidationContract.EntityEvidence } = {}
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local hasPart = false

	local function inspect(instance: Instance): ()
		counts.instances += 1
		captureEntityEvidence(instance, seenEntityIds, entities)
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
	table.sort(entities, function(a, b)
		return a.id < b.id
	end)

	local envelope: ValidationContract.Envelope? = nil
	if hasPart then
		envelope = table.freeze({
			min = freezeVec3(minX, minY, minZ),
			max = freezeVec3(maxX, maxY, maxZ),
		})
	end

	local fidelityCounts: ValidationContract.FidelityCounts = table.freeze({
		F0 = requiredNonNegativeIntegerAttribute(root, "UNRENDERED_FidelityF0"),
		F1 = requiredNonNegativeIntegerAttribute(root, "UNRENDERED_FidelityF1"),
		F2 = requiredNonNegativeIntegerAttribute(root, "UNRENDERED_FidelityF2"),
		F3 = requiredNonNegativeIntegerAttribute(root, "UNRENDERED_FidelityF3"),
		F4 = requiredNonNegativeIntegerAttribute(root, "UNRENDERED_FidelityF4"),
	})
	local snapshot: Snapshot = table.freeze({
		rootName = root.Name,
		labSchemaVersion = requiredSchemaVersion(root),
		labRecipeKey = requiredStringAttribute(root, RECIPE_ATTRIBUTE),
		worldId = requiredStringAttribute(root, WORLD_ATTRIBUTE),
		regionId = requiredStringAttribute(root, REGION_ATTRIBUTE),
		resolvedRegionFingerprint = requiredStringAttribute(root, FINGERPRINT_ATTRIBUTE),
		resolvedRegionReproKey = requiredStringAttribute(root, REPRO_KEY_ATTRIBUTE),
		entityCount = requiredNonNegativeIntegerAttribute(root, ENTITY_COUNT_ATTRIBUTE),
		representedCount = requiredNonNegativeIntegerAttribute(root, REPRESENTED_COUNT_ATTRIBUTE),
		fidelityCounts = fidelityCounts,
		entities = table.freeze(entities),
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

function PhysicsLabValidation.compare(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): Comparison
	return ValidationContract.compare(baseline, checkpoint, toleranceStuds)
end

function PhysicsLabValidation.assertSameEntityInventory(
	baseline: Snapshot,
	checkpoint: Snapshot
): ValidationContract.EntityInventoryReport
	return ValidationContract.assertSameEntityInventory(baseline, checkpoint)
end

function PhysicsLabValidation.assertFullLabEnvelope(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): ValidationContract.EnvelopeReport
	return ValidationContract.assertFullLabEnvelope(baseline, checkpoint, toleranceStuds)
end

return table.freeze(PhysicsLabValidation)
