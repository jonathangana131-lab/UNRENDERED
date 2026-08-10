local ReproKey = require("../support/ReproKey")

return function(runner)
	local fields = {
		worldSeed = "world|alpha",
		version = "determinism=1;generator=1",
		region = "r:0:0:0",
		subsystem = "worldgen.topology",
		localKey = "hall=A",
	}
	local reproKey = ReproKey.format(fields)

	runner:test("ReproKey canonical formatting", reproKey, function(expect)
		expect:equal(
			reproKey,
			"worldSeed=world%7Calpha|version=determinism%3D1;generator%3D1|region=r:0:0:0|subsystem=worldgen.topology|localKey=hall%3DA"
		)
		expect:equal(ReproKey.format(fields), reproKey, "repeat formatting")
	end)

	runner:test("ReproKey rejects incomplete keys", nil, function(expect)
		expect:throws(function()
			ReproKey.format({
				worldSeed = "world-alpha",
				version = "determinism=1;generator=1",
				region = "r:0:0:0",
				subsystem = "worldgen.topology",
			})
		end, "localKey must be a non-empty string")
	end)
end
