local ProductionLoader = require("../support/ProductionLoader")
local ReproKey = require("../support/ReproKey")

return function(runner)
	local reproKey = ReproKey.format({
		worldSeed = "world-alpha",
		version = "determinism=1;reality=1",
		region = "r:0:0:0",
		subsystem = "test.production-loader",
		localKey = "script-parent-sibling-require",
	})

	runner:test("ProductionLoader resolves script.Parent sibling requires", reproKey, function(expect)
		local loader = ProductionLoader.new(".")
		local first = loader:requireModule("src/shared/Core/Hash32.luau")
		local second = loader:requireModule("src/shared/Core/Hash32.luau")

		expect:truthy(first == second, "module results are cached by production path")
		expect:equal(first.jenkins("UNRENDERED", 1234), 0xd93c5d5c, "sibling contract require executes")
	end)
end
