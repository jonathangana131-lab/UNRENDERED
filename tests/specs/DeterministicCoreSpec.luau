local Contract = require("../../src/shared/Core/DeterminismContract")
local ReproKey = require("../support/ReproKey")

local function repro(subsystem, localKey)
	return ReproKey.format({
		worldSeed = "world-alpha",
		version = "determinism=1;generator=1",
		region = "r:0:0:0",
		subsystem = subsystem,
		localKey = localKey,
	})
end

return function(runner)
	runner:test("canonical byte encoding", repro("core.encoding", "u1"), function(expect)
		local delimiterByte = string.char(30)
		local delimiterPayload = "a" .. delimiterByte .. "b"
		expect:equal(Contract.encodeParts({}), "u1;0;", "empty list")
		expect:equal(Contract.encodeParts({ "" }), "u1;1;0:", "empty string")
		expect:equal(Contract.encodeParts({ "a", "bc" }), "u1;2;1:a2:bc", "part boundaries")
		expect:equal(
			Contract.encodeParts({ delimiterPayload, "" }),
			"u1;2;3:a" .. delimiterByte .. "b0:",
			"delimiter bytes"
		)
		expect:falsy(
			Contract.encodeParts({ "ab", "c" }) == Contract.encodeParts({ "a", "bc" }),
			"distinct boundaries"
		)
		expect:falsy(
			Contract.encodeParts({ delimiterPayload }) == Contract.encodeParts({ "a", "b" }),
			"delimiter alias"
		)
		expect:throws(function()
			Contract.encodeParts({ [1] = "a", [3] = "c" })
		end, nil, "sparse arrays")
		expect:throws(function()
			Contract.encodeParts({ [1] = "a", extra = "b" })
		end, nil, "non-array keys")
	end)

	runner:test("Hash32 v1 golden vectors", repro("core.hash32", "v1"), function(expect)
		expect:equal(Contract.hash32("", 0), 0x00000000, "empty")
		expect:equal(Contract.hash32("UNRENDERED", 1234), 0xd93c5d5c, "text")
		expect:equal(Contract.hash32("\0\31\30\255", 0xdeadbeef), 0xc8224a21, "binary")
		expect:equal(Contract.hashParts(0, { "a", "bc" }), 0x9f2752c3, "canonical parts")
		expect:throws(function()
			Contract.hash32("x")
		end, nil, "explicit seed required")
		expect:throws(function()
			Contract.hash32("x", -1)
		end, nil, "negative seed")
		expect:throws(function()
			Contract.hash32("x", 1.5)
		end, nil, "fractional seed")
	end)

	runner:test("StableId v1 golden vectors", repro("core.stable-id", "v1"), function(expect)
		local worldId = Contract.stableId("world", { "alpha" })
		expect:equal(worldId, "world:v1:9fa76d9d4d3f004052fffe125f6bfb2a", "world ID")
		expect:equal(
			Contract.stableId("entity", { "world:alpha", "region:r:0:0:0", "chair", "17" }),
			"entity:v1:e551babe198a1090ebb985f89608e821",
			"entity ID"
		)
		expect:truthy(Contract.isStableId(worldId), "current ID")
		expect:truthy(Contract.isStableId(worldId, "world"), "namespace")
		expect:falsy(Contract.isStableId(worldId, "entity"), "wrong namespace")
		expect:falsy(Contract.isStableId("world:9fa76d9d4d3f0040"), "old unversioned shape")
		expect:falsy(Contract.isStableId("World:v1:9fa76d9d4d3f004052fffe125f6bfb2a"), "uppercase namespace")
	end)

	runner:test("StableId v1 validation bounds", repro("core.stable-id", "validation"), function(expect)
		expect:throws(function()
			Contract.stableId("", { "alpha" })
		end, nil, "empty namespace")
		expect:throws(function()
			Contract.stableId("world:bad", { "alpha" })
		end, nil, "delimiter namespace")
		expect:throws(function()
			Contract.stableId("world", {})
		end, nil, "empty parts")
		expect:throws(function()
			Contract.stableId("world", { "alpha", "" })
		end, nil, "empty semantic part")
		expect:throws(function()
			Contract.stableId("world", { string.rep("a", 513) })
		end, nil, "oversized semantic part")

		local tooManyParts = {}
		for index = 1, 33 do
			tooManyParts[index] = tostring(index)
		end
		expect:throws(function()
			Contract.stableId("world", tooManyParts)
		end, nil, "excessive semantic parts")
	end)

	runner:test("xorshift32 v1 golden sequence", repro("core.rng", "seed-1"), function(expect)
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
			expect:equal(state, expected, `draw {index}`)
		end
		expect:equal(Contract.normalizeRngSeed(0), 0x6d2b79f5, "zero normalization")
		expect:throws(function()
			Contract.normalizeRngSeed(4294967296)
		end, nil, "out-of-range seed")
	end)

	runner:test("SeedStream v1 golden vectors", repro("worldgen.stream", "region-layout"), function(expect)
		local topologySeed =
			Contract.seedFor("world-alpha", 1, "worldgen.topology", { "region:r:0:0:0", "layout" })
		local materialSeed =
			Contract.seedFor("world-alpha", 1, "worldgen.material", { "region:r:0:0:0", "layout" })
		local objectSeed =
			Contract.seedFor("world-alpha", 1, "worldgen.object", { "region:r:0:0:0", "layout" })
		expect:equal(topologySeed, 0xcaa062ba, "topology")
		expect:equal(materialSeed, 0xa6141672, "material")
		expect:equal(objectSeed, 0xc7e7a414, "object")
		expect:notEqual(topologySeed, materialSeed, "topology/material isolation")
		expect:notEqual(topologySeed, objectSeed, "topology/object isolation")
		expect:notEqual(
			topologySeed,
			Contract.seedFor("world-alpha", 2, "worldgen.topology", { "region:r:0:0:0", "layout" }),
			"generation version"
		)
		expect:notEqual(
			topologySeed,
			Contract.seedFor("world-alpha", 1, "worldgen.topology", { "layout", "region:r:0:0:0" }),
			"scope order"
		)

		local unrelatedState = Contract.normalizeRngSeed(materialSeed)
		for _ = 1, 100 do
			unrelatedState = Contract.nextRngState(unrelatedState)
		end
		expect:equal(
			Contract.seedFor("world-alpha", 1, "worldgen.topology", { "region:r:0:0:0", "layout" }),
			topologySeed,
			"unrelated stream consumption"
		)
	end)

	runner:test("SeedStream v1 validation bounds", repro("worldgen.stream", "validation"), function(expect)
		expect:throws(function()
			Contract.seedFor("", 1, "worldgen.topology", { "region" })
		end, nil, "empty world seed")
		expect:throws(function()
			Contract.seedFor("world-alpha", 0, "worldgen.topology", { "region" })
		end, nil, "generation version zero")
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "topology", { "region" })
		end, nil, "undotted salt")
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "worldgen..topology", { "region" })
		end, nil, "malformed salt")
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "worldgen.topology", {})
		end, nil, "empty scopes")
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "worldgen.topology", { "" })
		end, nil, "empty scope")
		expect:throws(function()
			Contract.seedFor(string.rep("w", 513), 1, "worldgen.topology", { "region" })
		end, nil, "oversized world seed")
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "worldgen.topology", { string.rep("s", 513) })
		end, nil, "oversized scope")

		local tooManyScopes = {}
		for index = 1, 33 do
			tooManyScopes[index] = tostring(index)
		end
		expect:throws(function()
			Contract.seedFor("world-alpha", 1, "worldgen.topology", tooManyScopes)
		end, nil, "excessive scopes")
	end)
end
