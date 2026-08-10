local process = require("@lune/process")
local Contract = require("../src/shared/Core/DeterminismContract")
local runWorldEntity = require("./world_entity")

local failures = 0

local function fail(name, detail)
	failures += 1
	print(`FAIL {name}: {detail}`)
end

local function pass(name)
	print(`PASS {name}`)
end

local function expectEqual(name, actual, expected)
	if actual ~= expected then
		fail(name, `expected {expected}, got {actual}`)
	else
		pass(name)
	end
end

local function expectTrue(name, value)
	if value then
		pass(name)
	else
		fail(name, "expected true")
	end
end

local function expectFalse(name, value)
	if not value then
		pass(name)
	else
		fail(name, "expected false")
	end
end

local function expectError(name, callback)
	local ok = pcall(callback)
	if ok then
		fail(name, "expected an error")
	else
		pass(name)
	end
end

-- Canonical byte encoding. Lengths are byte counts, not character counts.
expectEqual("encode empty list", Contract.encodeParts({}), "u1;0;")
expectEqual("encode empty string", Contract.encodeParts({ "" }), "u1;1;0:")
expectEqual("encode boundaries", Contract.encodeParts({ "a", "bc" }), "u1;2;1:a2:bc")
expectEqual("encode delimiter bytes", Contract.encodeParts({ "a\30b", "" }), "u1;2;3:a\30b0:")
expectFalse(
	"encoding distinguishes part boundaries",
	Contract.encodeParts({ "ab", "c" }) == Contract.encodeParts({ "a", "bc" })
)
expectError("encoding rejects sparse arrays", function()
	Contract.encodeParts({ [1] = "a", [3] = "c" })
end)
expectError("encoding rejects non-array keys", function()
	Contract.encodeParts({ [1] = "a", extra = "b" })
end)

-- Hash32 golden vectors. Any change here is a deterministic-contract migration.
expectEqual("hash empty golden", Contract.hash32("", 0), 0x00000000)
expectEqual("hash text golden", Contract.hash32("UNRENDERED", 1234), 0xd93c5d5c)
expectEqual("hash binary golden", Contract.hash32("\0\31\30\255", 0xdeadbeef), 0xc8224a21)
expectEqual("hash parts golden", Contract.hashParts(0, { "a", "bc" }), 0x9f2752c3)
expectError("hash requires explicit seed", function()
	Contract.hash32("x")
end)
expectError("hash rejects negative seed", function()
	Contract.hash32("x", -1)
end)
expectError("hash rejects fractional seed", function()
	Contract.hash32("x", 1.5)
end)

-- StableId v1 is namespace:v1:128-bit lowercase digest.
local worldId = Contract.stableId("world", { "alpha" })
expectEqual("stable id world golden", worldId, "world:v1:9fa76d9d4d3f004052fffe125f6bfb2a")
expectEqual(
	"stable id entity golden",
	Contract.stableId("entity", { "world:alpha", "region:r:0:0:0", "chair", "17" }),
	"entity:v1:e551babe198a1090ebb985f89608e821"
)
expectTrue("stable id recognizes current id", Contract.isStableId(worldId))
expectTrue("stable id recognizes namespace", Contract.isStableId(worldId, "world"))
expectFalse("stable id rejects wrong namespace", Contract.isStableId(worldId, "entity"))
expectFalse("stable id rejects old unversioned shape", Contract.isStableId("world:9fa76d9d4d3f0040"))
expectFalse(
	"stable id rejects uppercase namespace",
	Contract.isStableId("World:v1:9fa76d9d4d3f004052fffe125f6bfb2a")
)
expectError("stable id rejects empty namespace", function()
	Contract.stableId("", { "alpha" })
end)
expectError("stable id rejects empty parts", function()
	Contract.stableId("world", {})
end)
expectError("stable id rejects empty semantic part", function()
	Contract.stableId("world", { "alpha", "" })
end)
expectError("stable id rejects oversized semantic part", function()
	Contract.stableId("world", { string.rep("a", 513) })
end)
local tooManyParts = {}
for index = 1, 33 do
	tooManyParts[index] = tostring(index)
end
expectError("stable id rejects excessive semantic parts", function()
	Contract.stableId("world", tooManyParts)
end)

-- Xorshift32 v1 golden sequence. Seed zero maps to the documented fallback state.
local state = Contract.normalizeRngSeed(1)
local expectedSequence = {
	0x00042021,
	0x04080601,
	0x9dcca8c5,
	0x1255994f,
	0x8ef917d1,
	0x2c6f5bd0,
	0x25b2331a,
	0x19f91cb2,
}
for index, expected in expectedSequence do
	state = Contract.nextRngState(state)
	expectEqual(`rng seed=1 golden #{index}`, state, expected)
end
expectEqual("rng zero normalization", Contract.normalizeRngSeed(0), 0x6d2b79f5)
expectError("rng rejects out-of-range seed", function()
	Contract.normalizeRngSeed(4294967296)
end)

-- SeedStream v1 explicitly includes generation version, subsystem salt, and ordered semantic scopes.
local topologySeed = Contract.seedFor("world-alpha", 1, "worldgen.topology", { "region:r:0:0:0", "layout" })
local materialSeed = Contract.seedFor("world-alpha", 1, "worldgen.material", { "region:r:0:0:0", "layout" })
local objectSeed = Contract.seedFor("world-alpha", 1, "worldgen.object", { "region:r:0:0:0", "layout" })
expectEqual("seed stream topology golden", topologySeed, 0xcaa062ba)
expectEqual("seed stream material golden", materialSeed, 0xa6141672)
expectEqual("seed stream object golden", objectSeed, 0xc7e7a414)
expectFalse("subsystem salts isolate topology/material", topologySeed == materialSeed)
expectFalse("subsystem salts isolate topology/object", topologySeed == objectSeed)
expectFalse(
	"generation version changes stream",
	topologySeed == Contract.seedFor("world-alpha", 2, "worldgen.topology", { "region:r:0:0:0", "layout" })
)
expectFalse(
	"scope order changes stream",
	topologySeed == Contract.seedFor("world-alpha", 1, "worldgen.topology", { "layout", "region:r:0:0:0" })
)

local unrelatedState = Contract.normalizeRngSeed(materialSeed)
for _ = 1, 100 do
	unrelatedState = Contract.nextRngState(unrelatedState)
end
expectEqual(
	"advancing unrelated stream cannot perturb topology derivation",
	Contract.seedFor("world-alpha", 1, "worldgen.topology", { "region:r:0:0:0", "layout" }),
	topologySeed
)
expectError("seed stream rejects empty world seed", function()
	Contract.seedFor("", 1, "worldgen.topology", { "region" })
end)
expectError("seed stream rejects generation version zero", function()
	Contract.seedFor("world-alpha", 0, "worldgen.topology", { "region" })
end)
expectError("seed stream rejects undotted salt", function()
	Contract.seedFor("world-alpha", 1, "topology", { "region" })
end)
expectError("seed stream rejects malformed salt", function()
	Contract.seedFor("world-alpha", 1, "worldgen..topology", { "region" })
end)
expectError("seed stream rejects empty scopes", function()
	Contract.seedFor("world-alpha", 1, "worldgen.topology", {})
end)
expectError("seed stream rejects empty scope", function()
	Contract.seedFor("world-alpha", 1, "worldgen.topology", { "" })
end)
expectError("seed stream rejects oversized world seed", function()
	Contract.seedFor(string.rep("w", 513), 1, "worldgen.topology", { "region" })
end)
expectError("seed stream rejects oversized scope", function()
	Contract.seedFor("world-alpha", 1, "worldgen.topology", { string.rep("s", 513) })
end)
local tooManyScopes = {}
for index = 1, 33 do
	tooManyScopes[index] = tostring(index)
end
expectError("seed stream rejects excessive scopes", function()
	Contract.seedFor("world-alpha", 1, "worldgen.topology", tooManyScopes)
end)

failures += runWorldEntity()

if failures > 0 then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
