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

	expect(
		"Physics Lab region identity comes from ResolvedRegionRecipe",
		first.regionId == first.resolvedRegion.regionId
	)
	expect(
		"Physics Lab uses its explicit world seed reference",
		first.resolvedRegion.worldSeedRef == PhysicsLabRecipe.WORLD_SEED_REF
	)
	expect(
		"Physics Lab resolved truth repeats exactly",
		ResolvedRegionRecipe.equal(first.resolvedRegion, second.resolvedRegion)
	)
	expect("Physics Lab resolved region id repeats exactly", first.regionId == second.regionId)
	expect(
		"Physics Lab resolved fingerprint repeats exactly",
		first.resolvedRegion.recipeFingerprint == second.resolvedRegion.recipeFingerprint
	)
	expect(
		"module canonical resolved region matches built recipe",
		ResolvedRegionRecipe.equal(first.resolvedRegion, PhysicsLabRecipe.RESOLVED_REGION)
	)

	local allOriginsBound = true
	for _, entityRecipe in ipairs(first.entities) do
		if
			entityRecipe.entity.origin.worldId ~= first.worldId
			or entityRecipe.entity.origin.regionId ~= first.resolvedRegion.regionId
		then
			allOriginsBound = false
			break
		end
	end
	expect("every Physics Lab WorldEntity origin uses resolved region identity", allOriginsBound)

	local serialized = ResolvedRegionRecipe.serialize(first.resolvedRegion)
	local restored = ResolvedRegionRecipe.deserialize(serialized)
	expect("Physics Lab resolved truth survives canonical round trip", ResolvedRegionRecipe.equal(first.resolvedRegion, restored))

	local mutationAccepted = pcall(function()
		first.resolvedRegion.regionAddress.x = 99
	end)
	expect("Physics Lab resolved truth remains immutable", not mutationAccepted)

	return failures
end

return run