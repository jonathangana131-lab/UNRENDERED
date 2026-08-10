--!strict

local DeterminismContract = require(script.Parent.DeterminismContract)

local Hash32 = {
	ContractVersion = DeterminismContract.Hash32Version,
	EncodingVersion = DeterminismContract.EncodingVersion,
}

function Hash32.jenkins(text: string, seed: number?): number
	return DeterminismContract.hash32(text, seed)
end

function Hash32.combine(seed: number, ...: string): number
	return DeterminismContract.hashParts(seed, { ... })
end

function Hash32.encodeParts(parts: { string }): string
	return DeterminismContract.encodeParts(parts)
end

function Hash32.hex(value: number): string
	return DeterminismContract.hex32(value)
end

return table.freeze(Hash32)
