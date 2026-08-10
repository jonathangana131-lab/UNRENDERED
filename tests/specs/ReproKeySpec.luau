local ReproKey = require("../support/ReproKey")

return function(runner)
	local fields = {
		worldSeed = "world|7",
		version = "reality=1;topology=1",
		region = "4,-2,9",
		subsystem = "topology",
		localKey = "hall=A",
	}
	local reproKey = ReproKey.format(fields)

	runner:test("ReproKey canonical formatting", reproKey, function(expect)
		expect:equal(
			reproKey,
			"worldSeed=world%7C7|version=reality%3D1;topology%3D1|region=4,-2,9|subsystem=topology|localKey=hall%3DA"
		)
		expect:equal(ReproKey.format(fields), reproKey, "repeat formatting")
	end)

	runner:test("ReproKey rejects incomplete keys", nil, function(expect)
		expect:throws(function()
			ReproKey.format({
				worldSeed = "world-7",
				version = "1",
				region = "4,-2,9",
				subsystem = "topology",
			})
		end, "localKey must be a non-empty string")
	end)
end
