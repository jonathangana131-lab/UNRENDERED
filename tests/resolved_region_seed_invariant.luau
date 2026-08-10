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

	local worldId = StableId.fromParts("world", { "seed-invariant-world" })
	local function makeCandidate()
		return {
			worldId = worldId,
			worldSeed = "world-seed:seed-invariant-world",
			regionAddress = { x = 4, z = -2, layer = 1 },
			generatorVersions = {
				reality = 1,
				topology = 1,
				material = 1,
				object = 1,
				entity = 1,
			},
			semanticIntentKey = "commercial.office.fallback",
			topologyAnchorKeys = { "entry/west" },
			canonicalContentKeys = { "object/chair-a" },
		}
	end

	local locked = ResolvedRegionRecipe.new(makeCandidate())
	local contradictorySeed = makeCandidate()
	contradictorySeed.worldSeed = "world-seed:contradictory"
	local relockAccepted = pcall(function()
		ResolvedRegionRecipe.lock(locked, contradictorySeed)
	end)
	expect("same WorldId and RegionAddress reject contradictory worldSeed", not relockAccepted)

	local targetVersions = {
		reality = 2,
		topology = 2,
		material = 2,
		object = 2,
		entity = 2,
	}
	local plan = ResolvedRegionRecipe.planMigration(locked, targetVersions)
	expect("version change creates migration plan for seed invariant test", plan ~= nil)
	if plan ~= nil then
		local migrationAccepted = pcall(function()
			ResolvedRegionRecipe.runMigration(plan, function(source, requestedVersions)
				return {
					worldId = source.worldId,
					worldSeed = "world-seed:migration-rewrite",
					regionAddress = RegionAddress.toPlainData(source.regionAddress),
					generatorVersions = {
						reality = requestedVersions.reality,
						topology = requestedVersions.topology,
						material = requestedVersions.material,
						object = requestedVersions.object,
						entity = requestedVersions.entity,
					},
					semanticIntentKey = source.semanticIntentKey,
					topologyAnchorKeys = { "entry/west" },
					canonicalContentKeys = { "object/chair-a" },
				}
			end)
		end)
		expect("explicit migration cannot rewrite global worldSeed truth", not migrationAccepted)
	end

	return failures
end

return run
