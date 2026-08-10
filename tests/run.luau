local process = require("@lune/process")

local TestHarness = require("./support/TestHarness")
local registerDeterministicCore = require("./specs/DeterministicCoreSpec")
local registerReproKey = require("./specs/ReproKeySpec")
local runDeterministicRng = require("./deterministic_rng")
local runFidelityManager = require("./fidelity_manager")
local runFidelityManagerDeterminism = require("./fidelity_manager_determinism")
local runFidelityManagerRejectedStepAtomicity = require("./fidelity_manager_rejected_step_atomicity")
local runMaterialDNA = require("./materialdna_contract")
local runObjectGenome = require("./object_genome")
local runObjectGenomeContractLock = require("./object_genome_contract_lock")
local runWorldEntity = require("./world_entity")
local runWorldEntityRegistryShape = require("./world_entity_registry_shape")

local runner = TestHarness.new()
registerDeterministicCore(runner)
registerReproKey(runner)

local legacyFailures = runDeterministicRng()
	+ runWorldEntity()
	+ runWorldEntityRegistryShape()
	+ runFidelityManager()
	+ runFidelityManagerDeterminism()
	+ runFidelityManagerRejectedStepAtomicity()
	+ runMaterialDNA()
	+ runObjectGenome()
	+ runObjectGenomeContractLock()
local deterministicPassed = runner:run()

if legacyFailures > 0 or not deterministicPassed then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
