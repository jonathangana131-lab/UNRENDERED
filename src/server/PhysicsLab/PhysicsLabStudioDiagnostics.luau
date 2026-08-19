--!strict

local RunService = game:GetService("RunService")

local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)
local Validation = require(script.Parent.PhysicsLabValidation)

local PhysicsLabStudioDiagnostics = {}

local DIAGNOSTICS_ROOT_NAME = "UNRENDERED_PhysicsLabDiagnostics"
local DIAGNOSTICS_SCHEMA_VERSION = 1
local DEFAULT_TOGGLE_EVIDENCE_CYCLES = 20
local MAX_TOGGLE_EVIDENCE_CYCLES = 20
local CHECKPOINT_CYCLES = table.freeze({ [1] = true, [5] = true, [10] = true, [20] = true })

export type EntityDiagnostic = {
	key: string,
	worldEntityId: string,
	fidelity: string,
	recipeKey: string,
	representationRevision: number,
	stateRevision: number,
	representationClass: string?,
}

export type Snapshot = {
	schemaVersion: number,
	enabled: boolean,
	worldId: string,
	regionId: string,
	resolvedRegionFingerprint: string,
	resolvedRegionReproKey: string,
	diagnosticInstanceCount: number,
	entities: { EntityDiagnostic },
}

type ReadoutPlan = {
	key: string,
	worldEntityId: string,
	fidelity: string,
	representationRevision: number,
	stateRevision: number,
	adornee: BasePart,
}

local function assertStudioServer(): ()
	assert(RunService:IsStudio(), "Physics Lab diagnostics are Studio-only")
	assert(RunService:IsServer(), "Physics Lab diagnostics must run on the server")
end

local function requireStringAttribute(instance: Instance, attributeName: string): string
	local value = instance:GetAttribute(attributeName)
	assert(type(value) == "string" and value ~= "", `missing diagnostics identity attribute: {attributeName}`)
	return value :: string
end

local function requireNonNegativeIntegerAttribute(instance: Instance, attributeName: string): number
	local value = instance:GetAttribute(attributeName)
	assert(
		type(value) == "number" and value == value and value >= 0 and value % 1 == 0,
		`missing or invalid diagnostics integer attribute: {attributeName}`
	)
	return value :: number
end

local function requireToggleCycleCount(cycles: any): number
	if cycles == nil then
		return DEFAULT_TOGGLE_EVIDENCE_CYCLES
	end
	assert(
		type(cycles) == "number"
			and cycles == cycles
			and cycles >= 1
			and cycles <= MAX_TOGGLE_EVIDENCE_CYCLES
			and cycles % 1 == 0,
		`diagnostics cycle count must be an integer in [1, {MAX_TOGGLE_EVIDENCE_CYCLES}]`
	)
	return cycles :: number
end

local function assertRepresentationMetadata(
	representation: Instance,
	entityId: string,
	expectedFidelity: string,
	expectedRecipeKey: string,
	expectedRepresentationRevision: number,
	expectedStateRevision: number
): ()
	local representedFidelity = requireStringAttribute(representation, "UNRENDERED_Fidelity")
	assert(
		expectedFidelity == representedFidelity,
		`diagnostics fidelity disagrees with authoritative WorldEntity: {entityId}`
	)

	local representedRecipeKey = requireStringAttribute(representation, "UNRENDERED_RecipeKey")
	assert(
		expectedRecipeKey == representedRecipeKey,
		`diagnostics recipe key disagrees with authoritative WorldEntity: {entityId}`
	)

	local representedRepresentationRevision =
		requireNonNegativeIntegerAttribute(representation, "UNRENDERED_RepresentationRevision")
	assert(
		expectedRepresentationRevision == representedRepresentationRevision,
		`diagnostics representation revision disagrees with authoritative WorldEntity: {entityId}`
	)

	local representedStateRevision =
		requireNonNegativeIntegerAttribute(representation, "UNRENDERED_StateRevision")
	assert(
		expectedStateRevision == representedStateRevision,
		`diagnostics state revision disagrees with authoritative WorldEntity: {entityId}`
	)
end

local function diagnosticsRoot(model: Model): Folder?
	local existing = model:FindFirstChild(DIAGNOSTICS_ROOT_NAME)
	if existing == nil then
		return nil
	end
	assert(existing:IsA("Folder"), `unexpected diagnostics root class: {existing.ClassName}`)
	assert(
		existing:GetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned") == true,
		"refusing to operate on unrelated Physics Lab diagnostics root"
	)
	return existing
end

local function directRepresentations(lab: PhysicsLabRealizer.RealizedLab, model: Model): { Instance }
	local representations = {}
	local seenEntityIds: { [string]: boolean } = {}
	for _, child in ipairs(model:GetChildren()) do
		if child.Name ~= DIAGNOSTICS_ROOT_NAME and child:GetAttribute("UNRENDERED_WorldEntityId") ~= nil then
			local entityId = requireStringAttribute(child, "UNRENDERED_WorldEntityId")
			assert(
				seenEntityIds[entityId] ~= true,
				`diagnostics representation enumeration contains duplicate WorldEntityId: {entityId}`
			)
			assert(
				lab.ownsRepresentation(entityId, child),
				`diagnostics child is not the authoritative owned representation: {entityId}`
			)
			seenEntityIds[entityId] = true
			table.insert(representations, child)
		end
	end

	local representedCount = requireNonNegativeIntegerAttribute(model, "UNRENDERED_RepresentedCount")
	assert(
		#representations == representedCount,
		`diagnostics representation enumeration disagrees with represented count: expected {representedCount}, got {#representations}`
	)

	table.sort(representations, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	return representations
end

local function adorneeFor(representation: Instance): BasePart
	if representation:IsA("BasePart") then
		return representation
	end
	local part = representation:FindFirstChildWhichIsA("BasePart", true)
	assert(
		part ~= nil and part:IsA("BasePart"),
		`diagnostics representation has no BasePart: {representation.Name}`
	)
	return part
end

local function preflightReadouts(lab: PhysicsLabRealizer.RealizedLab, model: Model): { ReadoutPlan }
	local plans: { ReadoutPlan } = {}
	for _, representation in ipairs(directRepresentations(lab, model)) do
		local entityId = requireStringAttribute(representation, "UNRENDERED_WorldEntityId")
		local record = lab.getRecord(entityId)
		assertRepresentationMetadata(
			representation,
			entityId,
			record.fidelity,
			record.origin.recipeKey,
			record.representationRevision,
			record.stateRevision
		)
		local plan: ReadoutPlan = {
			key = representation.Name,
			worldEntityId = record.id,
			fidelity = record.fidelity,
			representationRevision = record.representationRevision,
			stateRevision = record.stateRevision,
			adornee = adorneeFor(representation),
		}
		table.freeze(plan)
		table.insert(plans, plan)
	end
	table.freeze(plans)
	return plans
end

function PhysicsLabStudioDiagnostics.capture(lab: PhysicsLabRealizer.RealizedLab): Snapshot
	assertStudioServer()
	local model = lab.model
	local folder = diagnosticsRoot(model)
	local entities: { EntityDiagnostic } = {}

	for _, representation in ipairs(directRepresentations(lab, model)) do
		local entityId = requireStringAttribute(representation, "UNRENDERED_WorldEntityId")
		local record = lab.getRecord(entityId)
		assertRepresentationMetadata(
			representation,
			entityId,
			record.fidelity,
			record.origin.recipeKey,
			record.representationRevision,
			record.stateRevision
		)

		local representationClass = representation:GetAttribute("UNRENDERED_RepresentationClass")
		assert(
			representationClass == nil or type(representationClass) == "string",
			`invalid representation class diagnostics attribute: {representation.Name}`
		)

		local entity: EntityDiagnostic = {
			key = representation.Name,
			worldEntityId = record.id,
			fidelity = record.fidelity,
			recipeKey = record.origin.recipeKey,
			representationRevision = record.representationRevision,
			stateRevision = record.stateRevision,
			representationClass = representationClass :: string?,
		}
		table.freeze(entity)
		table.insert(entities, entity)
	end

	table.freeze(entities)
	local diagnosticInstanceCount = 0
	if folder ~= nil then
		diagnosticInstanceCount = 1 + #folder:GetDescendants()
	end

	local snapshot: Snapshot = {
		schemaVersion = DIAGNOSTICS_SCHEMA_VERSION,
		enabled = folder ~= nil,
		worldId = requireStringAttribute(model, "UNRENDERED_WorldId"),
		regionId = requireStringAttribute(model, "UNRENDERED_RegionId"),
		resolvedRegionFingerprint = requireStringAttribute(model, "UNRENDERED_ResolvedRegionFingerprint"),
		resolvedRegionReproKey = requireStringAttribute(model, "UNRENDERED_ResolvedRegionReproKey"),
		diagnosticInstanceCount = diagnosticInstanceCount,
		entities = entities,
	}
	table.freeze(snapshot)
	return snapshot
end

function PhysicsLabStudioDiagnostics.enable(lab: PhysicsLabRealizer.RealizedLab): Snapshot
	assertStudioServer()
	local model = lab.model
	assert(diagnosticsRoot(model) == nil, "Physics Lab diagnostics are already enabled")

	-- Validate every source needed by the readout tree before mutating the lab.
	-- This keeps all explicit contract failures outside the ownership transaction.
	local fingerprint = requireStringAttribute(model, "UNRENDERED_ResolvedRegionFingerprint")
	local reproKey = requireStringAttribute(model, "UNRENDERED_ResolvedRegionReproKey")
	local plans = preflightReadouts(lab, model)

	local folder = Instance.new("Folder")

	-- Instance realization is transactional: every created child is parented to
	-- the owned tree before fallible configuration, so rollback destroys all
	-- resources created by this call before propagating the original error.
	local ok, result = pcall(function(): Snapshot
		folder.Name = DIAGNOSTICS_ROOT_NAME
		folder:SetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned", true)
		folder.Parent = model
		for index, plan in ipairs(plans) do
			local billboard = Instance.new("BillboardGui")
			billboard.Parent = folder
			billboard.Name = string.format("Entity_%03d_%s", index, plan.key)
			billboard.AlwaysOnTop = true
			billboard.MaxDistance = 120
			billboard.Size = UDim2.fromOffset(560, 136)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
			billboard.Adornee = plan.adornee

			local label = Instance.new("TextLabel")
			label.Parent = billboard
			label.Name = "Readout"
			label.BackgroundTransparency = 0.2
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.Code
			label.TextSize = 12
			label.TextWrapped = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.Text = string.format(
				"%s | %s | fidelity=%s\nreprRev=%d | stateRev=%d\nfingerprint=%s\nrepro=%s",
				plan.key,
				plan.worldEntityId,
				plan.fidelity,
				plan.representationRevision,
				plan.stateRevision,
				fingerprint,
				reproKey
			)
		end
		return PhysicsLabStudioDiagnostics.capture(lab)
	end)

	if not ok then
		folder:Destroy()
		error(result, 0)
	end
	return result :: Snapshot
end

function PhysicsLabStudioDiagnostics.disable(lab: PhysicsLabRealizer.RealizedLab): Snapshot
	assertStudioServer()
	local folder = diagnosticsRoot(lab.model)
	if folder ~= nil then
		folder:Destroy()
	end
	local snapshot = PhysicsLabStudioDiagnostics.capture(lab)
	assert(
		not snapshot.enabled and snapshot.diagnosticInstanceCount == 0,
		"Physics Lab diagnostics did not cleanly disable"
	)
	return snapshot
end

function PhysicsLabStudioDiagnostics.runToggleEvidence(
	lab: PhysicsLabRealizer.RealizedLab,
	cycles: number?
): { [string]: any }
	assertStudioServer()
	local cycleCount = requireToggleCycleCount(cycles)

	local initial = PhysicsLabStudioDiagnostics.capture(lab)
	assert(
		not initial.enabled and initial.diagnosticInstanceCount == 0,
		"Physics Lab diagnostics must be off before toggle evidence begins"
	)
	local baseline = Validation.captureFull(lab.model)
	local checkpoints = {}
	local maxDiagnosticInstances = 0
	local sample: EntityDiagnostic? = nil

	for cycle = 1, cycleCount do
		-- Full canonical validation includes deterministic ObjectGenome fingerprinting.
		-- Real Studio evidence showed that 20 uninterrupted enable/disable/full-snapshot
		-- iterations can exhaust Roblox's script watchdog even though each individual
		-- cycle is valid. This evidence helper is Studio-only, so yield one real
		-- Heartbeat per cycle to keep the work incremental without changing any truth,
		-- identity, resource-delta, or envelope assertion.
		RunService.Heartbeat:Wait()

		local enabled = PhysicsLabStudioDiagnostics.enable(lab)
		assert(enabled.enabled, `diagnostics failed to enable at cycle {cycle}`)
		assert(
			enabled.diagnosticInstanceCount > 0,
			`diagnostics created no inspectable readouts at cycle {cycle}`
		)
		maxDiagnosticInstances = math.max(maxDiagnosticInstances, enabled.diagnosticInstanceCount)
		if sample == nil then
			sample = enabled.entities[1]
		end

		local disabled = PhysicsLabStudioDiagnostics.disable(lab)
		assert(not disabled.enabled, `diagnostics remained enabled at cycle {cycle}`)
		local offSnapshot = Validation.captureFull(lab.model)
		local comparison = Validation.compare(baseline, offSnapshot, 0.001)
		for countName, delta in pairs(comparison.delta) do
			assert(delta == 0, `diagnostics-off resource drift at cycle {cycle}: {countName}={delta}`)
		end
		assert(comparison.envelope.ok, comparison.envelope.reason or "diagnostics-off envelope drifted")

		if CHECKPOINT_CYCLES[cycle] == true or cycle == cycleCount then
			local checkpoint = {
				cycle = cycle,
				diagnosticInstanceCount = enabled.diagnosticInstanceCount,
				delta = comparison.delta,
				envelope = comparison.envelope,
			}
			table.freeze(checkpoint)
			table.insert(checkpoints, checkpoint)
		end

		-- The evidence sweep is intentionally bounded but performs a full canonical
		-- validation every cycle. Yield once between cycles so Studio's Luau watchdog
		-- does not treat the complete 20-cycle diagnostic soak as one uninterrupted
		-- timeslice. All enable/off/resource/envelope assertions above remain exact.
		RunService.Heartbeat:Wait()
	end

	assert(sample ~= nil, "diagnostics evidence did not capture an entity sample")
	table.freeze(checkpoints)
	local finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)
	assert(
		not finalSnapshot.enabled and finalSnapshot.diagnosticInstanceCount == 0,
		"Physics Lab diagnostics must be off when toggle evidence finishes"
	)
	local evidence = {
		schemaVersion = DIAGNOSTICS_SCHEMA_VERSION,
		cycleCount = cycleCount,
		initiallyEnabled = initial.enabled,
		finallyEnabled = finalSnapshot.enabled,
		maxDiagnosticInstances = maxDiagnosticInstances,
		worldId = finalSnapshot.worldId,
		regionId = finalSnapshot.regionId,
		resolvedRegionFingerprint = finalSnapshot.resolvedRegionFingerprint,
		resolvedRegionReproKey = finalSnapshot.resolvedRegionReproKey,
		entitySample = sample,
		checkpoints = checkpoints,
	}
	table.freeze(evidence)
	return evidence
end

return table.freeze(PhysicsLabStudioDiagnostics)
