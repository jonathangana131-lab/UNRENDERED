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
	-- enabled-window assertion must be protected so the owned diagnostics overlay
	-- is disabled before the original validation failure is propagated.
	local cycleProtection = string.find(sweepSource, "local cycleOk, cycleResult = pcall(function()", 1, true)
	local enabled =
		string.find(sweepSource, "local enabled = PhysicsLabStudioDiagnostics.enable(lab)", 1, true)
	local cleanup =
		string.find(sweepSource, "local disabled = PhysicsLabStudioDiagnostics.disable(lab)", 1, true)
	local protectionClose = cycleProtection
		and string.find(
			sweepSource,
			"\n\t\tend)\n\n\t\tlocal disabled = PhysicsLabStudioDiagnostics.disable(lab)",
			cycleProtection,
			true
		)
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
	local failureGuard = cleanup and string.find(sweepSource, "if not cycleOk then", cleanup, true)
	local propagate = failureGuard and string.find(sweepSource, "error(cycleResult, 0)", failureGuard, true)
	local disabledAssertion = cleanup
		and string.find(sweepSource, "assert(not disabled.enabled", cleanup, true)
	local offCapture = cleanup
		and string.find(sweepSource, "Validation.captureFull(lab.model)", cleanup, true)

	expect(
		"failed enabled-window validation disables diagnostics before propagating the original failure",
		cycleProtection ~= nil
			and enabled ~= nil
			and cleanup ~= nil
			and failureGuard ~= nil
			and propagate ~= nil
			and enabled < cycleProtection
			and cycleProtection < cleanup
			and cleanup < failureGuard
			and failureGuard < propagate
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
			and protectionClose < cleanup
	)

	expect(
		"successful cleanup cannot mask the original enabled-window failure with normal-path checks",
		propagate ~= nil
			and disabledAssertion ~= nil
			and offCapture ~= nil
			and propagate < disabledAssertion
			and propagate < offCapture
	)

	return failures
end

return run
