local ResolvedRegionRecipe = require("../src/shared/Reality/ResolvedRegionRecipe")

local function recipeFixture(contentKey)
	return ResolvedRegionRecipe.lock(nil, {
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
		semanticIntentKeys = { "office.department.general" },
		topologyAnchorKeys = { "anchor:reception:west" },
		canonicalContentKeys = { contentKey },
		firstObservationKey = "observation:cohort-a:0001",
	}).recipe
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

	local recipe = recipeFixture("object:chair:reception-01")
	local baseFingerprint = recipe.baseFingerprint
	local fullFingerprint = recipe.fingerprint
	local payload = {
		mechanism = { angle = 17.5, latched = false },
		tags = { "player-moved", "observed" },
	}
	local delta = ResolvedRegionRecipe.createDelta(recipe, 1, {
		kind = "entity-state",
		targetKey = "object:chair:reception-01",
		payload = payload,
	})

	expectEqual("delta binds exact generated base", delta.baseFingerprint, baseFingerprint)
	expectEqual("delta sequence is explicit", delta.sequence, 1)
	expectEqual("delta kind is preserved", delta.kind, "entity-state")
	expectEqual("delta target is preserved", delta.targetKey, "object:chair:reception-01")

	payload.mechanism.angle = 90
	expectEqual("delta owns payload snapshot", delta.payload.mechanism.angle, 17.5)
	local mutationAccepted = pcall(function()
		delta.payload.mechanism.angle = 45
	end)
	expectEqual("delta nested payload rejects mutation", mutationAccepted, false)
	expectEqual("delta creation leaves base fingerprint unchanged", recipe.baseFingerprint, baseFingerprint)
	expectEqual("delta creation leaves lock fingerprint unchanged", recipe.fingerprint, fullFingerprint)

	local reconstructed = ResolvedRegionRecipe.reconstructDelta(recipe, {
		baseFingerprint = delta.baseFingerprint,
		sequence = delta.sequence,
		kind = delta.kind,
		targetKey = delta.targetKey,
		payload = delta.payload,
	})
	expectEqual("delta reconstructs against matching base", reconstructed.baseFingerprint, baseFingerprint)
	expectEqual("delta reconstruction owns payload", reconstructed.payload.mechanism.angle, 17.5)

	local differentBase = recipeFixture("object:chair:replacement-02")
	local wrongBaseAccepted = pcall(function()
		ResolvedRegionRecipe.reconstructDelta(differentBase, delta)
	end)
	expectEqual("delta rejects different generated base", wrongBaseAccepted, false)

	local zeroSequenceAccepted = pcall(function()
		ResolvedRegionRecipe.createDelta(recipe, 0, {
			kind = "invalid-sequence",
			payload = {},
		})
	end)
	expectEqual("delta sequence must be positive", zeroSequenceAccepted, false)

	local nonFinitePayloadAccepted = pcall(function()
		ResolvedRegionRecipe.createDelta(recipe, 2, {
			kind = "invalid-payload",
			payload = { energy = math.huge },
		})
	end)
	expectEqual("delta payload rejects non-finite numbers", nonFinitePayloadAccepted, false)

	local mixedPayloadAccepted = pcall(function()
		ResolvedRegionRecipe.createDelta(recipe, 2, {
			kind = "invalid-payload",
			payload = {
				nested = { [1] = "first", named = "second" },
			},
		})
	end)
	expectEqual("delta payload rejects mixed nested keys", mixedPayloadAccepted, false)

	local cyclic = {}
	cyclic.self = cyclic
	local cyclicPayloadAccepted = pcall(function()
		ResolvedRegionRecipe.createDelta(recipe, 2, {
			kind = "invalid-payload",
			payload = { nested = cyclic },
		})
	end)
	expectEqual("delta payload rejects cycles", cyclicPayloadAccepted, false)

	if failures == 0 then
		print("ResolvedRegionRecipe delta tests passed")
	end
	return failures
end

return run
