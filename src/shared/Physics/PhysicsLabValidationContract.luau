--!strict

local PhysicsLabValidationContract = {}

export type Vec3 = { x: number, y: number, z: number }
export type FidelityCounts = {
	F0: number,
	F1: number,
	F2: number,
	F3: number,
	F4: number,
}
export type EntityEvidence = {
	id: string,
	fidelity: string,
	recipeKey: string,
}
export type EntityMismatch = {
	id: string,
	baselineFidelity: string,
	checkpointFidelity: string,
	baselineRecipeKey: string,
	checkpointRecipeKey: string,
}

export type ResourceCounts = {
	instances: number,
	models: number,
	parts: number,
	assemblies: number,
	attachments: number,
	constraints: number,
	joints: number,
}

export type Envelope = { min: Vec3, max: Vec3 }

export type Snapshot = {
	rootName: string,
	labSchemaVersion: number,
	labRecipeKey: string,
	worldId: string,
	regionId: string,
	resolvedRegionFingerprint: string,
	resolvedRegionReproKey: string,
	entityCount: number,
	representedCount: number,
	fidelityCounts: FidelityCounts,
	entities: { EntityEvidence },
	counts: ResourceCounts,
	envelopeStuds: Envelope?,
}

export type ResourceDelta = ResourceCounts
export type FidelityDelta = FidelityCounts
export type EntityInventoryReport = {
	ok: boolean,
	reason: string?,
	entityCountDelta: number,
	representedCountDelta: number,
	fidelityDelta: FidelityDelta,
	missingIds: { string },
	unexpectedIds: { string },
	mismatches: { EntityMismatch },
}
export type EnvelopeDrift = { min: Vec3, max: Vec3, maxAbsStuds: number }
export type EnvelopeReport = {
	ok: boolean,
	reason: string?,
	toleranceStuds: number,
	driftStuds: EnvelopeDrift?,
}
export type Comparison = {
	delta: ResourceDelta,
	entities: EntityInventoryReport,
	envelope: EnvelopeReport,
}

local COUNT_KEYS = table.freeze({
	"instances",
	"models",
	"parts",
	"assemblies",
	"attachments",
	"constraints",
	"joints",
})

local IDENTITY_KEYS = table.freeze({
	"labRecipeKey",
	"worldId",
	"regionId",
	"resolvedRegionFingerprint",
	"resolvedRegionReproKey",
})

local VALID_FIDELITIES = table.freeze({
	F0 = true,
	F1 = true,
	F2 = true,
	F3 = true,
	F4 = true,
})

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: any): boolean
	return isFinite(value) and value >= 0 and value % 1 == 0
end

local function inspectVec3(value: any, label: string): (boolean, string?)
	if type(value) ~= "table" then
		return false, `{label} must be a table`
	end
	for _, axis in ipairs({ "x", "y", "z" }) do
		if not isFinite(value[axis]) then
			return false, `{label}.{axis} must be finite`
		end
	end
	return true, nil
end

local function inspectEnvelope(envelope: any): (boolean, string?)
	if type(envelope) ~= "table" then
		return false, "envelopeStuds must be a table when present"
	end
	local minOk, minError = inspectVec3(envelope.min, "envelopeStuds.min")
	if not minOk then
		return false, minError
	end
	local maxOk, maxError = inspectVec3(envelope.max, "envelopeStuds.max")
	if not maxOk then
		return false, maxError
	end
	for _, axis in ipairs({ "x", "y", "z" }) do
		if envelope.min[axis] > envelope.max[axis] then
			return false, `envelopeStuds.min.{axis} exceeds max.{axis}`
		end
	end
	return true, nil
end

local function inspectFidelityCounts(value: any): (boolean, string?)
	if type(value) ~= "table" then
		return false, "snapshot.fidelityCounts must be a table"
	end
	for _, fidelity in ipairs({ "F0", "F1", "F2", "F3", "F4" }) do
		if not isNonNegativeInteger(value[fidelity]) then
			return false, `snapshot.fidelityCounts.{fidelity} must be a non-negative integer`
		end
	end
	return true, nil
end

local function inspectEntities(snapshot: any): (boolean, string?)
	if type(snapshot.entities) ~= "table" then
		return false, "snapshot.entities must be an array"
	end
	if #snapshot.entities ~= snapshot.representedCount then
		return false, "snapshot.entities must contain exactly representedCount entries"
	end

	local previousId: string? = nil
	for index, entity in ipairs(snapshot.entities) do
		if type(entity) ~= "table" then
			return false, `snapshot.entities[{index}] must be a table`
		end
		if type(entity.id) ~= "string" or entity.id == "" then
			return false, `snapshot.entities[{index}].id must be a non-empty string`
		end
		if previousId ~= nil and entity.id <= previousId then
			return false, "snapshot.entities must be strictly sorted by unique WorldEntity id"
		end
		previousId = entity.id
		if type(entity.fidelity) ~= "string" or VALID_FIDELITIES[entity.fidelity] ~= true then
			return false, `snapshot.entities[{index}].fidelity must be F0-F4`
		end
		if entity.fidelity == "F0" then
			return false, `snapshot.entities[{index}] cannot represent an F0 WorldEntity`
		end
		if type(entity.recipeKey) ~= "string" or entity.recipeKey == "" then
			return false, `snapshot.entities[{index}].recipeKey must be a non-empty string`
		end
	end
	return true, nil
end

function PhysicsLabValidationContract.inspectSnapshot(snapshot: any): (boolean, string?)
	if type(snapshot) ~= "table" then
		return false, "snapshot must be a table"
	end
	if type(snapshot.rootName) ~= "string" or snapshot.rootName == "" then
		return false, "snapshot.rootName must be a non-empty string"
	end
	if not isNonNegativeInteger(snapshot.labSchemaVersion) or snapshot.labSchemaVersion < 1 then
		return false, "snapshot.labSchemaVersion must be a positive integer"
	end
	for _, field in ipairs(IDENTITY_KEYS) do
		if type(snapshot[field]) ~= "string" or snapshot[field] == "" then
			return false, `snapshot.{field} must be a non-empty string`
		end
	end
	if not isNonNegativeInteger(snapshot.entityCount) then
		return false, "snapshot.entityCount must be a non-negative integer"
	end
	if not isNonNegativeInteger(snapshot.representedCount) then
		return false, "snapshot.representedCount must be a non-negative integer"
	end
	if snapshot.representedCount > snapshot.entityCount then
		return false, "snapshot.representedCount cannot exceed entityCount"
	end

	local fidelityOk, fidelityError = inspectFidelityCounts(snapshot.fidelityCounts)
	if not fidelityOk then
		return false, fidelityError
	end
	local fidelityTotal = snapshot.fidelityCounts.F0
		+ snapshot.fidelityCounts.F1
		+ snapshot.fidelityCounts.F2
		+ snapshot.fidelityCounts.F3
		+ snapshot.fidelityCounts.F4
	if fidelityTotal ~= snapshot.entityCount then
		return false, "snapshot.fidelityCounts must sum to entityCount"
	end

	local entitiesOk, entitiesError = inspectEntities(snapshot)
	if not entitiesOk then
		return false, entitiesError
	end
	local representedByFidelity = { F1 = 0, F2 = 0, F3 = 0, F4 = 0 }
	for _, entity in ipairs(snapshot.entities) do
		representedByFidelity[entity.fidelity] += 1
	end
	for _, fidelity in ipairs({ "F1", "F2", "F3", "F4" }) do
		if representedByFidelity[fidelity] > snapshot.fidelityCounts[fidelity] then
			return false,
				`snapshot.entities contains more {fidelity} representations than authoritative fidelity count`
		end
	end

	if type(snapshot.counts) ~= "table" then
		return false, "snapshot.counts must be a table"
	end
	for _, key in ipairs(COUNT_KEYS) do
		if not isNonNegativeInteger(snapshot.counts[key]) then
			return false, `snapshot.counts.{key} must be a non-negative integer`
		end
	end
	if snapshot.counts.instances < 1 then
		return false, "snapshot.counts.instances must include the selected lab root"
	end
	if snapshot.envelopeStuds ~= nil then
		local envelopeOk, envelopeError = inspectEnvelope(snapshot.envelopeStuds)
		if not envelopeOk then
			return false, envelopeError
		end
	end
	return true, nil
end

local function assertSnapshot(snapshot: Snapshot, label: string): ()
	local ok, problem = PhysicsLabValidationContract.inspectSnapshot(snapshot)
	assert(ok, `{label} validation snapshot is invalid: {problem or "unknown validation error"}`)
end

local function assertSameIdentity(baseline: Snapshot, checkpoint: Snapshot): ()
	assert(
		baseline.labSchemaVersion == checkpoint.labSchemaVersion,
		"Physics Lab validation snapshots use different lab schema versions"
	)
	for _, key in ipairs(IDENTITY_KEYS) do
		assert(
			baseline[key] == checkpoint[key],
			`Physics Lab validation snapshots differ at identity field {key}`
		)
	end
end

local function freezeVec3(value: Vec3): Vec3
	return table.freeze({ x = value.x, y = value.y, z = value.z })
end

local function resourceDelta(before: ResourceCounts, after: ResourceCounts): ResourceDelta
	return table.freeze({
		instances = after.instances - before.instances,
		models = after.models - before.models,
		parts = after.parts - before.parts,
		assemblies = after.assemblies - before.assemblies,
		attachments = after.attachments - before.attachments,
		constraints = after.constraints - before.constraints,
		joints = after.joints - before.joints,
	})
end

local function fidelityDelta(before: FidelityCounts, after: FidelityCounts): FidelityDelta
	return table.freeze({
		F0 = after.F0 - before.F0,
		F1 = after.F1 - before.F1,
		F2 = after.F2 - before.F2,
		F3 = after.F3 - before.F3,
		F4 = after.F4 - before.F4,
	})
end

function PhysicsLabValidationContract.delta(before: Snapshot, after: Snapshot): ResourceDelta
	assertSnapshot(before, "before")
	assertSnapshot(after, "after")
	assertSameIdentity(before, after)
	return resourceDelta(before.counts, after.counts)
end

function PhysicsLabValidationContract.compareEntityInventory(
	baseline: Snapshot,
	checkpoint: Snapshot
): EntityInventoryReport
	assertSnapshot(baseline, "baseline")
	assertSnapshot(checkpoint, "checkpoint")
	assertSameIdentity(baseline, checkpoint)

	local baselineById: { [string]: EntityEvidence } = {}
	local checkpointById: { [string]: EntityEvidence } = {}
	for _, entity in ipairs(baseline.entities) do
		baselineById[entity.id] = entity
	end
	for _, entity in ipairs(checkpoint.entities) do
		checkpointById[entity.id] = entity
	end

	local missingIds: { string } = {}
	local unexpectedIds: { string } = {}
	local mismatches: { EntityMismatch } = {}
	for _, entity in ipairs(baseline.entities) do
		local after = checkpointById[entity.id]
		if after == nil then
			table.insert(missingIds, entity.id)
		elseif after.fidelity ~= entity.fidelity or after.recipeKey ~= entity.recipeKey then
			table.insert(
				mismatches,
				table.freeze({
					id = entity.id,
					baselineFidelity = entity.fidelity,
					checkpointFidelity = after.fidelity,
					baselineRecipeKey = entity.recipeKey,
					checkpointRecipeKey = after.recipeKey,
				})
			)
		end
	end
	for _, entity in ipairs(checkpoint.entities) do
		if baselineById[entity.id] == nil then
			table.insert(unexpectedIds, entity.id)
		end
	end

	local fidelity = fidelityDelta(baseline.fidelityCounts, checkpoint.fidelityCounts)
	local entityCountDelta = checkpoint.entityCount - baseline.entityCount
	local representedCountDelta = checkpoint.representedCount - baseline.representedCount
	local ok = entityCountDelta == 0
		and representedCountDelta == 0
		and fidelity.F0 == 0
		and fidelity.F1 == 0
		and fidelity.F2 == 0
		and fidelity.F3 == 0
		and fidelity.F4 == 0
		and #missingIds == 0
		and #unexpectedIds == 0
		and #mismatches == 0

	return table.freeze({
		ok = ok,
		reason = if ok then nil else "represented WorldEntity inventory or fidelity summary changed",
		entityCountDelta = entityCountDelta,
		representedCountDelta = representedCountDelta,
		fidelityDelta = fidelity,
		missingIds = table.freeze(missingIds),
		unexpectedIds = table.freeze(unexpectedIds),
		mismatches = table.freeze(mismatches),
	})
end

function PhysicsLabValidationContract.compareFullLabEnvelope(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): EnvelopeReport
	assertSnapshot(baseline, "baseline")
	assertSnapshot(checkpoint, "checkpoint")
	assertSameIdentity(baseline, checkpoint)

	local tolerance = toleranceStuds or 0.001
	assert(
		isFinite(tolerance) and tolerance >= 0,
		"Physics Lab envelope tolerance must be finite and non-negative"
	)

	local expected = baseline.envelopeStuds
	local actual = checkpoint.envelopeStuds
	if expected == nil then
		return table.freeze({
			ok = false,
			reason = "baseline has no BasePart envelope",
			toleranceStuds = tolerance,
			driftStuds = nil,
		})
	end
	if actual == nil then
		return table.freeze({
			ok = false,
			reason = "checkpoint has no BasePart envelope",
			toleranceStuds = tolerance,
			driftStuds = nil,
		})
	end

	local minDrift = {
		x = actual.min.x - expected.min.x,
		y = actual.min.y - expected.min.y,
		z = actual.min.z - expected.min.z,
	}
	local maxDrift = {
		x = actual.max.x - expected.max.x,
		y = actual.max.y - expected.max.y,
		z = actual.max.z - expected.max.z,
	}
	local maxAbs = 0
	for _, drift in ipairs({ minDrift, maxDrift }) do
		maxAbs = math.max(maxAbs, math.abs(drift.x), math.abs(drift.y), math.abs(drift.z))
	end
	local ok = maxAbs <= tolerance
	local drift: EnvelopeDrift = table.freeze({
		min = freezeVec3(minDrift),
		max = freezeVec3(maxDrift),
		maxAbsStuds = maxAbs,
	})

	return table.freeze({
		ok = ok,
		reason = if ok then nil else "full-lab physical envelope drift exceeded tolerance",
		toleranceStuds = tolerance,
		driftStuds = drift,
	})
end

function PhysicsLabValidationContract.compare(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): Comparison
	return table.freeze({
		delta = PhysicsLabValidationContract.delta(baseline, checkpoint),
		entities = PhysicsLabValidationContract.compareEntityInventory(baseline, checkpoint),
		envelope = PhysicsLabValidationContract.compareFullLabEnvelope(baseline, checkpoint, toleranceStuds),
	})
end

function PhysicsLabValidationContract.assertSameEntityInventory(
	baseline: Snapshot,
	checkpoint: Snapshot
): EntityInventoryReport
	local report = PhysicsLabValidationContract.compareEntityInventory(baseline, checkpoint)
	assert(
		report.ok,
		`Physics Lab entity inventory validation failed: {report.reason or "unknown entity inventory violation"}`
	)
	return report
end

function PhysicsLabValidationContract.assertFullLabEnvelope(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): EnvelopeReport
	local report = PhysicsLabValidationContract.compareFullLabEnvelope(baseline, checkpoint, toleranceStuds)
	assert(
		report.ok,
		`Physics Lab full-lab envelope validation failed: {report.reason or "unknown envelope violation"}`
	)
	return report
end

return table.freeze(PhysicsLabValidationContract)
