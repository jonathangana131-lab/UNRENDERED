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
	local lockedVersions = PhysicsLabRecipe.RESOLVED_GENERATOR_VERSIONS

	expect(
		"Physics Lab resolved recipe uses current schema",
		resolved.schemaVersion == ResolvedRegionRecipe.SCHEMA_VERSION
	)
	expect("Physics Lab resolved recipe uses canonical WorldId", resolved.worldId == first.worldId)
	expect(
		"Physics Lab resolved recipe uses explicit world seed reference",
		resolved.worldSeedRef == PhysicsLabRecipe.WORLD_SEED_REF
	)
	expect(
		"Physics Lab resolved recipe pins Wave-1 generator versions",
		lockedVersions.reality == 1
			and lockedVersions.topology == 1
			and lockedVersions.material == 1
			and lockedVersions.object == 1
			and lockedVersions.entity == 1
			and resolved.generatorVersions.reality == lockedVersions.reality
			and resolved.generatorVersions.topology == lockedVersions.topology
			and resolved.generatorVersions.material == lockedVersions.material
			and resolved.generatorVersions.object == lockedVersions.object
			and resolved.generatorVersions.entity == lockedVersions.entity
	)
	expect("Physics Lab region identity comes from resolved truth", first.regionId == resolved.regionId)
	expect("Physics Lab region identity repeats exactly", first.regionId == second.regionId)

	local replay = ResolvedRegionRecipe.lock({
		worldId = first.worldId,
		worldSeedRef = PhysicsLabRecipe.WORLD_SEED_REF,
		regionAddress = resolved.regionAddress,
		generatorVersions = lockedVersions,
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
	for _, entityRecipe in ipairs(first.entities) do
		if
			entityRecipe.entity.origin.worldId ~= first.worldId
			or entityRecipe.entity.origin.regionId ~= resolved.regionId
		then
			allOriginsBound = false
			break
		end
	end
	expect("every Physics Lab WorldEntity origin uses resolved region identity", allOriginsBound)

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

	local versionMutationAccepted = pcall(function()
		lockedVersions.reality = 2
	end)
	expect("Physics Lab resolved generator versions remain immutable", not versionMutationAccepted)

	return failures
end

return run
