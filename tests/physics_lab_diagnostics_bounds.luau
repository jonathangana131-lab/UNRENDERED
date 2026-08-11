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
	local validator = position("local function requireToggleCycleCount(cycles: any): number")
	local defaultReturn = position("return DEFAULT_TOGGLE_EVIDENCE_CYCLES")
	local typeGuard = position('type(cycles) == "number"')
	local lowerBound = position("cycles >= 1")
	local upperBound = position("cycles <= MAX_TOGGLE_EVIDENCE_CYCLES")
	local integerGuard = position("cycles % 1 == 0")
	local cycleDefault = position("local cycleCount = requireToggleCycleCount(cycles)")
	local loopStart = position("for cycle = 1, cycleCount do")
	local canonicalCheckpoint = position("[20] = true")

	expect("canonical evidence default remains twenty cycles", defaultBound ~= nil)
	expect("manual evidence override is capped at the documented twenty-cycle proof", maxBound ~= nil)
	expect(
		"cycle validator handles runtime-typed input before numeric range operators",
		validator ~= nil
			and typeGuard ~= nil
			and lowerBound ~= nil
			and validator < typeGuard
			and typeGuard < lowerBound
	)
	expect(
		"nil cycle override resolves to the canonical bounded default",
		validator ~= nil and defaultReturn ~= nil and validator < defaultReturn
	)
	expect(
		"cycle range and integer guards are all present before evidence iteration",
		lowerBound ~= nil
			and upperBound ~= nil
			and integerGuard ~= nil
			and cycleDefault ~= nil
			and loopStart ~= nil
			and lowerBound < cycleDefault
			and upperBound < cycleDefault
			and integerGuard < cycleDefault
			and cycleDefault < loopStart
	)
	expect("twenty-cycle checkpoint remains part of the canonical evidence shape", canonicalCheckpoint ~= nil)

	return failures
end

return run
