--!strict

local Hash32 = require(script.Parent.Parent.Core.Hash32)
local DeterministicRng = require(script.Parent.Parent.Core.DeterministicRng)

local SeedStream = {}

function SeedStream.derive(worldSeed: string, scopes: { string })
	local hash = Hash32.jenkins(worldSeed, 0x9e3779b9)
	for _, scope in scopes do
		hash = Hash32.combine(hash, scope)
	end
	return DeterministicRng.new(hash)
end

return table.freeze(SeedStream)
