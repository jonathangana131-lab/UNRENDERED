local fs = require("@lune/fs")

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
	local returnStart = position("\treturn table.freeze({\n\t\tmodel = model,")
	local returnEnd = returnStart and position("\n\t})\nend", returnStart) or nil
	local publicHandle = if returnStart ~= nil and returnEnd ~= nil
		then string.sub(source, returnStart, returnEnd)
		else ""

	expect("RealizedLab exposes exact candidate ownership predicate", ownsType ~= nil and ownsStart ~= nil)
	expect(
		"ownership predicate locks authoritative fail-closed exact Instance semantics",
		normalizeWhitespace(ownsSource) == expectedOwnsSource
	)
	expect(
		"public handle exposes predicate without exposing private representation map",
		publicHandle:find("ownsRepresentation = ownsRepresentation", 1, true) ~= nil
			and publicHandle:find("representations = representations", 1, true) == nil
	)

	return failures
end

return run
