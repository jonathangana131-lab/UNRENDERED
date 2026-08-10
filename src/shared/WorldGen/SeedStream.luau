--!strict

local DeterminismContract = require(script.Parent.Parent.Core.DeterminismContract)
local DeterministicRng = require(script.Parent.Parent.Core.DeterministicRng)

local SeedStream = {
	ContractVersion = DeterminismContract.SeedStreamVersion,
}

function SeedStream.seedFor(
	worldSeed: string,
	generationVersion: number,
	subsystemSalt: string,
	scopes: { string }
): number
	return DeterminismContract.seedFor(worldSeed, generationVersion, subsystemSalt, scopes)
end

function SeedStream.derive(
	worldSeed: string,
	generationVersion: number,
	subsystemSalt: string,
	scopes: { string }
)
	return DeterministicRng.new(SeedStream.seedFor(worldSeed, generationVersion, subsystemSalt, scopes))
end

return table.freeze(SeedStream)
