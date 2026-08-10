local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_WORLD_ID = "world:v1:b2eccb898b0d09866a4df94d651fda4f"
local OTHER_WORLD_ID = "world:v1:dcac2b768af90b35d13b961727e32ac0"
local GOLDEN_V1_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_V1_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"
local GOLDEN_V2_REGION_ID = "region:v1:1841ffe5f321ed0511919940bd21a6ff"
local GOLDEN_V2_FINGERPRINT = "resolved-region:v2:c7e170974f1459509fadc3e829d4d8e4"

local function historicalV1Serialized()
	return {
		schemaVersion = 1,
		regionId = GOLDEN_V1_REGION_ID,
		worldSeedRef = "world-seed:office-alpha",
		regionAddress = {
			x = 12,
			z = -4,
			layer = 1,
		},
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
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
		recipeFingerprint = GOLDEN_V1_FINGERPRINT,
	}
end

local function currentV2Candidate(worldId)
	return {
		worldId = worldId,
		worldSeedRef = "world-seed:office-alpha",
		regionAddress = RegionAddress.new(12, -4, 1),
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
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

	-- Schema v1 is compatibility-only. Normal first observation creates v2;
	-- historical v1 loading is explicit so new code cannot accidentally mint
	-- more seed-derived regional identities.
	local locked = ResolvedRegionRecipe.deserializeLegacyV1(historicalV1Serialized())

	expect("historical v1 recipe is recognized as legacy", ResolvedRegionRecipe.isLegacyV1(locked))
	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_V1_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_V1_FINGERPRINT
	)

	local reconstructed = ResolvedRegionRecipe.deserializeLegacyV1(ResolvedRegionRecipe.serialize(locked))
	expect(
		"historical v1 serialized truth remains reconstructable",
		ResolvedRegionRecipe.equal(locked, reconstructed)
	)
	expect(
		"normal deserialize refuses implicit v1 compatibility loading",
		rejects(function()
			ResolvedRegionRecipe.deserialize(historicalV1Serialized())
		end)
	)
	expect(
		"historical v1 explicitly reports migration required",
		ResolvedRegionRecipe.requiresMigration(locked)
	)

	expect(
		"legacy truth cannot participate in v2 observation before explicit WorldId upgrade",
		rejects(function()
			ResolvedRegionRecipe.resolveOnObservation(locked, currentV2Candidate(GOLDEN_WORLD_ID))
		end)
	)

	local upgraded, receipt = ResolvedRegionRecipe.upgradeLegacyV1(locked, GOLDEN_WORLD_ID)
	expect("explicit WorldId upgrade creates schema v2", upgraded.schemaVersion == 2)
	expect("explicit WorldId upgrade records WorldId", upgraded.worldId == GOLDEN_WORLD_ID)
	expect("explicit WorldId upgrade keeps seed provenance", upgraded.worldSeedRef == locked.worldSeedRef)
	expect("explicit WorldId upgrade uses v2 region identity", upgraded.regionId == GOLDEN_V2_REGION_ID)
	expect(
		"explicit WorldId upgrade uses v2 content fingerprint",
		upgraded.recipeFingerprint == GOLDEN_V2_FINGERPRINT
	)
	expect("legacy source identity stays unchanged", locked.regionId == GOLDEN_V1_REGION_ID)
	expect("legacy source fingerprint stays unchanged", locked.recipeFingerprint == GOLDEN_V1_FINGERPRINT)
	expect("upgrade receipt records explicit WorldId", receipt.worldId == GOLDEN_WORLD_ID)
	expect("upgrade receipt records source region identity", receipt.sourceRegionId == GOLDEN_V1_REGION_ID)
	expect("upgrade receipt records target region identity", receipt.targetRegionId == GOLDEN_V2_REGION_ID)
	expect("upgrade receipt records source fingerprint", receipt.sourceFingerprint == GOLDEN_V1_FINGERPRINT)
	expect("upgrade receipt records target fingerprint", receipt.targetFingerprint == GOLDEN_V2_FINGERPRINT)

	local otherWorldUpgrade = ResolvedRegionRecipe.upgradeLegacyV1(locked, OTHER_WORLD_ID)
	expect(
		"operator-supplied WorldId controls corrected v2 identity",
		otherWorldUpgrade.regionId ~= upgraded.regionId
	)

	expect(
		"legacy upgrade rejects malformed WorldId",
		rejects(function()
			ResolvedRegionRecipe.upgradeLegacyV1(locked, "world:guess")
		end)
	)
	expect(
		"generic generator migration refuses legacy identity",
		rejects(function()
			ResolvedRegionRecipe.migrate(
				locked,
				{
					reality = 2,
					topology = 1,
					material = 1,
					object = 1,
					entity = 1,
				},
				"migration:legacy-without-world",
				function()
					return currentV2Candidate(GOLDEN_WORLD_ID)
				end
			)
		end)
	)

	local reproKey = ResolvedRegionRecipe.reproKey(locked)
	expect("legacy repro key carries legacy marker", string.find(reproKey, "legacy-v1", 1, true) ~= nil)
	expect("legacy repro key carries region identity", string.find(reproKey, locked.regionId, 1, true) ~= nil)
	expect(
		"legacy repro key carries exact fingerprint",
		string.find(reproKey, locked.recipeFingerprint, 1, true) ~= nil
	)

	return failures
end

return run
