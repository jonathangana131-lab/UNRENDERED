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

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local sweepStart = string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local sweepEnd = sweepStart
		and string.find(source, "\nreturn table.freeze(PhysicsLabStudioDiagnostics)", sweepStart, true)
	local sweepSource = if sweepStart ~= nil and sweepEnd ~= nil
		then string.sub(source, sweepStart, sweepEnd - 1)
		else ""

	local enabledSnapshot = string.find(
		sweepSource,
		"local enabled = PhysicsLabStudioDiagnostics.enable(lab)",
		1,
		true
	)
	local disabledSnapshot = enabledSnapshot
		and string.find(
			sweepSource,
			"local disabled = PhysicsLabStudioDiagnostics.disable(lab)",
			enabledSnapshot,
			true
		)
	local enabledCanonicalValidation = enabledSnapshot
		and disabledSnapshot
		and string.find(sweepSource, "Validation.captureFull(lab.model)", enabledSnapshot, true)

	expect(
		"every enabled diagnostics cycle validates canonical world integrity before diagnostics are disabled",
		enabledSnapshot ~= nil
			and disabledSnapshot ~= nil
			and enabledCanonicalValidation ~= nil
			and enabledSnapshot < enabledCanonicalValidation
			and enabledCanonicalValidation < disabledSnapshot
	)

	return failures
end

return run
