local fs = require("@lune/fs")

local REALIZER_SOURCE = "src/server/PhysicsLab/PhysicsLabRealizer.luau"
local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL physics-lab-representation-ownership {name}`)
		else
			print(`PASS physics-lab-representation-ownership {name}`)
		end
	end

	local realizer = fs.readFile(REALIZER_SOURCE)
	local diagnostics = fs.readFile(DIAGNOSTICS_SOURCE)

	local ownsType =
		realizer:find("ownsRepresentation: (entityId: string, candidate: Instance) -> boolean", 1, true)
	local ownsStart = realizer:find(
		"local function ownsRepresentation(entityId: string, candidate: Instance): boolean",
		1,
		true
	)
	local ownsEnd = ownsStart and realizer:find("\n\tlocal function captureState", ownsStart, true) or nil
	local ownsSource = if ownsStart ~= nil and ownsEnd ~= nil
		then realizer:sub(ownsStart, ownsEnd - 1)
		else ""

	expect("RealizedLab exposes exact candidate ownership predicate", ownsType ~= nil and ownsStart ~= nil)
	expect(
		"ownership predicate preserves fidelity authority before exact Instance comparison",
		ownsSource:find("if not isRepresented(entityId) then", 1, true) ~= nil
			and ownsSource:find("local representation = representations[entityId]", 1, true) ~= nil
			and ownsSource:find("representation == candidate and candidate.Parent == model", 1, true)
				~= nil
	)
	expect(
		"public handle exposes predicate without exposing private representation map",
		realizer:find("ownsRepresentation = ownsRepresentation", 1, true) ~= nil
			and realizer:find("representations = representations", 1, true) == nil
	)

	local enumerationStart = diagnostics:find(
		"local function directRepresentations(lab: PhysicsLabRealizer.RealizedLab, model: Model): { Instance }",
		1,
		true
	)
	local enumerationEnd = enumerationStart
			and diagnostics:find(
				"\nlocal function adorneeFor(representation: Instance): BasePart",
				enumerationStart,
				true
			)
		or nil
	local enumerationSource = if enumerationStart ~= nil and enumerationEnd ~= nil
		then diagnostics:sub(enumerationStart, enumerationEnd - 1)
		else ""

	expect(
		"diagnostics enumeration proves unique exact runtime-owned representations",
		enumerationSource:find("seenEntityIds[entityId] ~= true", 1, true) ~= nil
			and enumerationSource:find("lab.ownsRepresentation(entityId, child)", 1, true) ~= nil
			and enumerationSource:find("#representations == representedCount", 1, true) ~= nil
	)
	expect(
		"preflight and machine-readable capture both consume ownership-checked enumeration",
		select(2, diagnostics:gsub("directRepresentations%(lab, model%)", "")) == 2
	)

	return failures
end

return run
