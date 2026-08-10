--!strict

local DeterminismContract = require(script.Parent.DeterminismContract)

local StableId = {
	ContractVersion = DeterminismContract.StableIdVersion,
}

export type StableId = string

function StableId.fromParts(namespace: string, parts: { string }): StableId
	return DeterminismContract.stableId(namespace, parts)
end

function StableId.is(value: unknown, namespace: string?): boolean
	return DeterminismContract.isStableId(value, namespace)
end

return table.freeze(StableId)
