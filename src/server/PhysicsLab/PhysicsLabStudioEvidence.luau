--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local FidelityManager = require(Shared.Physics.FidelityManager)
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)
local PhysicsLabStudioHarness = require(script.Parent.PhysicsLabStudioHarness)
local PhysicsLabValidation = require(script.Parent.PhysicsLabValidation)

type RealizedLab = PhysicsLabRealizer.RealizedLab

type EntityEvidence = {
	key: string,
	entityId: string,
	kind: "object" | "primitive",
	initialStateRevision: number,
	finalStateRevision: number,
	initialRepresentationRevision: number,
	finalRepresentationRevision: number,
}

type CheckpointEvidence = {
	cycle: number,
	snapshot: PhysicsLabValidation.Snapshot,
	comparison: PhysicsLabValidation.Comparison,
}

export type LifecycleEvidence = {
	schemaVersion: number,
	cycleCount: number,
	envelopeToleranceStuds: number,
	baseline: PhysicsLabValidation.Snapshot,
	checkpoints: { CheckpointEvidence },
	entities: { EntityEvidence },
}

local PhysicsLabStudioEvidence = {}

local EVIDENCE_SCHEMA_VERSION = 1
local CYCLE_COUNT = 20
local CYCLE_STRIDE_SECONDS = 10
local ENVELOPE_TOLERANCE_STUDS = 0.001
local CHECKPOINT_CYCLES: { [number]: boolean } = table.freeze({
	[1] = true,
	[5] = true,
	[10] = true,
	[20] = true,
})

local NO_DEMAND: FidelityManager.PolicyInputs = table.freeze({
	distanceStuds = 1000000,
	visible = false,
	directlyObserved = false,
	secondsSinceInteraction = math.huge,
	significance = 0,
	networkRelevance = 0,
	entityRelevance = 0,
})

local F2_DEMAND: FidelityManager.PolicyInputs = table.freeze({
	distanceStuds = 100,
	visible = false,
	directlyObserved = false,
	secondsSinceInteraction = math.huge,
	significance = 0,
	networkRelevance = 0,
	entityRelevance = 0,
})

local function assertZeroResourceDelta(comparison: PhysicsLabValidation.Comparison, cycle: number): ()
	local delta = comparison.delta
	assert(
		delta.instances == 0,
		`Physics Lab lifecycle cycle {cycle} changed Instance count by {delta.instances}`
	)
	assert(delta.models == 0, `Physics Lab lifecycle cycle {cycle} changed Model count by {delta.models}`)
	assert(delta.parts == 0, `Physics Lab lifecycle cycle {cycle} changed BasePart count by {delta.parts}`)
	assert(
		delta.assemblies == 0,
		`Physics Lab lifecycle cycle {cycle} changed assembly count by {delta.assemblies}`
	)
	assert(
		delta.attachments == 0,
		`Physics Lab lifecycle cycle {cycle} changed Attachment count by {delta.attachments}`
	)
	assert(
		delta.constraints == 0,
		`Physics Lab lifecycle cycle {cycle} changed Constraint count by {delta.constraints}`
	)
	assert(
		delta.joints == 0,
		`Physics Lab lifecycle cycle {cycle} changed JointInstance count by {delta.joints}`
	)
end

local function demoteToF0(lab: RealizedLab, entityId: string, baseTime: number): ()
	local before = lab.getRecord(entityId)
	assert(before.fidelity == "F2", `expected F2 before lifecycle demotion: {entityId}`)
	assert(lab.isRepresented(entityId), `expected F2 representation before lifecycle demotion: {entityId}`)

	local pending = lab.step(entityId, NO_DEMAND, baseTime)
	assert(
		not pending.transitioned and pending.desiredLevel == "F0" and pending.blockedReason == "hold",
		`first lifecycle demotion sample did not establish the production F0 hold: {entityId}`
	)

	local result, demoted = lab.step(entityId, NO_DEMAND, baseTime + 2)
	assert(result.transitioned and demoted.fidelity == "F0", `F2->F0 lifecycle transition failed: {entityId}`)
	assert(
		not lab.isRepresented(entityId),
		`F0 lifecycle transition left a representation behind: {entityId}`
	)
end

local function promoteToF2(lab: RealizedLab, entityId: string, baseTime: number): ()
	local before = lab.getRecord(entityId)
	assert(before.fidelity == "F0", `expected F0 before lifecycle promotion: {entityId}`)
	assert(
		not lab.isRepresented(entityId),
		`F0 entity was unexpectedly represented before promotion: {entityId}`
	)

	local pending = lab.step(entityId, F2_DEMAND, baseTime + 3)
	assert(
		not pending.transitioned and pending.desiredLevel == "F2" and pending.blockedReason == "hold",
		`first lifecycle promotion sample did not establish the production F2 hold: {entityId}`
	)

	local result, promoted = lab.step(entityId, F2_DEMAND, baseTime + 3.2)
	assert(
		result.transitioned and promoted.fidelity == "F2",
		`F0->F2 lifecycle transition failed: {entityId}`
	)
	assert(
		lab.isRepresented(entityId),
		`F2 lifecycle transition failed to rebuild representation: {entityId}`
	)
	assert(promoted.id == before.id, `WorldEntity identity changed during lifecycle promotion: {entityId}`)
end

function PhysicsLabStudioEvidence.runLifecycle20(): LifecycleEvidence
	-- Own a fresh runtime clock for every evidence run so this remains safe after
	-- prior manual harness steps and across repeat invocations in one Studio session.
	local lab = PhysicsLabStudioHarness.restart()
	local recipe = PhysicsLabRecipe.build()
	local baseline = PhysicsLabValidation.capture(lab.model)
	local initialStateRevisionById: { [string]: number } = {}
	local initialRepresentationRevisionById: { [string]: number } = {}

	assert(
		lab.model:GetAttribute("UNRENDERED_EntityCount") == #recipe.entities,
		"Physics Lab runtime/entity recipe population mismatch before lifecycle evidence"
	)
	assert(
		lab.model:GetAttribute("UNRENDERED_RepresentedCount") == #recipe.entities,
		"Physics Lab must begin lifecycle evidence with the complete F2 representation"
	)

	for _, entityRecipe in ipairs(recipe.entities) do
		local entityId = entityRecipe.entity.id
		local record = lab.getRecord(entityId)
		assert(record.fidelity == "F2", `Physics Lab lifecycle evidence requires initial F2: {entityId}`)
		assert(
			lab.isRepresented(entityId),
			`Physics Lab lifecycle evidence requires representation: {entityId}`
		)
		initialStateRevisionById[entityId] = record.stateRevision
		initialRepresentationRevisionById[entityId] = record.representationRevision
	end

	local checkpoints: { CheckpointEvidence } = {}
	for cycle = 1, CYCLE_COUNT do
		local baseTime = (cycle - 1) * CYCLE_STRIDE_SECONDS

		for _, entityRecipe in ipairs(recipe.entities) do
			demoteToF0(lab, entityRecipe.entity.id, baseTime)
		end
		assert(
			lab.model:GetAttribute("UNRENDERED_RepresentedCount") == 0,
			`Physics Lab lifecycle cycle {cycle} did not fully tear down F2 representations`
		)
		assert(
			lab.model:GetAttribute("UNRENDERED_EntityCount") == #recipe.entities,
			`Physics Lab lifecycle cycle {cycle} changed authoritative registration count after teardown`
		)

		for _, entityRecipe in ipairs(recipe.entities) do
			promoteToF2(lab, entityRecipe.entity.id, baseTime)
		end
		assert(
			lab.model:GetAttribute("UNRENDERED_RepresentedCount") == #recipe.entities,
			`Physics Lab lifecycle cycle {cycle} did not restore the complete F2 representation`
		)
		assert(
			lab.model:GetAttribute("UNRENDERED_EntityCount") == #recipe.entities,
			`Physics Lab lifecycle cycle {cycle} changed authoritative registration count after rebuild`
		)

		if CHECKPOINT_CYCLES[cycle] then
			local snapshot = PhysicsLabValidation.capture(lab.model)
			local comparison = PhysicsLabValidation.compare(baseline, snapshot, ENVELOPE_TOLERANCE_STUDS)
			assertZeroResourceDelta(comparison, cycle)
			PhysicsLabValidation.assertFullLabEnvelope(baseline, snapshot, ENVELOPE_TOLERANCE_STUDS)
			table.insert(
				checkpoints,
				table.freeze({
					cycle = cycle,
					snapshot = snapshot,
					comparison = comparison,
				})
			)
		end
	end

	local entities: { EntityEvidence } = {}
	for _, entityRecipe in ipairs(recipe.entities) do
		local entityId = entityRecipe.entity.id
		local final = lab.getRecord(entityId)
		local initialStateRevision = initialStateRevisionById[entityId]
		local initialRepresentationRevision = initialRepresentationRevisionById[entityId]
		assert(
			initialStateRevision ~= nil,
			`missing initial state revision for lifecycle evidence: {entityId}`
		)
		assert(
			initialRepresentationRevision ~= nil,
			`missing initial representation revision for lifecycle evidence: {entityId}`
		)
		assert(final.id == entityId, `WorldEntity identity changed after lifecycle evidence: {entityId}`)
		assert(final.fidelity == "F2", `Physics Lab did not finish lifecycle evidence at F2: {entityId}`)
		assert(lab.isRepresented(entityId), `Physics Lab lost final F2 representation: {entityId}`)
		assert(
			final.stateRevision == initialStateRevision + CYCLE_COUNT,
			`Physics Lab state capture revision count drifted across lifecycle evidence: {entityId}`
		)
		assert(
			final.representationRevision == initialRepresentationRevision + CYCLE_COUNT * 2,
			`Physics Lab representation revision count drifted across lifecycle evidence: {entityId}`
		)

		table.insert(
			entities,
			table.freeze({
				key = entityRecipe.key,
				entityId = entityId,
				kind = entityRecipe.kind,
				initialStateRevision = initialStateRevision,
				finalStateRevision = final.stateRevision,
				initialRepresentationRevision = initialRepresentationRevision,
				finalRepresentationRevision = final.representationRevision,
			})
		)
	end

	return table.freeze({
		schemaVersion = EVIDENCE_SCHEMA_VERSION,
		cycleCount = CYCLE_COUNT,
		envelopeToleranceStuds = ENVELOPE_TOLERANCE_STUDS,
		baseline = baseline,
		checkpoints = table.freeze(checkpoints),
		entities = table.freeze(entities),
	})
end

return table.freeze(PhysicsLabStudioEvidence)
