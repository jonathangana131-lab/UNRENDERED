local ProductionLoader = require("./support/ProductionLoader")

local ValidationContract = ProductionLoader.requireShared("Physics/PhysicsLabValidationContract")

local function snapshot(counts, minX, maxX)
	return {
		rootName = "UNRENDERED_PhysicsLab",
		labSchemaVersion = 1,
		labRecipeKey = "physics-lab.production-shell",
		worldId = "world:v1:physics-lab",
		regionId = "region:v2:physics-lab",
		resolvedRegionSchemaVersion = 2,
		worldSeedRef = "world-seed-ref:physics-lab",
		resolvedRegionFingerprint = "fingerprint:v2:physics-lab",
		resolvedRegionReproKey = "world=v1|region=v2|recipe=physics-lab",
		counts = counts,
		envelopeStuds = if minX == nil
			then nil
			else {
				min = { x = minX, y = -1, z = -2 },
				max = { x = maxX, y = 5, z = 8 },
			},
	}
end

local function counts(instances, constraints)
	return {
		instances = instances,
		models = 6,
		parts = 40,
		assemblies = 40,
		attachments = 0,
		constraints = constraints,
		joints = 0,
	}
end

-- captureInternal always counts the selected owned lab Model even when it has no BaseParts.
local function rootOnlyCounts()
	return {
		instances = 1,
		models = 1,
		parts = 0,
		assemblies = 0,
		attachments = 0,
		constraints = 0,
		joints = 0,
	}
end

local function run(): number
	local failures = 0
	local function expect(name, condition)
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local baseline = snapshot(counts(46, 0), -10, 10)
	local rebuilt = snapshot(counts(49, 3), -10.0004, 10.0005)
	local valid, problem = ValidationContract.inspectSnapshot(baseline)
	expect("baseline snapshot validates", valid and problem == nil)
	expect(
		"snapshot preserves deterministic replay identity",
		baseline.resolvedRegionSchemaVersion == 2
			and baseline.worldSeedRef ~= ""
			and baseline.resolvedRegionFingerprint ~= ""
			and baseline.resolvedRegionReproKey ~= ""
	)

	local comparison = ValidationContract.compare(baseline, rebuilt, 0.001)
	expect("resource delta records total Instance growth", comparison.delta.instances == 3)
	expect("resource delta records total constraint growth", comparison.delta.constraints == 3)
	expect("resource deltas are evidence and do not fail a stable envelope", comparison.envelope.ok)
	expect(
		"envelope report records measured maximum drift",
		comparison.envelope.driftStuds ~= nil
			and math.abs(comparison.envelope.driftStuds.maxAbsStuds - 0.0005) < 1e-9
	)

	local expanded = snapshot(counts(46, 0), -10.01, 10)
	local expandedReport = ValidationContract.compareFullLabEnvelope(baseline, expanded, 0.001)
	expect("full-lab envelope expansion fails closed", not expandedReport.ok)
	expect("envelope violation retains an explicit reason", expandedReport.reason ~= nil)

	local collapsed = snapshot(counts(46, 0), -9.99, 10)
	local collapsedReport = ValidationContract.compareFullLabEnvelope(baseline, collapsed, 0.001)
	expect("full-lab envelope shrink also fails the rebuild checkpoint", not collapsedReport.ok)

	local missingEnvelope = snapshot(rootOnlyCounts(), nil, nil)
	local missingReport = ValidationContract.compareFullLabEnvelope(baseline, missingEnvelope, 0.001)
	expect("missing checkpoint envelope fails closed", not missingReport.ok)

	local asserted = pcall(function()
		ValidationContract.assertFullLabEnvelope(baseline, expanded, 0.001)
	end)
	expect("assertFullLabEnvelope rejects measured envelope drift", not asserted)

	local malformed = snapshot(counts(0, 0), -10, 10)
	local malformedOk = ValidationContract.inspectSnapshot(malformed)
	expect("snapshot validation rejects a count that omits the root", malformedOk == false)

	local unknownSnapshotField = snapshot(counts(46, 0), -10, 10)
	unknownSnapshotField.syntheticEvidence = true
	local unknownSnapshotFieldOk = ValidationContract.inspectSnapshot(unknownSnapshotField)
	expect(
		"snapshot validation rejects fields captureInternal cannot produce",
		unknownSnapshotFieldOk == false
	)

	local unknownCountField = snapshot(counts(46, 0), -10, 10)
	unknownCountField.counts.unclassified = 0
	local unknownCountFieldOk = ValidationContract.inspectSnapshot(unknownCountField)
	expect("snapshot validation rejects unknown resource-count fields", unknownCountFieldOk == false)

	local unknownEnvelopeField = snapshot(counts(46, 0), -10, 10)
	unknownEnvelopeField.envelopeStuds.padding = 0
	local unknownEnvelopeFieldOk = ValidationContract.inspectSnapshot(unknownEnvelopeField)
	expect("snapshot validation rejects unknown envelope fields", unknownEnvelopeFieldOk == false)

	local unknownVectorField = snapshot(counts(46, 0), -10, 10)
	unknownVectorField.envelopeStuds.min.w = 0
	local unknownVectorFieldOk = ValidationContract.inspectSnapshot(unknownVectorField)
	expect("snapshot validation rejects unknown envelope-vector fields", unknownVectorFieldOk == false)

	local unknownKeyToStrings = 0
	local hostileUnknownKey = setmetatable({}, {
		__tostring = function()
			unknownKeyToStrings += 1
			error("unknown key tostring executed")
		end,
	})
	local hostileUnknownField = snapshot(counts(46, 0), -10, 10)
	hostileUnknownField[hostileUnknownKey] = true
	local hostileUnknownCallOk, hostileUnknownAccepted = pcall(function()
		return ValidationContract.inspectSnapshot(hostileUnknownField)
	end)
	expect(
		"snapshot validation rejects hostile unknown keys without formatting them",
		hostileUnknownCallOk and hostileUnknownAccepted == false and unknownKeyToStrings == 0
	)

	local missingRootModel = snapshot(counts(46, 0), -10, 10)
	missingRootModel.counts.models = 0
	local missingRootModelOk = ValidationContract.inspectSnapshot(missingRootModel)
	expect("snapshot validation rejects a missing selected Model root", missingRootModelOk == false)

	local impossibleClassifiedTotal = snapshot(counts(45, 0), -10, 10)
	local impossibleClassifiedTotalOk = ValidationContract.inspectSnapshot(impossibleClassifiedTotal)
	expect(
		"snapshot validation rejects classified Instance counts above total instances",
		impossibleClassifiedTotalOk == false
	)

	local impossibleAssemblyCount = snapshot(counts(46, 0), -10, 10)
	impossibleAssemblyCount.counts.assemblies = 41
	local impossibleAssemblyCountOk = ValidationContract.inspectSnapshot(impossibleAssemblyCount)
	expect("snapshot validation rejects more assemblies than BaseParts", impossibleAssemblyCountOk == false)

	local missingPartAssembly = snapshot(counts(46, 0), -10, 10)
	missingPartAssembly.counts.assemblies = 0
	local missingPartAssemblyOk = ValidationContract.inspectSnapshot(missingPartAssembly)
	expect("snapshot validation rejects BaseParts without an assembly", missingPartAssemblyOk == false)

	local partsWithoutEnvelope = snapshot(counts(46, 0), nil, nil)
	local partsWithoutEnvelopeOk = ValidationContract.inspectSnapshot(partsWithoutEnvelope)
	expect(
		"snapshot validation rejects BaseParts without a physical envelope",
		partsWithoutEnvelopeOk == false
	)

	local envelopeWithoutParts = snapshot(rootOnlyCounts(), -1, 1)
	local envelopeWithoutPartsOk = ValidationContract.inspectSnapshot(envelopeWithoutParts)
	expect("snapshot validation rejects an envelope without BaseParts", envelopeWithoutPartsOk == false)

	local missingResolvedSchema = snapshot(counts(46, 0), -10, 10)
	missingResolvedSchema.resolvedRegionSchemaVersion = 0
	local missingResolvedSchemaOk = ValidationContract.inspectSnapshot(missingResolvedSchema)
	expect("snapshot validation rejects missing resolved schema identity", missingResolvedSchemaOk == false)

	local missingWorldSeedRef = snapshot(counts(46, 0), -10, 10)
	missingWorldSeedRef.worldSeedRef = ""
	local missingWorldSeedRefOk = ValidationContract.inspectSnapshot(missingWorldSeedRef)
	expect("snapshot validation rejects missing world-seed provenance", missingWorldSeedRefOk == false)

	local missingRepro = snapshot(counts(46, 0), -10, 10)
	missingRepro.resolvedRegionReproKey = ""
	local missingReproOk = ValidationContract.inspectSnapshot(missingRepro)
	expect("snapshot validation rejects missing deterministic repro identity", missingReproOk == false)

	local hostileRootReads = 0
	local hostileRoot = setmetatable({}, {
		__index = function()
			hostileRootReads += 1
			error("snapshot metatable executed")
		end,
	})
	local hostileRootCallOk, hostileRootAccepted = pcall(function()
		return ValidationContract.inspectSnapshot(hostileRoot)
	end)
	expect(
		"snapshot validation rejects top-level metatables before field access",
		hostileRootCallOk and hostileRootAccepted == false and hostileRootReads == 0
	)

	local hostileCountReads = 0
	local hostileCounts = snapshot(counts(46, 0), -10, 10)
	hostileCounts.counts = setmetatable({}, {
		__index = function()
			hostileCountReads += 1
			error("count metatable executed")
		end,
	})
	local hostileCountsCallOk, hostileCountsAccepted = pcall(function()
		return ValidationContract.inspectSnapshot(hostileCounts)
	end)
	expect(
		"snapshot validation rejects count metatables before count access",
		hostileCountsCallOk and hostileCountsAccepted == false and hostileCountReads == 0
	)

	local hostileEnvelopeReads = 0
	local hostileEnvelope = snapshot(counts(46, 0), -10, 10)
	hostileEnvelope.envelopeStuds = setmetatable({}, {
		__index = function()
			hostileEnvelopeReads += 1
			error("envelope metatable executed")
		end,
	})
	local hostileEnvelopeCallOk, hostileEnvelopeAccepted = pcall(function()
		return ValidationContract.inspectSnapshot(hostileEnvelope)
	end)
	expect(
		"snapshot validation rejects envelope metatables before vector access",
		hostileEnvelopeCallOk and hostileEnvelopeAccepted == false and hostileEnvelopeReads == 0
	)

	local hostileVectorReads = 0
	local hostileVector = snapshot(counts(46, 0), -10, 10)
	hostileVector.envelopeStuds.min = setmetatable({}, {
		__index = function()
			hostileVectorReads += 1
			error("vector metatable executed")
		end,
	})
	local hostileVectorCallOk, hostileVectorAccepted = pcall(function()
		return ValidationContract.inspectSnapshot(hostileVector)
	end)
	expect(
		"snapshot validation rejects vector metatables before axis access",
		hostileVectorCallOk and hostileVectorAccepted == false and hostileVectorReads == 0
	)

	local protectedSnapshot = snapshot(counts(46, 0), -10, 10)
	setmetatable(protectedSnapshot, { __metatable = "locked" })
	local protectedSnapshotOk = ValidationContract.inspectSnapshot(protectedSnapshot)
	expect("snapshot validation rejects protected inert metatables", protectedSnapshotOk == false)

	local differentTruth = snapshot(counts(46, 0), -10, 10)
	differentTruth.resolvedRegionFingerprint = "fingerprint:v2:different-truth"
	local crossIdentityAccepted = pcall(function()
		ValidationContract.compare(baseline, differentTruth, 0.001)
	end)
	expect("before/after comparison rejects a different resolved truth identity", not crossIdentityAccepted)

	local differentResolvedSchema = snapshot(counts(46, 0), -10, 10)
	differentResolvedSchema.resolvedRegionSchemaVersion = 3
	local crossSchemaAccepted = pcall(function()
		ValidationContract.compare(baseline, differentResolvedSchema, 0.001)
	end)
	expect("before/after comparison rejects a different resolved schema", not crossSchemaAccepted)

	local differentWorldSeedRef = snapshot(counts(46, 0), -10, 10)
	differentWorldSeedRef.worldSeedRef = "world-seed-ref:different"
	local crossSeedAccepted = pcall(function()
		ValidationContract.compare(baseline, differentWorldSeedRef, 0.001)
	end)
	expect("before/after comparison rejects different seed provenance", not crossSeedAccepted)

	local badToleranceAccepted = pcall(function()
		ValidationContract.compareFullLabEnvelope(baseline, rebuilt, -1)
	end)
	expect("negative envelope tolerance is rejected", not badToleranceAccepted)

	local falseToleranceAccepted = pcall(function()
		ValidationContract.compareFullLabEnvelope(baseline, rebuilt, false)
	end)
	expect("false envelope tolerance does not silently select the default", not falseToleranceAccepted)

	return failures
end

return run
