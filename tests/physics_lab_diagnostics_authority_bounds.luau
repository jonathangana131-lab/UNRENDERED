local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"
local REALIZER_SOURCE = "src/server/PhysicsLab/PhysicsLabRealizer.luau"

local function normalizeWhitespace(value: string): string
	local normalized = string.gsub(value, "%s+", " ")
	normalized = string.gsub(normalized, "^ ", "")
	return string.gsub(normalized, " $", "")
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-authority-bounds {name}`)
		else
			print(`PASS diagnostics-authority-bounds {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local enumeration = position(
		"local function directRepresentations(lab: PhysicsLabRealizer.RealizedLab, model: Model): { Instance }"
	)
	local ownershipGuard = position("lab.ownsRepresentation(entityId, child)", enumeration)
	local weakMembershipGuard = position("lab.isRepresented(entityId)", enumeration)
	local representedCount = position(
		'requireNonNegativeIntegerAttribute(model, "UNRENDERED_RepresentedCount")',
		enumeration
	)
	local preflight = position("local function preflightReadouts")
	local preflightEnumeration = position("directRepresentations(lab, model)", preflight)
	local capture = position("function PhysicsLabStudioDiagnostics.capture")
	local captureEnumeration = position("directRepresentations(lab, model)", capture)

	expect(
		"representation enumeration binds each child to the exact runtime-owned Instance",
		enumeration ~= nil
			and ownershipGuard ~= nil
			and weakMembershipGuard == nil
			and representedCount ~= nil
			and enumeration < ownershipGuard
			and ownershipGuard < representedCount
	)
	expect(
		"preflight and capture both use the exact-ownership enumeration",
		preflight ~= nil
			and preflightEnumeration ~= nil
			and capture ~= nil
			and captureEnumeration ~= nil
			and preflight < preflightEnumeration
			and preflightEnumeration < capture
			and capture < captureEnumeration
	)

	local realizerSource = fs.readFile(REALIZER_SOURCE)
	local ownsType = string.find(
		realizerSource,
		"ownsRepresentation: (entityId: string, candidate: Instance) -> boolean",
		1,
		true
	)
	local ownsStart = string.find(
		realizerSource,
		"local function ownsRepresentation(entityId: string, candidate: Instance): boolean",
		1,
		true
	)
	local ownsEnd = ownsStart and string.find(realizerSource, "\n\tlocal function captureState", ownsStart, true) or nil
	local ownsSource = if ownsStart ~= nil and ownsEnd ~= nil
		then string.sub(realizerSource, ownsStart, ownsEnd - 1)
		else ""
	local expectedOwnsSource = normalizeWhitespace([[
		local function ownsRepresentation(entityId: string, candidate: Instance): boolean
			assert(not destroyed, "Physics Lab has been destroyed")
			if not isRepresented(entityId) then
				return false
			end

			local representation = representations[entityId]
			return representation == candidate and candidate.Parent == model
		end
	]])
	local returnStart = string.find(realizerSource, "\treturn table.freeze({\n\t\tmodel = model,", 1, true)
	local returnEnd = returnStart and string.find(realizerSource, "\n\t})\nend", returnStart, true) or nil
	local publicHandle = if returnStart ~= nil and returnEnd ~= nil
		then string.sub(realizerSource, returnStart, returnEnd)
		else ""

	expect("RealizedLab exposes exact candidate ownership predicate", ownsType ~= nil and ownsStart ~= nil)
	expect(
		"ownership predicate preserves fail-closed exact Instance semantics",
		normalizeWhitespace(ownsSource) == expectedOwnsSource
	)
	expect(
		"public handle exposes ownership predicate without exposing the private map",
		publicHandle:find("ownsRepresentation = ownsRepresentation", 1, true) ~= nil
			and publicHandle:find("representations = representations", 1, true) == nil
	)

	local defaultBound = position("local DEFAULT_TOGGLE_EVIDENCE_CYCLES = 20")
	local maxBound = position("local MAX_TOGGLE_EVIDENCE_CYCLES = 20")
	local validator = position("local function requireToggleCycleCount(cycles: any): number")
	local exactNilDefault = position("\tif cycles == nil then", validator)
	local defaultReturn = position("return DEFAULT_TOGGLE_EVIDENCE_CYCLES", validator)
	local typeGuard = position('type(cycles) == "number"', validator)
	local nanGuard = position("cycles == cycles", validator)
	local lowerBound = position("cycles >= 1", validator)
	local upperBound = position("cycles <= MAX_TOGGLE_EVIDENCE_CYCLES", validator)
	local integerGuard = position("cycles % 1 == 0", validator)
	local truthinessDefault = position("cycles or DEFAULT_TOGGLE_EVIDENCE_CYCLES")
	local cycleCount = position("local cycleCount = requireToggleCycleCount(cycles)")
	local loopStart = position("for cycle = 1, cycleCount do")

	expect("canonical diagnostics evidence default remains twenty cycles", defaultBound ~= nil)
	expect("diagnostics evidence overrides are capped at twenty cycles", maxBound ~= nil)
	expect(
		"only exact nil selects the canonical cycle default",
		validator ~= nil
			and exactNilDefault ~= nil
			and defaultReturn ~= nil
			and typeGuard ~= nil
			and validator < exactNilDefault
			and exactNilDefault < defaultReturn
			and defaultReturn < typeGuard
			and truthinessDefault == nil
	)
	expect(
		"runtime cycle input is type checked before numeric guards",
		typeGuard ~= nil
			and nanGuard ~= nil
			and lowerBound ~= nil
			and upperBound ~= nil
			and integerGuard ~= nil
			and typeGuard < nanGuard
			and typeGuard < lowerBound
			and typeGuard < upperBound
			and typeGuard < integerGuard
	)
	expect(
		"all cycle guards run before any evidence iteration",
		nanGuard ~= nil
			and lowerBound ~= nil
			and upperBound ~= nil
			and integerGuard ~= nil
			and cycleCount ~= nil
			and loopStart ~= nil
			and nanGuard < cycleCount
			and lowerBound < cycleCount
			and upperBound < cycleCount
			and integerGuard < cycleCount
			and cycleCount < loopStart
	)

	return failures
end

return run