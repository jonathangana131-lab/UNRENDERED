local process = require("@lune/process")

local TestHarness = require("./support/TestHarness")
local registerDeterministicCore = require("./specs/DeterministicCoreSpec")
local registerReproKey = require("./specs/ReproKeySpec")

local runner = TestHarness.new()
registerDeterministicCore(runner)
registerReproKey(runner)

if not runner:run() then
	process.exit(1)
end
