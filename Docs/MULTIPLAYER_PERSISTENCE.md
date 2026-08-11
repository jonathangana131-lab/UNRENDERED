# Multiplayer and Persistence

## One conceptual world

Players share a canonical WorldId even when multiple Roblox server processes host active regions. A Roblox server is a temporary simulation worker, not the universe.

## Active region authority

A live region has an authority lease/record. Durable truth is stored through DataStore-backed repositories; rapidly changing cross-server routing/lease/cache state can use MemoryStore where appropriate. MessagingService can coordinate bounded notifications. All cloud calls stay behind project services.

The server is the authority for gameplay-critical resolved truth inside its active simulation scope. Clients may observe, predict, render, and report evidence, but a client report is never itself permission to create or rewrite canonical WorldEntity identity, resolved-region recipes, persistence state, or authoritative ownership.

## Hero Gate two-client authority contract

The permanent Physics Lab uses a deliberately narrow multiplayer proof before broader network architecture is unlocked.

Source-level invariants:
- the server owns creation of the canonical lab runtime and its WorldEntity truth;
- clients are independent observers of replicated canonical state, not alternate generators of canonical truth;
- the server binds each observation to the actual calling player/session and server-established request context rather than trusting client-supplied observer identity or request ownership;
- a client observation must be comparable using stable domain identity, not Roblox Instance identity alone;
- canonical comparison includes the lab schema version and resolved-region schema version as truth provenance, not only recipe/world/region IDs and content fingerprints;
- canonical count evidence must be internally consistent with structure: for the full-F2 Hero Gate baseline, entity/represented counts must agree with the server-owned canonical entity-ID set rather than merely matching echoed client fields;
- client-supplied identity, counts, fingerprints, repro keys, schema versions, or state are untrusted evidence until checked against server-owned truth;
- teardown or evidence handoff must fail closed: missing, duplicate, stale, malformed, unknown-version, or cross-request observations cannot be merged into a passing result.

A true two-client Studio evidence row requires one real multiplayer server session with at least two independently observed clients. Acceptance requires exactly one canonical lab root and agreement across both clients on the server-established WorldId, RegionId, lab schema version, resolved-region schema version, resolved fingerprint/repro identity, canonical entity IDs, and required structure/count facts. At the full-F2 baseline, both canonical counts must equal the authoritative canonical entity-ID count, and each client must independently observe that same complete set. A mismatch is evidence of divergence; it is never repaired by choosing one client as canonical.

The evidence transport/evaluator schema must itself be explicitly versioned. Adding a new canonical truth field to the server or client observation payload is not sufficient if the evaluator does not recognize and require that field; all three sides must advance together and preserve fail-closed handling for unknown/missing fields. Likewise, the semantic evaluator must independently enforce relationships between fields instead of relying on producer-side assertions to make inconsistent durable payloads impossible.

Matching observations prove only the tested shared canonical view. They do not establish a blanket authority claim for future movement, physics ownership, damage, inventory, prediction, persistence, or networking systems.

Offline/source tests may harden comparison, validation, serialization, and fail-closed rules, but they cannot satisfy the real two-client engine evidence requirement. Until accepted Studio evidence exists, true two-client canonical authority remains **UNVERIFIED**.

## Region convergence

Unobserved space between distant players is potential. If independently observed bubbles approach, a reconciliation job receives both canonical boundaries and generates a bridge that preserves established truth.

Static/canonical structure should replicate primarily as compact recipe/IDs where practical; dynamic objects/entities replicate authoritative state.

## Interest dimensions

A player can be relevant by:
- visual/physics proximity,
- acoustic reach,
- radio/phone connection,
- security camera connection,
- global event participation.

Do not equate network interest only with render distance.

## Persistence model

Region = generated base + durable deltas.

Deltas can include:
- moved significant object,
- damage,
- door/circuit state,
- writing,
- dropped equipment,
- recording,
- reality anchor,
- significant entity injury/state.

Never persist the whole Workspace hierarchy.

## Reality confidence

Observation, multiple observers, player modification, recordings/anchors, settlements, and significance can stabilize a region. Abandoned low-confidence regions may become eligible for explicitly designed forgetting/mutation rules. High-significance player work is not casually randomized away.

## Settlements

Players build with found physical objects instead of a construction UI. Long-lived areas can become culturally named anchors. If abandoned, surrounding low-confidence routes may change while anchored core truths remain, producing emergent archaeology.

## Entry Cohorts

Friends can intentionally enter nearby for usability. Once badly separated, the world does not automatically rubber-band them together.

## Communication

Primary presentation:
- proximity voice,
- radios,
- telephones,
- intercoms,
- notes/writing,
- recordings.

No global in-world chat spam by default. Moderation, mute/block/report and accessibility controls remain explicit and easy to access.
