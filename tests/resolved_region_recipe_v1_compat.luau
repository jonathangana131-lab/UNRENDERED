local DeterminismContract = require("../src/shared/Core/DeterminismContract")
local RegionAddress = require("../src/shared/Spatial/RegionAddress")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"
local HISTORICAL_FINGERPRINT_SEEDS = {
	0x6a09e667,
	0xbb67ae85,
	0x3c6ef372,
	0xa54ff53a,
}

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

local function sortedCopy(values)
	local copy = table.clone(values)
	table.sort(copy)
	return copy
end

local function historicalV1RegionId(candidate)
	return DeterminismContract.stableId("region", {
		candidate.worldSeedRef,
		RegionAddress.key(candidate.regionAddress),
	})
end

local function historicalV1Fingerprint(candidate)
	local anchors = sortedCopy(candidate.topologyAnchors)
	local content = sortedCopy(candidate.canonicalContentKeys)
	local payload = DeterminismContract.encodeParts({
		"resolved-region-recipe",
		"1",
		candidate.worldSeedRef,
		RegionAddress.key(candidate.regionAddress),
		tostring(candidate.generatorVersions.reality),
		tostring(candidate.generatorVersions.topology),
		tostring(candidate.generatorVersions.material),
		tostring(candidate.generatorVersions.object),
		tostring(candidate.generatorVersions.entity),
		candidate.semanticIntentKey,
		DeterminismContract.encodeParts(anchors),
		DeterminismContract.encodeParts(content),
	})
	local digest = {}
	for _, seed in ipairs(HISTORICAL_FINGERPRINT_SEEDS) do
		table.insert(digest, DeterminismContract.hex32(DeterminismContract.hash32(payload, seed)))
	end
	return string.format("resolved-region:v1:%s", table.concat(digest))
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

	-- Schema v1 was retired before persistence because it conflated WorldId and
	-- generation-seed provenance. Keep its exact deterministic vectors as a
	-- historical oracle without asking the current v2 production constructor to
	-- recreate or deserialize that invalid identity model.
	local historical = historicalV1Candidate()
	expect(
		"historical v1 region identity vector remains pinned",
		historicalV1RegionId(historical) == GOLDEN_REGION_ID
	)
	expect(
		"historical v1 recipe fingerprint vector remains pinned",
		historicalV1Fingerprint(historical) == GOLDEN_RECIPE_FINGERPRINT
	)

	local reordered = historicalV1Candidate()
	reordered.topologyAnchors = {
		"anchor:east-primary-threshold",
		"anchor:west-service-threshold",
	}
	reordered.canonicalContentKeys = {
		"fixture:fluorescent-row-a",
		"material:carpet-batch-a",
		"object:chair-a",
	}
	expect(
		"historical v1 fingerprint remains order-independent",
		historicalV1Fingerprint(reordered) == GOLDEN_RECIPE_FINGERPRINT
	)

	local syntheticFuture = historicalV1Candidate()
	syntheticFuture.generatorVersions = {
		reality = 2,
		topology = 2,
		material = 2,
		object = 2,
		entity = 2,
	}
	expect(
		"historical v1 generator drift preserved its seed-derived region identity",
		historicalV1RegionId(syntheticFuture) == GOLDEN_REGION_ID
	)
	expect(
		"historical v1 generator drift changed its exact fingerprint",
		historicalV1Fingerprint(syntheticFuture) ~= GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"historical v1 golden stays unchanged after future-vector evaluation",
		historicalV1Fingerprint(historical) == GOLDEN_RECIPE_FINGERPRINT
	)

	return failures
end

return run
