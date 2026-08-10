--!strict

export type RegionAddress = {
	x: number,
	z: number,
	layer: number,
}

local RegionAddress = {}

function RegionAddress.new(x: number, z: number, layer: number?): RegionAddress
	assert(x % 1 == 0 and z % 1 == 0, "region coordinates must be integers")
	local resolvedLayer = layer or 0
	assert(resolvedLayer % 1 == 0, "layer must be an integer")
	return table.freeze({ x = x, z = z, layer = resolvedLayer })
end

function RegionAddress.key(address: RegionAddress): string
	return string.format("r:%d:%d:%d", address.x, address.z, address.layer)
end

return table.freeze(RegionAddress)
