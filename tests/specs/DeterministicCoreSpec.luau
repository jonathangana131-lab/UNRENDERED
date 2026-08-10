local ProductionLoader = require("../support/ProductionLoader")
local ReproKey = require("../support/ReproKey")

local function repro(subsystem, localKey)
	return ReproKey.format({
		worldSeed = "world-7",
		version = "reality=1;topology=1",
		region = "4,-2,9",
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

	runner:test("Hash32 golden vectors", repro("core.hash32", "jenkins-v1"), function(expect)
		expect:equal(Hash32.jenkins("", 0), 0, "empty input")
		expect:equal(Hash32.jenkins("UNRENDERED", 1234), 0xd93c5d5c, "seeded input")
		expect:equal(Hash32.hex(0xd93c5d5c), "d93c5d5c", "hex encoding")
		expect:equal(
			Hash32.combine(0x9e3779b9, "region:4,-2,9", "topology", "hall-A"),
			0xab4976d9,
			"scope combination"
		)
	end)

	runner:test("StableId golden vectors", repro("core.stable-id", "world-entity-chair"), function(expect)
		local id = StableId.fromParts("world_entity", {
			"world-7",
			"region:4,-2,9",
			"chair",
			"seat-A",
		})
		expect:equal(id, "world_entity:6da69c4db383be4d")
		expect:truthy(StableId.is(id, "world_entity"), "namespace validation")
		expect:falsy(StableId.is("world_entity:not-a-hash"), "malformed ID")
		expect:throws(function()
			StableId.fromParts("", { "world-7" })
		end, "namespace must not be empty", "empty namespace")
	end)

	runner:test("DeterministicRng golden sequence", repro("core.rng", "xorshift32-seed-1"), function(expect)
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
	end)

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

	runner:test("SeedStream scoped golden sequence", repro("worldgen.topology", "hall-A"), function(expect)
		local topology = SeedStream.derive("world-7", {
			"region:4,-2,9",
			"topology",
			"hall-A",
		})
		local expected = {
			0x08f519da,
			0xd20f8b9d,
			0x4cfb7e43,
			0x4552f49a,
		}
		for index, value in expected do
			expect:equal(topology:nextU32(), value, `draw {index}`)
		end
	end)

	runner:test(
		"SeedStream subsystem isolation",
		repro("worldgen.stream-isolation", "topology-vs-materials"),
		function(expect)
			local topologyA = SeedStream.derive("world-7", {
				"region:4,-2,9",
				"topology",
				"hall-A",
			})
			local materials = SeedStream.derive("world-7", {
				"region:4,-2,9",
				"materials",
				"hall-A",
			})

			local topologyFirst = topologyA:nextU32()
			for _ = 1, 32 do
				materials:nextU32()
			end

			local topologyB = SeedStream.derive("world-7", {
				"region:4,-2,9",
				"topology",
				"hall-A",
			})
			expect:equal(topologyB:nextU32(), topologyFirst, "unrelated stream consumption")

			local differentScope = SeedStream.derive("world-7", {
				"region:4,-2,9",
				"materials",
				"hall-A",
			})
			expect:notEqual(differentScope:nextU32(), topologyFirst, "subsystem salt")
		end
	)
end
