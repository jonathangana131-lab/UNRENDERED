local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipeV1 = ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1")
local ResolvedRegionRecipeV1Internal =
	ProductionLoader.requireShared("Reality/ResolvedRegionRecipeV1Internal")

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

	local function rejects(callback): boolean
		return not pcall(callback)
	end

	-- This fixture is literal already-observed v1 truth. The public legacy
	-- boundary is replay-only: it can reconstruct accepted history but cannot
	-- create new v1 canonical locks.
	local sourcePayload = historicalV1Serialized()
	local locked = ResolvedRegionRecipeV1.deserialize(sourcePayload)

	expect("legacy v1 public boundary is replay-only", ResolvedRegionRecipeV1.REPLAY_ONLY == true)
	expect("legacy v1 public boundary exposes no lock constructor", ResolvedRegionRecipeV1.lock == nil)
	expect("legacy v1 internal core exposes no lock constructor", ResolvedRegionRecipeV1Internal.lock == nil)
	expect(
		"legacy v1 internal core exposes no observation or migration write path",
		ResolvedRegionRecipeV1Internal.resolveOnObservation == nil
			and ResolvedRegionRecipeV1Internal.migrate == nil
	)
	expect("historical v1 region identity remains compatible", locked.regionId == GOLDEN_REGION_ID)
	expect(
		"historical v1 recipe fingerprint remains compatible",
		locked.recipeFingerprint == GOLDEN_RECIPE_FINGERPRINT
	)

	-- Replay owns the payload it accepts. Mutating a caller-owned decoded
	-- record after deserialization must never rewrite already-accepted truth.
	sourcePayload.regionAddress.x = 999
	sourcePayload.generatorVersions.reality = 2
	sourcePayload.topologyAnchors[1] = "anchor:mutated-after-replay"
	sourcePayload.canonicalContentKeys[1] = "object:mutated-after-replay"
	expect("v1 replay owns region-address input", locked.regionAddress.x == 12)
	expect("v1 replay owns generator-version input", locked.generatorVersions.reality == 1)
	expect(
		"v1 replay owns topology-anchor input",
		locked.topologyAnchors[1] == "anchor:east-primary-threshold"
	)
	expect(
		"v1 replay owns canonical-content input",
		locked.canonicalContentKeys[1] == "fixture:fluorescent-row-a"
	)

	expect(
		"accepted v1 replay truth is immutable",
		rejects(function()
			locked.semanticIntentKey = "intent:mutated"
		end)
	)
	expect(
		"accepted v1 replay nested truth is immutable",
		rejects(function()
			locked.generatorVersions.reality = 2
		end)
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

	-- Serialization must also detach its mutable transport record from the
	-- immutable replay recipe retained by the domain layer.
	serialized.regionAddress.x = 777
	serialized.generatorVersions.topology = 2
	serialized.topologyAnchors[1] = "anchor:transport-mutation"
	serialized.canonicalContentKeys[1] = "object:transport-mutation"
	expect("v1 serialize detaches region-address transport", locked.regionAddress.x == 12)
	expect("v1 serialize detaches version transport", locked.generatorVersions.topology == 1)
	expect(
		"v1 serialize detaches topology-anchor transport",
		locked.topologyAnchors[1] == "anchor:east-primary-threshold"
	)
	expect(
		"v1 serialize detaches canonical-content transport",
		locked.canonicalContentKeys[1] == "fixture:fluorescent-row-a"
	)

	local injectedWorldId = historicalV1Serialized()
	injectedWorldId.worldId = "world:v1:b2eccb898b0d09866a4df94d651fda4f"
	expect(
		"legacy v1 replay rejects injected WorldId instead of reinterpreting identity",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(injectedWorldId)
		end)
	)

	local tamperedRegionId = historicalV1Serialized()
	tamperedRegionId.regionId = "region:v1:1841ffe5f321ed0511919940bd21a6ff"
	expect(
		"legacy v1 replay rejects tampered region identity",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(tamperedRegionId)
		end)
	)

	local tamperedFingerprint = historicalV1Serialized()
	tamperedFingerprint.semanticIntentKey = "intent:tampered-history"
	expect(
		"legacy v1 replay rejects content that no longer matches historical fingerprint",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(tamperedFingerprint)
		end)
	)

	local unknownField = historicalV1Serialized()
	unknownField.workspaceModel = "forbidden"
	expect(
		"legacy v1 replay rejects unknown representation fields",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(unknownField)
		end)
	)

	local metatablePayload = historicalV1Serialized()
	setmetatable(metatablePayload.regionAddress, {})
	expect(
		"legacy v1 replay rejects metatable-backed nested records",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(metatablePayload)
		end)
	)

	local nonFiniteVersion = historicalV1Serialized()
	nonFiniteVersion.generatorVersions.entity = math.huge
	expect(
		"legacy v1 replay rejects non-finite historical generator versions",
		rejects(function()
			ResolvedRegionRecipeV1.deserialize(nonFiniteVersion)
		end)
	)

	return failures
end

return run
