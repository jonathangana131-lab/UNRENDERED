--!strict

local PhysicsLabScale = {
	-- Project-owned Physics Lab realization boundary. Canonical lab/ObjectGenome
	-- geometry remains SI meters; only physical Roblox representation uses studs.
	METERS_PER_STUD = 0.28,
}

PhysicsLabScale.STUDS_PER_METER = 1 / PhysicsLabScale.METERS_PER_STUD

local function assertFinite(name: string, value: unknown): ()
	assert(type(value) == "number", `{name} must be a number`)
	local numericValue = value :: number
	assert(
		numericValue == numericValue and numericValue > -math.huge and numericValue < math.huge,
		`{name} must be finite`
	)
end

function PhysicsLabScale.metersToStuds(meters: number): number
	assertFinite("meters", meters)
	local studs = meters * PhysicsLabScale.STUDS_PER_METER
	assertFinite("converted studs", studs)
	return studs
end

function PhysicsLabScale.studsToMeters(studs: number): number
	assertFinite("studs", studs)
	local meters = studs * PhysicsLabScale.METERS_PER_STUD
	assertFinite("converted meters", meters)
	return meters
end

return table.freeze(PhysicsLabScale)
