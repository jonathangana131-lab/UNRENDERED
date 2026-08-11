local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-bounds {name}`)
		else
			print(`PASS diagnostics-bounds {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local defaultBound = position("local DEFAULT_TOGGLE_EVIDENCE_CYCLES = 20")
	local maxBound = position("local MAX_TOGGLE_EVIDENCE_CYCLES = 20")
	local cycleDefault = position("local cycleCount = cycles or DEFAULT_TOGGLE_EVIDENCE_CYCLES")
	local upperBound = position("cycleCount <= MAX_TOGGLE_EVIDENCE_CYCLES")
	local loopStart = position("for cycle = 1, cycleCount do")
	local canonicalCheckpoint = position("[20] = true")

	expect("canonical evidence default remains twenty cycles", defaultBound ~= nil)
	expect("manual evidence override is capped at the documented twenty-cycle proof", maxBound ~= nil)
	expect(
		"default cycle count uses the named bounded contract",
		cycleDefault ~= nil and defaultBound ~= nil and defaultBound < cycleDefault
	)
	expect(
		"cycle upper bound is validated before any evidence iteration",
		upperBound ~= nil and loopStart ~= nil and upperBound < loopStart
	)
	expect("twenty-cycle checkpoint remains part of the canonical evidence shape", canonicalCheckpoint ~= nil)

	return failures
end

return run
