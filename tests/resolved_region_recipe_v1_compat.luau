local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipeV1 = ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

local function historicalV1Record()
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
			"anchor:west-service-threshold",
			"anchor:east-primary-threshold",
		},
		canonicalContentKeys = {
			"object:chair-a",
			"material:carpet-batch-a",
			"fixture:fluorescent-row-a",
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

	-- Already-observed schema-v1 truth is reconstructed from a literal record.
	-- The isolated compatibility module intentionally exposes no observation/lock
	-- API, so it cannot mint new canonical content under the deprecated identity law.
	local locked = ResolvedRegionRecipeV1.deserialize(historicalV1Record())
	expect("historical v1 decoder remains schema 1", ResolvedRegionRecipeV1.SCHEMA_VERSION == 1)
	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"historical v1 fingerprint API remains compatible",
		ResolvedRegionRecipeV1.fingerprint(locked) == GOLDEN_RECIPE_FINGERPRINT
	)

	local reconstructed = ResolvedRegionRecipeV1.deserialize(ResolvedRegionRecipeV1.serialize(locked))
	expect(
		"historical v1 serialized truth remains reconstructable",
		ResolvedRegionRecipeV1.equal(locked, reconstructed)
	)
	expect("legacy v1 compatibility module exposes no new-write lock API", ResolvedRegionRecipeV1.lock == nil)
	expect(
		"legacy v1 compatibility module exposes no observation transition API",
		ResolvedRegionRecipeV1.resolveOnObservation == nil
	)

	return failures
end

return run
