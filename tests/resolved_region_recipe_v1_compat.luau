local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
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

	-- This fixture models already-observed v1 truth. It intentionally does not
	-- read RealityVersions.current(), so later generator-version bumps cannot
	-- change the compatibility vector being protected here.
	local locked = ResolvedRegionRecipe.lock(historicalV1Candidate())

	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	local reconstructed = ResolvedRegionRecipe.deserialize(ResolvedRegionRecipe.serialize(locked))
	expect(
		"historical v1 serialized truth remains reconstructable",
		ResolvedRegionRecipe.equal(locked, reconstructed)
	)

	local syntheticFuture = historicalV1Candidate()
	syntheticFuture.generatorVersions = {
		reality = 2,
		topology = 2,
		material = 2,
		object = 2,
		entity = 2,
	}
	local futureLocked = ResolvedRegionRecipe.lock(syntheticFuture)
	expect("generator-version drift preserves region identity", futureLocked.regionId == GOLDEN_REGION_ID)
	expect(
		"generator-version drift changes exact recipe fingerprint",
		futureLocked.recipeFingerprint ~= GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"historical v1 vector stays unchanged after future-version construction",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	return failures
end

return run
