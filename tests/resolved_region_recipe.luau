local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")
local RealityVersions = ProductionLoader.requireShared("Reality/RealityVersions")

local GOLDEN_REGION_ID = "region:v1:7cd90883b952e7534e6f3ffdd71d66a7"
local GOLDEN_RECIPE_FINGERPRINT = "resolved-region:v1:6448a82dcdebe20b03d9a6a98847bdd7"

local function makeVersions()
	local current = RealityVersions.current()
	return {
		reality = current.reality,
		topology = current.topology,
		material = current.material,
		object = current.object,
		entity = current.entity,
	}
end

local function makeCandidate()
	return {
		worldSeedRef = "world-seed:office-alpha",
		regionAddress = RegionAddress.new(12, -4, 1),
		generatorVersions = makeVersions(),
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

	local candidate = makeCandidate()
	local locked = ResolvedRegionRecipe.resolveOnObservation(nil, candidate)

	expect("first observation creates schema-v1 locked recipe", locked.schemaVersion == 1)
	expect("v1 region identity stays golden-locked", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"v1 recipe fingerprint stays golden-locked",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)
	expect(
		"lock snapshots current reality version",
		locked.generatorVersions.reality == candidate.generatorVersions.reality
	)
	expect(
		"topology anchors canonicalize independently of input order",
		locked.topologyAnchors[1] == "anchor:east-primary-threshold"
			and locked.topologyAnchors[2] == "anchor:west-service-threshold"
	)
	expect(
		"canonical content keys are sorted",
		locked.canonicalContentKeys[1] == "fixture:fluorescent-row-a"
			and locked.canonicalContentKeys[2] == "material:carpet-batch-a"
			and locked.canonicalContentKeys[3] == "object:chair-a"
	)
	expect(
		"resolved base recipe is immutable",
		rejects(function()
			locked.semanticIntentKey = "intent:mutated"
		end)
	)
	expect(
		"resolved nested version snapshot is immutable",
		rejects(function()
			locked.generatorVersions.reality += 1
		end)
	)

	local repeated = ResolvedRegionRecipe.lock(makeCandidate())
	expect("identical candidate reconstructs equal truth", ResolvedRegionRecipe.equal(locked, repeated))
	expect(
		"identical candidate reconstructs identical fingerprint",
		ResolvedRegionRecipe.fingerprint(locked) == ResolvedRegionRecipe.fingerprint(repeated)
	)

	local reordered = makeCandidate()
	reordered.topologyAnchors = {
		"anchor:east-primary-threshold",
		"anchor:west-service-threshold",
	}
	reordered.canonicalContentKeys = {
		"fixture:fluorescent-row-a",
		"object:chair-a",
		"material:carpet-batch-a",
	}
	local reorderedLocked = ResolvedRegionRecipe.lock(reordered)
	expect(
		"set ordering cannot perturb canonical recipe",
		ResolvedRegionRecipe.equal(locked, reorderedLocked)
	)

	local changedContent = makeCandidate()
	changedContent.semanticIntentKey = "intent:commercial-office.renovated"
	local changedLocked = ResolvedRegionRecipe.lock(changedContent)
	expect("content revisions preserve stable region identity", changedLocked.regionId == locked.regionId)
	expect(
		"content revisions change deterministic fingerprint",
		changedLocked.recipeFingerprint ~= locked.recipeFingerprint
	)
	expect(
		"content revisions are not reconstruction-equal",
		not ResolvedRegionRecipe.equal(changedLocked, locked)
	)

	local serialized = ResolvedRegionRecipe.serialize(locked)
	local reconstructed = ResolvedRegionRecipe.deserialize(serialized)
	expect(
		"serialize-deserialize reconstructs equal recipe",
		ResolvedRegionRecipe.equal(locked, reconstructed)
	)
	expect("round trip preserves region identity", reconstructed.regionId == locked.regionId)
	expect("round trip preserves fingerprint", reconstructed.recipeFingerprint == locked.recipeFingerprint)

	serialized.semanticIntentKey = "intent:tampered-after-storage"
	expect(
		"deserialize rejects stored content that no longer matches fingerprint",
		rejects(function()
			ResolvedRegionRecipe.deserialize(serialized)
		end)
	)

	local unknownField = ResolvedRegionRecipe.serialize(locked)
	unknownField.workspaceModel = "forbidden"
	expect(
		"deserialize rejects unknown representation fields",
		rejects(function()
			ResolvedRegionRecipe.deserialize(unknownField)
		end)
	)

	local deltaField = ResolvedRegionRecipe.serialize(locked)
	deltaField.deltaRefs = { "delta:door-open:0001" }
	expect(
		"generated base rejects embedded mutable delta state",
		rejects(function()
			ResolvedRegionRecipe.deserialize(deltaField)
		end)
	)

	local nextGeneratorCandidate = makeCandidate()
	nextGeneratorCandidate.generatorVersions.reality += 1
	nextGeneratorCandidate.semanticIntentKey = "intent:new-generator-output"
	nextGeneratorCandidate.canonicalContentKeys = { "object:new-generator-chair" }
	local observedAgain = ResolvedRegionRecipe.resolveOnObservation(locked, nextGeneratorCandidate)
	expect(
		"later observation preserves first locked recipe",
		ResolvedRegionRecipe.equal(observedAgain, locked)
	)
	expect(
		"generator upgrade cannot silently rewrite locked version",
		observedAgain.generatorVersions.reality == locked.generatorVersions.reality
	)
	expect(
		"generator upgrade cannot silently rewrite content",
		observedAgain.semanticIntentKey == locked.semanticIntentKey
	)

	local malformedFutureCandidate = {
		worldSeedRef = candidate.worldSeedRef,
		regionAddress = candidate.regionAddress,
		generatorVersions = {
			reality = math.huge,
		},
		semanticIntentKey = "",
		topologyAnchors = { "anchor:duplicate", "anchor:duplicate" },
		canonicalContentKeys = "not-an-array",
	}
	local observedThroughMalformedFuture = ResolvedRegionRecipe.resolveOnObservation(
		locked,
		malformedFutureCandidate
	)
	expect(
		"established truth ignores malformed future generator content",
		ResolvedRegionRecipe.equal(observedThroughMalformedFuture, locked)
	)

	local wrongRegionCandidate = makeCandidate()
	wrongRegionCandidate.regionAddress = RegionAddress.new(13, -4, 1)
	expect(
		"locked recipe cannot be reused for a different region address",
		rejects(function()
			ResolvedRegionRecipe.resolveOnObservation(locked, wrongRegionCandidate)
		end)
	)

	local wrongWorldCandidate = makeCandidate()
	wrongWorldCandidate.worldSeedRef = "world-seed:other-world"
	expect(
		"locked recipe cannot be reused for a different world seed reference",
		rejects(function()
			ResolvedRegionRecipe.resolveOnObservation(locked, wrongWorldCandidate)
		end)
	)

	local duplicateAnchors = makeCandidate()
	duplicateAnchors.topologyAnchors = { "anchor:a", "anchor:a" }
	expect(
		"candidate rejects duplicate topology anchors",
		rejects(function()
			ResolvedRegionRecipe.lock(duplicateAnchors)
		end)
	)

	local sparseContent = makeCandidate()
	sparseContent.canonicalContentKeys = {
		[1] = "object:a",
		[3] = "object:c",
	}
	expect(
		"candidate rejects sparse content arrays",
		rejects(function()
			ResolvedRegionRecipe.lock(sparseContent)
		end)
	)

	local extraCandidateField = makeCandidate()
	extraCandidateField.workspace = {}
	expect(
		"candidate exact shape rejects physical representation data",
		rejects(function()
			ResolvedRegionRecipe.lock(extraCandidateField)
		end)
	)

	local targetVersions = makeVersions()
	targetVersions.reality += 1
	expect(
		"locked recipe reports explicit migration requirement",
		ResolvedRegionRecipe.requiresMigration(locked, targetVersions)
	)

	local migrated, receipt = ResolvedRegionRecipe.migrate(
		locked,
		targetVersions,
		"migration:reality-v1-to-v2",
		function(source, target)
			return {
				worldSeedRef = source.worldSeedRef,
				regionAddress = source.regionAddress,
				generatorVersions = target,
				semanticIntentKey = "intent:commercial-office.migrated-v2",
				topologyAnchors = source.topologyAnchors,
				canonicalContentKeys = {
					"fixture:fluorescent-row-a",
					"material:carpet-batch-a",
					"object:chair-a-v2",
				},
			}
		end
	)
	expect("explicit migration preserves stable region identity", migrated.regionId == locked.regionId)
	expect(
		"explicit migration advances exact target version",
		migrated.generatorVersions.reality == targetVersions.reality
	)
	expect(
		"explicit migration changes recipe fingerprint",
		migrated.recipeFingerprint ~= locked.recipeFingerprint
	)
	expect(
		"explicit migration clears migration requirement",
		not ResolvedRegionRecipe.requiresMigration(migrated, targetVersions)
	)
	expect(
		"migration receipt records source fingerprint",
		receipt.sourceFingerprint == locked.recipeFingerprint
	)
	expect(
		"migration receipt records target fingerprint",
		receipt.targetFingerprint == migrated.recipeFingerprint
	)
	expect(
		"migration receipt records explicit migration key",
		receipt.migrationKey == "migration:reality-v1-to-v2"
	)

	expect(
		"migration refuses unchanged version snapshots",
		rejects(function()
			ResolvedRegionRecipe.migrate(locked, makeVersions(), "migration:no-op", function(source, target)
				return {
					worldSeedRef = source.worldSeedRef,
					regionAddress = source.regionAddress,
					generatorVersions = target,
					semanticIntentKey = source.semanticIntentKey,
					topologyAnchors = source.topologyAnchors,
					canonicalContentKeys = source.canonicalContentKeys,
				}
			end)
		end)
	)

	expect(
		"migration builder cannot redirect stable region identity",
		rejects(function()
			ResolvedRegionRecipe.migrate(
				locked,
				targetVersions,
				"migration:bad-address",
				function(source, target)
					return {
						worldSeedRef = source.worldSeedRef,
						regionAddress = RegionAddress.new(99, 99, 0),
						generatorVersions = target,
						semanticIntentKey = source.semanticIntentKey,
						topologyAnchors = source.topologyAnchors,
						canonicalContentKeys = source.canonicalContentKeys,
					}
				end
			)
		end)
	)

	local reproKey = ResolvedRegionRecipe.reproKey(locked)
	expect("repro key carries region identity", string.find(reproKey, locked.regionId, 1, true) ~= nil)
	expect(
		"repro key carries exact recipe fingerprint",
		string.find(reproKey, locked.recipeFingerprint, 1, true) ~= nil
	)

	return failures
end

return run
