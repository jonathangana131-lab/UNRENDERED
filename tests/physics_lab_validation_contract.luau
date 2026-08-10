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

	local badToleranceAccepted = pcall(function()
		ValidationContract.compareFullLabEnvelope(baseline, rebuilt, -1)
	end)
	expect("negative envelope tolerance is rejected", not badToleranceAccepted)

	return failures
end

return run
