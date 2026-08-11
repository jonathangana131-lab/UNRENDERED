local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-atomicity {name}`)
		else
			print(`PASS diagnostics-atomicity {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local preflight = position("local plans = preflightReadouts(lab, model)")
	local transaction = position("local ok, result = pcall(function(): Snapshot")
	local rootName = position("folder.Name = DIAGNOSTICS_ROOT_NAME")
	local rootOwnership = position('folder:SetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned", true)')
	local parentMutation = position("folder.Parent = model")
	local billboardOwnership = position("billboard.Parent = folder")
	local billboardConfiguration = position("billboard.AlwaysOnTop = true")
	local labelOwnership = position("label.Parent = billboard")
	local labelConfiguration = position("label.BackgroundTransparency = 0.2")
	local capture = position("return PhysicsLabStudioDiagnostics.capture(lab)")
	local transactionEnd = position("\tend)\n\n\tif not ok then")
	local rollback = position("folder:Destroy()")
	local propagate = position("error(result, 0)")
	local evidenceDisable = position("\tPhysicsLabStudioDiagnostics.disable(lab)")
	local evidenceBaseline = position("\tlocal baseline = Validation.captureFull(lab.model)")
	local evidenceInitial = position("\tlocal initial = PhysicsLabStudioDiagnostics.capture(lab)")
	local evidenceEnable = position("\t\tlocal enabled = PhysicsLabStudioDiagnostics.enable(lab)")
	local evidenceDisableCycle = position("\t\tlocal disabled = PhysicsLabStudioDiagnostics.disable(lab)")
	local evidenceOffSnapshot = position("\t\tlocal offSnapshot = Validation.captureFull(lab.model)")
	local evidenceComparison = position("Validation.compare(baseline, offSnapshot, 0.001)")
	local evidenceDeltaCheck = position("for countName, delta in pairs(comparison.delta) do")
	local evidenceEnvelopeCheck = position("assert(comparison.envelope.ok")
	local evidenceFinalSnapshot = position("\tlocal finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)")
	local evidenceFinalState = position("finallyEnabled = finalSnapshot.enabled")
	local evidenceFreeze = position("\ttable.freeze(evidence)")

	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"Instance realization begins inside a protected transaction",
		transaction ~= nil and parentMutation ~= nil and transaction < parentMutation
	)
	expect(
		"diagnostics root identity is established inside the transaction before parenting",
		transaction ~= nil
			and rootName ~= nil
			and rootOwnership ~= nil
			and parentMutation ~= nil
			and transaction < rootName
			and rootName < rootOwnership
			and rootOwnership < parentMutation
	)
	expect(
		"BillboardGui is owned before fallible configuration",
		billboardOwnership ~= nil
			and billboardConfiguration ~= nil
			and billboardOwnership < billboardConfiguration
	)
	expect(
		"TextLabel is owned before fallible configuration",
		labelOwnership ~= nil and labelConfiguration ~= nil and labelOwnership < labelConfiguration
	)
	expect(
		"post-realization capture remains inside the protected transaction",
		capture ~= nil
			and transaction ~= nil
			and transactionEnd ~= nil
			and transaction < capture
			and capture < transactionEnd
	)
	expect(
		"failed realization destroys the owned diagnostics tree before propagating",
		rollback ~= nil
			and propagate ~= nil
			and transactionEnd ~= nil
			and transactionEnd < rollback
			and rollback < propagate
	)
	expect(
		"toggle evidence establishes its baseline only after forcing diagnostics off",
		evidenceDisable ~= nil
			and evidenceBaseline ~= nil
			and evidenceInitial ~= nil
			and evidenceDisable < evidenceBaseline
			and evidenceBaseline < evidenceInitial
	)
	expect(
		"each evidence cycle disables diagnostics before the comparable off snapshot",
		evidenceEnable ~= nil
			and evidenceDisableCycle ~= nil
			and evidenceOffSnapshot ~= nil
			and evidenceEnable < evidenceDisableCycle
			and evidenceDisableCycle < evidenceOffSnapshot
	)
	expect(
		"resource and envelope no-drift checks are derived from the off snapshot",
		evidenceOffSnapshot ~= nil
			and evidenceComparison ~= nil
			and evidenceDeltaCheck ~= nil
			and evidenceEnvelopeCheck ~= nil
			and evidenceOffSnapshot < evidenceComparison
			and evidenceComparison < evidenceDeltaCheck
			and evidenceDeltaCheck < evidenceEnvelopeCheck
	)
	expect(
		"final evidence publishes diagnostics state only after the cycle cleanup path",
		evidenceDisableCycle ~= nil
			and evidenceFinalSnapshot ~= nil
			and evidenceFinalState ~= nil
			and evidenceFreeze ~= nil
			and evidenceDisableCycle < evidenceFinalSnapshot
			and evidenceFinalSnapshot < evidenceFinalState
			and evidenceFinalState < evidenceFreeze
	)

	return failures
end

return run
