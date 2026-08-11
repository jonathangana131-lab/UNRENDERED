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
	adornee: BasePart,
}

type ReadoutExpectation = {
	worldEntityId: string,
	adornee: BasePart,
	text: string,
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

local function requireToggleCycleCount(cycles: any): number
	if cycles == nil then
		return DEFAULT_TOGGLE_EVIDENCE_CYCLES
	end
	assert(
		type(cycles) == "number" and cycles >= 1 and cycles <= MAX_TOGGLE_EVIDENCE_CYCLES and cycles % 1 == 0,
		`diagnostics cycle count must be an integer in [1, {MAX_TOGGLE_EVIDENCE_CYCLES}]`
	)
	return cycles :: number
end

local function diagnosticsRoot(model: Model): Folder?
	local existing: Instance? = nil
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == DIAGNOSTICS_ROOT_NAME then
			assert(existing == nil, "duplicate Physics Lab diagnostics root")
			existing = child
		end
	end
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
	local expectedRepresentedCount = model:GetAttribute("UNRENDERED_RepresentedCount")
	assert(
		type(expectedRepresentedCount) == "number"
			and expectedRepresentedCount >= 0
			and expectedRepresentedCount % 1 == 0,
		"invalid authoritative Physics Lab represented-count metric"
	)

	local representations = {}
	local seenEntityIds: { [string]: boolean } = {}
	for _, child in ipairs(model:GetChildren()) do
		if child.Name ~= DIAGNOSTICS_ROOT_NAME and child:GetAttribute("UNRENDERED_WorldEntityId") ~= nil then
			local entityId = requireStringAttribute(child, "UNRENDERED_WorldEntityId")
			assert(not seenEntityIds[entityId], `duplicate diagnostics representation id: {entityId}`)
			assert(
				lab.ownsRepresentation(entityId, child),
				`diagnostics child is not the authoritative representation Instance: {entityId}`
			)
			seenEntityIds[entityId] = true
			table.insert(representations, child)
		end
	end
	assert(
		#representations == expectedRepresentedCount,
		`diagnostics representation count disagrees with authoritative lab metric: expected {expectedRepresentedCount}, got {#representations}`
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

local function readoutText(
	key: string,
	worldEntityId: string,
	fidelity: string,
	fingerprint: string,
	reproKey: string
): string
	return string.format(
		"%s | %s | fidelity=%s\nfingerprint=%s\nrepro=%s",
		key,
		worldEntityId,
		fidelity,
		fingerprint,
		reproKey
	)
end

local function preflightReadouts(lab: PhysicsLabRealizer.RealizedLab, model: Model): { ReadoutPlan }
	local plans: { ReadoutPlan } = {}
	for _, representation in ipairs(directRepresentations(lab, model)) do
		local entityId = requireStringAttribute(representation, "UNRENDERED_WorldEntityId")
		local record = lab.getRecord(entityId)
		local representedFidelity = requireStringAttribute(representation, "UNRENDERED_Fidelity")
		assert(
			record.fidelity == representedFidelity,
			`diagnostics fidelity disagrees with authoritative WorldEntity: {entityId}`
		)
		local plan: ReadoutPlan = {
			key = representation.Name,
			worldEntityId = record.id,
			fidelity = record.fidelity,
			adornee = adorneeFor(representation),
		}
		table.freeze(plan)
		table.insert(plans, plan)
	end
	table.freeze(plans)
	return plans
end

local function validateReadoutCompleteness(folder: Folder, entities: { ReadoutExpectation }): number
	local expectedEntities: { [string]: ReadoutExpectation } = {}
	for _, entity in ipairs(entities) do
		assert(
			expectedEntities[entity.worldEntityId] == nil,
			`duplicate authoritative diagnostics entity id: {entity.worldEntityId}`
		)
		expectedEntities[entity.worldEntityId] = entity
	end

	local seenEntityIds: { [string]: boolean } = {}
	local readoutCount = 0
	for _, child in ipairs(folder:GetChildren()) do
		assert(child:IsA("BillboardGui"), `unexpected diagnostics readout class: {child.ClassName}`)
		local entityId = requireStringAttribute(child, "UNRENDERED_WorldEntityId")
		local expectedEntity = expectedEntities[entityId]
		assert(
			expectedEntity ~= nil,
			`diagnostics readout does not map to an authoritative represented entity: {entityId}`
		)
		assert(seenEntityIds[entityId] == nil, `duplicate diagnostics readout identity: {entityId}`)
		assert(
			child.Adornee == expectedEntity.adornee,
			`diagnostics readout Adornee disagrees with authoritative representation: {entityId}`
		)
		seenEntityIds[entityId] = true

		local label = child:FindFirstChild("Readout")
		assert(label ~= nil and label:IsA("TextLabel"), `diagnostics readout has no TextLabel: {entityId}`)
		assert(#child:GetDescendants() == 1, `diagnostics readout has unexpected descendants: {entityId}`)
		assert(
			label.Text == expectedEntity.text,
			`diagnostics readout text disagrees with authoritative projection: {entityId}`
		)
		readoutCount += 1
	end

	assert(
		readoutCount == #entities,
		`diagnostics readout count disagrees with authoritative entities: expected {#entities}, got {readoutCount}`
	)
	return 1 + 2 * readoutCount
end

function PhysicsLabStudioDiagnostics.capture(lab: PhysicsLabRealizer.RealizedLab): Snapshot
	assertStudioServer()
	local model = lab.model
	local folder = diagnosticsRoot(model)
	local fingerprint = requireStringAttribute(model, "UNRENDERED_ResolvedRegionFingerprint")
	local reproKey = requireStringAttribute(model, "UNRENDERED_ResolvedRegionReproKey")
	local entities: { ReadoutExpectation } = {}
	local snapshotEntities: { EntityDiagnostic } = {}

	for _, representation in ipairs(directRepresentations(lab, model)) do
		local entityId = requireStringAttribute(representation, "UNRENDERED_WorldEntityId")
		local record = lab.getRecord(entityId)
		local representedFidelity = requireStringAttribute(representation, "UNRENDERED_Fidelity")
		assert(
			record.fidelity == representedFidelity,
			`diagnostics fidelity disagrees with authoritative WorldEntity: {entityId}`
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
		table.insert(snapshotEntities, entity)

		local expectation: ReadoutExpectation = {
			worldEntityId = record.id,
			adornee = adorneeFor(representation),
			text = readoutText(representation.Name, record.id, record.fidelity, fingerprint, reproKey),
		}
		table.freeze(expectation)
		table.insert(entities, expectation)
	end

	table.freeze(entities)
	table.freeze(snapshotEntities)
	local diagnosticInstanceCount = 0
	if folder ~= nil then
		diagnosticInstanceCount = validateReadoutCompleteness(folder, entities)
	end

	local snapshot: Snapshot = {
		schemaVersion = DIAGNOSTICS_SCHEMA_VERSION,
		enabled = folder ~= nil,
		worldId = requireStringAttribute(model, "UNRENDERED_WorldId"),
		regionId = requireStringAttribute(model, "UNRENDERED_RegionId"),
		resolvedRegionFingerprint = fingerprint,
		resolvedRegionReproKey = reproKey,
		diagnosticInstanceCount = diagnosticInstanceCount,
		entities = snapshotEntities,
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
			billboard:SetAttribute("UNRENDERED_WorldEntityId", plan.worldEntityId)
			billboard.AlwaysOnTop = true
			billboard.MaxDistance = 120
			billboard.Size = UDim2.fromOffset(560, 116)
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
			label.Text = readoutText(plan.key, plan.worldEntityId, plan.fidelity, fingerprint, reproKey)
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

	PhysicsLabStudioDiagnostics.disable(lab)
	local baseline = Validation.captureFull(lab.model)
	local initial = PhysicsLabStudioDiagnostics.capture(lab)
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
	assert(not finalSnapshot.enabled, "diagnostics were re-enabled after the final cycle")
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
