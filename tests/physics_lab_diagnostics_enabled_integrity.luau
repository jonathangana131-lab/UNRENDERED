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
	-- Ignore inactive line comments, and anchor checks on semantic tokens instead
	-- of one-line function signatures so StyLua wrapping cannot change the result.
	local source = string.gsub(rawSource, "%-%-[^\n]*", "")

	local helperStart =
		string.find(source, "local function captureCanonicalWhileDiagnosticsEnabled(", 1, true)
	local helperEnd = helperStart
		and string.find(source, "function PhysicsLabStudioDiagnostics.capture(", helperStart, true)
	local archivableCheck = helperStart and string.find(source, "Archivable", helperStart, true)
	local cloneLab = helperStart
		and string.find(source, "local cloneInstance = lab.model:Clone()", helperStart, true)
	local archivableAssert = archivableCheck and string.find(source, "assert(", archivableCheck, true)
	local archivableError = archivableCheck and string.find(source, "error(", archivableCheck, true)
	local proveCloneModel = helperStart
		and string.find(source, 'assert(cloneInstance:IsA("Model")', helperStart, true)
	local locateOwnedOverlay = helperStart
		and string.find(source, "local clonedRoot = diagnosticsRoot(clone)", helperStart, true)
	local removeOwnedOverlay = helperStart and string.find(source, "clonedRoot:Destroy()", helperStart, true)
	local canonicalCapture = helperStart
		and string.find(source, "return Validation.captureFull(clone)", helperStart, true)
	local destroyClone = helperStart and string.find(source, "clone:Destroy()", helperStart, true)
	local propagate = helperStart and string.find(source, "error(result, 0)", helperStart, true)

	expect(
		"enabled canonical integrity is checked on a disposable clone",
		helperStart ~= nil
			and helperEnd ~= nil
			and cloneLab ~= nil
			and proveCloneModel ~= nil
			and helperStart < cloneLab
			and cloneLab < proveCloneModel
			and proveCloneModel < helperEnd
	)

	-- Instance:Clone() intentionally omits descendants whose Archivable property is
	-- false. The enabled-state evidence seam must therefore fail closed on that
	-- live condition (or otherwise prove clone completeness) before cloning, or an
	-- unauthorized live child can disappear before strict canonical validation.
	local failsClosedBeforeClone = cloneLab ~= nil
		and (
			(archivableAssert ~= nil and archivableAssert < cloneLab)
			or (archivableError ~= nil and archivableError < cloneLab)
		)
	expect(
		"enabled canonical clone cannot silently omit non-Archivable live truth",
		helperStart ~= nil
			and helperEnd ~= nil
			and archivableCheck ~= nil
			and cloneLab ~= nil
			and helperStart < archivableCheck
			and archivableCheck < cloneLab
			and failsClosedBeforeClone
			and cloneLab < helperEnd
	)

	expect(
		"only the exact owned diagnostics overlay is removed before strict canonical validation",
		locateOwnedOverlay ~= nil
			and removeOwnedOverlay ~= nil
			and canonicalCapture ~= nil
			and helperEnd ~= nil
			and locateOwnedOverlay < removeOwnedOverlay
			and removeOwnedOverlay < canonicalCapture
			and canonicalCapture < helperEnd
	)
	expect(
		"disposable canonical clone is destroyed before either success or propagated failure returns",
		canonicalCapture ~= nil
			and destroyClone ~= nil
			and propagate ~= nil
			and helperEnd ~= nil
			and canonicalCapture < destroyClone
			and destroyClone < propagate
			and propagate < helperEnd
	)

	local evidenceStart =
		string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local evidenceReturn = evidenceStart and string.find(source, "return evidence", evidenceStart, true)
	local enable = evidenceStart
		and string.find(
			source,
			"local enabled = PhysicsLabStudioDiagnostics.enable(lab)",
			evidenceStart,
			true
		)
	local onSnapshot = evidenceStart
		and string.find(
			source,
			"local onSnapshot = captureCanonicalWhileDiagnosticsEnabled(lab)",
			evidenceStart,
			true
		)
	local onCompare = evidenceStart
		and string.find(
			source,
			"local onComparison = Validation.compare(baseline, onSnapshot, 0.001)",
			evidenceStart,
			true
		)
	local onDelta = evidenceStart
		and string.find(source, "for countName, delta in pairs(onComparison.delta) do", evidenceStart, true)
	local onEnvelope = onDelta and string.find(source, "onComparison.envelope.ok", onDelta, true)
	local disable = evidenceStart
		and string.find(
			source,
			"local disabled = PhysicsLabStudioDiagnostics.disable(lab)",
			evidenceStart,
			true
		)

	expect(
		"each enabled evidence window validates canonical truth before diagnostics are disabled",
		evidenceStart ~= nil
			and evidenceReturn ~= nil
			and enable ~= nil
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
			and disable < evidenceReturn
	)

	return failures
end

return run
