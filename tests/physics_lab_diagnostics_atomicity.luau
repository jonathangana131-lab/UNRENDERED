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
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local diagnosticsRootStart = position("local function diagnosticsRoot(model: Model): Folder?")
	local diagnosticsRootEnd = diagnosticsRootStart
			and position("\nlocal function directRepresentations", diagnosticsRootStart)
		or nil
	local diagnosticsRootSource = if diagnosticsRootStart ~= nil and diagnosticsRootEnd ~= nil
		then string.sub(source, diagnosticsRootStart, diagnosticsRootEnd - 1)
		else ""
	local diagnosticsRootEnumeration = string.find(diagnosticsRootSource, "model:GetChildren()", 1, true)
	local diagnosticsRootNameFilter = string.find(
		diagnosticsRootSource,
		"child.Name == DIAGNOSTICS_ROOT_NAME",
		1,
		true
	)
	local diagnosticsRootDuplicateGuard = string.find(
		diagnosticsRootSource,
		"duplicate Physics Lab diagnostics root",
		1,
		true
	)
	local diagnosticsRootSingleLookup = string.find(
		diagnosticsRootSource,
		"model:FindFirstChild(DIAGNOSTICS_ROOT_NAME)",
		1,
		true
	)

	local directRepresentationsStart = position(
		"local function directRepresentations(lab: PhysicsLabRealizer.RealizedLab, model: Model): { Instance }"
	)
	local directRepresentationsEnd =
		position("\nlocal function adorneeFor(representation: Instance): BasePart")
	local directRepresentationsSource = nil
	if directRepresentationsStart ~= nil and directRepresentationsEnd ~= nil then
		directRepresentationsSource =
			string.sub(source, directRepresentationsStart, directRepresentationsEnd - 1)
	end
	local representedCountMetric = directRepresentationsSource ~= nil
		and string.find(directRepresentationsSource, '"UNRENDERED_RepresentedCount"', 1, true)
	local representedCountEquality = directRepresentationsSource ~= nil
		and string.find(directRepresentationsSource, "#representations == expectedRepresentedCount", 1, true)
	local uniqueRepresentationIds = directRepresentationsSource ~= nil
		and string.find(directRepresentationsSource, "not seenEntityIds[entityId]", 1, true)
	local exactInstanceOwnership = directRepresentationsSource ~= nil
		and string.find(directRepresentationsSource, "lab.ownsRepresentation(entityId, child)", 1, true)
	local booleanOnlyMembership = directRepresentationsSource ~= nil
		and string.find(directRepresentationsSource, "lab.isRepresented(entityId)", 1, true)
	local preflightDefinition =
		position("local function preflightReadouts(lab: PhysicsLabRealizer.RealizedLab, model: Model)")
	local captureDefinition = position(
		"function PhysicsLabStudioDiagnostics.capture(lab: PhysicsLabRealizer.RealizedLab): Snapshot"
	)
	local preflightEnumeration =
		position("for _, representation in ipairs(directRepresentations(lab, model)) do")
	local captureEnumeration = nil
	if captureDefinition ~= nil then
		captureEnumeration = string.find(
			source,
			"for _, representation in ipairs(directRepresentations(lab, model)) do",
			captureDefinition,
			true
		)
	end

	local enableStart =
		position("function PhysicsLabStudioDiagnostics.enable(lab: PhysicsLabRealizer.RealizedLab): Snapshot")
	local enableEnd = enableStart and position("\nfunction PhysicsLabStudioDiagnostics.disable", enableStart)
		or nil
	local enableSource = if enableStart ~= nil and enableEnd ~= nil
		then string.sub(source, enableStart, enableEnd - 1)
		else ""
	local enablePreflight = string.find(enableSource, "local plans = preflightReadouts(lab, model)", 1, true)
	local enableTransaction =
		string.find(enableSource, "local ok, result = pcall(function(): Snapshot", 1, true)
	local enableCapture =
		string.find(enableSource, "return PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
	local yieldAfterPreflight = if enablePreflight ~= nil
		then string.find(enableSource, ":Wait(", enablePreflight, true)
		else nil
	local taskYieldAfterPreflight = if enablePreflight ~= nil
		then string.find(enableSource, "task.wait(", enablePreflight, true)
		else nil

	local disableStart = position(
		"function PhysicsLabStudioDiagnostics.disable(lab: PhysicsLabRealizer.RealizedLab): Snapshot"
	)
	local disableEnd = disableStart
			and position("\nfunction PhysicsLabStudioDiagnostics.runToggleEvidence", disableStart)
		or nil
	local disableSource = if disableStart ~= nil and disableEnd ~= nil
		then string.sub(source, disableStart, disableEnd - 1)
		else ""
	local disableOptionalGuard = string.find(disableSource, "if folder ~= nil then", 1, true)
	local disableDestroy = string.find(disableSource, "folder:Destroy()", 1, true)
	local disableCapture =
		string.find(disableSource, "local snapshot = PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
	local disablePostcondition =
		string.find(disableSource, "not snapshot.enabled and snapshot.diagnosticInstanceCount == 0", 1, true)

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
	local evidenceCheckpointsFreeze = position("\ttable.freeze(checkpoints)")
	local evidenceFinalSnapshot = position("\tlocal finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)")
	local evidenceFinalState = position("finallyEnabled = finalSnapshot.enabled")
	local evidenceFreeze = position("\ttable.freeze(evidence)")

	expect(
		"diagnostics root discovery rejects duplicate same-named roots",
		diagnosticsRootEnumeration ~= nil
			and diagnosticsRootNameFilter ~= nil
			and diagnosticsRootDuplicateGuard ~= nil
			and diagnosticsRootSingleLookup == nil
	)
	expect(
		"direct representation enumeration proves authoritative count and exact Instance ownership",
		directRepresentationsSource ~= nil
			and representedCountMetric ~= nil
			and representedCountEquality ~= nil
			and uniqueRepresentationIds ~= nil
			and exactInstanceOwnership ~= nil
			and booleanOnlyMembership == nil
	)
	expect(
		"standalone preflight and capture both consume the authoritative-set enumeration",
		preflightDefinition ~= nil
			and captureDefinition ~= nil
			and preflightEnumeration ~= nil
			and captureEnumeration ~= nil
			and preflightDefinition < preflightEnumeration
			and preflightEnumeration < captureDefinition
			and captureDefinition < captureEnumeration
	)
	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"Instance realization begins inside a protected transaction",
		transaction ~= nil and parentMutation ~= nil and transaction < parentMutation
	)
	expect(
		"authority preflight reaches protected capture without yielding",
		enablePreflight ~= nil
			and enableTransaction ~= nil
			and enableCapture ~= nil
			and enablePreflight < enableTransaction
			and enableTransaction < enableCapture
			and yieldAfterPreflight == nil
			and taskYieldAfterPreflight == nil
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
		"force-off cleanup remains idempotent and verifies the disabled baseline",
		disableOptionalGuard ~= nil
			and disableDestroy ~= nil
			and disableCapture ~= nil
			and disablePostcondition ~= nil
			and disableOptionalGuard < disableDestroy
			and disableDestroy < disableCapture
			and disableCapture < disablePostcondition
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
		"final evidence publishes diagnostics state only after the whole cycle loop",
		evidenceDisableCycle ~= nil
			and evidenceCheckpointsFreeze ~= nil
			and evidenceFinalSnapshot ~= nil
			and evidenceFinalState ~= nil
			and evidenceFreeze ~= nil
			and evidenceDisableCycle < evidenceCheckpointsFreeze
			and evidenceCheckpointsFreeze < evidenceFinalSnapshot
			and evidenceFinalSnapshot < evidenceFinalState
			and evidenceFinalState < evidenceFreeze
	)

	return failures
end

return run