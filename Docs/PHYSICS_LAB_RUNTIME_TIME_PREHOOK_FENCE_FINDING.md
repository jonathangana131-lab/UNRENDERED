# Physics Lab Runtime / FidelityManager pre-hook convergence finding

Status: bounded Hero-Gate integration finding. This document records a concrete regression conflict between two retained Physics Lab source lineages. It does not change production behavior or claim Roblox Studio evidence.

## Retained lineages

Runtime synthesis PR #408 retains `PhysicsLabRuntime.step()` from the runtime-transaction lineage. It sets private `transitionInFlight` before entering `FidelityManager.step()`, wraps that whole manager call in `pcall`, clears the guard on failure, and keeps callback/runtime mutation fail-closed.

Its retained `tests/physics_lab_runtime.luau` contains a pre-hook adversary built for the older FidelityManager behavior. A metatable-backed `PolicyInputs` object increments `policyReads` from `__index`, attempts `runtime:dispose()`, and the test explicitly requires `policyReads > 0` while proving the runtime guard blocks the mutation and remains retryable.

FidelityManager generation-4 PR #385 deliberately strengthens the lower boundary. Its retained source requires `PolicyInputs` to be a metatable-free plain table before reading fields, requires numeric values such as `nowSeconds` to establish primitive-number type before numeric operators, and its adversarial suite requires hostile policy-input and hostile-time metamethod counts to remain exactly zero.

## Concrete convergence conflict

The two retained behaviors are individually safe, but their current regressions are not composition-compatible.

If #385's accepted FidelityManager hardening is composed underneath #408 without reconciling the runtime test, the metatable-backed `PolicyInputs` value is rejected by `validateInputs()` before `__index` executes. That is the stronger desired boundary, but #408's assertion that the hostile policy metatable **must** be exercised (`policyReads > 0`) becomes expected-red.

This is not evidence that #385 should be weakened or that #408's whole-manager transaction fence should be removed. It is a stale test expectation at the integration seam between two retained lineages.

The same composition also makes a proposed hostile-`nowSeconds` runtime metamethod adversary inappropriate: #385 already rejects hostile time with zero metamethod execution before numeric comparison. Regression coverage should preserve that stronger no-execute boundary rather than deliberately force a caller metamethod to run.

## Smallest safe reconciliation

When the runtime and FidelityManager lineages are composed, update the runtime pre-hook regression to match the stronger lower-layer contract:

1. keep a metatable-backed hostile `PolicyInputs` value, but require zero `__index` execution;
2. keep the malformed call rejection assertion;
3. prove registry and FidelityManager populations remain the full canonical recipe population;
4. prove the target WorldEntity fidelity remains authoritative and synchronized;
5. prove an immediate canonical retry succeeds, preserving `PhysicsLabRuntime` failure-unwind semantics;
6. add or retain a hostile `nowSeconds` composition assertion that requires zero comparison/arithmetic metamethod execution, matching #385 rather than the older manager behavior;
7. retain the existing capture/observer/dispose/reentrant callback tests as the direct runtime transaction-guard evidence for caller code that is legitimately invoked inside the transition transaction.

Do not delete the private whole-manager guard merely because malformed policy/time values become no-execute. The guard still scopes the full manager operation and the runtime-owned transition callback path, while the lower manager now provides a stricter rejection boundary for malformed plain-data inputs.

## Why this matters

A merge that simply combines production source and runs the retained suites will fail for the wrong reason: the stronger no-execute FidelityManager contract violates an older test's requirement to execute hostile caller code. Treating that failure as a product regression could pressure an integrator to weaken #385 just to satisfy stale runtime evidence.

The convergence fix should instead update the runtime regression so both safety layers are represented accurately:

- malformed policy/time values are rejected before caller metamethod execution by FidelityManager;
- runtime transaction/callback mutations remain fenced and retryable by PhysicsLabRuntime.

## Non-duplication

This finding is distinct from the existing runtime capacity findings:

- #451 — complete realization-bearing recipe-value authenticity;
- #467 — top-level and `EntityRecipe` wrapper schema closure;
- #494 — canonical entity sequence/order authenticity;
- #501 — exact dense `recipe.entities` container shape.

It is also distinct from #385 itself. #385 owns the lower FidelityManager no-execute behavior; this finding records the stale retained **runtime** regression that must be reconciled when #385 and #408 converge.

## Recommended integration

Do not create a competing Physics Lab runtime or FidelityManager framework. Absorb this test reconciliation into the retained #408/#385 current-main convergence path, alongside the already accepted runtime and fidelity invariants.

Require fresh exact-head canonical CI and independent source/test review after composition. This is source/test integration work only; it does not require Roblox Studio, viewport, physical-contact, device-performance, persistence, networking, or two-client evidence.

Door, Chair, and Player remain locked behind the Physics Lab Hero Gate.
