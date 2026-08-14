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

	local function expectOrigin(name, origin: any, expected: any)
		expectEqual(`{name} worldId`, origin.worldId, expected.worldId)
		expectEqual(`{name} regionId`, origin.regionId, expected.regionId)
		expectEqual(`{name} generator`, origin.generator, expected.generator)
		expectEqual(`{name} generatorVersion`, origin.generatorVersion, expected.generatorVersion)
		expectEqual(`{name} recipeKey`, origin.recipeKey, expected.recipeKey)
	end

	local function expectFrozen(name, mutate)
		local mutationAccepted = pcall(mutate)
		expectEqual(name, mutationAccepted, false)
	end

	local entityId = "entity:duplicate-origin-evidence"
	local sharedRecipeKey = "fixture/shared-recipe"
	local existingOrigin = {
		worldId = "world:alpha",
		regionId = "region:alpha",
		generator = "objects.office",
		generatorVersion = 1,
		recipeKey = sharedRecipeKey,
	}
	local incomingOrigin = {
		worldId = "world:beta",
		regionId = "region:beta",
		generator = "objects.reconstruction",
		generatorVersion = 2,
		recipeKey = sharedRecipeKey,
	}
	local existing = WorldEntity.new({
		id = entityId,
		kind = "office-chair",
		origin = existingOrigin,
	})
	local incoming = WorldEntity.new({
		id = entityId,
		kind = "office-chair",
		origin = incomingOrigin,
	})

	local registry = WorldEntity.createRegistry(1)
	local firstRegistered = WorldEntity.register(registry, existing)
	local duplicateRegistered, diagnosticValue = WorldEntity.register(registry, incoming)
	local diagnostic = diagnosticValue :: any

	expectEqual("first origin owns the identity", firstRegistered, true)
	expectEqual("conflicting origin is rejected", duplicateRegistered, false)
	expectEqual("duplicate diagnostic is returned", diagnosticValue ~= nil, true)
	expectEqual("legacy existing recipe key remains stable", diagnostic.existingRecipeKey, sharedRecipeKey)
	expectEqual("legacy incoming recipe key remains stable", diagnostic.incomingRecipeKey, sharedRecipeKey)
	expectOrigin("returned existing origin", diagnostic.existingOrigin, existingOrigin)
	expectOrigin("returned incoming origin", diagnostic.incomingOrigin, incomingOrigin)

	local retained = WorldEntity.duplicateDiagnostics(registry)[1] :: any
	expectEqual("complete diagnostic is retained", retained ~= nil, true)
	expectOrigin("retained existing origin", retained.existingOrigin, existingOrigin)
	expectOrigin("retained incoming origin", retained.incomingOrigin, incomingOrigin)
	expectFrozen("retained incoming origin snapshot rejects mutation", function()
		retained.incomingOrigin.worldId = "world:mutated"
	end)

	local authoritative = WorldEntity.get(registry, entityId) :: any
	expectEqual("duplicate origin cannot replace first registration", authoritative.origin.worldId, "world:alpha")

	local mutableEntityId = "entity:duplicate-origin-mutable-boundary"
	local mutableExistingOrigin = {
		worldId = "world:existing",
		regionId = "region:existing",
		generator = "objects.storage",
		generatorVersion = 7,
		recipeKey = "fixture/existing-storage",
	}
	local mutableIncomingOrigin = {
		worldId = "world:incoming",
		regionId = "region:incoming",
		generator = "objects.carts",
		generatorVersion = 8,
		recipeKey = "fixture/incoming-cart",
	}
	local mutableRegistry = WorldEntity.createRegistry(1)
	local canonicalExisting = WorldEntity.new({
		id = mutableEntityId,
		kind = "filing-cabinet",
		origin = mutableExistingOrigin,
	})
	local mutableIncoming: any = {
		id = mutableEntityId,
		kind = "rolling-cart",
		origin = {
			worldId = mutableIncomingOrigin.worldId,
			regionId = mutableIncomingOrigin.regionId,
			generator = mutableIncomingOrigin.generator,
			generatorVersion = mutableIncomingOrigin.generatorVersion,
			recipeKey = mutableIncomingOrigin.recipeKey,
		},
		fidelity = "F0",
		persistentState = {},
		stateRevision = 0,
		representationRevision = 0,
	}

	local existingRegistered = WorldEntity.register(mutableRegistry, canonicalExisting)
	expectEqual("mutable-boundary existing record registers", existingRegistered, true)
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
	expectOrigin("returned mutable existing origin", mutableDiagnostic.existingOrigin, mutableExistingOrigin)
	expectOrigin("returned mutable incoming origin", mutableDiagnostic.incomingOrigin, mutableIncomingOrigin)
	expectFrozen("returned mutable diagnostic rejects top-level mutation", function()
		mutableDiagnostic.incomingKind = "mutated-returned-kind"
	end)
	expectFrozen("returned mutable existing origin rejects mutation", function()
		mutableDiagnostic.existingOrigin.worldId = "world:mutated-returned-existing"
	end)
	expectFrozen("returned mutable incoming origin rejects mutation", function()
		mutableDiagnostic.incomingOrigin.worldId = "world:mutated-returned-incoming"
	end)

	local mutableRetained = WorldEntity.duplicateDiagnostics(mutableRegistry)[1] :: any
	expectEqual("mutable-boundary diagnostic is retained", mutableRetained ~= nil, true)
	expectEqual("retained mutable diagnostic keeps entity id", mutableRetained.entityId, mutableEntityId)
	expectEqual("retained mutable diagnostic keeps existing kind", mutableRetained.existingKind, "filing-cabinet")
	expectEqual("retained mutable diagnostic keeps incoming kind", mutableRetained.incomingKind, "rolling-cart")
	expectOrigin("retained mutable existing origin", mutableRetained.existingOrigin, mutableExistingOrigin)
	expectOrigin("retained mutable incoming origin", mutableRetained.incomingOrigin, mutableIncomingOrigin)
	expectFrozen("retained mutable diagnostic rejects top-level mutation", function()
		mutableRetained.incomingKind = "mutated-retained-kind"
	end)
	expectFrozen("retained mutable existing origin rejects mutation", function()
		mutableRetained.existingOrigin.worldId = "world:mutated-retained-existing"
	end)
	expectFrozen("retained mutable incoming origin rejects mutation", function()
		mutableRetained.incomingOrigin.worldId = "world:mutated-retained-incoming"
	end)

	local mutableAuthoritative = WorldEntity.get(mutableRegistry, mutableEntityId) :: any
	expectEqual("mutable duplicate cannot replace first kind", mutableAuthoritative.kind, "filing-cabinet")
	expectEqual("mutable duplicate cannot replace first worldId", mutableAuthoritative.origin.worldId, "world:existing")
	expectEqual(
		"mutable duplicate cannot replace first recipe key",
		mutableAuthoritative.origin.recipeKey,
		"fixture/existing-storage"
	)

	return failures
end

return run
