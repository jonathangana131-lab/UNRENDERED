# Deterministic Testing

UNRENDERED's canonical deterministic systems must fail with exact, durable repro information. Pure regression tests run in Lune so deterministic bugs can be reproduced without Roblox Studio.

## Run

```bash
lune run tests/run
```

CI runs the same entrypoint after formatting and lint checks.

## Harness layout

- `tests/run.luau` registers suites and owns the process exit code.
- `tests/support/TestHarness.luau` provides named tests, assertions, summary output, and optional repro-key reporting.
- `tests/support/ReproKey.luau` formats canonical repro keys.
- `tests/support/ProductionLoader.luau` executes actual production ModuleScript source under Lune with a minimal `script`/ModuleScript `require` adapter.
- `tests/specs/` contains focused regression suites.

The production loader exists so deterministic tests exercise the implementation in `src/` instead of maintaining copied test-only versions of hashing, IDs, or RNG algorithms. It is intentionally narrow: it emulates only ModuleScript parent/child lookup and `require` behavior needed by pure domain modules. Roblox engine behavior still belongs in Studio tests.

## Repro keys

Every procedural or deterministic failure that can depend on world context should carry these fields in this order:

1. `worldSeed`
2. `version`
3. `region`
4. `subsystem`
5. `localKey`

Example:

```text
worldSeed=world-7|version=reality%3D1;topology%3D1|region=4,-2,9|subsystem=topology|localKey=hall-A
```

The formatter escapes delimiters so the key remains one unambiguous line in CI logs. Version text should identify every generator/schema version that materially affects the reproduced result.

## Golden vectors

Golden vectors are compatibility contracts, not convenience snapshots. Current coverage locks:

- `Hash32.jenkins` and `Hash32.combine` output,
- StableId output and validation behavior,
- deterministic RNG sequences including zero-seed fallback,
- scoped `SeedStream` output and subsystem isolation.

If an intentional architecture change requires a golden vector to change, treat that as a deterministic contract migration: document the reason, assess already-resolved-world consequences, and update the vector in the same reviewed change. Do not casually regenerate expected values to make CI green.

## Adding a regression

1. Reduce the failure to pure deterministic/domain inputs where possible.
2. Record its exact repro key.
3. Add a focused test under `tests/specs/`.
4. Register the suite in `tests/run.luau`.
5. Prefer fixed expected outputs for compatibility-sensitive algorithms and invariant assertions for broader behavior.
6. Keep Roblox Instances, networking, rendering, and physics-engine behavior in their appropriate Studio/lab validation paths.

A failed harness case prints its test name, assertion failure, and `REPRO` key when supplied, followed by a compact pass/fail summary.
