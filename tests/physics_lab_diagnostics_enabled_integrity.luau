local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"
local DESCENDANT_FENCE = "for _, liveInstance in ipairs(lab.model:GetDescendants()) do local isDiagnosticsOverlay = liveInstance == liveRoot or liveInstance:IsDescendantOf(liveRoot) if not isDiagnosticsOverlay then assert( liveInstance.Archivable,"

local function hasCompleteCloneProof(compactHelper: string): boolean
	local modelArchivable = string.find(compactHelper, "assert(lab.model.Archivable,", 1, true)
	local descendantFence = string.find(compactHelper, DESCENDANT_FENCE, 1, true)
	local cloneLab = string.find(compactHelper, "local cloneInstance = lab.model:Clone()", 1, true)
	return modelArchivable ~= nil
		and descendantFence ~= nil
		and cloneLab ~= nil
		and modelArchivable < descendantFence
		and descendantFence < cloneLab
end

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
	local helperSource = if helperStart ~= nil and helperEnd ~= nil
		then string.sub(source, helperStart, helperEnd - 1)
		else nil
	local compactHelper = if helperSource ~= nil then string.gsub(helperSource, "%s+", " ") else nil

	local cloneLab = compactHelper
		and string.find(compactHelper, "local cloneInstance = lab.model:Clone()", 1, true)
	local proveCloneModel = compactHelper
		and string.find(compactHelper, 'assert(cloneInstance:IsA("Model")', 1, true)
	local locateOwnedOverlay = compactHelper
		and string.find(compactHelper, "local clonedRoot = diagnosticsRoot(clone)", 1, true)
	local removeOwnedOverlay = compactHelper and string.find(compactHelper, "clonedRoot:Destroy()", 1, true)
	local canonicalCapture = compactHelper
		and string.find(compactHelper, "return Validation.captureFull(clone)", 1, true)
	local destroyClone = compactHelper and string.find(compactHelper, "clone:Destroy()", 1, true)
	local propagate = compactHelper and string.find(compactHelper, "error(result, 0)", 1, true)

	expect(
		"enabled canonical integrity is checked on a disposable clone",
		helperStart ~= nil
			and helperEnd ~= nil
			and cloneLab ~= nil
			and proveCloneModel ~= nil
			and cloneLab < proveCloneModel
	)

	-- Instance:Clone() omits non-Archivable descendants. Pin the complete helper-local
	-- proof, not merely an Archivable token plus any earlier assertion: scan every live
	-- descendant, exempt only the exact owned overlay tree, and fail closed on canonical
	-- descendants before the disposable clone is created.
	expect(
		"enabled canonical clone proves every non-overlay live descendant is Archivable before cloning",
		compactHelper ~= nil and hasCompleteCloneProof(compactHelper)
	)

	local modelOnlyMutant =
		"assert(lab.model.Archivable, \"model must be cloneable\") local cloneInstance = lab.model:Clone()"
	expect(
		"clone-completeness matcher rejects the prior model-only false-pass mutant",
		not hasCompleteCloneProof(modelOnlyMutant)
	)

	local broadOverlayMutant = string.gsub(
		DESCENDANT_FENCE,
		"liveInstance == liveRoot or liveInstance:IsDescendantOf(liveRoot)",
		"liveInstance.Name == liveRoot.Name",
		1
	)
	expect(
		"clone-completeness matcher rejects a broadened overlay exemption mutant",
		not hasCompleteCloneProof(
			"assert(lab.model.Archivable, \"model\") "
				.. broadOverlayMutant
				.. " local cloneInstance = lab.model:Clone()"
		)
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
