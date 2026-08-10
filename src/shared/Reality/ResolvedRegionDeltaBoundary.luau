--!strict

local ResolvedRegionRecipe = require(script.Parent.ResolvedRegionRecipe)

local ResolvedRegionDeltaBoundary = {
	SCHEMA_VERSION = 1,
}

export type BaseReference = {
	boundarySchemaVersion: number,
	recipeSchemaVersion: number,
	regionId: string,
	recipeFingerprint: string,
}

local BASE_REFERENCE_KEYS: { [string]: boolean } = table.freeze({
	boundarySchemaVersion = true,
	recipeSchemaVersion = true,
	regionId = true,
	recipeFingerprint = true,
})

local function exactPlainRecord(value: unknown): any
	assert(type(value) == "table", "delta base reference must be a table")
	local source = value :: any
	assert(getmetatable(source) == nil, "delta base reference must not have a metatable")
	for key in pairs(source) do
		assert(
			type(key) == "string" and BASE_REFERENCE_KEYS[key] == true,
			`delta base reference contains unknown schema key {tostring(key)}`
		)
	end
	return source
end

function ResolvedRegionDeltaBoundary.fromRecipe(recipe: ResolvedRegionRecipe.Recipe): BaseReference
	local canonical = ResolvedRegionRecipe.deserialize(recipe)
	return table.freeze({
		boundarySchemaVersion = ResolvedRegionDeltaBoundary.SCHEMA_VERSION,
		recipeSchemaVersion = canonical.schemaVersion,
		regionId = canonical.regionId,
		recipeFingerprint = canonical.recipeFingerprint,
	})
end

function ResolvedRegionDeltaBoundary.assertMatches(
	recipe: ResolvedRegionRecipe.Recipe,
	reference: BaseReference
): ()
	local canonical = ResolvedRegionRecipe.deserialize(recipe)
	local source = exactPlainRecord(reference)
	assert(
		source.boundarySchemaVersion == ResolvedRegionDeltaBoundary.SCHEMA_VERSION,
		"delta base boundary schema version mismatch"
	)
	assert(source.recipeSchemaVersion == canonical.schemaVersion, "delta base recipe schema version mismatch")
	assert(source.regionId == canonical.regionId, "delta base region identity mismatch")
	assert(source.recipeFingerprint == canonical.recipeFingerprint, "delta base recipe fingerprint mismatch")
end

return table.freeze(ResolvedRegionDeltaBoundary)
