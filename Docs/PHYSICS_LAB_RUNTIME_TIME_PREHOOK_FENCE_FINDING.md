# Physics Lab Runtime hostile-time pre-hook fence finding

Status: bounded Hero-Gate source-depth finding. This document records a regression-integrity gap in the retained `PhysicsLabRuntime` synthesis lineage; it does not change production behavior or claim Roblox Studio evidence.

## Context

Retained runtime synthesis PR #408 deliberately fences the *entire* `FidelityManager.step()` call with `transitionInFlight` before invoking the manager. Its production comment names both caller-owned policy inputs **and time** as values whose hostile operators/metamethods must not receive a pre-hook mutation window.

That ordering matters because `FidelityManager.step()` validates `nowSeconds` before policy evaluation and before accepted manager mutation. The validation performs numeric equality/order checks (`isFinite(nowSeconds)` and monotonic comparison). A dynamically supplied non-number table can therefore execute comparison metamethods even though the public Luau type is `number`.

The current production runtime is protected: `transitionInFlight` is already set before calling the manager, so a hostile time metamethod that calls `runtime:dispose()` or recursively mutates the runtime reaches `assertMutationAllowed()` and fails closed; the outer `pcall` then clears the guard for retry.

## Concrete regression gap

`tests/physics_lab_runtime.luau` directly proves the policy-input half of that pre-hook contract with a metatable-backed `PolicyInputs` value whose `__index` attempts `runtime:dispose()`. It verifies rejection, preserved registry/Fidelity populations, preserved fidelity authority, and an immediate valid retry.

The retained suite does **not** exercise the earlier `nowSeconds` validation half of the same documented fence.

That leaves a narrow regression-integrity seam: a future refactor could move or add time preflight outside the runtime transaction guard while leaving policy-input evaluation protected. The existing hostile-policy regression would still pass even though a hostile time value could again invoke caller code before mutation fencing is active.

## Minimal adversary

A focused pure regression should create a fresh runtime and pass a metatable-backed value as `nowSeconds` whose comparison metamethod attempts a prohibited runtime mutation such as `runtime:dispose()`.

The required assertions are:

1. the malformed time call rejects;
2. the hostile comparison metamethod is actually reached, proving the intended pre-hook window was exercised;
3. the attempted runtime mutation is rejected while the private transaction guard is active;
4. registry and FidelityManager populations remain the full canonical recipe population;
5. the target WorldEntity fidelity remains authoritative and synchronized;
6. the outer failure unwind clears `transitionInFlight` so an immediate canonical numeric-time retry succeeds.

Use the smallest Luau metamethod shape that deterministically exercises the production time-validation comparison path. Do not weaken `FidelityManager`'s fail-closed malformed-time behavior merely to make the fixture convenient.

## Non-duplication

This finding is distinct from the existing runtime capacity findings:

- #451 — complete realization-bearing recipe-value authenticity;
- #467 — top-level and `EntityRecipe` wrapper schema closure;
- #494 — canonical entity sequence/order authenticity;
- #501 — exact dense `recipe.entities` container shape.

It also does not replace the existing hostile-policy-input regression. That test covers a later caller-owned evaluation surface; this finding pins the separately documented and earlier hostile-time validation surface.

FidelityManager source hardening is not proposed here. Retained runtime production already establishes the correct whole-manager transaction fence; the missing piece is adversarial coverage that prevents later refactors from silently narrowing it.

## Recommended integration

Do not create a competing Physics Lab runtime framework. Add the hostile-time regression to the retained runtime synthesis lineage (#408) or its current-main convergence successor alongside the existing hostile-policy pre-hook regression.

Require fresh exact-head canonical CI and independent source/test review after absorption. Keep the regression source-only: it does not require Roblox Studio, viewport, physical-contact, device-performance, persistence, networking, or two-client evidence.

Door, Chair, and Player remain locked behind the Physics Lab Hero Gate.
