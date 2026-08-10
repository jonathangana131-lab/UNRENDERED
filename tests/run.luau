local process = require("@lune/process")

local TestHarness = require("./support/TestHarness")
local registerDeterministicCore = require("./specs/DeterministicCoreSpec")
local registerReproKey = require("./specs/ReproKeySpec")
local runDeterministicRng = require("./deterministic_rng")
local runWorldEntity = require("./world_entity")

local runner = TestHarness.new()
registerDeterministicCore(runner)
registerReproKey(runner)

local deterministicPassed = runner:run()
local legacyFailures = runDeterministicRng() + runWorldEntity()

if not deterministicPassed or legacyFailures > 0 then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
