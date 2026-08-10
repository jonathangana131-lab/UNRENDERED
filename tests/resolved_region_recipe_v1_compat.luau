local ProductionLoader = require("./support/ProductionLoader")

local DeterminismContract = ProductionLoader.requireShared("Core/DeterminismContract")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"
local FINGERPRINT_SEEDS = {
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
}

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

	-- Historical v1 is deliberately an offline compatibility oracle, not an
	-- executable production schema. V2 must never infer WorldId from this seed.
	local address = RegionAddress.new(12, -4, 1)
	local worldSeedRef = "world-seed:office-alpha"
	local topologyAnchors = {
		"anchor:east-primary-threshold",
		"anchor:west-service-threshold",
	}
	local canonicalContentKeys = {
		"fixture:fluorescent-row-a",
		"material:carpet-batch-a",
		"object:chair-a",
	}
	local regionId = DeterminismContract.stableId("region", {
		worldSeedRef,
		RegionAddress.key(address),
	})
	local payload = DeterminismContract.encodeParts({
		"resolved-region-recipe",
		"1",
		worldSeedRef,
		RegionAddress.key(address),
		"1",
		"1",
		"1",
		"1",
		"1",
		"intent:commercial-office.late-90s",
		DeterminismContract.encodeParts(topologyAnchors),
		DeterminismContract.encodeParts(canonicalContentKeys),
	})
	local digest = {}
	for _, seed in FINGERPRINT_SEEDS do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hash32(payload, seed)))
	end
	local fingerprint = `resolved-region:v1:{table.concat(digest)}`

	expect("historical v1 region identity oracle remains locked", regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint oracle remains locked",
		fingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	return failures
end

return run
