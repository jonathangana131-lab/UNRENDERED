--!strict

local PhysicsLabValidationContract = {}

export type Vec3 = { x: number, y: number, z: number }

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
	resolvedRegionSchemaVersion: number,
	worldSeedRef: string,
	resolvedRegionFingerprint: string,
	resolvedRegionReproKey: string,
	counts: ResourceCounts,
	envelopeStuds: Envelope?,
}

export type ResourceDelta = ResourceCounts
export type EnvelopeDrift = { min: Vec3, max: Vec3, maxAbsStuds: number }
export type EnvelopeReport = {
	ok: boolean,
	reason: string?,
	toleranceStuds: number,
	driftStuds: EnvelopeDrift?,
}
export type Comparison = { delta: ResourceDelta, envelope: EnvelopeReport }

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
	"worldSeedRef",
	"resolvedRegionFingerprint",
	"resolvedRegionReproKey",
})

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: any): boolean
	return isFinite(value) and value >= 0 and value % 1 == 0
end

local function isPositiveInteger(value: any): boolean
	return isNonNegativeInteger(value) and value >= 1
end

local function isPlainTable(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

local function inspectVec3(value: any, label: string): (boolean, string?)
	if not isPlainTable(value) then
		return false, `{label} must be a plain table`
	end
	for _, axis in ipairs({ "x", "y", "z" }) do
		if not isFinite(value[axis]) then
			return false, `{label}.{axis} must be finite`
		end
	end
	return true, nil
end

local function inspectEnvelope(envelope: any): (boolean, string?)
	if not isPlainTable(envelope) then
		return false, "envelopeStuds must be a plain table when present"
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

function PhysicsLabValidationContract.inspectSnapshot(snapshot: any): (boolean, string?)
	if not isPlainTable(snapshot) then
		return false, "snapshot must be a plain table"
	end
	if type(snapshot.rootName) ~= "string" or snapshot.rootName == "" then
		return false, "snapshot.rootName must be a non-empty string"
	end
	if not isPositiveInteger(snapshot.labSchemaVersion) then
		return false, "snapshot.labSchemaVersion must be a positive integer"
	end
	if not isPositiveInteger(snapshot.resolvedRegionSchemaVersion) then
		return false, "snapshot.resolvedRegionSchemaVersion must be a positive integer"
	end
	for _, field in ipairs(IDENTITY_KEYS) do
		if type(snapshot[field]) ~= "string" or snapshot[field] == "" then
			return false, `snapshot.{field} must be a non-empty string`
		end
	end
	if not isPlainTable(snapshot.counts) then
		return false, "snapshot.counts must be a plain table"
	end
	for _, key in ipairs(COUNT_KEYS) do
		if not isNonNegativeInteger(snapshot.counts[key]) then
			return false, `snapshot.counts.{key} must be a non-negative integer`
		end
	end
	if snapshot.counts.instances < 1 then
		return false, "snapshot.counts.instances must include the selected lab root"
	end
	if snapshot.counts.models < 1 then
		return false, "snapshot.counts.models must include the selected lab Model root"
	end

	local classifiedInstances = snapshot.counts.models
		+ snapshot.counts.parts
		+ snapshot.counts.attachments
		+ snapshot.counts.constraints
		+ snapshot.counts.joints
	if classifiedInstances > snapshot.counts.instances then
		return false, "snapshot.counts classified Instance total exceeds instances"
	end
	if snapshot.counts.assemblies > snapshot.counts.parts then
		return false, "snapshot.counts.assemblies cannot exceed parts"
	end
	if snapshot.counts.parts > 0 and snapshot.counts.assemblies < 1 then
		return false, "snapshot.counts.assemblies must include an assembly when BaseParts are present"
	end
	if snapshot.counts.parts > 0 and snapshot.envelopeStuds == nil then
		return false, "snapshot.envelopeStuds is required when BaseParts are present"
	end
	if snapshot.counts.parts == 0 and snapshot.envelopeStuds ~= nil then
		return false, "snapshot.envelopeStuds must be nil when no BaseParts are present"
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
	assert(
		baseline.resolvedRegionSchemaVersion == checkpoint.resolvedRegionSchemaVersion,
		"Physics Lab validation snapshots use different resolved-region schema versions"
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

function PhysicsLabValidationContract.delta(before: Snapshot, after: Snapshot): ResourceDelta
	assertSnapshot(before, "before")
	assertSnapshot(after, "after")
	assertSameIdentity(before, after)
	return resourceDelta(before.counts, after.counts)
end

function PhysicsLabValidationContract.compareFullLabEnvelope(
	baseline: Snapshot,
	checkpoint: Snapshot,
	toleranceStuds: number?
): EnvelopeReport
	assertSnapshot(baseline, "baseline")
	assertSnapshot(checkpoint, "checkpoint")
	assertSameIdentity(baseline, checkpoint)

	local tolerance = if toleranceStuds == nil then 0.001 else toleranceStuds
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
		envelope = PhysicsLabValidationContract.compareFullLabEnvelope(baseline, checkpoint, toleranceStuds),
	})
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
