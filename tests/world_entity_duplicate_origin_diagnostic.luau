local WorldEntity = require("../src/shared/Reality/WorldEntity")

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

	local entityId = "entity:duplicate-origin-evidence"
	local sharedRecipeKey = "fixture/shared-recipe"
	local existing = WorldEntity.new({
		id = entityId,
		kind = "office-chair",
		origin = {
			worldId = "world:alpha",
			regionId = "region:alpha",
			generator = "objects.office",
			generatorVersion = 1,
			recipeKey = sharedRecipeKey,
		},
	})
	local incoming = WorldEntity.new({
		id = entityId,
		kind = "office-chair",
		origin = {
			worldId = "world:beta",
			regionId = "region:beta",
			generator = "objects.reconstruction",
			generatorVersion = 2,
			recipeKey = sharedRecipeKey,
		},
	})

	local registry = WorldEntity.createRegistry(1)
	local firstRegistered = WorldEntity.register(registry, existing)
	local duplicateRegistered, diagnostic = WorldEntity.register(registry, incoming)
	local duplicateDiagnostic = diagnostic :: any

	expectEqual("first origin owns the identity", firstRegistered, true)
	expectEqual("conflicting origin is rejected", duplicateRegistered, false)
	expectEqual("duplicate diagnostic is returned", diagnostic ~= nil, true)
	expectEqual(
		"legacy existing recipe key remains stable",
		duplicateDiagnostic.existingRecipeKey,
		sharedRecipeKey
	)
	expectEqual(
		"legacy incoming recipe key remains stable",
		duplicateDiagnostic.incomingRecipeKey,
		sharedRecipeKey
	)
	expectEqual(
		"existing origin worldId is preserved",
		duplicateDiagnostic.existingOrigin.worldId,
		"world:alpha"
	)
	expectEqual(
		"incoming origin worldId is preserved",
		duplicateDiagnostic.incomingOrigin.worldId,
		"world:beta"
	)
	expectEqual(
		"existing origin regionId is preserved",
		duplicateDiagnostic.existingOrigin.regionId,
		"region:alpha"
	)
	expectEqual(
		"incoming origin regionId is preserved",
		duplicateDiagnostic.incomingOrigin.regionId,
		"region:beta"
	)
	expectEqual(
		"existing origin generator is preserved",
		duplicateDiagnostic.existingOrigin.generator,
		"objects.office"
	)
	expectEqual(
		"incoming origin generator is preserved",
		duplicateDiagnostic.incomingOrigin.generator,
		"objects.reconstruction"
	)
	expectEqual(
		"existing generator version is preserved",
		duplicateDiagnostic.existingOrigin.generatorVersion,
		1
	)
	expectEqual(
		"incoming generator version is preserved",
		duplicateDiagnostic.incomingOrigin.generatorVersion,
		2
	)
	expectEqual(
		"existing origin recipe key is preserved",
		duplicateDiagnostic.existingOrigin.recipeKey,
		sharedRecipeKey
	)
	expectEqual(
		"incoming origin recipe key is preserved",
		duplicateDiagnostic.incomingOrigin.recipeKey,
		sharedRecipeKey
	)

	local retained = WorldEntity.duplicateDiagnostics(registry)[1] :: any
	expectEqual("complete diagnostic is retained", retained ~= nil, true)
	expectEqual(
		"retained existing origin stays distinguishable",
		retained.existingOrigin.worldId,
		"world:alpha"
	)
	expectEqual(
		"retained incoming origin stays distinguishable",
		retained.incomingOrigin.worldId,
		"world:beta"
	)
	local retainedOriginMutationAccepted = pcall(function()
		retained.incomingOrigin.worldId = "world:mutated"
	end)
	expectEqual("retained incoming origin snapshot rejects mutation", retainedOriginMutationAccepted, false)

	local authoritative = WorldEntity.get(registry, entityId) :: any
	expectEqual(
		"duplicate origin cannot replace first registration",
		authoritative.origin.worldId,
		"world:alpha"
	)

	local mutableEntityId = "entity:duplicate-origin-mutable-boundary"
	local mutableRegistry = WorldEntity.createRegistry(1)
	local canonicalExisting = WorldEntity.new({
		id = mutableEntityId,
		kind = "filing-cabinet",
		origin = {
			worldId = "world:existing",
			regionId = "region:existing",
			generator = "objects.storage",
			generatorVersion = 7,
			recipeKey = "fixture/existing-storage",
		},
	})
	local mutableIncoming: any = {
		id = mutableEntityId,
		kind = "rolling-cart",
		origin = {
			worldId = "world:incoming",
			regionId = "region:incoming",
			generator = "objects.carts",
			generatorVersion = 8,
			recipeKey = "fixture/incoming-cart",
		},
		fidelity = "F0",
		persistentState = {},
		stateRevision = 0,
		representationRevision = 0,
	}

	expectEqual(
		"mutable-boundary existing record registers",
		WorldEntity.register(mutableRegistry, canonicalExisting),
		true
	)
	local mutableRegistered, mutableDiagnosticValue = WorldEntity.register(mutableRegistry, mutableIncoming)
	local mutableDiagnostic = mutableDiagnosticValue :: any
	expectEqual("direct mutable duplicate is rejected", mutableRegistered, false)
	expectEqual("direct mutable duplicate returns diagnostic", mutableDiagnosticValue ~= nil, true)

	mutableIncoming.id = "entity:caller-mutated"
	mutableIncoming.kind = "caller-mutated-kind"
	mutableIncoming.origin.worldId = "world:caller-mutated"
	mutableIncoming.origin.regionId = "region:caller-mutated"
	mutableIncoming.origin.generator = "objects.caller-mutated"
	mutableIncoming.origin.generatorVersion = 99
	mutableIncoming.origin.recipeKey = "fixture/caller-mutated"

	expectEqual("returned mutable diagnostic keeps entity id", mutableDiagnostic.entityId, mutableEntityId)
	expectEqual("returned mutable diagnostic keeps existing kind", mutableDiagnostic.existingKind, "filing-cabinet")
	expectEqual("returned mutable diagnostic keeps incoming kind", mutableDiagnostic.incomingKind, "rolling-cart")
	expectEqual(
		"returned mutable diagnostic keeps existing worldId",
		mutableDiagnostic.existingOrigin.worldId,
		"world:existing"
	)
	expectEqual(
		"returned mutable diagnostic keeps existing regionId",
		mutableDiagnostic.existingOrigin.regionId,
		"region:existing"
	)
	expectEqual(
		"returned mutable diagnostic keeps existing generator",
		mutableDiagnostic.existingOrigin.generator,
		"objects.storage"
	)
	expectEqual(
		"returned mutable diagnostic keeps existing generator version",
		mutableDiagnostic.existingOrigin.generatorVersion,
		7
	)
	expectEqual(
		"returned mutable diagnostic keeps existing recipe key",
		mutableDiagnostic.existingOrigin.recipeKey,
		"fixture/existing-storage"
	)
	expectEqual(
		"returned mutable diagnostic keeps incoming worldId",
		mutableDiagnostic.incomingOrigin.worldId,
		"world:incoming"
	)
	expectEqual(
		"returned mutable diagnostic keeps incoming regionId",
		mutableDiagnostic.incomingOrigin.regionId,
		"region:incoming"
	)
	expectEqual(
		"returned mutable diagnostic keeps incoming generator",
		mutableDiagnostic.incomingOrigin.generator,
		"objects.carts"
	)
	expectEqual(
		"returned mutable diagnostic keeps incoming generator version",
		mutableDiagnostic.incomingOrigin.generatorVersion,
		8
	)
	expectEqual(
		"returned mutable diagnostic keeps incoming recipe key",
		mutableDiagnostic.incomingOrigin.recipeKey,
		"fixture/incoming-cart"
	)

	local returnedTopMutationAccepted = pcall(function()
		mutableDiagnostic.incomingKind = "mutated-returned-kind"
	end)
	local returnedExistingOriginMutationAccepted = pcall(function()
		mutableDiagnostic.existingOrigin.worldId = "world:mutated-returned-existing"
	end)
	local returnedIncomingOriginMutationAccepted = pcall(function()
		mutableDiagnostic.incomingOrigin.worldId = "world:mutated-returned-incoming"
	end)
	expectEqual("returned mutable diagnostic rejects top-level mutation", returnedTopMutationAccepted, false)
	expectEqual(
		"returned mutable diagnostic existing origin rejects mutation",
		returnedExistingOriginMutationAccepted,
		false
	)
	expectEqual(
		"returned mutable diagnostic incoming origin rejects mutation",
		returnedIncomingOriginMutationAccepted,
		false
	)

	local mutableRetained = WorldEntity.duplicateDiagnostics(mutableRegistry)[1] :: any
	expectEqual("mutable-boundary diagnostic is retained", mutableRetained ~= nil, true)
	expectEqual("retained mutable diagnostic keeps entity id", mutableRetained.entityId, mutableEntityId)
	expectEqual("retained mutable diagnostic keeps existing kind", mutableRetained.existingKind, "filing-cabinet")
	expectEqual("retained mutable diagnostic keeps incoming kind", mutableRetained.incomingKind, "rolling-cart")
	expectEqual(
		"retained mutable diagnostic keeps existing worldId",
		mutableRetained.existingOrigin.worldId,
		"world:existing"
	)
	expectEqual(
		"retained mutable diagnostic keeps existing regionId",
		mutableRetained.existingOrigin.regionId,
		"region:existing"
	)
	expectEqual(
		"retained mutable diagnostic keeps existing generator",
		mutableRetained.existingOrigin.generator,
		"objects.storage"
	)
	expectEqual(
		"retained mutable diagnostic keeps existing generator version",
		mutableRetained.existingOrigin.generatorVersion,
		7
	)
	expectEqual(
		"retained mutable diagnostic keeps existing recipe key",
		mutableRetained.existingOrigin.recipeKey,
		"fixture/existing-storage"
	)
	expectEqual(
		"retained mutable diagnostic keeps incoming worldId",
		mutableRetained.incomingOrigin.worldId,
		"world:incoming"
	)
	expectEqual(
		"retained mutable diagnostic keeps incoming regionId",
		mutableRetained.incomingOrigin.regionId,
		"region:incoming"
	)
	expectEqual(
		"retained mutable diagnostic keeps incoming generator",
		mutableRetained.incomingOrigin.generator,
		"objects.carts"
	)
	expectEqual(
		"retained mutable diagnostic keeps incoming generator version",
		mutableRetained.incomingOrigin.generatorVersion,
		8
	)
	expectEqual(
		"retained mutable diagnostic keeps incoming recipe key",
		mutableRetained.incomingOrigin.recipeKey,
		"fixture/incoming-cart"
	)

	local retainedTopMutationAccepted = pcall(function()
		mutableRetained.incomingKind = "mutated-retained-kind"
	end)
	local retainedExistingOriginMutationAccepted = pcall(function()
		mutableRetained.existingOrigin.worldId = "world:mutated-retained-existing"
	end)
	local retainedIncomingOriginMutationAccepted = pcall(function()
		mutableRetained.incomingOrigin.worldId = "world:mutated-retained-incoming"
	end)
	expectEqual("retained mutable diagnostic rejects top-level mutation", retainedTopMutationAccepted, false)
	expectEqual(
		"retained mutable diagnostic existing origin rejects mutation",
		retainedExistingOriginMutationAccepted,
		false
	)
	expectEqual(
		"retained mutable diagnostic incoming origin rejects mutation",
		retainedIncomingOriginMutationAccepted,
		false
	)

	local mutableAuthoritative = WorldEntity.get(mutableRegistry, mutableEntityId) :: any
	expectEqual("mutable duplicate cannot replace first registration kind", mutableAuthoritative.kind, "filing-cabinet")
	expectEqual(
		"mutable duplicate cannot replace first registration worldId",
		mutableAuthoritative.origin.worldId,
		"world:existing"
	)
	expectEqual(
		"mutable duplicate cannot replace first registration recipe key",
		mutableAuthoritative.origin.recipeKey,
		"fixture/existing-storage"
	)

	return failures
end

return run
