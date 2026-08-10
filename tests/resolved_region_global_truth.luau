local StableId = require("../src/shared/Core/StableId")
local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")
local RegionAddress = require("../src/shared/Spatial/RegionAddress")

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local function rejects(callback)
		return not pcall(callback)
	end

	local worldId = StableId.fromParts("world", { "shared-canonical-world" })
	local function makeCandidate()
		return {
			worldId = worldId,
			worldSeed = "world-seed:shared-canonical-world",
			regionAddress = { x = 0, z = 0, layer = 0 },
			generatorVersions = {
				reality = 1,
				topology = 1,
				material = 1,
				object = 1,
				entity = 1,
			},
			semanticIntentKey = "commercial.office.fallback",
			topologyAnchorKeys = { "exit/east", "entry/west", "service/north" },
			canonicalContentKeys = { "object/front-desk", "fixture/light-row-a", "object/chair-a" },
		}
	end

	local locked = ResolvedRegionRecipe.new(makeCandidate())
	expect(
		"v1 WorldId fixture stays deterministic",
		worldId == "world:v1:c2e094b5e477eeb7c4b3566ebb9dee22"
	)
	expect(
		"v1 resolved region identity stays deterministic",
		locked.id == "region:v1:10b42978018aaf8203977a384f9438c8"
	)
	expect(
		"v1 resolved recipe fingerprint stays deterministic",
		ResolvedRegionRecipe.fingerprint(locked) == "rr1:aaa45fdc"
	)

	local wrongSeed = makeCandidate()
	wrongSeed.worldSeed = "world-seed:contradictory-global-truth"
	expect(
		"first-observation relock rejects a contradictory world seed",
		rejects(function()
			ResolvedRegionRecipe.lock(locked, wrongSeed)
		end)
	)

	local targetVersions = {
		reality = 2,
		topology = 1,
		material = 1,
		object = 1,
		entity = 1,
	}
	local plan = ResolvedRegionRecipe.planMigration(locked, targetVersions)
	expect("migration plan exists for changed generator versions", plan ~= nil)
	if plan ~= nil then
		expect(
			"explicit migration rejects changing global world seed truth",
			rejects(function()
				ResolvedRegionRecipe.runMigration(plan, function(source, versions)
					return {
						worldId = source.worldId,
						worldSeed = "world-seed:contradictory-global-truth",
						regionAddress = RegionAddress.toPlainData(source.regionAddress),
						generatorVersions = versions,
						semanticIntentKey = source.semanticIntentKey,
						topologyAnchorKeys = source.topologyAnchorKeys,
						canonicalContentKeys = source.canonicalContentKeys,
					}
				end)
			end)
		)
	end

	return failures
end

return run
