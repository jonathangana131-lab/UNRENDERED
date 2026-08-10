local StableId = require("../src/shared/Core/StableId")
local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")
local RegionAddress = require("../src/shared/Spatial/RegionAddress")

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
	end

	local worldId = StableId.fromParts("world", { "shared-canonical-world" })
	local otherWorldId = StableId.fromParts("world", { "other-canonical-world" })
	local versions = {
		reality = 1,
		topology = 1,
		material = 1,
		object = 1,
		entity = 1,
	}

	local function makeCandidate()
		return {
			worldId = worldId,
			worldSeed = "world-seed:shared-canonical-world",
			regionAddress = { x = 0, z = 0, layer = 0 },
			generatorVersions = {
				reality = 1,
				topology = 1,
				material = 1,
				object = 1,
				entity = 1,
			},
			semanticIntentKey = "commercial.office.fallback",
			topologyAnchorKeys = { "exit/east", "entry/west", "service/north" },
			canonicalContentKeys = { "object/front-desk", "fixture/light-row-a", "object/chair-a" },
		}
	end

	local function potentialFromResolved(recipe)
		local plain = ResolvedRegionRecipe.toPlainData(recipe)
		plain.schemaVersion = nil
		plain.id = nil
		return plain
	end

	local candidate = makeCandidate()
	local locked, lockDisposition = ResolvedRegionRecipe.lock(nil, candidate)
	expectEqual("first observation reports a new lock", lockDisposition, "locked")
	expect("resolved recipe is frozen", not pcall(function()
		locked.worldSeed = "changed"
	end))
	expect("nested region address is frozen", not pcall(function()
		locked.regionAddress.x = 9
	end))
	expect("nested versions are frozen", not pcall(function()
		locked.generatorVersions.topology = 9
	end))
	expect("anchor array is frozen", not pcall(function()
		table.insert(locked.topologyAnchorKeys, "extra")
	end))
	expectEqual(
		"canonical spatial key comes from RegionAddress",
		RegionAddress.key(locked.regionAddress),
		"r:0:0:0"
	)
	expectEqual(
		"region id derives from world + canonical RegionAddress",
		locked.id,
		ResolvedRegionRecipe.regionId(worldId, { x = 0, z = 0, layer = 0 })
	)
	expectEqual("anchors canonicalize into lexical order", locked.topologyAnchorKeys[1], "entry/west")
	expectEqual(
		"content keys canonicalize into lexical order",
		locked.canonicalContentKeys[1],
		"fixture/light-row-a"
	)

	candidate.regionAddress.x = 99
	candidate.generatorVersions.topology = 99
	table.insert(candidate.topologyAnchorKeys, "mutated/anchor")
	expectEqual("locked address owns its input", locked.regionAddress.x, 0)
	expectEqual("locked versions own their input", locked.generatorVersions.topology, 1)
	expectEqual("locked anchors own their input", #locked.topologyAnchorKeys, 3)

	local plain = ResolvedRegionRecipe.toPlainData(locked)
	local reconstructed = ResolvedRegionRecipe.fromPlainData(plain)
	expect(
		"plain-data round trip is reconstruction-equivalent",
		ResolvedRegionRecipe.equivalent(locked, reconstructed)
	)
	expectEqual(
		"plain-data round trip preserves fingerprint",
		ResolvedRegionRecipe.fingerprint(reconstructed),
		ResolvedRegionRecipe.fingerprint(locked)
	)

	plain.regionAddress.x = 12
	plain.generatorVersions.reality = 12
	table.insert(plain.canonicalContentKeys, "object/new")
	expectEqual("serialized copy mutation cannot rewrite locked address", locked.regionAddress.x, 0)
	expectEqual(
		"serialized copy mutation cannot rewrite locked versions",
		locked.generatorVersions.reality,
		1
	)
	expectEqual("serialized copy mutation cannot rewrite locked content", #locked.canonicalContentKeys, 3)

	local exactCandidate = makeCandidate()
	local exactRelock, exactDisposition = ResolvedRegionRecipe.lock(locked, exactCandidate)
	expectEqual("same observed candidate reports an existing match", exactDisposition, "existing-match")
	expect(
		"same observed candidate preserves locked truth",
		ResolvedRegionRecipe.equivalent(locked, exactRelock)
	)

	local futureCandidate = makeCandidate()
	futureCandidate.generatorVersions = {
		reality = 2,
		topology = 7,
		material = 3,
		object = 8,
		entity = 4,
	}
	futureCandidate.semanticIntentKey = "commercial.office.reinterpreted"
	futureCandidate.topologyAnchorKeys = { "future/anchor" }
	futureCandidate.canonicalContentKeys = { "future/content" }
	local relocked, conflictDisposition = ResolvedRegionRecipe.lock(locked, futureCandidate)
	expectEqual(
		"same identity with changed generation reports conflict",
		conflictDisposition,
		"existing-conflict"
	)
	expect(
		"already observed truth survives generator upgrade candidate",
		ResolvedRegionRecipe.equivalent(locked, relocked)
	)
	expectEqual(
		"generator upgrade candidate cannot change semantic intent",
		relocked.semanticIntentKey,
		"commercial.office.fallback"
	)
	expect(
		"version mismatch is exposed before migration",
		ResolvedRegionRecipe.needsMigration(locked, futureCandidate.generatorVersions)
	)
	expect(
		"matching versions do not request migration",
		not ResolvedRegionRecipe.needsMigration(locked, versions)
	)

	local crossRegionCandidate = makeCandidate()
	crossRegionCandidate.regionAddress = { x = 1, z = 0, layer = 0 }
	local crossRegionAccepted = pcall(function()
		ResolvedRegionRecipe.lock(locked, crossRegionCandidate)
	end)
	expect("relock rejects a different RegionAddress", not crossRegionAccepted)

	local crossWorldCandidate = makeCandidate()
	crossWorldCandidate.worldId = otherWorldId
	local crossWorldAccepted = pcall(function()
		ResolvedRegionRecipe.lock(locked, crossWorldCandidate)
	end)
	expect("relock rejects a different WorldId", not crossWorldAccepted)

	local sameSetDifferentOrder = makeCandidate()
	sameSetDifferentOrder.topologyAnchorKeys = { "service/north", "entry/west", "exit/east" }
	sameSetDifferentOrder.canonicalContentKeys = {
		"object/chair-a",
		"object/front-desk",
		"fixture/light-row-a",
	}
	local normalized = ResolvedRegionRecipe.new(sameSetDifferentOrder)
	expect(
		"set-like key order cannot perturb canonical reconstruction",
		ResolvedRegionRecipe.equivalent(locked, normalized)
	)
	expectEqual(
		"set-like key order cannot perturb fingerprint",
		ResolvedRegionRecipe.fingerprint(locked),
		ResolvedRegionRecipe.fingerprint(normalized)
	)

	local changedContent = makeCandidate()
	changedContent.canonicalContentKeys = {
		"object/front-desk",
		"fixture/light-row-a",
		"object/chair-b",
	}
	local changed = ResolvedRegionRecipe.new(changedContent)
	expect(
		"canonical content change changes exact reconstruction",
		not ResolvedRegionRecipe.equivalent(locked, changed)
	)
	expect(
		"canonical content change changes diagnostic fingerprint",
		ResolvedRegionRecipe.fingerprint(locked) ~= ResolvedRegionRecipe.fingerprint(changed)
	)

	local basePlain = ResolvedRegionRecipe.toPlainData(locked)
	expect("generated-base serialization contains no mutable delta field", basePlain.mutableDeltas == nil)
	basePlain.mutableDeltas = { { kind = "object.moved" } }
	local deltaFieldAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(basePlain)
	end)
	expect("generated-base boundary rejects mutable delta state", not deltaFieldAccepted)

	local plan = ResolvedRegionRecipe.planMigration(locked, futureCandidate.generatorVersions)
	expect("version mismatch creates an explicit migration plan", plan ~= nil)
	if plan ~= nil then
		expectEqual(
			"migration plan preserves source fingerprint provenance",
			plan.sourceFingerprint,
			ResolvedRegionRecipe.fingerprint(locked)
		)
		expectEqual("migration plan preserves source version provenance", plan.sourceVersions.reality, 1)
		expectEqual("migration plan records target versions", plan.targetVersions.reality, 2)

		local migration = ResolvedRegionRecipe.runMigration(plan, function(source, targetVersions)
			local output = makeCandidate()
			output.worldId = source.worldId
			output.regionAddress = RegionAddress.toPlainData(source.regionAddress)
			output.generatorVersions = {
				reality = targetVersions.reality,
				topology = targetVersions.topology,
				material = targetVersions.material,
				object = targetVersions.object,
				entity = targetVersions.entity,
			}
			output.semanticIntentKey = "commercial.office.migrated"
			return output
		end)
		expectEqual(
			"migration result keeps source fingerprint provenance",
			migration.sourceFingerprint,
			ResolvedRegionRecipe.fingerprint(locked)
		)
		expectEqual("migration result uses target versions", migration.target.generatorVersions.reality, 2)
		expectEqual("migration result preserves canonical region identity", migration.target.id, locked.id)
		expectEqual("migration does not mutate stored source truth", locked.generatorVersions.reality, 1)

		local _, postMigrationDisposition =
			ResolvedRegionRecipe.lock(locked, potentialFromResolved(migration.target))
		expectEqual(
			"ordinary observation still preserves source until caller explicitly persists migration",
			postMigrationDisposition,
			"existing-conflict"
		)

		local crossIdentityMigrationAccepted = pcall(function()
			ResolvedRegionRecipe.runMigration(plan, function(source, targetVersions)
				local output = makeCandidate()
				output.worldId = source.worldId
				output.regionAddress = {
					x = source.regionAddress.x + 1,
					z = source.regionAddress.z,
					layer = source.regionAddress.layer,
				}
				output.generatorVersions = {
					reality = targetVersions.reality,
					topology = targetVersions.topology,
					material = targetVersions.material,
					object = targetVersions.object,
					entity = targetVersions.entity,
				}
				return output
			end)
		end)
		expect("migration hook rejects a changed region identity", not crossIdentityMigrationAccepted)
	end

	expect(
		"matching versions create no migration plan",
		ResolvedRegionRecipe.planMigration(locked, versions) == nil
	)

	local duplicateCandidate = makeCandidate()
	duplicateCandidate.topologyAnchorKeys = { "entry/a", "entry/a" }
	local duplicateAccepted = pcall(function()
		ResolvedRegionRecipe.new(duplicateCandidate)
	end)
	expect("duplicate canonical keys reject", not duplicateAccepted)

	local invalidWorldCandidate = makeCandidate()
	invalidWorldCandidate.worldId = "world:not-a-stable-id"
	local invalidWorldAccepted = pcall(function()
		ResolvedRegionRecipe.new(invalidWorldCandidate)
	end)
	expect("non-canonical world id rejects", not invalidWorldAccepted)

	local stringAddressCandidate = makeCandidate()
	stringAddressCandidate.regionAddress = "office/0/0/0"
	local stringAddressAccepted = pcall(function()
		ResolvedRegionRecipe.new(stringAddressCandidate)
	end)
	expect("free-form string region addresses reject", not stringAddressAccepted)

	local unknownPotential = makeCandidate()
	unknownPotential.workspaceModel = "Workspace.Region"
	local unknownPotentialAccepted = pcall(function()
		ResolvedRegionRecipe.new(unknownPotential)
	end)
	expect("potential recipe rejects unknown representation fields", not unknownPotentialAccepted)

	local metatablePotential = setmetatable({}, {
		__index = makeCandidate(),
	})
	local metatablePotentialAccepted = pcall(function()
		ResolvedRegionRecipe.new(metatablePotential)
	end)
	expect("potential recipe rejects metatable-backed synthetic fields", not metatablePotentialAccepted)

	local tamperedPlain = ResolvedRegionRecipe.toPlainData(locked)
	tamperedPlain.id = StableId.fromParts("region", { "tampered" })
	local tamperedIdAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(tamperedPlain)
	end)
	expect("persisted region id must match world + address", not tamperedIdAccepted)

	local unknownFieldPlain = ResolvedRegionRecipe.toPlainData(locked)
	unknownFieldPlain.runtimeState = { observedBy = "player" }
	local unknownFieldAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(unknownFieldPlain)
	end)
	expect("resolved generated base rejects runtime state fields", not unknownFieldAccepted)

	local extraAddressField = ResolvedRegionRecipe.toPlainData(locked)
	extraAddressField.regionAddress.semantic = "office"
	local extraAddressAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(extraAddressField)
	end)
	expect("RegionAddress snapshot rejects competing address metadata", not extraAddressAccepted)

	local metatableAddressCandidate = makeCandidate()
	metatableAddressCandidate.regionAddress = setmetatable({}, {
		__index = { x = 0, z = 0, layer = 0 },
	})
	local metatableAddressAccepted = pcall(function()
		ResolvedRegionRecipe.new(metatableAddressCandidate)
	end)
	expect("RegionAddress rejects metatable-backed coordinates", not metatableAddressAccepted)

	local unsafeCoordinateAccepted = pcall(function()
		RegionAddress.new(math.huge, 0, 0)
	end)
	expect("RegionAddress rejects non-finite coordinates", not unsafeCoordinateAccepted)

	local nonFiniteVersionCandidate = makeCandidate()
	nonFiniteVersionCandidate.generatorVersions.topology = math.huge
	local nonFiniteVersionAccepted = pcall(function()
		ResolvedRegionRecipe.new(nonFiniteVersionCandidate)
	end)
	expect("non-finite generator version rejects", not nonFiniteVersionAccepted)

	return failures
end

return run
