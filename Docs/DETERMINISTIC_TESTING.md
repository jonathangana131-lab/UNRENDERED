# Deterministic Testing

UNRENDERED's canonical deterministic systems must fail with exact, durable repro information. Pure regression tests run in Lune so deterministic bugs can be reproduced without Roblox Studio.

## Run

```bash
lune run tests/run
```

CI runs the same entrypoint after formatting, lint, static analysis, and the canonical-randomness audit.

## Harness layout

- `tests/run.luau` registers deterministic suites, preserves the existing pure domain suites, and owns the process exit code.
- `tests/support/TestHarness.luau` provides named tests, assertions, summary output, and optional repro-key reporting.
- `tests/support/ReproKey.luau` formats canonical repro keys.
- `tests/support/ProductionLoader.luau` executes actual production ModuleScript source under Lune with a minimal `script`/ModuleScript `require` adapter.
- `tests/specs/` contains focused regression suites.

The production loader exists so deterministic tests exercise the implementation in `src/` instead of maintaining copied test-only versions of hashing, IDs, RNG, or stream derivation. It is intentionally narrow: it emulates only ModuleScript parent/child lookup and `require` behavior needed by pure domain modules. Roblox engine behavior still belongs in Studio tests.

## Repro keys

Every procedural or deterministic failure that can depend on world context should carry these fields in this order:

1. `worldSeed`
2. `version`
3. `region`
4. `subsystem`
5. `localKey`

Example:

```text
worldSeed=world-alpha|version=determinism%3D1;reality%3D1|region=r:0:0:0|subsystem=worldgen.topology|localKey=layout
```

The formatter escapes delimiters so the key remains one unambiguous line in CI logs. Version text should identify every generator/schema/contract version that materially affects the reproduced result.

## Golden vectors

Golden vectors are compatibility contracts, not convenience snapshots. The structured harness executes the production modules and locks:

- canonical Hash32 string-list encoding and hash output,
- StableId v1 output and validation behavior,
- deterministic RNG sequences including zero-seed fallback,
- explicit `SeedStream` v1 derivation from world seed, generation version, subsystem salt, and ordered scopes,
- subsystem and generation-version isolation.

The normative deterministic contract remains `Docs/DETERMINISM_CONTRACT.md`. If an intentional architecture change requires a golden vector to change, treat that as a versioned deterministic-contract migration: document the reason, assess already-resolved-world consequences, and update the production contract and regression vector in the same reviewed change. Do not regenerate expected values merely to make CI green.

## Adding a regression

1. Reduce the failure to pure deterministic/domain inputs where possible.
2. Record its exact repro key.
3. Add a focused test under `tests/specs/`.
4. Register the suite in `tests/run.luau`.
5. Prefer fixed expected outputs for compatibility-sensitive algorithms and invariant assertions for broader behavior.
6. Keep Roblox Instances, networking, rendering, and physics-engine behavior in their appropriate Studio/lab validation paths.

A failed harness case prints its test name, assertion failure, and `REPRO` key when supplied, followed by a compact pass/fail summary.
