--!strict

local MAX_SAFE_INTEGER = 9007199254740991

export type RegionAddress = {
	x: number,
	z: number,
	layer: number,
}

local RegionAddress = {}

local function isSafeInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
		and math.abs(value) <= MAX_SAFE_INTEGER
end

local function validatePlainShape(value: any)
	assert(type(value) == "table", "region address must be a table")
	assert(getmetatable(value) == nil, "region address must not have a metatable")

	local seen = 0
	for key in pairs(value) do
		assert(key == "x" or key == "z" or key == "layer", `region address contains unsupported key {tostring(key)}`)
		seen += 1
	end
	assert(seen == 3 and value.x ~= nil and value.z ~= nil and value.layer ~= nil, "region address requires x, z, and layer")
	assert(isSafeInteger(value.x) and isSafeInteger(value.z), "region coordinates must be safe integers")
	assert(isSafeInteger(value.layer), "layer must be a safe integer")
end

function RegionAddress.new(x: number, z: number, layer: number?): RegionAddress
	local resolvedLayer = if layer == nil then 0 else layer
	assert(isSafeInteger(x) and isSafeInteger(z), "region coordinates must be safe integers")
	assert(isSafeInteger(resolvedLayer), "layer must be a safe integer")
	return table.freeze({ x = x, z = z, layer = resolvedLayer })
end

function RegionAddress.fromPlainData(value: any): RegionAddress
	validatePlainShape(value)
	return RegionAddress.new(value.x, value.z, value.layer)
end

function RegionAddress.toPlainData(address: RegionAddress): RegionAddress
	local canonical = RegionAddress.fromPlainData(address)
	return { x = canonical.x, z = canonical.z, layer = canonical.layer }
end

function RegionAddress.key(address: RegionAddress): string
	local canonical = RegionAddress.fromPlainData(address)
	return string.format("r:%d:%d:%d", canonical.x, canonical.z, canonical.layer)
end

function RegionAddress.equal(left: RegionAddress, right: RegionAddress): boolean
	return RegionAddress.key(left) == RegionAddress.key(right)
end

return table.freeze(RegionAddress)
