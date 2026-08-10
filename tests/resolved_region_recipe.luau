local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function hasCode(report, code)
	for _, issue in ipairs(report.issues) do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	local function expectEqual(name, actual, expected)
		expect(name, actual == expected)
		if actual ~= expected then
			print(`  expected {tostring(expected)}, got {tostring(actual)}`)
		end
	end

	local candidate = {
		worldSeed = "world-alpha",
		regionAddress = "office/0/0/0",
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
		semanticIntent = "commercial-office",
		topologyAnchors = { "west-entry", "east-corridor" },
		canonicalContentKeys = { "object.front-desk", "door.entry", "fixture.ceiling-grid" },
	}

	local recipe = ResolvedRegionRecipe.lock(candidate)
	expectEqual(
		"world seed is stored as a deterministic reference",
		recipe.worldSeedRef,
		"world-seed:v1:61f1374cbd3f6fecb68c37e9b6876a97"
	)
	expectEqual(
		"region identity is stable from world seed reference plus address",
		recipe.regionId,
		"world-region:v1:2f14795f9e638557f36d07cc6099292d"
	)
	expectEqual(
		"resolved recipe fingerprint golden",
		recipe.recipeFingerprint,
		"resolved-region-recipe:v1:0ef00e972cca5ec61b46cf0eb6f6b04d"
	)
	expectEqual("topology anchors canonicalize order", recipe.topologyAnchors[1], "east-corridor")
	expectEqual("content keys canonicalize order", recipe.canonicalContentKeys[1], "door.entry")

	local reorderedCandidate = deepCopy(candidate)
	reorderedCandidate.topologyAnchors = { "east-corridor", "west-entry" }
	reorderedCandidate.canonicalContentKeys = { "fixture.ceiling-grid", "object.front-desk", "door.entry" }
	local reordered = ResolvedRegionRecipe.lock(reorderedCandidate)
	expectEqual(
		"candidate traversal order cannot perturb canonical recipe",
		reordered.recipeFingerprint,
		recipe.recipeFingerprint
	)

	local mutationAccepted = pcall(function()
		recipe.semanticIntent = "warehouse"
	end)
	expect("locked recipe rejects mutation", not mutationAccepted)
	local anchorMutationAccepted = pcall(function()
		recipe.topologyAnchors[1] = "changed"
	end)
	expect("locked recipe nested arrays reject mutation", not anchorMutationAccepted)

	local serialized = ResolvedRegionRecipe.toPlainData(recipe)
	local reconstructed = ResolvedRegionRecipe.fromPlainData(serialized)
	expectEqual(
		"plain-data round trip preserves reconstruction fingerprint",
		reconstructed.recipeFingerprint,
		recipe.recipeFingerprint
	)
	expectEqual("plain-data round trip preserves region identity", reconstructed.regionId, recipe.regionId)
	serialized.semanticIntent = "mutated-copy"
	serialized.topologyAnchors[1] = "mutated-copy"
	expectEqual("serialized copy cannot mutate immutable base", recipe.semanticIntent, "commercial-office")
	expectEqual(
		"serialized nested copy cannot mutate immutable base",
		recipe.topologyAnchors[1],
		"east-corridor"
	)

	local tampered = ResolvedRegionRecipe.toPlainData(recipe)
	tampered.semanticIntent = "warehouse"
	local tamperedReport = ResolvedRegionRecipe.inspect(tampered)
	expect(
		"same-version canonical content drift is detected by fingerprint",
		not tamperedReport.ok and hasCode(tamperedReport, "recipe.fingerprint_mismatch")
	)

	local unsorted = ResolvedRegionRecipe.toPlainData(recipe)
	unsorted.topologyAnchors = { "west-entry", "east-corridor" }
	local unsortedReport = ResolvedRegionRecipe.inspect(unsorted)
	expect(
		"serialized recipes require canonical sorted sets",
		not unsortedReport.ok and hasCode(unsortedReport, "array.canonical_order")
	)

	local firstLocked, firstCreated = ResolvedRegionRecipe.resolveFirstObservation(nil, candidate)
	expect("first observation creates canonical truth", firstCreated)
	expectEqual(
		"first observation matches direct lock",
		firstLocked.recipeFingerprint,
		recipe.recipeFingerprint
	)

	local upgradedCandidate = deepCopy(candidate)
	upgradedCandidate.generatorVersions.reality = 2
	upgradedCandidate.semanticIntent = "upgraded-generator-office"
	upgradedCandidate.canonicalContentKeys = { "door.entry", "fixture.new-family" }
	local preserved, secondCreated =
		ResolvedRegionRecipe.resolveFirstObservation(firstLocked, upgradedCandidate)
	expect("later observations do not relock established truth", not secondCreated)
	expectEqual(
		"generator upgrade cannot silently rewrite observed recipe",
		preserved.recipeFingerprint,
		firstLocked.recipeFingerprint
	)
	expectEqual("locked generator version stays established", preserved.generatorVersions.reality, 1)

	local wrongRegion = deepCopy(candidate)
	wrongRegion.regionAddress = "office/0/0/1"
	local acceptedWrongRegion = pcall(function()
		ResolvedRegionRecipe.resolveFirstObservation(firstLocked, wrongRegion)
	end)
	expect("existing lock rejects a different region identity", not acceptedWrongRegion)

	local targetVersions = deepCopy(candidate.generatorVersions)
	targetVersions.reality = 2
	local implicitMigrationAccepted = pcall(function()
		(ResolvedRegionRecipe.migrate :: any)(recipe, targetVersions, nil)
	end)
	expect("generator-version changes require an explicit migration hook", not implicitMigrationAccepted)

	local migrated = ResolvedRegionRecipe.migrate(recipe, targetVersions, function(locked, target)
		expectEqual("migration hook sees immutable established version", locked.generatorVersions.reality, 1)
		expectEqual("migration hook receives requested target version", target.reality, 2)
		return {
			semanticIntent = "commercial-office-reconstructed-v2",
			topologyAnchors = { "west-entry", "east-corridor" },
			canonicalContentKeys = { "fixture.ceiling-grid", "door.entry", "object.front-desk" },
		}
	end)
	expectEqual("explicit migration preserves stable region identity", migrated.regionId, recipe.regionId)
	expectEqual("explicit migration records target version", migrated.generatorVersions.reality, 2)
	expect(
		"explicit migration produces a new recipe fingerprint",
		migrated.recipeFingerprint ~= recipe.recipeFingerprint
	)
	expectEqual("migration does not mutate established source recipe", recipe.generatorVersions.reality, 1)

	local deltaStream = ResolvedRegionRecipe.newDeltaStream(recipe)
	expectEqual("delta stream binds stable region", deltaStream.regionId, recipe.regionId)
	expectEqual(
		"delta stream binds exact immutable base fingerprint",
		deltaStream.baseRecipeFingerprint,
		recipe.recipeFingerprint
	)
	local delta = ResolvedRegionRecipe.appendDelta(
		deltaStream,
		recipe,
		"door.entry.open-state",
		"state-payload:v1:door-entry-open"
	)
	expectEqual("delta stream sequences durable changes", delta.sequence, 1)
	expectEqual("delta stream advances sequence", deltaStream.nextSequence, 2)
	expect(
		"delta stream remains valid after append",
		ResolvedRegionRecipe.inspectDeltaStream(deltaStream, recipe).ok
	)
	expectEqual(
		"mutable deltas do not alter immutable recipe fingerprint",
		recipe.recipeFingerprint,
		"resolved-region-recipe:v1:0ef00e972cca5ec61b46cf0eb6f6b04d"
	)
	local staleAgainstMigrated = ResolvedRegionRecipe.inspectDeltaStream(deltaStream, migrated)
	expect(
		"delta stream cannot silently attach to a migrated base recipe",
		not staleAgainstMigrated.ok and hasCode(staleAgainstMigrated, "delta.base_fingerprint")
	)

	local extraField = ResolvedRegionRecipe.toPlainData(recipe)
	extraField.workspaceInstance = "Part"
	expect(
		"plain-data recipe rejects unknown representation fields",
		not ResolvedRegionRecipe.inspect(extraField).ok
	)

	local duplicateCandidate = deepCopy(candidate)
	duplicateCandidate.canonicalContentKeys = { "door.entry", "door.entry" }
	local duplicateAccepted = pcall(function()
		ResolvedRegionRecipe.lock(duplicateCandidate)
	end)
	expect("candidate rejects duplicate canonical content keys", not duplicateAccepted)

	return failures
end

return run
