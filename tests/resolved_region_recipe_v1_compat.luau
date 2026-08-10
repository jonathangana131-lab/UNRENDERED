local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipeV1 = ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

local function historicalV1Candidate()
	return {
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

	-- This fixture models already-observed historical v1 truth through the
	-- explicitly legacy decoder. New canonical locks use ResolvedRegionRecipe
	-- v2 and must never infer WorldId from v1 seed provenance.
	local locked = ResolvedRegionRecipeV1.lock(historicalV1Candidate())

	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	local reconstructed = ResolvedRegionRecipeV1.deserialize(ResolvedRegionRecipeV1.serialize(locked))
	expect(
		"historical v1 serialized truth remains reconstructable",
		ResolvedRegionRecipeV1.equal(locked, reconstructed)
	)

	local syntheticFuture = historicalV1Candidate()
	syntheticFuture.generatorVersions = {
		reality = 2,
		topology = 2,
		material = 2,
		object = 2,
		entity = 2,
	}
	local futureLocked = ResolvedRegionRecipeV1.lock(syntheticFuture)
	expect("generator-version drift preserves historical v1 region identity", futureLocked.regionId == GOLDEN_REGION_ID)
	expect(
		"generator-version drift changes historical v1 exact recipe fingerprint",
		futureLocked.recipeFingerprint ~= GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"historical v1 vector stays unchanged after future-version construction",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	return failures
end

return run