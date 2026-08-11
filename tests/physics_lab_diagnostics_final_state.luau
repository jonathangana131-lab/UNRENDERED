local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-final-state {name}`)
		else
			print(`PASS diagnostics-final-state {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local sweepStart = string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local sweepEnd = sweepStart
		and string.find(source, "\nreturn table.freeze(PhysicsLabStudioDiagnostics)", sweepStart, true)
	local sweepSource = if sweepStart ~= nil and sweepEnd ~= nil
		then string.sub(source, sweepStart, sweepEnd - 1)
		else ""

	local finalSnapshot =
		string.find(sweepSource, "local finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
	local finalDisabledGuard = string.find(sweepSource, "assert(not finalSnapshot.enabled", 1, true)
	local finalStatePublish = string.find(sweepSource, "finallyEnabled = finalSnapshot.enabled", 1, true)

	expect(
		"successful toggle evidence fails closed if diagnostics were re-enabled after the final cycle",
		finalSnapshot ~= nil
			and finalDisabledGuard ~= nil
			and finalStatePublish ~= nil
			and finalSnapshot < finalDisabledGuard
			and finalDisabledGuard < finalStatePublish
	)

	return failures
end

return run
