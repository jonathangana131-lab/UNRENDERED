local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")
local Versions = require("../src/shared/Core/Versions")

local function requestFixture()
	return {
		worldId = "world:shared-alpha",
		worldSeedRef = "world-seed:shared-alpha:v1",
		address = { x = 12, z = -7, layer = 2 },
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
		semanticIntentKeys = {
			"office.department.general",
			"office.era.late-1990s",
		},
		topologyAnchorKeys = {
			"anchor:service-corridor:east",
			"anchor:reception:west",
		},
		canonicalContentKeys = {
			"object:chair:reception-01",
			"fixture:fluorescent-row:a",
			"surface:carpet:main",
		},
		firstObservationKey = "observation:cohort-a:0001",
	}
end

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS {name}`)
		end
	end

	local current = ResolvedRegionRecipe.currentGeneratorVersions()
	expectEqual("current reality version", current.reality, Versions.Reality)
	expectEqual("current topology version", current.topology, Versions.Topology)
	expectEqual("current material version", current.material, Versions.Material)
	expectEqual("current object version", current.object, Versions.Object)
	expectEqual("current entity version", current.entity, Versions.Entity)

	local request = requestFixture()
	request.semanticIntentKeys = {
		"office.era.late-1990s",
		"office.department.general",
	}
	request.topologyAnchorKeys = {
		"anchor:reception:west",
		"anchor:service-corridor:east",
	}
	request.canonicalContentKeys = {
		"surface:carpet:main",
		"object:chair:reception-01",
		"fixture:fluorescent-row:a",
	}

	local first = ResolvedRegionRecipe.lock(nil, request)
	expectEqual("first observation locks", first.lockedNow, true)
	expectEqual("first candidate matches itself", first.candidateMatches, true)
	expectEqual("region key is canonical", first.recipe.regionKey, "r:12:-7:2")
	expectEqual("semantic keys canonicalize order", first.recipe.semanticIntentKeys[1], "office.department.general")
	expectEqual("topology keys canonicalize order", first.recipe.topologyAnchorKeys[1], "anchor:reception:west")
	expectEqual("content keys canonicalize order", first.recipe.canonicalContentKeys[1], "fixture:fluorescent-row:a")

	request.address.x = 999
	request.generatorVersions.reality = 99
	request.semanticIntentKeys[1] = "mutated"
	expectEqual("locked address is owned", first.recipe.address.x, 12)
	expectEqual("locked versions are owned", first.recipe.generatorVersions.reality, 1)
	expectEqual("locked key lists are owned", first.recipe.semanticIntentKeys[1], "office.department.general")

	local topLevelMutationAccepted = pcall(function()
		first.recipe.worldId = "mutated"
	end)
	expectEqual("locked recipe rejects mutation", topLevelMutationAccepted, false)
	local nestedMutationAccepted = pcall(function()
		first.recipe.generatorVersions.reality = 2
	end)
	expectEqual("locked nested version snapshot rejects mutation", nestedMutationAccepted, false)

	local snapshot = ResolvedRegionRecipe.snapshot(first.recipe)
	local reconstructed = ResolvedRegionRecipe.reconstruct(snapshot)
	expectEqual("snapshot reconstruction equals original", ResolvedRegionRecipe.equal(first.recipe, reconstructed), true)
	expectEqual("snapshot reconstruction preserves fingerprint", reconstructed.fingerprint, first.recipe.fingerprint)
	expectEqual("snapshot reconstruction preserves base fingerprint", reconstructed.baseFingerprint, first.recipe.baseFingerprint)

	snapshot.address.x = 500
	snapshot.generatorVersions.reality = 500
	snapshot.semanticIntentKeys[1] = "mutated-after-reconstruct"
	expectEqual("reconstruction owns address snapshot", reconstructed.address.x, 12)
	expectEqual("reconstruction owns version snapshot", reconstructed.generatorVersions.reality, 1)
	expectEqual("reconstruction owns key snapshot", reconstructed.semanticIntentKeys[1], "office.department.general")

	local reordered = requestFixture()
	reordered.semanticIntentKeys = {
		"office.era.late-1990s",
		"office.department.general",
	}
	reordered.topologyAnchorKeys = {
		"anchor:reception:west",
		"anchor:service-corridor:east",
	}
	reordered.canonicalContentKeys = {
		"surface:carpet:main",
		"fixture:fluorescent-row:a",
		"object:chair:reception-01",
	}
	reordered.firstObservationKey = "observation:cohort-b:9999"
	local second = ResolvedRegionRecipe.lock(first.recipe, reordered)
	expectEqual("second observation does not relock", second.lockedNow, false)
	expectEqual("observation identity does not alter generated-base match", second.candidateMatches, true)
	expectEqual("second observation preserves first observation key", second.recipe.firstObservationKey, first.recipe.firstObservationKey)
	expectEqual("second observation preserves exact locked record", second.recipe.fingerprint, first.recipe.fingerprint)

	local alternateObservation = ResolvedRegionRecipe.lock(nil, reordered).recipe
	expectEqual("same generated recipe has same base fingerprint", ResolvedRegionRecipe.sameBase(first.recipe, alternateObservation), true)
	expectEqual("different first observation produces different locked record", ResolvedRegionRecipe.equal(first.recipe, alternateObservation), false)

	local upgradedCandidate = requestFixture()
	upgradedCandidate.generatorVersions.reality = 2
	local upgradeAttempt = ResolvedRegionRecipe.lock(first.recipe, upgradedCandidate)
	expectEqual("generator upgrade does not rewrite locked region", upgradeAttempt.lockedNow, false)
	expectEqual("generator upgrade reports a different candidate base", upgradeAttempt.candidateMatches, false)
	expectEqual("locked historical version remains v1", upgradeAttempt.recipe.generatorVersions.reality, 1)
	expectEqual("locked historical fingerprint remains unchanged", upgradeAttempt.recipe.fingerprint, first.recipe.fingerprint)

	local migrated = ResolvedRegionRecipe.migrate(first.recipe, {
		migrationKey = "reality.v1-to-v2.test",
		generatorVersions = {
			reality = 2,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
		semanticIntentKeys = first.recipe.semanticIntentKeys,
		topologyAnchorKeys = first.recipe.topologyAnchorKeys,
		canonicalContentKeys = first.recipe.canonicalContentKeys,
	})
	expectEqual("migration preserves region identity", migrated.id, first.recipe.id)
	expectEqual("migration preserves first observation", migrated.firstObservationKey, first.recipe.firstObservationKey)
	expectEqual("migration changes requested version", migrated.generatorVersions.reality, 2)
	expectEqual("migration records source fingerprint", migrated.migration.fromFingerprint, first.recipe.fingerprint)
	expectEqual("migration records key", migrated.migration.key, "reality.v1-to-v2.test")
	expectEqual("migration changes full fingerprint", migrated.fingerprint == first.recipe.fingerprint, false)
	expectEqual("version migration changes generated base", ResolvedRegionRecipe.sameBase(first.recipe, migrated), false)

	local migratedSnapshot = ResolvedRegionRecipe.snapshot(migrated)
	expectEqual("migrated snapshot reconstructs exactly", ResolvedRegionRecipe.equal(migrated, ResolvedRegionRecipe.reconstruct(migratedSnapshot)), true)

	local tampered = ResolvedRegionRecipe.snapshot(first.recipe)
	tampered.generatorVersions.object = 2
	local tamperedAccepted = pcall(function()
		ResolvedRegionRecipe.reconstruct(tampered)
	end)
	expectEqual("reconstruction rejects silent generator-version change", tamperedAccepted, false)

	local duplicateKeys = requestFixture()
	duplicateKeys.canonicalContentKeys = { "content:a", "content:a" }
	local duplicateAccepted = pcall(function()
		ResolvedRegionRecipe.lock(nil, duplicateKeys)
	end)
	expectEqual("lock rejects duplicate canonical keys", duplicateAccepted, false)

	local unsafeAddress = requestFixture()
	unsafeAddress.address.x = 9007199254740992
	local unsafeAccepted = pcall(function()
		ResolvedRegionRecipe.lock(nil, unsafeAddress)
	end)
	expectEqual("lock rejects unsafe region coordinate", unsafeAccepted, false)

	if failures == 0 then
		print("ResolvedRegionRecipe lock tests passed")
	end
	return failures
end

return run
