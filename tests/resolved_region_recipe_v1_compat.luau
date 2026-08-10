local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipeV1 = ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

local function historicalV1Serialized()
	return {
		schemaVersion = 1,
		regionId = GOLDEN_REGION_ID,
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

	-- This fixture is literal already-observed v1 truth. The public legacy
	-- boundary is replay-only: it can reconstruct accepted history but cannot
	-- create new v1 canonical locks.
	local locked = ResolvedRegionRecipeV1.deserialize(historicalV1Serialized())

	expect("legacy v1 public boundary is replay-only", ResolvedRegionRecipeV1.REPLAY_ONLY == true)
	expect("legacy v1 public boundary exposes no lock constructor", ResolvedRegionRecipeV1.lock == nil)
	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	local serialized = ResolvedRegionRecipeV1.serialize(locked)
	local reconstructed = ResolvedRegionRecipeV1.deserialize(serialized)
	expect(
		"historical v1 serialized truth remains reconstructable",
		ResolvedRegionRecipeV1.equal(locked, reconstructed)
	)
	expect(
		"historical v1 fingerprint remains exact after replay round trip",
		ResolvedRegionRecipeV1.fingerprint(reconstructed) == GOLDEN_RECIPE_FINGERPRINT
	)

	return failures
end

return run
