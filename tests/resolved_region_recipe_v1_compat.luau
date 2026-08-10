local ProductionLoader = require("./support/ProductionLoader")

local LegacyResolvedRegionRecipeV1 =
	ProductionLoader.requireShared("Reality/LegacyResolvedRegionRecipeV1")
local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

local function historicalV1Serialized()
	return {
		schemaVersion = 1,
		regionId = GOLDEN_REGION_ID,
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
			"anchor:east-primary-threshold",
			"anchor:west-service-threshold",
		},
		canonicalContentKeys = {
			"fixture:fluorescent-row-a",
			"material:carpet-batch-a",
			"object:chair-a",
		},
		recipeFingerprint = GOLDEN_RECIPE_FINGERPRINT,
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

	-- This fixture models already-observed v1 truth. New observations must use
	-- ResolvedRegionRecipe v2; this isolated module exists only to reconstruct
	-- the frozen historical v1 framing without inventing a WorldId.
	local historical = LegacyResolvedRegionRecipeV1.deserialize(historicalV1Serialized())

	expect("historical v1 decoder is version-locked", LegacyResolvedRegionRecipeV1.SCHEMA_VERSION == 1)
	expect("historical v1 region identity remains compatible", historical.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		historical.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	local reconstructed = LegacyResolvedRegionRecipeV1.deserialize(
		LegacyResolvedRegionRecipeV1.serialize(historical)
	)
	expect(
		"historical v1 serialized truth remains reconstructable",
		LegacyResolvedRegionRecipeV1.equal(historical, reconstructed)
	)
	expect(
		"historical v1 reconstruction preserves exact fingerprint",
		LegacyResolvedRegionRecipeV1.fingerprint(reconstructed) == GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"legacy reconstruction never invents WorldId",
		LegacyResolvedRegionRecipeV1.serialize(reconstructed).worldId == nil
	)
	expect(
		"legacy compatibility module exposes no v1 observation lock path",
		LegacyResolvedRegionRecipeV1.lock == nil
	)
	expect(
		"current v2 decoder never silently reinterprets historical v1",
		rejects(function()
			ResolvedRegionRecipe.deserialize(LegacyResolvedRegionRecipeV1.serialize(historical))
		end)
	)

	local tampered = LegacyResolvedRegionRecipeV1.serialize(historical)
	tampered.semanticIntentKey = "intent:tampered-v1-history"
	expect(
		"legacy decoder rejects v1 content that no longer matches its fingerprint",
		rejects(function()
			LegacyResolvedRegionRecipeV1.deserialize(tampered)
		end)
	)

	return failures
end

return run
