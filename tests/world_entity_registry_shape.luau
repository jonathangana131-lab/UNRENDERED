local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function makeRecord()
	return {
		id = "entity:registry-shape",
		kind = "office-chair",
		origin = {
			worldId = "world:0000000000000001",
			regionId = "region:office-a",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = "chair/registry-shape",
		},
		fidelity = "F1",
		persistentState = {},
		stateRevision = 0,
		representationRevision = 0,
	}
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean): ()
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local function registerAccepts(record): boolean
		local registry = WorldEntity.createRegistry()
		local ok = pcall(function()
			WorldEntity.register(registry, record)
		end)
		return ok
	end

	expect("registry accepts exact mutable record shape", registerAccepts(makeRecord()))

	local extraRecord = makeRecord()
	extraRecord.authorityLease = "future-field"
	expect("registry rejects unknown record field", not registerAccepts(extraRecord))

	local extraOrigin = makeRecord()
	extraOrigin.origin.persistenceEpoch = 2
	expect("registry rejects unknown origin field", not registerAccepts(extraOrigin))

	local metatableRecord = setmetatable(makeRecord(), {
		__index = function()
			return "forged"
		end,
	})
	expect("registry rejects record metatable", not registerAccepts(metatableRecord))

	local metatableOrigin = makeRecord()
	metatableOrigin.origin = setmetatable(metatableOrigin.origin, {
		__index = function()
			return "forged"
		end,
	})
	expect("registry rejects origin metatable", not registerAccepts(metatableOrigin))

	return failures
end

return run
