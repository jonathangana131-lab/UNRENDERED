local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")

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

	local first = PhysicsLabRecipe.build()
	local second = PhysicsLabRecipe.build()
	local resolved = PhysicsLabRecipe.RESOLVED_REGION

	expect(
		"Physics Lab resolved recipe uses current schema",
		resolved.schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION
	)
	expect("Physics Lab resolved recipe uses canonical WorldId", resolved.worldId == first.worldId)
	expect(
		"Physics Lab resolved recipe uses explicit world seed reference",
		resolved.worldSeedRef == PhysicsLabRecipe.WORLD_SEED_REF
	)
	expect("Physics Lab region identity comes from resolved truth", first.regionId == resolved.regionId)
	expect("Physics Lab region identity repeats exactly", first.regionId == second.regionId)
	expect("Physics Lab resolved identity revision advances generator contract", PhysicsLabRecipe.GENERATOR_VERSION == 2)
	expect("Physics Lab resolved identity revision advances recipe key", PhysicsLabRecipe.RECIPE_KEY == "physics-lab.hero-gate.v2")

	local versions = resolved.generatorVersions
	expect(
		"Physics Lab first-observation versions are a literal Wave-1 snapshot",
		versions.reality == 1
			and versions.topology == 1
			and versions.material == 1
			and versions.object == 1
			and versions.entity == 1
	)
	expect("Physics Lab exports the exact locked version snapshot", versions == PhysicsLabRecipe.RESOLVED_GENERATOR_VERSIONS)

	local replay = ResolvedRegionRecipe.lock({
		worldId = first.worldId,
		worldSeedRef = PhysicsLabRecipe.WORLD_SEED_REF,
		regionAddress = resolved.regionAddress,
		generatorVersions = resolved.generatorVersions,
		semanticIntentKey = resolved.semanticIntentKey,
		topologyAnchors = resolved.topologyAnchors,
		canonicalContentKeys = resolved.canonicalContentKeys,
	})
	expect("Physics Lab resolved truth replays exactly", ResolvedRegionRecipe.equal(resolved, replay))
	expect(
		"Physics Lab resolved fingerprint replays exactly",
		resolved.recipeFingerprint == replay.recipeFingerprint
	)

	local allOriginsBound = true
	local allOriginsVersioned = true
	for _, entityRecipe in ipairs(first.entities) do
		if
			entityRecipe.entity.origin.worldId ~= first.worldId
			or entityRecipe.entity.origin.regionId ~= resolved.regionId
		then
			allOriginsBound = false
			break
		end
		if
			entityRecipe.entity.origin.generatorVersion ~= PhysicsLabRecipe.GENERATOR_VERSION
			or string.sub(entityRecipe.entity.origin.recipeKey, 1, #PhysicsLabRecipe.RECIPE_KEY) ~= PhysicsLabRecipe.RECIPE_KEY
		then
			allOriginsVersioned = false
			break
		end
	end
	expect("every Physics Lab WorldEntity origin uses resolved region identity", allOriginsBound)
	expect("every Physics Lab WorldEntity origin uses the v2 lab contract", allOriginsVersioned)

	local serialized = ResolvedRegionRecipe.serialize(resolved)
	local restored = ResolvedRegionRecipe.deserialize(serialized)
	expect(
		"Physics Lab resolved truth survives canonical round trip",
		ResolvedRegionRecipe.equal(resolved, restored)
	)

	local mutationAccepted = pcall(function()
		resolved.regionAddress.x = 99
	end)
	expect("Physics Lab resolved truth remains immutable", not mutationAccepted)

	return failures
end

return run
