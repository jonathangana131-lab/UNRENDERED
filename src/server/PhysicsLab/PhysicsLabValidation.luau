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

local function requiredStringAttribute(root: Instance, name: string): string
	local value = root:GetAttribute(name)
	assert(type(value) == "string" and value ~= "", `Physics Lab validation requires string attribute {name}`)
	return value
end

local function requiredSchemaVersion(root: Instance): number
	local value = root:GetAttribute(SCHEMA_ATTRIBUTE)
	assert(
		type(value) == "number" and value == value and value >= 1 and value % 1 == 0,
		`Physics Lab validation requires positive integer attribute {SCHEMA_ATTRIBUTE}`
	)
	return value
end

local function freezeVec3(x: number, y: number, z: number): ValidationContract.Vec3
	return table.freeze({ x = x, y = y, z = z })
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
			local assemblyRoot = instance.AssemblyRootPart
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
		labSchemaVersion = requiredSchemaVersion(root),
		labRecipeKey = requiredStringAttribute(root, RECIPE_ATTRIBUTE),
		worldId = requiredStringAttribute(root, WORLD_ATTRIBUTE),
		regionId = requiredStringAttribute(root, REGION_ATTRIBUTE),
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
