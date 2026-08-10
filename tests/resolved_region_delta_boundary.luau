local ProductionLoader = require("./support/ProductionLoader")

local ResolvedRegionDeltaBoundary = ProductionLoader.requireShared("Reality/ResolvedRegionDeltaBoundary")
local ResolvedRegionRecipe = ProductionLoader.requireShared("Reality/ResolvedRegionRecipe")
local RegionAddress = ProductionLoader.requireShared("Spatial/RegionAddress")
local RealityVersions = ProductionLoader.requireShared("Reality/RealityVersions")

local function makeCandidate()
	local versions = RealityVersions.current()
	return {
		worldSeedRef = "world-seed:delta-boundary",
		regionAddress = RegionAddress.new(3, -8, 0),
		generatorVersions = {
			reality = versions.reality,
			topology = versions.topology,
			material = versions.material,
			object = versions.object,
			entity = versions.entity,
		},
		semanticIntentKey = "intent:commercial-office.delta-boundary",
		topologyAnchors = { "anchor:entry" },
		canonicalContentKeys = { "object:door-a" },
	}
end

local function copyReference(reference)
	return {
		boundarySchemaVersion = reference.boundarySchemaVersion,
		recipeSchemaVersion = reference.recipeSchemaVersion,
		regionId = reference.regionId,
		recipeFingerprint = reference.recipeFingerprint,
	}
end

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

	local function rejects(callback)
		return not pcall(callback)
	end

	local base = ResolvedRegionRecipe.lock(makeCandidate())
	local reference = ResolvedRegionDeltaBoundary.fromRecipe(base)
	expect("delta boundary schema is explicit", reference.boundarySchemaVersion == 1)
	expect("delta boundary snapshots recipe schema", reference.recipeSchemaVersion == base.schemaVersion)
	expect("delta boundary snapshots stable region identity", reference.regionId == base.regionId)
	expect(
		"delta boundary snapshots exact immutable fingerprint",
		reference.recipeFingerprint == base.recipeFingerprint
	)
	expect("exact immutable base accepts its delta binding", not rejects(function()
		ResolvedRegionDeltaBoundary.assertMatches(base, reference)
	end))

	local callerOwnedStream = {
		base = reference,
		entries = {},
	}
	table.insert(callerOwnedStream.entries, { key = "door:open", payloadRef = "payload:0001" })
	expect("caller-owned mutable stream stays bound without entering recipe schema", not rejects(function()
		ResolvedRegionDeltaBoundary.assertMatches(base, callerOwnedStream.base)
	end))

	local changedCandidate = makeCandidate()
	changedCandidate.canonicalContentKeys = { "object:door-b" }
	local changedBase = ResolvedRegionRecipe.lock(changedCandidate)
	expect("content revision keeps region identity", changedBase.regionId == base.regionId)
	expect(
		"content revision changes immutable fingerprint",
		changedBase.recipeFingerprint ~= base.recipeFingerprint
	)
	expect(
		"delta binding rejects same-region different-base replay",
		rejects(function()
			ResolvedRegionDeltaBoundary.assertMatches(changedBase, reference)
		end)
	)

	local otherRegionCandidate = makeCandidate()
	otherRegionCandidate.regionAddress = RegionAddress.new(4, -8, 0)
	local otherRegion = ResolvedRegionRecipe.lock(otherRegionCandidate)
	expect(
		"delta binding rejects cross-region replay",
		rejects(function()
			ResolvedRegionDeltaBoundary.assertMatches(otherRegion, reference)
		end)
	)

	local wrongBoundarySchema = copyReference(reference)
	wrongBoundarySchema.boundarySchemaVersion += 1
	expect(
		"delta binding rejects boundary schema drift",
		rejects(function()
			ResolvedRegionDeltaBoundary.assertMatches(base, wrongBoundarySchema)
		end)
	)

	local extraField = copyReference(reference)
	extraField.payload = "forbidden"
	expect(
		"delta binding rejects persistence payload fields",
		rejects(function()
			ResolvedRegionDeltaBoundary.assertMatches(base, extraField)
		end)
	)

	local metatableReference = copyReference(reference)
	setmetatable(metatableReference, { __index = {} })
	expect(
		"delta binding rejects metatable-backed references",
		rejects(function()
			ResolvedRegionDeltaBoundary.assertMatches(base, metatableReference)
		end)
	)

	expect(
		"canonical delta base reference is immutable",
		rejects(function()
			reference.recipeFingerprint = changedBase.recipeFingerprint
		end)
	)

	return failures
end

return run
