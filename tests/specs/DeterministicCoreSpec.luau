local ProductionLoader = require("../support/ProductionLoader")
local ReproKey = require("../support/ReproKey")

local function repro(subsystem, localKey)
	return ReproKey.format({
		worldSeed = "world-alpha",
		version = "determinism=1;reality=1",
		region = "r:0:0:0",
		subsystem = subsystem,
		localKey = localKey,
	})
end

return function(runner)
	local loader = ProductionLoader.new(".")
	local Hash32 = loader:requireModule("src/shared/Core/Hash32.luau")
	local DeterministicRng = loader:requireModule("src/shared/Core/DeterministicRng.luau")
	local StableId = loader:requireModule("src/shared/Core/StableId.luau")
	local SeedStream = loader:requireModule("src/shared/WorldGen/SeedStream.luau")

	runner:test("Hash32 production golden vectors", repro("core.hash32", "jenkins-v1"), function(expect)
		expect:equal(Hash32.jenkins("", 0), 0, "empty input")
		expect:equal(Hash32.jenkins("UNRENDERED", 1234), 0xd93c5d5c, "seeded input")
		expect:equal(Hash32.encodeParts({ "a", "bc" }), "u1;2;1:a2:bc", "canonical part encoding")
		expect:equal(Hash32.combine(0, "a", "bc"), 0x9f2752c3, "canonical combined hash")
		expect:equal(Hash32.hex(0xd93c5d5c), "d93c5d5c", "hex encoding")
	end)

	runner:test("StableId v1 production golden", repro("core.stable-id", "world-alpha"), function(expect)
		local id = StableId.fromParts("world", { "alpha" })
		expect:equal(id, "world:v1:9fa76d9d4d3f004052fffe125f6bfb2a")
		expect:truthy(StableId.is(id, "world"), "namespace validation")
		expect:falsy(StableId.is("world:9fa76d9d4d3f0040"), "legacy unversioned shape")
		expect:throws(function()
			StableId.fromParts("", { "alpha" })
		end, nil, "empty namespace")
	end)

	runner:test(
		"DeterministicRng v1 production sequence",
		repro("core.rng", "xorshift32-seed-1"),
		function(expect)
			local rng = DeterministicRng.new(1)
			local expected = {
				0x00042021,
				0x04080601,
				0x9dcca8c5,
				0x1255994f,
				0x8ef917d1,
				0x2c6f5bd0,
			}
			for index, value in expected do
				expect:equal(rng:nextU32(), value, `draw {index}`)
			end
		end
	)

	runner:test(
		"DeterministicRng zero-seed fallback",
		repro("core.rng", "xorshift32-seed-0"),
		function(expect)
			local rng = DeterministicRng.new(0)
			local expected = {
				0x40aec71f,
				0x91e00c19,
				0x9c0fe128,
				0x6570f69d,
			}
			for index, value in expected do
				expect:equal(rng:nextU32(), value, `draw {index}`)
			end

			expect:throws(function()
				rng:nextInteger(4, 3)
			end, "minimum must be <= maximum", "invalid integer range")
			expect:throws(function()
				rng:chance(1.1)
			end, "probability must be in [0, 1]", "invalid probability")
		end
	)

	runner:test("SeedStream v1 production golden", repro("worldgen.topology", "layout"), function(expect)
		local scopes = { "region:r:0:0:0", "layout" }
		local seed = SeedStream.seedFor("world-alpha", 1, "worldgen.topology", scopes)
		expect:equal(seed, 0xcaa062ba, "derived topology seed")

		local topology = SeedStream.derive("world-alpha", 1, "worldgen.topology", scopes)
		local expected = {
			0x181f79e1,
			0x13476c70,
			0x27eb7194,
			0x72e37a78,
		}
		for index, value in expected do
			expect:equal(topology:nextU32(), value, `draw {index}`)
		end
	end)

	runner:test(
		"SeedStream subsystem and version isolation",
		repro("worldgen.stream-isolation", "topology-vs-material"),
		function(expect)
			local scopes = { "region:r:0:0:0", "layout" }
			local topologySeed = SeedStream.seedFor("world-alpha", 1, "worldgen.topology", scopes)
			local materialSeed = SeedStream.seedFor("world-alpha", 1, "worldgen.material", scopes)
			expect:equal(topologySeed, 0xcaa062ba, "topology seed")
			expect:equal(materialSeed, 0xa6141672, "material seed")
			expect:notEqual(materialSeed, topologySeed, "subsystem salt")
			expect:notEqual(
				SeedStream.seedFor("world-alpha", 2, "worldgen.topology", scopes),
				topologySeed,
				"generation version"
			)

			local material = SeedStream.derive("world-alpha", 1, "worldgen.material", scopes)
			for _ = 1, 32 do
				material:nextU32()
			end

			local topology = SeedStream.derive("world-alpha", 1, "worldgen.topology", scopes)
			expect:equal(topology:nextU32(), 0x181f79e1, "unrelated stream consumption")
		end
	)
end
