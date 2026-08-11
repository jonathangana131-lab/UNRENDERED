local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local ResolvedRegionRecipeV1 = ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_WORLD_ID = "world:v1:b2eccb898b0d09866a4df94d651fda4f"
local GOLDEN_REGION_ID = "region:v1:1841ffe5f321ed0511919940bd21a6ff"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v2:c7e170974f1459509fadc3e829d4d8e4"
local LEGACY_V1_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local LEGACY_V1_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

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

local function historicalV1Serialized()
	return {
		schemaVersion = 1,
		regionId = LEGACY_V1_REGION_ID,
		worldSeedRef = "world-seed:office-alpha",
		regionAddress = {
			x = 12,
			z = -4,
			layer = 1,
		},
		generatorVersions = historicalV2Versions(),
		semanticIntentKey = "intent:commercial-office.late-90s",
		topologyAnchors = {
			"anchor:east-primary-threshold",
			"anchor:west-service-threshold",
		},
		canonicalContentKeys = {
			"fixture:fluorescent-row-a",
			"material:carpet-batch-a",
			"object:chair-a",
		},
		recipeFingerprint = LEGACY_V1_FINGERPRINT,
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

	local v2TostringCalls = 0
	local hostileV2Key = setmetatable({}, {
		__tostring = function()
			v2TostringCalls += 1
			error("hostile v2 schema key __tostring executed")
		end,
	})
	local hostileV2Candidate: any = historicalV2Candidate()
	hostileV2Candidate[hostileV2Key] = true
	expect(
		"v2 rejects non-string schema keys",
		rejects(function()
			ResolvedRegionRecipe.lock(hostileV2Candidate)
		end)
	)
	expect("v2 schema rejection does not execute hostile __tostring", v2TostringCalls == 0)

	local v1TostringCalls = 0
	local hostileV1Key = setmetatable({}, {
		__tostring = function()
			v1TostringCalls += 1
			error("hostile v1 schema key __tostring executed")
		end,
	})
	local hostileV1Recipe: any = historicalV1Serialized()
	hostileV1Recipe[hostileV1Key] = true
	expect(
		"legacy v1 replay rejects non-string schema keys",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(hostileV1Recipe)
		end)
	)
	expect("legacy v1 replay rejection does not execute hostile __tostring", v1TostringCalls == 0)

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