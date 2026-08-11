local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-enabled-integrity {name}`)
		else
			print(`PASS diagnostics-enabled-integrity {name}`)
		end
	end

	local rawSource = fs.readFile(DIAGNOSTICS_SOURCE)
	local source = string.gsub(rawSource, "%-%-[^\n]*", "")

	local helperStart = string.find(
		source,
		"local function captureCanonicalWhileDiagnosticsEnabled(lab: PhysicsLabRealizer.RealizedLab): Validation.Snapshot",
		1,
		true
	)
	local helperEnd = helperStart
		and string.find(source, "\nfunction PhysicsLabStudioDiagnostics.capture", helperStart, true)
	local helperSource = if helperStart ~= nil and helperEnd ~= nil
		then string.sub(source, helperStart, helperEnd - 1)
		else ""

	local cloneLab = string.find(helperSource, "local cloneInstance = lab.model:Clone()", 1, true)
	local proveCloneModel = string.find(helperSource, 'assert(cloneInstance:IsA("Model")', 1, true)
	local locateOwnedOverlay = string.find(helperSource, "local clonedRoot = diagnosticsRoot(clone)", 1, true)
	local removeOwnedOverlay = string.find(helperSource, "clonedRoot:Destroy()", 1, true)
	local canonicalCapture = string.find(helperSource, "return Validation.captureFull(clone)", 1, true)
	local destroyClone = string.find(helperSource, "clone:Destroy()", 1, true)
	local propagate = string.find(helperSource, "error(result, 0)", 1, true)

	expect(
		"enabled canonical integrity is checked on a disposable clone",
		cloneLab ~= nil and proveCloneModel ~= nil and cloneLab < proveCloneModel
	)
	expect(
		"only the exact owned diagnostics overlay is removed before strict canonical validation",
		locateOwnedOverlay ~= nil
			and removeOwnedOverlay ~= nil
			and canonicalCapture ~= nil
			and locateOwnedOverlay < removeOwnedOverlay
			and removeOwnedOverlay < canonicalCapture
	)
	expect(
		"disposable canonical clone is destroyed before either success or propagated failure returns",
		canonicalCapture ~= nil
			and destroyClone ~= nil
			and propagate ~= nil
			and canonicalCapture < destroyClone
			and destroyClone < propagate
	)

	local evidenceStart =
		string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local evidenceEnd = evidenceStart and string.find(source, "\nreturn table.freeze", evidenceStart, true)
	local evidenceSource = if evidenceStart ~= nil and evidenceEnd ~= nil
		then string.sub(source, evidenceStart, evidenceEnd - 1)
		else ""

	local enable =
		string.find(evidenceSource, "local enabled = PhysicsLabStudioDiagnostics.enable(lab)", 1, true)
	local onSnapshot = string.find(
		evidenceSource,
		"local onSnapshot = captureCanonicalWhileDiagnosticsEnabled(lab)",
		1,
		true
	)
	local onCompare = string.find(
		evidenceSource,
		"local onComparison = Validation.compare(baseline, onSnapshot, 0.001)",
		1,
		true
	)
	local onDelta =
		string.find(evidenceSource, "for countName, delta in pairs(onComparison.delta) do", 1, true)
	local onEnvelope = string.find(evidenceSource, "assert(onComparison.envelope.ok", 1, true)
	local disable =
		string.find(evidenceSource, "local disabled = PhysicsLabStudioDiagnostics.disable(lab)", 1, true)
	local directLiveCapture = nil
	if enable ~= nil and disable ~= nil and enable < disable then
		directLiveCapture = string.find(
			string.sub(evidenceSource, enable, disable - 1),
			"Validation.captureFull(lab.model)",
			1,
			true
		)
	end

	expect(
		"each enabled evidence window validates canonical truth before diagnostics are disabled",
		enable ~= nil
			and onSnapshot ~= nil
			and onCompare ~= nil
			and onDelta ~= nil
			and onEnvelope ~= nil
			and disable ~= nil
			and enable < onSnapshot
			and onSnapshot < onCompare
			and onCompare < onDelta
			and onDelta < onEnvelope
			and onEnvelope < disable
	)
	expect(
		"enabled evidence never asks the strict validator to bless the live overlay as canonical state",
		directLiveCapture == nil
	)

	return failures
end

return run
