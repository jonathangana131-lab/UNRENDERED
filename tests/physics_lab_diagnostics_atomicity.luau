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
	local function occurrences(needle: string): number
		local count = 0
		local cursor = 1
		while true do
			local found = string.find(source, needle, cursor, true)
			if found == nil then
				break
			end
			count += 1
			cursor = found + #needle
		end
		return count
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
	local representationRevision = position("representationRevision = record.representationRevision")
	local stateRevision = position("stateRevision = record.stateRevision")
	local visualRevisionReadout = position("reprRev=%d | stateRev=%d")
	local revisionReader = position("local function requireRevisionAttribute")
	local representationRevisionAttribute =
		position('representationRevision = requireRevisionAttribute(representation, "UNRENDERED_RepresentationRevision")')
	local stateRevisionAttribute =
		position('stateRevision = requireRevisionAttribute(representation, "UNRENDERED_StateRevision")')
	local representationRevisionAgreement =
		position("record.representationRevision == represented.representationRevision")
	local stateRevisionAgreement = position("record.stateRevision == represented.stateRevision")
	local capture = position("return PhysicsLabStudioDiagnostics.capture(lab)")
	local transactionEnd = position("\tend)\n\n\tif not ok then")
	local rollback = position("folder:Destroy()")
	local propagate = position("error(result, 0)")
	local toggleEvidence = position("function PhysicsLabStudioDiagnostics.runToggleEvidence(")
	local toggleInitial = position("local initial = PhysicsLabStudioDiagnostics.capture(lab)")
	local toggleDefaultOff = position("not initial.enabled and initial.diagnosticInstanceCount == 0")
	local toggleBaseline = position("local baseline = Validation.captureFull(lab.model)")
	local firstToggleDisable = position("local disabled = PhysicsLabStudioDiagnostics.disable(lab)")
	local legacyDefaultOffNormalizer = position("PhysicsLabStudioDiagnostics.disable(lab)\n\tlocal baseline")
	local toggleFinalSnapshot = position("local finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)")
	local toggleFinalOff =
		position("not finalSnapshot.enabled and finalSnapshot.diagnosticInstanceCount == 0")
	local toggleFinalPublication = position("finallyEnabled = finalSnapshot.enabled")

	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"authoritative revisions are preflighted before the owned root is parented",
		representationRevision ~= nil
			and stateRevision ~= nil
			and parentMutation ~= nil
			and representationRevision < parentMutation
			and stateRevision < parentMutation
	)
	expect("live readouts expose both authoritative revision counters", visualRevisionReadout ~= nil)
	expect(
		"realized revision attributes are required before diagnostics mutation",
		revisionReader ~= nil
			and representationRevisionAttribute ~= nil
			and stateRevisionAttribute ~= nil
			and parentMutation ~= nil
			and revisionReader < representationRevisionAttribute
			and representationRevisionAttribute < parentMutation
			and stateRevisionAttribute < parentMutation
	)
	expect(
		"revision attributes must be finite nonnegative integers",
		position("and value >= 0") ~= nil
			and position("and value < math.huge") ~= nil
			and position("and value % 1 == 0") ~= nil
	)
	expect(
		"preflight rejects stale realized revision metadata before mutation",
		representationRevisionAgreement ~= nil
			and stateRevisionAgreement ~= nil
			and parentMutation ~= nil
			and representationRevisionAgreement < parentMutation
			and stateRevisionAgreement < parentMutation
	)
	expect(
		"capture and preflight both require exact realized-to-authoritative revisions",
		occurrences("record.representationRevision == represented.representationRevision") == 2
			and occurrences("record.stateRevision == represented.stateRevision") == 2
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
		"toggle evidence observes and rejects a default-on state before baseline or cleanup",
		toggleEvidence ~= nil
			and toggleInitial ~= nil
			and toggleDefaultOff ~= nil
			and toggleBaseline ~= nil
			and firstToggleDisable ~= nil
			and toggleEvidence < toggleInitial
			and toggleInitial < toggleDefaultOff
			and toggleDefaultOff < toggleBaseline
			and toggleBaseline < firstToggleDisable
			and legacyDefaultOffNormalizer == nil
	)
	expect(
		"toggle evidence rejects a final diagnostics-on state before publishing success",
		toggleFinalSnapshot ~= nil
			and toggleFinalOff ~= nil
			and toggleFinalPublication ~= nil
			and toggleFinalSnapshot < toggleFinalOff
			and toggleFinalOff < toggleFinalPublication
	)

	return failures
end

return run
