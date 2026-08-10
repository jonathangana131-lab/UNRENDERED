local ProductionLoader = require("./support/ProductionLoader")

local ValidationContract = ProductionLoader.requireShared("Physics/PhysicsLabValidationContract")

local function snapshot(counts, minX, maxX)
	return {
		rootName = "UNRENDERED_PhysicsLab",
		labSchemaVersion = 1,
		labRecipeKey = "physics-lab.production-shell",
		worldId = "world:v1:physics-lab",
		regionId = "region:v2:physics-lab",
		resolvedRegionFingerprint = "fingerprint:v2:physics-lab",
		resolvedRegionReproKey = "world=v1|region=v2|recipe=physics-lab",
		entityCount = 2,
		representedCount = 2,
		fidelityCounts = {
			F0 = 0,
			F1 = 0,
			F2 = 2,
			F3 = 0,
			F4 = 0,
		},
		entities = {
			{ id = "entity:v1:a", fidelity = "F2", recipeKey = "lab.a" },
			{ id = "entity:v1:b", fidelity = "F2", recipeKey = "lab.b" },
		},
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
		baseline.resolvedRegionFingerprint ~= "" and baseline.resolvedRegionReproKey ~= ""
	)
	expect(
		"snapshot carries deterministic represented WorldEntity inventory",
		#baseline.entities == baseline.representedCount
			and baseline.entities[1].id == "entity:v1:a"
			and baseline.entities[2].recipeKey == "lab.b"
	)

	local comparison = ValidationContract.compare(baseline, rebuilt, 0.001)
	expect("resource delta records total Instance growth", comparison.delta.instances == 3)
	expect("resource delta records total constraint growth", comparison.delta.constraints == 3)
	expect("resource deltas are evidence and do not fail a stable envelope", comparison.envelope.ok)
	expect("unchanged represented WorldEntity inventory remains stable", comparison.entities.ok)
	expect(
		"envelope report records measured maximum drift",
		comparison.envelope.driftStuds ~= nil
			and math.abs(comparison.envelope.driftStuds.maxAbsStuds - 0.0005) < 1e-9
	)

	local swappedIdentity = snapshot(counts(46, 0), -10, 10)
	swappedIdentity.entities[2] = { id = "entity:v1:c", fidelity = "F2", recipeKey = "lab.c" }
	local swappedComparison = ValidationContract.compare(baseline, swappedIdentity, 0.001)
	expect("same resource totals and envelope do not hide a swapped WorldEntity id", not swappedComparison.entities.ok)
	expect(
		"entity inventory reports missing and unexpected ids deterministically",
		#swappedComparison.entities.missingIds == 1
			and swappedComparison.entities.missingIds[1] == "entity:v1:b"
			and #swappedComparison.entities.unexpectedIds == 1
			and swappedComparison.entities.unexpectedIds[1] == "entity:v1:c"
	)
	expect(
		"swapped entity identity can coexist with zero aggregate resource/envelope drift",
		swappedComparison.delta.instances == 0 and swappedComparison.envelope.ok
	)

	local changedFidelity = snapshot(counts(46, 0), -10, 10)
	changedFidelity.entities[2] = { id = "entity:v1:b", fidelity = "F3", recipeKey = "lab.b" }
	changedFidelity.fidelityCounts = {
		F0 = 0,
		F1 = 0,
		F2 = 1,
		F3 = 1,
		F4 = 0,
	}
	local fidelityComparison = ValidationContract.compareEntityInventory(baseline, changedFidelity)
	expect("represented WorldEntity fidelity drift is reported", not fidelityComparison.ok)
	expect(
		"fidelity drift records both entity-level and aggregate evidence",
		#fidelityComparison.mismatches == 1
			and fidelityComparison.mismatches[1].id == "entity:v1:b"
			and fidelityComparison.fidelityDelta.F2 == -1
			and fidelityComparison.fidelityDelta.F3 == 1
	)

	local partialDemotion = snapshot(counts(45, 0), -10, 10)
	partialDemotion.representedCount = 1
	partialDemotion.fidelityCounts = {
		F0 = 1,
		F1 = 0,
		F2 = 1,
		F3 = 0,
		F4 = 0,
	}
	partialDemotion.entities = {
		{ id = "entity:v1:a", fidelity = "F2", recipeKey = "lab.a" },
	}
	local partialAccepted, partialComparison = pcall(function()
		return ValidationContract.compare(baseline, partialDemotion, 0.001)
	end)
	expect("partial demotion remains measurable instead of being rejected as cross-truth", partialAccepted)
	expect(
		"partial demotion is explicitly visible in entity inventory evidence",
		partialAccepted
			and not partialComparison.entities.ok
			and partialComparison.entities.representedCountDelta == -1
			and partialComparison.entities.fidelityDelta.F0 == 1
	)

	local assertedInventory = pcall(function()
		ValidationContract.assertSameEntityInventory(baseline, swappedIdentity)
	end)
	expect("assertSameEntityInventory rejects a same-envelope identity swap", not assertedInventory)

	local expanded = snapshot(counts(46, 0), -10.01, 10)
	local expandedReport = ValidationContract.compareFullLabEnvelope(baseline, expanded, 0.001)
	expect("full-lab envelope expansion fails closed", not expandedReport.ok)
	expect("envelope violation retains an explicit reason", expandedReport.reason ~= nil)

	local collapsed = snapshot(counts(46, 0), -9.99, 10)
	local collapsedReport = ValidationContract.compareFullLabEnvelope(baseline, collapsed, 0.001)
	expect("full-lab envelope shrink also fails the rebuild checkpoint", not collapsedReport.ok)

	local missingEnvelope = snapshot(counts(1, 0), nil, nil)
	local missingReport = ValidationContract.compareFullLabEnvelope(baseline, missingEnvelope, 0.001)
	expect("missing checkpoint envelope fails closed", not missingReport.ok)

	local asserted = pcall(function()
		ValidationContract.assertFullLabEnvelope(baseline, expanded, 0.001)
	end)
	expect("assertFullLabEnvelope rejects measured envelope drift", not asserted)

	local malformed = snapshot(counts(0, 0), -10, 10)
	local malformedOk = ValidationContract.inspectSnapshot(malformed)
	expect("snapshot validation rejects a count that omits the root", malformedOk == false)

	local missingRepro = snapshot(counts(46, 0), -10, 10)
	missingRepro.resolvedRegionReproKey = ""
	local missingReproOk = ValidationContract.inspectSnapshot(missingRepro)
	expect("snapshot validation rejects missing deterministic repro identity", missingReproOk == false)

	local duplicateEntity = snapshot(counts(46, 0), -10, 10)
	duplicateEntity.entities[2].id = "entity:v1:a"
	local duplicateEntityOk = ValidationContract.inspectSnapshot(duplicateEntity)
	expect("snapshot validation rejects duplicate represented WorldEntity ids", duplicateEntityOk == false)

	local missingEntityEvidence = snapshot(counts(46, 0), -10, 10)
	missingEntityEvidence.representedCount = 1
	local missingEntityEvidenceOk = ValidationContract.inspectSnapshot(missingEntityEvidence)
	expect("snapshot validation rejects represented-count evidence gaps", missingEntityEvidenceOk == false)

	local representedF0 = snapshot(counts(46, 0), -10, 10)
	representedF0.entities[1].fidelity = "F0"
	representedF0.fidelityCounts = {
		F0 = 1,
		F1 = 0,
		F2 = 1,
		F3 = 0,
		F4 = 0,
	}
	local representedF0Ok = ValidationContract.inspectSnapshot(representedF0)
	expect("snapshot validation rejects a physical representation claiming F0", representedF0Ok == false)

	local differentTruth = snapshot(counts(46, 0), -10, 10)
	differentTruth.resolvedRegionFingerprint = "fingerprint:v2:different-truth"
	local crossIdentityAccepted = pcall(function()
		ValidationContract.compare(baseline, differentTruth, 0.001)
	end)
	expect("before/after comparison rejects a different resolved truth identity", not crossIdentityAccepted)

	local badToleranceAccepted = pcall(function()
		ValidationContract.compareFullLabEnvelope(baseline, rebuilt, -1)
	end)
	expect("negative envelope tolerance is rejected", not badToleranceAccepted)

	return failures
end

return run
