local ReproKey = {}

local FIELD_ORDER = {
	"worldSeed",
	"version",
	"region",
	"subsystem",
	"localKey",
}

local function escape(value)
	local escaped = string.gsub(value, "%%", "%%25")
	escaped = string.gsub(escaped, "|", "%%7C")
	escaped = string.gsub(escaped, "=", "%%3D")
	escaped = string.gsub(escaped, "\r", "%%0D")
	escaped = string.gsub(escaped, "\n", "%%0A")
	return escaped
end

function ReproKey.format(fields)
	assert(type(fields) == "table", "repro key fields must be a table")

	local encoded = {}
	for _, fieldName in FIELD_ORDER do
		local value = fields[fieldName]
		assert(type(value) == "string" and value ~= "", `{fieldName} must be a non-empty string`)
		table.insert(encoded, `{fieldName}={escape(value)}`)
	end

	return table.concat(encoded, "|")
end

return table.freeze(ReproKey)
