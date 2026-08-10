--!strict

-- Historical replay boundary only. New canonical truth must use
-- ResolvedRegionRecipe v2; this wrapper intentionally exposes no lock or
-- migration/write constructor.
local Core = require(script.Parent.ResolvedRegionRecipeV1Internal)

local ResolvedRegionRecipeV1 = {
	SCHEMA_VERSION = Core.SCHEMA_VERSION,
	FINGERPRINT_VERSION = Core.FINGERPRINT_VERSION,
	REPLAY_ONLY = true,
}

function ResolvedRegionRecipeV1.deserialize(data: unknown): any
	return Core.deserialize(data)
end

function ResolvedRegionRecipeV1.serialize(recipe: any): { [string]: any }
	return Core.serialize(recipe)
end

function ResolvedRegionRecipeV1.equal(left: any, right: any): boolean
	return Core.equal(left, right)
end

function ResolvedRegionRecipeV1.fingerprint(recipe: any): string
	return Core.fingerprint(recipe)
end

function ResolvedRegionRecipeV1.reproKey(recipe: any): string
	return Core.reproKey(recipe)
end

return table.freeze(ResolvedRegionRecipeV1)
