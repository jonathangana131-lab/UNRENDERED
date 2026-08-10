--!strict

local Hash32 = require(script.Parent.Hash32)

local StableId = {}

export type StableId = string

local function canonicalize(parts: { string }): string
	return table.concat(parts, "\30")
end

function StableId.fromParts(namespace: string, parts: { string }): StableId
	assert(namespace ~= "", "namespace must not be empty")
	local canonical = canonicalize(parts)
	local high = Hash32.jenkins(namespace .. "\31" .. canonical, 0x243f6a88)
	local low = Hash32.jenkins(namespace .. "\31" .. canonical, 0x85a308d3)
	return string.format("%s:%s%s", namespace, Hash32.hex(high), Hash32.hex(low))
end

function StableId.is(value: unknown, namespace: string?): boolean
	if type(value) ~= "string" then
		return false
	end
	if namespace == nil then
		return string.match(value, "^[%w_.-]+:%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
	end
	return string.match(value, "^" .. namespace .. ":%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

return table.freeze(StableId)
