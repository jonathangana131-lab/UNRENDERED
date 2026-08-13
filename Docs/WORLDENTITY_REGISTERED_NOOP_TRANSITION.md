# WorldEntity Registered No-Op Transition Cost

## Finding

The retained WorldEntity generation-9 source lineage in PR #437 keeps the reviewed own-before-derive lifecycle boundary: detached `WorldEntity.transition()` first re-owns the supplied record so mutable or hostile caller state cannot leak into returned truth.

That safety rule currently also applies when `Registry.transitionRegistered()` receives a transition whose target fidelity already equals the registry-owned record fidelity and `capturedState == nil`.

For that registered case the operation is semantically a no-op: fidelity, persistent state, `stateRevision`, and `representationRevision` all remain unchanged. However, `transitionRegistered()` still calls `WorldEntity.transition()`, which calls `ownRecord()` and deep-clones the already-owned persistent snapshot before returning a new frozen record. The registry then replaces its authoritative record with that new but revision-identical snapshot.

The retained persistent-state limits keep one call bounded (depth 64, 4096 nodes, 65536 cumulative string bytes), but they do not make repeated needless re-ownership free. A public no-op transition can therefore produce avoidable allocation/GC work proportional to the maximum owned snapshot while no revision advertises any state or representation change.

## Current production reachability

Current `FidelityManager.step()` returns before invoking its transition hook when desired fidelity already equals current fidelity, so this finding does **not** claim that the permanent Physics Lab currently performs this work every frame.

The gap is at the public WorldEntity registry lifecycle contract and can become hot if another caller uses `transitionRegistered()` defensively or retries an already-satisfied target. It is therefore a source-depth/performance invariant, not Studio evidence and not proof of current player-visible jank.

## Required boundary

Preserve both existing guarantees:

1. Detached `WorldEntity.transition()` must continue to own/validate caller-provided records before returning truth, including a same-fidelity no-op, because detached input may be mutable.
2. `Registry.transitionRegistered()` may trust the record already held in its closure-private registry as owned immutable truth. When `target == current.fidelity` and `capturedState == nil`, it should return that current record without deep re-ownership or authoritative-record replacement.

Same-fidelity calls **with** captured state remain state captures and must continue to increment `stateRevision` through the existing bounded ownership path.

## Regression target

A focused Pure Luau regression should:

- register a canonical entity with a non-trivial nested persistent snapshot;
- retain the exact registered record reference;
- call `transitionRegistered(entityId, currentFidelity, nil)`;
- prove the returned record and subsequent registry lookup are the exact incumbent owned snapshot;
- prove `stateRevision` and `representationRevision` are unchanged;
- separately prove detached same-fidelity transition of a structurally valid mutable record still returns a newly owned/frozen snapshot rather than exposing the caller table;
- preserve the existing same-fidelity-with-capture revision behavior.

This keeps the optimization inside the registry capability boundary instead of weakening detached validation.

## Scope

This finding does not change StableId, WorldEntity schema, fidelity policy, persistence format, networking, Roblox Instances, or generator versions. It does not unlock Door/Chair/Player work and does not claim Roblox Studio, viewport, contact, performance-device, or two-client evidence.

It is intended for absorption by the existing `HG-BACKFILL-WORLDENTITY` successor lineage after the currently owned PR #437 review/test work is reconciled, rather than as a competing WorldEntity implementation.
