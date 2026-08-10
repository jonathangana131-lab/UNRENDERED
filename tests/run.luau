local process = require("@lune/process")

local TestHarness = require("./support/TestHarness")
local registerDeterministicCore = require("./specs/DeterministicCoreSpec")
local registerReproKey = require("./specs/ReproKeySpec")
local runDeterministicRng = require("./deterministic_rng")
local runFidelityManager = require("./fidelity_manager")
local runFidelityManagerDeterminism = require("./fidelity_manager_determinism")
local runWorldEntity = require("./world_entity")

local runner = TestHarness.new()
registerDeterministicCore(runner)
registerReproKey(runner)

local suiteFailures = runDeterministicRng()
	+ runWorldEntity()
	+ runFidelityManager()
	+ runFidelityManagerDeterminism()
local deterministicPassed = runner:run()

if suiteFailures > 0 or not deterministicPassed then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
