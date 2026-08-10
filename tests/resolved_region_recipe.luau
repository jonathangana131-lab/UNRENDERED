local ProductionLoader = require("./support/ProductionLoader")

local StableId = ProductionLoader.requireShared("Core/StableId")
local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")

local function fixtureDraft()
	return {
		worldId = "world:v1:test",
		worldSeedRef = "world-seed:v1:test",
		regionId = "region:v1:office-a",
		regionAddress = "office/a",
		generatorVersions = {
			reality = 1,
			topology = 1,
			material = 1,
			object = 1,
			entity = 1,
		},
		semanticIntentKey = "office.commercial.anonymous",
		topologyAnchorKeys = {
			"anchor.service-core",
			"anchor.entry",
		},
		canonicalContentKeys = {
			"object.front-desk",
			"fixture.ceiling-grid",
			"material.carpet-batch-a",
		},
	}
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL resolved_region_recipe {name}`)
		else
			print(`PASS resolved_region_recipe {name}`)
		end
	end

	local draft = fixtureDraft()
	local recipe = ResolvedRegionRecipe.lock(draft)

	expect("schema version is explicit", ResolvedRegionRecipe.SCHEMA_VERSION == 1)
	expect(
		"recipe id uses project StableId namespace",
		StableId.is(recipe.recipeId, ResolvedRegionRecipe.RECIPE_NAMESPACE)
	)
	expect(
		"fixture recipe id is golden locked",
		recipe.recipeId == "resolved-region-recipe:v1:e70de5f4636c51244ba6a4e159c676ab"
	)
	expect("locking same draft is deterministic", ResolvedRegionRecipe.lock(fixtureDraft()).recipeId == recipe.recipeId)
	expect("recipe fingerprint is recipe identity", ResolvedRegionRecipe.fingerprint(recipe) == recipe.recipeId)

	expect(
		"topology anchor keys canonicalize as a set",
		recipe.topologyAnchorKeys[1] == "anchor.entry" and recipe.topologyAnchorKeys[2] == "anchor.service-core"
	)
	expect(
		"canonical content keys canonicalize as a set",
		recipe.canonicalContentKeys[1] == "fixture.ceiling-grid"
			and recipe.canonicalContentKeys[2] == "material.carpet-batch-a"
			and recipe.canonicalContentKeys[3] == "object.front-desk"
	)

	local reorderedDraft = fixtureDraft()
	reorderedDraft.topologyAnchorKeys = {
		"anchor.entry",
		"anchor.service-core",
	}
	reorderedDraft.canonicalContentKeys = {
		"material.carpet-batch-a",
		"object.front-desk",
		"fixture.ceiling-grid",
	}
	expect(
		"set ordering cannot perturb canonical recipe identity",
		ResolvedRegionRecipe.lock(reorderedDraft).recipeId == recipe.recipeId
	)

	local serialized = ResolvedRegionRecipe.serialize(recipe)
	local reconstructed = ResolvedRegionRecipe.reconstruct(serialized)
	expect("serialized recipe reconstructs", ResolvedRegionRecipe.equals(recipe, reconstructed))
	expect("reconstruction preserves exact recipe id", reconstructed.recipeId == recipe.recipeId)
	expect("reconstruction preserves generator versions", reconstructed.generatorVersions.topology == 1)

	serialized.topologyAnchorKeys[1] = "anchor.mutated-copy"
	expect(
		"serialized copy cannot mutate locked recipe",
		recipe.topologyAnchorKeys[1] == "anchor.entry"
	)
	local tamperedOk = pcall(function()
		ResolvedRegionRecipe.reconstruct(serialized)
	end)
	expect("tampered serialized content is rejected by recipe id", not tamperedOk)

	local changedDraft = fixtureDraft()
	changedDraft.semanticIntentKey = "office.commercial.revised"
	expect(
		"immutable recipe content drift changes recipe id",
		ResolvedRegionRecipe.lock(changedDraft).recipeId ~= recipe.recipeId
	)

	local newerDraft = fixtureDraft()
	newerDraft.generatorVersions.reality = 2
	newerDraft.generatorVersions.topology = 2
	local existingAfterObservation, didLockExisting = ResolvedRegionRecipe.resolve(recipe, newerDraft)
	expect("existing observed truth wins later resolution", not didLockExisting and existingAfterObservation.recipeId == recipe.recipeId)
	expect(
		"later generator versions do not rewrite observed truth",
		existingAfterObservation.generatorVersions.reality == 1
			and existingAfterObservation.generatorVersions.topology == 1
	)
	expect(
		"the same newer draft would be distinct if still unobserved",
		ResolvedRegionRecipe.lock(newerDraft).recipeId ~= recipe.recipeId
	)

	local firstRecipe, didFirstLock = ResolvedRegionRecipe.resolve(nil, fixtureDraft())
	expect("first observation locks a recipe", didFirstLock and firstRecipe.recipeId == recipe.recipeId)

	local deltaBase = ResolvedRegionRecipe.deltaBaseReference(recipe)
	expect(
		"mutable delta systems bind to immutable recipe identity only",
		deltaBase.recipeId == recipe.recipeId
			and deltaBase.recipeSchemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION
			and deltaBase.deltas == nil
	)

	local legacy = {
		schemaVersion = 0,
		legacyRecipeKey = "legacy-office-a",
	}
	local withoutMigrationOk = pcall(function()
		ResolvedRegionRecipe.reconstruct(legacy)
	end)
	expect("unsupported schema requires explicit migration", not withoutMigrationOk)

	local migrationCalled = false
	local migrated = ResolvedRegionRecipe.reconstruct(legacy, function(fromVersion, toVersion, source)
		migrationCalled = fromVersion == 0
			and toVersion == ResolvedRegionRecipe.SCHEMA_VERSION
			and source.legacyRecipeKey == "legacy-office-a"
		return ResolvedRegionRecipe.serialize(recipe)
	end)
	expect("explicit migration hook can produce current canonical recipe", migrationCalled and migrated.recipeId == recipe.recipeId)

	local badMigrationOk = pcall(function()
		ResolvedRegionRecipe.reconstruct(legacy, function()
			return {
				schemaVersion = ResolvedRegionRecipe.SCHEMA_VERSION,
				recipeId = recipe.recipeId,
			}
		end)
	end)
	expect("migration output must satisfy current schema", not badMigrationOk)

	local duplicateDraft = fixtureDraft()
	duplicateDraft.topologyAnchorKeys = {
		"anchor.entry",
		"anchor.entry",
	}
	local duplicateOk = pcall(function()
		ResolvedRegionRecipe.lock(duplicateDraft)
	end)
	expect("duplicate canonical keys are rejected", not duplicateOk)

	local metatableDraft = fixtureDraft()
	setmetatable(metatableDraft, {})
	local metatableOk = pcall(function()
		ResolvedRegionRecipe.lock(metatableDraft)
	end)
	expect("metatable-backed canonical draft is rejected", not metatableOk)

	local extraFieldSerialized = ResolvedRegionRecipe.serialize(recipe)
	extraFieldSerialized.workspaceInstance = "not-canonical"
	expect("unknown serialized fields are rejected", not ResolvedRegionRecipe.inspect(extraFieldSerialized).ok)

	local nonPlainSerialized = ResolvedRegionRecipe.serialize(recipe)
	nonPlainSerialized.canonicalContentKeys[1] = function() end
	local nonPlainOk = pcall(function()
		ResolvedRegionRecipe.reconstruct(nonPlainSerialized)
	end)
	expect("non-plain canonical recipe values are rejected", not nonPlainOk)

	local currentVersions = ResolvedRegionRecipe.currentGeneratorVersions()
	expect(
		"current generator version snapshot is explicit",
		currentVersions.reality >= 1
			and currentVersions.topology >= 1
			and currentVersions.material >= 1
			and currentVersions.object >= 1
			and currentVersions.entity >= 1
	)

	return failures
end

return run
