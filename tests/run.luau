local process = require("@lune/process")

local TestHarness = require("./support/TestHarness")
local registerDeterministicCore = require("./specs/DeterministicCoreSpec")
local registerReproKey = require("./specs/ReproKeySpec")
local runDeterministicRng = require("./deterministic_rng")
local runFidelityManager = require("./fidelity_manager")
local runFidelityManagerDeterminism = require("./fidelity_manager_determinism")
local runMaterialDNA = require("./materialdna_contract")
local runWorldEntity = require("./world_entity")
local runWorldEntityNewStateShape = require("./world_entity_new_state_shape")
local runWorldEntityRegistryShape = require("./world_entity_registry_shape")

local runner = TestHarness.new()
registerDeterministicCore(runner)
registerReproKey(runner)

local legacyFailures = runDeterministicRng()
	+ runWorldEntity()
	+ runWorldEntityNewStateShape()
	+ runWorldEntityRegistryShape()
	+ runFidelityManager()
	+ runFidelityManagerDeterminism()
	+ runMaterialDNA()
local deterministicPassed = runner:run()

if legacyFailures > 0 or not deterministicPassed then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
