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

	local returnedDiagnosticMutationAccepted = pcall(function()
		duplicateDiagnostic.incomingKind = "mutated-kind"
	end)
	expectEqual(
		"returned duplicate diagnostic rejects top-level mutation",
		returnedDiagnosticMutationAccepted,
		false
	)
	local returnedExistingOriginMutationAccepted = pcall(function()
		duplicateDiagnostic.existingOrigin.worldId = "world:mutated-existing"
	end)
	expectEqual(
		"returned existing origin snapshot rejects mutation",
		returnedExistingOriginMutationAccepted,
		false
	)
	local returnedIncomingOriginMutationAccepted = pcall(function()
		duplicateDiagnostic.incomingOrigin.worldId = "world:mutated-incoming"
	end)
	expectEqual(
		"returned incoming origin snapshot rejects mutation",
		returnedIncomingOriginMutationAccepted,
		false
	)
	expectEqual(
		"returned existing origin remains authoritative after rejected mutation",
		duplicateDiagnostic.existingOrigin.worldId,
		"world:alpha"
	)
	expectEqual(
		"returned incoming origin remains evidence after rejected mutation",
		duplicateDiagnostic.incomingOrigin.worldId,
		"world:beta"
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

	return failures
end

return run
