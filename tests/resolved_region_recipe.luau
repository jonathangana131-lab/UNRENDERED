local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")
local StableId = require("../src/shared/Core/StableId")

local WORLD_ID = StableId.fromParts("world", { "shared-alpha" })

local function deepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] ~= nil then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, nested in pairs(value) do
		copy[deepCopy(key, seen)] = deepCopy(nested, seen)
	end
	return copy
end

local function baseInput()
	return {
		worldId = WORLD_ID,
		worldSeedRef = "seed-ref:shared-alpha:v1",
		regionAddress = { x = -12, z = 44, layer = 0 },
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
		semanticIntent = "commercial-office.fallback",
		topologyAnchorKeys = {
			"exit:east/service-corridor",
			"entry:west/reception",
		},
		canonicalContentKeys = {
			"object:front-desk",
			"material:carpet/main",
			"fixture:ceiling-grid/a",
		},
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

	local function expect(name, condition)
		expectEqual(name, condition, true)
	end

	local source = baseInput()
	local locked = ResolvedRegionRecipe.lockFirstObservation(source)
	expectEqual("resolved schema version is explicit", locked.schemaVersion, 1)
	expect("region identity is canonical StableId", string.match(locked.regionId, "^region:v1:") ~= nil)
	expect(
		"recipe fingerprint is separately versioned StableId",
		string.match(locked.fingerprint, "^resolved%-region%-recipe:v1:") ~= nil
	)
	expectEqual("topology keys canonicalize lexically", locked.topologyAnchorKeys[1], "entry:west/reception")
	expectEqual(
		"content keys canonicalize lexically",
		locked.canonicalContentKeys[1],
		"fixture:ceiling-grid/a"
	)

	source.worldId = "world:mutated"
	source.regionAddress.x = 999
	source.generatorVersions.reality = 99
	source.topologyAnchorKeys[1] = "mutated"
	source.canonicalContentKeys[1] = "mutated"
	expectEqual("lock defensively copies world identity", locked.worldId, WORLD_ID)
	expectEqual("lock defensively copies address", locked.regionAddress.x, -12)
	expectEqual("lock defensively copies versions", locked.generatorVersions.reality, 1)
	expectEqual("lock defensively copies anchor set", locked.topologyAnchorKeys[1], "entry:west/reception")

	local nestedMutationAccepted = pcall(function()
		locked.generatorVersions.reality = 2
	end)
	expectEqual("locked generator versions reject mutation", nestedMutationAccepted, false)
	local anchorMutationAccepted = pcall(function()
		locked.topologyAnchorKeys[1] = "changed"
	end)
	expectEqual("locked topology keys reject mutation", anchorMutationAccepted, false)

	local reorderedInput = baseInput()
	reorderedInput.topologyAnchorKeys = {
		"entry:west/reception",
		"exit:east/service-corridor",
	}
	reorderedInput.canonicalContentKeys = {
		"fixture:ceiling-grid/a",
		"material:carpet/main",
		"object:front-desk",
	}
	local reordered = ResolvedRegionRecipe.lockFirstObservation(reorderedInput)
	expectEqual("set traversal order cannot change region identity", reordered.regionId, locked.regionId)
	expectEqual(
		"set traversal order cannot change recipe fingerprint",
		reordered.fingerprint,
		locked.fingerprint
	)
	expect("canonical equality ignores input set order", ResolvedRegionRecipe.equals(locked, reordered))

	local changedContentInput = baseInput()
	changedContentInput.canonicalContentKeys[1] = "object:different-chair"
	local changedContent = ResolvedRegionRecipe.lockFirstObservation(changedContentInput)
	expectEqual("content changes do not change region identity", changedContent.regionId, locked.regionId)
	expect("content changes alter recipe fingerprint", changedContent.fingerprint ~= locked.fingerprint)

	local initiallyResolved = ResolvedRegionRecipe.resolveFirstObservation(nil, baseInput())
	expectEqual(
		"empty first-observation state locks the candidate",
		initiallyResolved.fingerprint,
		locked.fingerprint
	)

	local exactRepeat = ResolvedRegionRecipe.resolveFirstObservation(locked, baseInput())
	expectEqual(
		"exact repeat preserves first observed fingerprint",
		exactRepeat.fingerprint,
		locked.fingerprint
	)

	local futureCandidateInput = baseInput()
	futureCandidateInput.generatorVersions.reality = 2
	futureCandidateInput.canonicalContentKeys[1] = "object:future-chair"
	local futureResolved = ResolvedRegionRecipe.resolveFirstObservation(locked, futureCandidateInput)
	expectEqual(
		"later generator/content candidate cannot rewrite observed truth",
		futureResolved.fingerprint,
		locked.fingerprint
	)
	expectEqual(
		"later candidate cannot rewrite locked reality version",
		futureResolved.generatorVersions.reality,
		1
	)

	local wrongSeedInput = baseInput()
	wrongSeedInput.worldSeedRef = "seed-ref:different:v1"
	local wrongSeedAccepted = pcall(function()
		ResolvedRegionRecipe.resolveFirstObservation(locked, wrongSeedInput)
	end)
	expectEqual("relock rejects a different world seed", wrongSeedAccepted, false)

	local wrongRegionInput = baseInput()
	wrongRegionInput.regionAddress.x += 1
	local wrongRegionAccepted = pcall(function()
		ResolvedRegionRecipe.resolveFirstObservation(locked, wrongRegionInput)
	end)
	expectEqual("relock rejects a different region", wrongRegionAccepted, false)

	local serialized = ResolvedRegionRecipe.serialize(locked)
	local reconstructed = ResolvedRegionRecipe.deserialize(serialized)
	expect(
		"plain-data round trip preserves canonical equality",
		ResolvedRegionRecipe.equals(locked, reconstructed)
	)
	expectEqual("round trip preserves exact fingerprint", reconstructed.fingerprint, locked.fingerprint)

	local relocked = ResolvedRegionRecipe.lockFirstObservation(ResolvedRegionRecipe.lockInput(locked))
	expectEqual(
		"stored lock input deterministically reconstructs recipe",
		relocked.fingerprint,
		locked.fingerprint
	)

	local tampered = deepCopy(serialized)
	tampered.generatorVersions.reality = 2
	local tamperedAccepted = pcall(function()
		ResolvedRegionRecipe.deserialize(tampered)
	end)
	expectEqual("deserialization rejects same-record version drift", tamperedAccepted, false)

	local targetVersions = deepCopy(locked.generatorVersions)
	targetVersions.reality = 2
	targetVersions.topology = 3
	local migrationPlan = ResolvedRegionRecipe.migrationPlan(locked, targetVersions)
	expect("generator upgrade produces explicit migration plan", migrationPlan ~= nil)
	if migrationPlan ~= nil then
		expectEqual("migration plan is anchored to locked region", migrationPlan.regionId, locked.regionId)
		expectEqual(
			"migration plan preserves source fingerprint",
			migrationPlan.fromFingerprint,
			locked.fingerprint
		)
		expectEqual(
			"migration plan reports reality change first",
			migrationPlan.changedGenerators[1],
			"reality"
		)
		expectEqual(
			"migration plan reports topology change second",
			migrationPlan.changedGenerators[2],
			"topology"
		)
	end
	expectEqual(
		"migration planning does not mutate locked reality version",
		locked.generatorVersions.reality,
		1
	)
	expectEqual(
		"migration planning does not mutate locked topology version",
		locked.generatorVersions.topology,
		1
	)
	expectEqual(
		"matching generator versions require no migration",
		ResolvedRegionRecipe.migrationPlan(locked, locked.generatorVersions),
		nil
	)

	local invalidWorldInput = baseInput()
	invalidWorldInput.worldId = "world:shared-alpha"
	local invalidWorldAccepted = pcall(function()
		ResolvedRegionRecipe.lockFirstObservation(invalidWorldInput)
	end)
	expectEqual("resolved truth requires canonical WorldId StableId", invalidWorldAccepted, false)

	local duplicateAnchorInput = baseInput()
	duplicateAnchorInput.topologyAnchorKeys = { "same", "same" }
	local duplicateAnchorAccepted = pcall(function()
		ResolvedRegionRecipe.lockFirstObservation(duplicateAnchorInput)
	end)
	expectEqual("duplicate topology anchors are rejected", duplicateAnchorAccepted, false)

	local unknownKeyInput = baseInput()
	unknownKeyInput.workspaceModel = "forbidden"
	local unknownKeyAccepted = pcall(function()
		ResolvedRegionRecipe.lockFirstObservation(unknownKeyInput)
	end)
	expectEqual("unknown lock schema fields are rejected", unknownKeyAccepted, false)

	local nonFiniteAddressInput = baseInput()
	nonFiniteAddressInput.regionAddress.x = math.huge
	local nonFiniteAddressAccepted = pcall(function()
		ResolvedRegionRecipe.lockFirstObservation(nonFiniteAddressInput)
	end)
	expectEqual("non-finite region coordinates are rejected", nonFiniteAddressAccepted, false)

	local malformedVersionInput = baseInput()
	malformedVersionInput.generatorVersions.reality = 1.5
	local malformedVersionAccepted = pcall(function()
		ResolvedRegionRecipe.lockFirstObservation(malformedVersionInput)
	end)
	expectEqual("fractional generator versions are rejected", malformedVersionAccepted, false)

	local deltaPayload = {
		door = {
			open = true,
			angle = 37.5,
		},
		tags = { "player-moved", "durable" },
	}
	local delta = ResolvedRegionRecipe.newDelta(locked, 1, "mechanism-state", "door:service-a", deltaPayload)
	expectEqual("delta binds exact base schema", delta.baseSchemaVersion, locked.schemaVersion)
	expectEqual("delta binds exact base region", delta.baseRegionId, locked.regionId)
	expectEqual("delta binds exact base fingerprint", delta.baseFingerprint, locked.fingerprint)
	local matchingBaseAccepted = pcall(function()
		ResolvedRegionRecipe.assertDeltaMatchesBase(locked, delta)
	end)
	expectEqual("delta validates against its exact base", matchingBaseAccepted, true)
	local wrongBaseAccepted = pcall(function()
		ResolvedRegionRecipe.assertDeltaMatchesBase(changedContent, delta)
	end)
	expectEqual("delta rejects replay onto a different recipe fingerprint", wrongBaseAccepted, false)
	deltaPayload.door.open = false
	deltaPayload.tags[1] = "mutated"
	expectEqual("delta payload is defensively copied", delta.payload.door.open, true)
	expectEqual("delta nested arrays are defensively copied", delta.payload.tags[1], "player-moved")
	expectEqual(
		"delta creation cannot change base fingerprint",
		locked.fingerprint,
		reconstructed.fingerprint
	)
	local deltaMutationAccepted = pcall(function()
		delta.payload.door.angle = 90
	end)
	expectEqual("delta payload snapshot rejects mutation", deltaMutationAccepted, false)

	local falsePayloadAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 2, "invalid-payload-type", nil, false)
	end)
	expectEqual("delta payload rejects false instead of treating it as missing", falsePayloadAccepted, false)

	local oversizedStringAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 2, "invalid-string-size", nil, {
			note = string.rep("x", ResolvedRegionRecipe.MaxDeltaStringBytes + 1),
		})
	end)
	expectEqual("delta payload rejects oversized string values", oversizedStringAccepted, false)

	local cyclicPayload = {}
	cyclicPayload.self = cyclicPayload
	local cyclicDeltaAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 2, "invalid-cycle", nil, cyclicPayload)
	end)
	expectEqual("delta payload rejects cycles", cyclicDeltaAccepted, false)

	local functionDeltaAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 2, "invalid-function", nil, {
			callback = function() end,
		})
	end)
	expectEqual("delta payload rejects functions", functionDeltaAccepted, false)

	local nonFiniteDeltaAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 2, "invalid-number", nil, {
			energy = math.huge,
		})
	end)
	expectEqual("delta payload rejects non-finite numbers", nonFiniteDeltaAccepted, false)

	local zeroSequenceAccepted = pcall(function()
		ResolvedRegionRecipe.newDelta(locked, 0, "invalid-sequence", nil, {})
	end)
	expectEqual("delta sequence starts at one", zeroSequenceAccepted, false)

	return failures
end

return run
