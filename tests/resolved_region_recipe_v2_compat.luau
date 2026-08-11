local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_WORLD_ID = "world:v1:b2eccb898b0d09866a4df94d651fda4f"
local GOLDEN_REGION_ID = "region:v1:1841ffe5f321ed0511919940bd21a6ff"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v2:c7e170974f1459509fadc3e829d4d8e4"

local function historicalV2Versions()
	return {
		reality = 1,
		topology = 1,
		material = 1,
		object = 1,
		entity = 1,
	}
end

local function historicalV2Candidate()
	return {
		worldId = GOLDEN_WORLD_ID,
		worldSeedRef = "world-seed:office-alpha",
		regionAddress = RegionAddress.new(12, -4, 1),
		generatorVersions = historicalV2Versions(),
		semanticIntentKey = "intent:commercial-office.late-90s",
		topologyAnchors = {
			"anchor:west-service-threshold",
			"anchor:east-primary-threshold",
		},
		canonicalContentKeys = {
			"object:chair-a",
			"material:carpet-batch-a",
			"fixture:fluorescent-row-a",
		},
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

	local function rejects(callback): boolean
		return not pcall(callback)
	end

	-- This is a historical compatibility vector. It deliberately does not use
	-- RealityVersions.current(), so future generator bumps cannot move the v2
	-- identity/fingerprint law being protected here.
	local locked = ResolvedRegionRecipe.lock(historicalV2Candidate())
	expect("historical v2 WorldId stays literal", locked.worldId == GOLDEN_WORLD_ID)
	expect("historical v2 region identity stays literal", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v2 recipe fingerprint stays literal",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	local nonCanonicalWorldId = historicalV2Candidate()
	nonCanonicalWorldId.worldId = string.gsub(GOLDEN_WORLD_ID, ":v1:", ":v01:", 1)
	expect(
		"v2 rejects zero-padded StableId version aliases",
		rejects(function()
			ResolvedRegionRecipe.lock(nonCanonicalWorldId)
		end)
	)

	local targetVersions = historicalV2Versions()
	targetVersions.reality = 2
	expect(
		"migration builder cannot redirect world seed provenance",
		rejects(function()
			ResolvedRegionRecipe.migrate(
				locked,
				targetVersions,
				"migration:bad-seed-provenance",
				function(source, target)
					return {
						worldId = source.worldId,
						worldSeedRef = "world-seed:other-provenance",
						regionAddress = source.regionAddress,
						generatorVersions = target,
						semanticIntentKey = source.semanticIntentKey,
						topologyAnchors = source.topologyAnchors,
						canonicalContentKeys = source.canonicalContentKeys,
					}
				end
			)
		end)
	)

	return failures
end

return run
