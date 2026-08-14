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
	local failureGuard = cleanup and string.find(sweepSource, "if not cycleOk then", cleanup, true)
	local propagate = failureGuard and string.find(sweepSource, "error(cycleResult, 0)", failureGuard, true)

	expect(
		"failed enabled-window validation disables diagnostics before propagating the original failure",
		cycleProtection ~= nil
			and enabled ~= nil
			and cleanup ~= nil
			and failureGuard ~= nil
			and propagate ~= nil
			and enabled < cleanup
			and cycleProtection < cleanup
			and cleanup < failureGuard
			and failureGuard < propagate
	)

	return failures
end

return run
