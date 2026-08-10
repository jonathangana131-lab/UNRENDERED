# Multiplayer and Persistence

## One conceptual world

Players share a canonical WorldId even when multiple Roblox server processes host active regions. A Roblox server is a temporary simulation worker, not the universe.

## Active region authority

A live region has an authority lease/record. Durable truth is stored through DataStore-backed repositories; rapidly changing cross-server routing/lease/cache state can use MemoryStore where appropriate. MessagingService can coordinate bounded notifications. All cloud calls stay behind project services.

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
