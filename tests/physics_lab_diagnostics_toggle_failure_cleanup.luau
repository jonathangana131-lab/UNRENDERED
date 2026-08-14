local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-toggle-failure-cleanup {name}`)
		else
			print(`PASS diagnostics-toggle-failure-cleanup {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local sweepStart = string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local sweepEnd = sweepStart
		and string.find(source, "\nreturn table.freeze(PhysicsLabStudioDiagnostics)", sweepStart, true)
	local sweepSource = if sweepStart ~= nil and sweepEnd ~= nil
		then string.sub(source, sweepStart, sweepEnd - 1)
		else ""

	-- enable() is already failure-atomic. Once it succeeds, however, every later
	-- enabled-window assertion must be protected so the exact owned diagnostics
	-- overlay can be destroyed before the original validation failure propagates.
	local cycleProtection = string.find(sweepSource, "local cycleOk, cycleResult = pcall(function()", 1, true)
	local enabled =
		string.find(sweepSource, "local enabled = PhysicsLabStudioDiagnostics.enable(lab)", 1, true)
	local ownedRootStart, _, ownedRootName = string.find(
		sweepSource,
		"local%s+([%a_][%w_]*)%s*=%s*diagnosticsRoot%(%s*lab%.model%s*%)"
	)
	local strictCleanup =
		string.find(sweepSource, "local disabled = PhysicsLabStudioDiagnostics.disable(lab)", 1, true)
	local protectionClose = cycleProtection
		and string.find(sweepSource, "\n\t\tend)", cycleProtection, true)
	local enabledCountAssertion = cycleProtection
		and string.find(sweepSource, "enabled.diagnosticInstanceCount > 0", cycleProtection, true)
	local canonicalCapture = cycleProtection
		and string.find(sweepSource, "captureCanonicalWhileDiagnosticsEnabled(lab)", cycleProtection, true)
	local enabledComparison = cycleProtection
		and string.find(sweepSource, "Validation.compare(baseline, onSnapshot, 0.001)", cycleProtection, true)
	local resourceDriftAssertion = cycleProtection
		and string.find(sweepSource, "diagnostics-on canonical resource drift", cycleProtection, true)
	local envelopeDriftAssertion = cycleProtection
		and string.find(sweepSource, "diagnostics-on canonical envelope drifted", cycleProtection, true)
	local failureGuard = protectionClose and string.find(sweepSource, "if not cycleOk then", protectionClose, true)
	local propagate = failureGuard and string.find(sweepSource, "error(cycleResult, 0)", failureGuard, true)
	local directOwnedDestroy = nil
	if failureGuard ~= nil and ownedRootName ~= nil then
		directOwnedDestroy = string.find(sweepSource, ownedRootName .. ":Destroy()", failureGuard, true)
	end
	local disabledAssertion = strictCleanup
		and string.find(sweepSource, "assert(not disabled.enabled", strictCleanup, true)
	local offCapture = strictCleanup
		and string.find(sweepSource, "Validation.captureFull(lab.model)", strictCleanup, true)
	local failurePath = if failureGuard ~= nil and propagate ~= nil
		then string.sub(sweepSource, failureGuard, propagate)
		else ""
	local failurePathRediscovery = string.find(failurePath, "diagnosticsRoot(lab.model)", 1, true)
	local failurePathCapture = string.find(failurePath, "PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
		or string.find(failurePath, "Validation.captureFull(lab.model)", 1, true)

	expect(
		"successful enable pins the exact owned diagnostics root before fallible enabled-window validation",
		enabled ~= nil
			and ownedRootStart ~= nil
			and cycleProtection ~= nil
			and enabled < ownedRootStart
			and ownedRootStart < cycleProtection
	)

	expect(
		"failed enabled-window validation destroys the pinned owned root before propagating the original failure",
		failureGuard ~= nil
			and directOwnedDestroy ~= nil
			and propagate ~= nil
			and failureGuard < directOwnedDestroy
			and directOwnedDestroy < propagate
	)

	expect(
		"failure cleanup cannot rediscover or strictly recapture canonical state before original error propagation",
		failureGuard ~= nil
			and propagate ~= nil
			and failurePathRediscovery == nil
			and failurePathCapture == nil
	)

	expect(
		"strict disable and off-state validation are success-path work after the failure precedence guard",
		propagate ~= nil
			and strictCleanup ~= nil
			and disabledAssertion ~= nil
			and offCapture ~= nil
			and propagate < strictCleanup
			and strictCleanup < disabledAssertion
			and strictCleanup < offCapture
	)

	expect(
		"the complete enabled canonical validation window is cleanup-protected",
		cycleProtection ~= nil
			and protectionClose ~= nil
			and enabledCountAssertion ~= nil
			and canonicalCapture ~= nil
			and enabledComparison ~= nil
			and resourceDriftAssertion ~= nil
			and envelopeDriftAssertion ~= nil
			and cycleProtection < enabledCountAssertion
			and enabledCountAssertion < protectionClose
			and cycleProtection < canonicalCapture
			and canonicalCapture < protectionClose
			and cycleProtection < enabledComparison
			and enabledComparison < protectionClose
			and cycleProtection < resourceDriftAssertion
			and resourceDriftAssertion < protectionClose
			and cycleProtection < envelopeDriftAssertion
			and envelopeDriftAssertion < protectionClose
	)

	return failures
end

return run
