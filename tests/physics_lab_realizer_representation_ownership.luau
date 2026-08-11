local fs = require("@lune/fs")

local REALIZER_SOURCE = "src/server/PhysicsLab/PhysicsLabRealizer.luau"

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

	local source = fs.readFile(REALIZER_SOURCE)
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local ownsType = position("ownsRepresentation: (entityId: string, candidate: Instance) -> boolean")
	local ownsStart =
		position("local function ownsRepresentation(entityId: string, candidate: Instance): boolean")
	local ownsEnd = ownsStart and position("\n\tlocal function captureState", ownsStart) or nil
	local ownsSource = if ownsStart ~= nil and ownsEnd ~= nil
		then string.sub(source, ownsStart, ownsEnd - 1)
		else ""
	local returnStart = position("\treturn table.freeze({\n\t\tmodel = model,")
	local returnEnd = returnStart and position("\n\t})\nend", returnStart) or nil
	local publicHandle = if returnStart ~= nil and returnEnd ~= nil
		then string.sub(source, returnStart, returnEnd)
		else ""

	expect("RealizedLab exposes exact candidate ownership predicate", ownsType ~= nil and ownsStart ~= nil)
	expect(
		"ownership predicate preserves authoritative represented-state validation",
		position("if not isRepresented(entityId) then", ownsStart) ~= nil
			and ownsSource:find('assert(not destroyed, "Physics Lab has been destroyed")', 1, true) ~= nil
	)
	expect(
		"ownership predicate binds candidate by exact Instance identity",
		ownsSource:find("local representation = representations[entityId]", 1, true) ~= nil
			and ownsSource:find("representation == candidate", 1, true) ~= nil
	)
	expect(
		"ownership predicate rejects stale or reparented physical views",
		ownsSource:find("candidate.Parent == model", 1, true) ~= nil
	)
	expect(
		"public handle exposes predicate without exposing private representation map",
		publicHandle:find("ownsRepresentation = ownsRepresentation", 1, true) ~= nil
			and publicHandle:find("representations = representations", 1, true) == nil
	)

	return failures
end

return run
