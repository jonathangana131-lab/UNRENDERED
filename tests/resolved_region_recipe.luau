local StableId = require("../src/shared/Core/StableId")
local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")

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
	local versions = {
		reality = 1,
		topology = 1,
		material = 1,
		object = 1,
		entity = 1,
	}
	local candidate = {
		worldId = worldId,
		worldSeed = "world-seed:shared-canonical-world",
		regionAddress = "office/0/0/0",
		generatorVersions = versions,
		semanticIntentKey = "commercial.office.fallback",
		topologyAnchorKeys = { "exit/east", "entry/west", "service/north" },
		canonicalContentKeys = { "object/front-desk", "fixture/light-row-a", "object/chair-a" },
	}

	local locked, didLock = ResolvedRegionRecipe.lock(nil, candidate)
	expect("first observation locks candidate", didLock)
	expect("resolved recipe is frozen", not pcall(function()
		locked.regionAddress = "changed"
	end))
	expect("nested versions are frozen", not pcall(function()
		locked.generatorVersions.topology = 9
	end))
	expect("anchor array is frozen", not pcall(function()
		table.insert(locked.topologyAnchorKeys, "extra")
	end))
	expectEqual("region id derives from world + address", locked.id, ResolvedRegionRecipe.regionId(worldId, "office/0/0/0"))
	expectEqual("anchors canonicalize into lexical order", locked.topologyAnchorKeys[1], "entry/west")
	expectEqual("content keys canonicalize into lexical order", locked.canonicalContentKeys[1], "fixture/light-row-a")

	candidate.regionAddress = "mutated/outside"
	candidate.generatorVersions.topology = 99
	table.insert(candidate.topologyAnchorKeys, "mutated/anchor")
	expectEqual("locked address owns its input", locked.regionAddress, "office/0/0/0")
	expectEqual("locked versions own their input", locked.generatorVersions.topology, 1)
	expectEqual("locked anchors own their input", #locked.topologyAnchorKeys, 3)

	local plain = ResolvedRegionRecipe.toPlainData(locked)
	local reconstructed = ResolvedRegionRecipe.fromPlainData(plain)
	expect("plain-data round trip is reconstruction-equivalent", ResolvedRegionRecipe.equivalent(locked, reconstructed))
	expectEqual("plain-data round trip preserves fingerprint", ResolvedRegionRecipe.fingerprint(reconstructed), ResolvedRegionRecipe.fingerprint(locked))

	plain.regionAddress = "mutated/serialized-copy"
	plain.generatorVersions.reality = 12
	table.insert(plain.canonicalContentKeys, "object/new")
	expectEqual("serialized copy mutation cannot rewrite locked address", locked.regionAddress, "office/0/0/0")
	expectEqual("serialized copy mutation cannot rewrite locked versions", locked.generatorVersions.reality, 1)
	expectEqual("serialized copy mutation cannot rewrite locked content", #locked.canonicalContentKeys, 3)

	local futureCandidate = {
		worldId = worldId,
		worldSeed = "world-seed:shared-canonical-world",
		regionAddress = "office/0/0/0",
		generatorVersions = {
			reality = 2,
			topology = 7,
			material = 3,
			object = 8,
			entity = 4,
		},
		semanticIntentKey = "commercial.office.reinterpreted",
		topologyAnchorKeys = { "future/anchor" },
		canonicalContentKeys = { "future/content" },
	}
	local relocked, relockChanged = ResolvedRegionRecipe.lock(locked, futureCandidate)
	expect("already observed region does not relock", not relockChanged)
	expect("already observed truth survives generator upgrade candidate", ResolvedRegionRecipe.equivalent(locked, relocked))
	expectEqual("generator upgrade candidate cannot change semantic intent", relocked.semanticIntentKey, "commercial.office.fallback")
	expect(
		"version mismatch is exposed through explicit migration hook",
		ResolvedRegionRecipe.needsMigration(locked, futureCandidate.generatorVersions)
	)
	expect("matching versions do not request migration", not ResolvedRegionRecipe.needsMigration(locked, versions))

	local sameSetDifferentOrder = {
		worldId = worldId,
		worldSeed = "world-seed:shared-canonical-world",
		regionAddress = "office/0/0/0",
		generatorVersions = versions,
		semanticIntentKey = "commercial.office.fallback",
		topologyAnchorKeys = { "service/north", "entry/west", "exit/east" },
		canonicalContentKeys = { "object/chair-a", "object/front-desk", "fixture/light-row-a" },
	}
	local normalized = ResolvedRegionRecipe.new(sameSetDifferentOrder)
	expect("set-like key order cannot perturb canonical reconstruction", ResolvedRegionRecipe.equivalent(locked, normalized))
	expectEqual("set-like key order cannot perturb fingerprint", ResolvedRegionRecipe.fingerprint(locked), ResolvedRegionRecipe.fingerprint(normalized))

	local changedContent = {
		worldId = worldId,
		worldSeed = "world-seed:shared-canonical-world",
		regionAddress = "office/0/0/0",
		generatorVersions = versions,
		semanticIntentKey = "commercial.office.fallback",
		topologyAnchorKeys = { "exit/east", "entry/west", "service/north" },
		canonicalContentKeys = { "object/front-desk", "fixture/light-row-a", "object/chair-b" },
	}
	local changed = ResolvedRegionRecipe.new(changedContent)
	expect("canonical content change changes exact reconstruction", not ResolvedRegionRecipe.equivalent(locked, changed))
	expect("canonical content change changes diagnostic fingerprint", ResolvedRegionRecipe.fingerprint(locked) ~= ResolvedRegionRecipe.fingerprint(changed))

	local deltaStream = {}
	local fingerprintBeforeDelta = ResolvedRegionRecipe.fingerprint(locked)
	table.insert(deltaStream, { kind = "object.moved", entityKey = "object/chair-a" })
	expectEqual(
		"mutable deltas remain outside immutable generated base fingerprint",
		ResolvedRegionRecipe.fingerprint(locked),
		fingerprintBeforeDelta
	)

	local duplicateAccepted = pcall(function()
		ResolvedRegionRecipe.new({
			worldId = worldId,
			worldSeed = "seed",
			regionAddress = "office/dup",
			generatorVersions = versions,
			semanticIntentKey = "commercial.office",
			topologyAnchorKeys = { "entry/a", "entry/a" },
			canonicalContentKeys = {},
		})
	end)
	expect("duplicate canonical keys reject", not duplicateAccepted)

	local invalidWorldAccepted = pcall(function()
		ResolvedRegionRecipe.new({
			worldId = "world:not-a-stable-id",
			worldSeed = "seed",
			regionAddress = "office/invalid-world",
			generatorVersions = versions,
			semanticIntentKey = "commercial.office",
			topologyAnchorKeys = {},
			canonicalContentKeys = {},
		})
	end)
	expect("non-canonical world id rejects", not invalidWorldAccepted)

	local tamperedPlain = ResolvedRegionRecipe.toPlainData(locked)
	tamperedPlain.id = StableId.fromParts("region", { "tampered" })
	local tamperedIdAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(tamperedPlain)
	end)
	expect("persisted region id must match world + address", not tamperedIdAccepted)

	local unknownFieldPlain = ResolvedRegionRecipe.toPlainData(locked)
	unknownFieldPlain.workspaceModel = "Workspace.Region"
	local unknownFieldAccepted = pcall(function()
		ResolvedRegionRecipe.fromPlainData(unknownFieldPlain)
	end)
	expect("unknown representation fields reject at plain-data boundary", not unknownFieldAccepted)

	local nonFiniteVersionAccepted = pcall(function()
		ResolvedRegionRecipe.new({
			worldId = worldId,
			worldSeed = "seed",
			regionAddress = "office/non-finite",
			generatorVersions = {
				reality = 1,
				topology = math.huge,
				material = 1,
				object = 1,
				entity = 1,
			},
			semanticIntentKey = "commercial.office",
			topologyAnchorKeys = {},
			canonicalContentKeys = {},
		})
	end)
	expect("non-finite generator version rejects", not nonFiniteVersionAccepted)

	return failures
end

return run
