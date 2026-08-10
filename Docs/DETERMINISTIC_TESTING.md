# Deterministic Testing

UNRENDERED's canonical deterministic systems must fail with exact, durable repro information. Pure regression tests run in Lune so deterministic bugs can be reproduced without Roblox Studio.

## Run

```bash
lune run tests/run
```

CI runs the same entrypoint after formatting, lint, static analysis, and the canonical randomness audit.

## Harness layout

- `tests/run.luau` is the single pure-test entrypoint and owns the process exit code.
- `tests/support/TestHarness.luau` provides named tests, assertions, summary output, and optional repro-key reporting.
- `tests/support/ReproKey.luau` formats canonical repro keys.
- `tests/specs/DeterministicCoreSpec.luau` executes the production `DeterminismContract` module and locks its compatibility vectors.
- `tests/specs/ReproKeySpec.luau` locks repro-key formatting and required fields.
- Existing focused suites such as `tests/deterministic_rng.luau` and `tests/world_entity.luau` still run from the same entrypoint and can migrate onto the shared harness when touched for substantive work.

Deterministic tests must execute production modules rather than maintain test-only copies of hashing, ID, encoding, seed-derivation, or RNG algorithms. The v1 contract is directly importable under Lune, so the harness does not emulate Roblox ModuleScript behavior just to test it. Roblox Instances, networking, rendering, and physics-engine behavior still belong in Studio/lab validation paths.

## Repro keys

Every deterministic or procedural failure that depends on world context should carry these fields in this order:

1. `worldSeed`
2. `version`
3. `region`
4. `subsystem`
5. `localKey`

Example:

```text
worldSeed=world-alpha|version=determinism%3D1;generator%3D1|region=r:0:0:0|subsystem=worldgen.topology|localKey=hall-A
```

The formatter escapes delimiters so the key remains one unambiguous line in CI logs. `version` is an opaque compact version bundle: it must identify every deterministic/generator/schema version that materially affects the reproduced result. `subsystem` should use the same stable subsystem salt family as canonical stream derivation, and `localKey` should identify the smallest stable semantic input needed to replay the case.

## Golden vectors

Golden vectors are compatibility contracts, not convenience snapshots. Current structured coverage locks:

- canonical string-list byte encoding,
- Hash32 v1 output,
- StableId v1 output and validation bounds,
- xorshift32 v1 sequences including zero-seed normalization,
- SeedStream v1 output, generation-version sensitivity, scope ordering, and subsystem isolation.

The separate bounded-integer RNG suite locks rejection sampling against xorshift32's corrected `2^32 - 1` reachable nonzero-state domain, including remainder rejection and the maximum exactly uniform one-draw width. If an intentional architecture change requires a golden vector to change, treat that as a deterministic contract migration: document the reason, assess already-resolved-world consequences, and update the vector in the same reviewed change. Do not regenerate expected values merely to make CI green.

## Adding a regression

1. Reduce the failure to pure deterministic/domain inputs where possible.
2. Record its exact repro key.
3. Add a focused test under `tests/specs/`, or migrate the touched focused suite onto `TestHarness`.
4. Register new suites in `tests/run.luau`.
5. Import the production module being tested; never copy its algorithm into the test.
6. Prefer fixed expected outputs for compatibility-sensitive algorithms and invariant assertions for broader behavior.
7. Keep Roblox Instances, networking, rendering, and physics-engine behavior in their appropriate Studio/lab validation paths.

A failed harness case prints its test name, assertion failure, and `REPRO` key when supplied, followed by a compact pass/fail summary.
