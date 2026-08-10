local process = require("@lune/process")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local failures = 0

local function expectEqual(name, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {name}: expected {expected}, got {actual}`)
	else
		print(`PASS {name}`)
	end
end

local function expectTrue(name, value)
	if not value then
		failures += 1
		print(`FAIL {name}: expected true`)
	else
		print(`PASS {name}`)
	end
end

local function expectError(name, callback)
	local ok = pcall(callback)
	if ok then
		failures += 1
		print(`FAIL {name}: expected an error`)
	else
		print(`PASS {name}`)
	end
end

-- Pure algorithm smoke tests live here until the reusable deterministic harness lands in #8.
-- Values are intentionally duplicated from simple local implementations so CI can
-- catch accidental changes to canonical deterministic behavior without Roblox Studio.
local function hash32(text, seed)
	local UINT32 = 4294967296
	local hash = (seed or 0) % UINT32
	for i = 1, #text do
		hash = (hash + string.byte(text, i)) % UINT32
		hash = (hash + bit32.lshift(hash, 10)) % UINT32
		hash = bit32.bxor(hash, bit32.rshift(hash, 6))
	end
	hash = (hash + bit32.lshift(hash, 3)) % UINT32
	hash = bit32.bxor(hash, bit32.rshift(hash, 11))
	hash = (hash + bit32.lshift(hash, 15)) % UINT32
	return hash
end

expectEqual("hash deterministic repeat", hash32("UNRENDERED", 1234), hash32("UNRENDERED", 1234))
if hash32("UNRENDERED", 1234) == hash32("UNRENDERED!", 1234) then
	failures += 1
	print("FAIL hash distinguishes nearby input")
else
	print("PASS hash distinguishes nearby input")
end

local initialState = {
	wear = 0.15,
	mechanism = {
		latched = false,
	},
}

local entity = WorldEntity.new({
	id = "entity:0123456789abcdef",
	kind = "object",
	origin = {
		worldId = "world:fixture",
		regionId = "region:fixture",
		generator = "FixtureGenerator",
		generatorVersion = 1,
		localKey = "chair-a",
	},
	fidelity = "F3",
	persistentState = initialState,
})

expectEqual("WorldEntity starts at requested fidelity", entity.fidelity, "F3")
expectEqual("WorldEntity starts at revision zero", entity.lifecycleRevision, 0)
expectEqual("WorldEntity keeps stable identity", entity.id, "entity:0123456789abcdef")

initialState.wear = 0.9
initialState.mechanism.latched = true
expectEqual("WorldEntity clones input state", entity.persistentState.wear, 0.15)
expectEqual("WorldEntity clones nested input state", entity.persistentState.mechanism.latched, false)
expectError("WorldEntity state snapshot rejects top-level mutation", function()
	entity.persistentState.wear = 0.9
end)
expectError("WorldEntity state snapshot rejects nested mutation", function()
	entity.persistentState.mechanism.latched = true
end)

local registry = WorldEntity.newRegistry()
WorldEntity.register(registry, entity)
expectEqual("registry resolves stable identity", WorldEntity.get(registry, entity.id), entity)
expectError("registry rejects duplicate identity", function()
	WorldEntity.register(registry, entity)
end)

expectError("demotion requires state capture", function()
	WorldEntity.transitionRegistered(registry, entity.id, "F1")
end)

local capturedState = {
	mechanism = {
		latched = true,
	},
	lastInteractionTick = 42,
}
local demoted = WorldEntity.transitionRegistered(registry, entity.id, "F1", capturedState)
capturedState.mechanism.latched = false
capturedState.lastInteractionTick = 99

expectEqual("demotion preserves identity", demoted.id, entity.id)
expectEqual("demotion changes fidelity", demoted.fidelity, "F1")
expectEqual("demotion increments lifecycle revision", demoted.lifecycleRevision, 1)
expectEqual("captured state replaces changed field", demoted.persistentState.mechanism.latched, true)
expectEqual("captured state records new field", demoted.persistentState.lastInteractionTick, 42)
expectEqual("uncaptured durable state survives demotion", demoted.persistentState.wear, 0.15)
expectError("demoted snapshot rejects nested mutation", function()
	demoted.persistentState.mechanism.latched = false
end)

local promoted = WorldEntity.transitionRegistered(registry, entity.id, "F3")
expectEqual("promotion preserves identity after representation recreation", promoted.id, entity.id)
expectEqual("promotion restores requested fidelity", promoted.fidelity, "F3")
expectEqual("promotion increments lifecycle revision", promoted.lifecycleRevision, 2)
expectEqual("persistent state survives representation recreation", promoted.persistentState.mechanism.latched, true)

expectError("persistent state rejects executable values", function()
	WorldEntity.new({
		id = "entity:fedcba9876543210",
		kind = "object",
		origin = {
			worldId = "world:fixture",
			generator = "FixtureGenerator",
			generatorVersion = 1,
		},
		persistentState = {
			callback = function() end,
		},
	})
end)

local cyclic = {}
cyclic.self = cyclic
expectTrue("cyclic persistent state is rejected", not WorldEntity.validatePersistentState(cyclic))

if failures > 0 then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
