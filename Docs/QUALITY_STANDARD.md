# UNRENDERED Quality Standard — REALITY-GRADE

UNRENDERED is intentionally difficult to build. The project is allowed to be small for a long time; it is not allowed to normalize unfinished systems, obvious procedural repetition, stock-Roblox feel, or throwaway architecture.

Core motto:

> **Depth before breadth. Normality before anomaly. Data before representation. Measure before optimize. Never normalize jank. Finish deeply. Expand carefully.**

## 1. Reality-Grade

A major feature is not done because it works or because CI passes. It is **Reality-Grade** only when every applicable layer is complete enough that the system could ship without a planned rewrite.

Typical gates:
1. domain contract and stable IDs,
2. deterministic/reproducible behavior where applicable,
3. functional behavior,
4. physical correctness and edge cases,
5. integration with surrounding systems,
6. visual finish,
7. audio finish,
8. input/accessibility finish,
9. multiplayer/server-authority safety,
10. persistence/streaming lifecycle safety,
11. performance and memory budget,
12. automated tests/fuzz/repro cases,
13. Studio experience tests,
14. independent review,
15. polish/jank pass.

A feature may be merged incrementally before Reality-Grade, but the Feature Epic remains open and keeps priority until its required gates are complete.

## 2. Depth before breadth

Do not create 20 half-finished systems because 20 workers are available.

The project allows at most **3 active major Feature Epics**. Extra admitted workers deepen those epics through implementation, testing, visual/audio polish, tooling, performance, review, fuzzing, and integration; excess chats park instead of creating breadth.

An issue being open does **not** mean it is unlocked. `Docs/PROJECT_STATE.md` is the authoritative list of currently unlocked work.

Do not begin a gated P1/P2 feature simply because it looks more exciting.

## 3. Strike-team model

A mature feature can have multiple independent child tasks:
- implementation/contracts,
- QA/fuzzing,
- physics/performance,
- graphics/materials,
- audio,
- networking/persistence,
- UX/accessibility,
- integration/review.

Workers claim one major task at a time. They may continue to another compatible child after publishing their current work.

One worker does not need to own an entire feature forever, but one Epic must have a coherent integration path. Competing implementations require an ADR and evidence.

## 4. Hero Features

Development proves systems through a small number of absurdly complete examples before broad content expansion.

Suggested progression:
1. deterministic reality/identity kernel,
2. Reality-Grade door,
3. Reality-Grade chair,
4. Reality-Grade player walking/body interaction,
5. Reality-Grade small office cluster,
6. first two-player physical interaction,
7. first impossible spatial event,
8. first Still Life,
9. first entity,
10. first persistent settlement.

After a Hero Feature proves a framework, expand with families/variants rather than rewriting the framework.

## 5. Perfect 5 Minutes

The first experiential target is not a giant map. It is five minutes in a tiny office cluster that makes a player question whether this is Roblox.

Required qualities eventually include:
- excellent physical movement,
- one excellent door,
- one excellent chair,
- one cabinet/prop mechanism,
- flashlight/lighting interaction,
- believable commercial materials,
- strong fluorescent atmosphere,
- material-driven impact/scrape audio,
- clean streaming/representation lifecycle,
- no stock Roblox movement/UI feel,
- no enemy required.

If this is not compelling, adding kilometers of rooms is the wrong fix.

## 6. Experience tests

Automated assertions are necessary but insufficient. Every Hero Feature must have permanent experience scenarios.

Example door scenarios:
- slowly open from handle,
- peek through a small gap,
- slam at multiple forces,
- obstruct with furniture,
- push from both sides,
- entity interaction,
- two-player interaction,
- leave/reload region,
- server-authority correction,
- damaged/aged variants,
- acoustics and light occlusion.

Example chair scenarios:
- walk into it,
- sprint into it,
- drag by different grip points,
- tip/roll/spin,
- drop down stairs,
- entity trips over it,
- two players move it,
- sleep/wake/promote/demote,
- persist/reconstruct,
- stress stack/impact cases.

If it technically passes but visibly feels cheap or unstable, it fails Reality-Grade review.

## 7. Permanent labs

Maintain source-driven permanent validation environments rather than disposable demos:
- `BodyLab`,
- `DoorLab`,
- `FurnitureLab`,
- `MaterialLab`,
- `AcousticsLab`,
- `WorldGenLab`,
- `StillLifeLab`,
- `NetworkLab`.

Labs use production contracts and become regression fixtures.

## 8. Jank Ledger

Known quality defects must live in GitHub issues or a linked Epic checklist, not hidden TODO comments.

Examples:
- caster oscillation,
- hand penetration,
- camera roll spike,
- visible streaming seam,
- repeated texture phase,
- audio sample repetition,
- replication correction jitter.

A Feature Epic cannot reach Reality-Grade while material jank remains untracked. Accepted compromises require a reason and follow-up trigger.

## 9. Procedural quality

Procedural generation must include **procedural rejection**.

Every important generator should support:
- deterministic input/repro key,
- scoped/versioned RNG,
- bounds/plausibility validation,
- distribution testing,
- performance metrics,
- failure fallback,
- sample rendering where visual,
- rejection of invalid/cheap candidates.

For rare/high-significance content, oversample several cheap candidate plans and choose the strongest valid result. Spend more compute on rare content, not on every hallway.

The test question is: **Can a player tell the result was assembled by random independent choices?** If yes, improve semantic constraints.

## 10. Normality first

The Banality Engine is as important as anomaly generation.

Normal offices, bathrooms, halls, utility rooms, waiting spaces, furniture arrangements, lighting, signage, wear, and acoustics must be believable. Anomaly is a restrained violation of a trusted baseline.

Do not stack multiple independent rare rolls in one room. A shared rarity/anomaly budget controls major weirdness.

## 11. Staged generation

Never build one giant `GenerateRegion()` implementation.

Canonical pipeline is staged and inspectable:
1. macro reality fields,
2. RegionIntent / WorldIntent,
3. apparent building history,
4. topology graph,
5. structural plan,
6. service logic (ceiling/HVAC/electrical/plumbing as appropriate),
7. MaterialDNA/history,
8. lighting/electrical plan,
9. SupplyChainDNA / furnishing plan,
10. ObjectGenome population,
11. Ghost Traffic / wear / cleaning history,
12. narrative incidents/traces,
13. atmosphere,
14. anomaly pass,
15. Still Life/entity eligibility,
16. first-observation lock,
17. Roblox realization.

Each stage has its own version and can be tested/profiled independently.

## 12. Three worlds

Keep these separate:

### Conceptual world
World seed, addresses, fields, semantic relationships, possible topology, players/anchors. No Roblox Instances required.

### Resolved world
Observed/locked recipes, IDs, material/object genomes, histories, deltas. Mostly plain data.

### Physical world
The currently instantiated Roblox representation around active observers.

Workspace is never the canonical universe database.

## 13. Simulation LOD

Every expensive system needs fidelity levels, not only meshes.

Examples:
- physics articulation,
- entity cognition,
- audio propagation,
- mechanisms,
- particles,
- dynamic lighting,
- networking frequency,
- persistence detail.

F0–F4 identity survives representation changes.

The Fidelity Manager maintains budgets and uses distance, visibility, observation, motion, recent interaction, significance, network relevance, and entity relevance. Use hysteresis so objects do not thrash between states.

## 14. Performance architecture

Performance is a feature, not end-stage cleanup.

Every costly subsystem exposes metrics. Maintain configurable budget profiles for server/client CPU, memory, active Instances, rigid bodies, constraints, generated cells, network bandwidth, lights/shadows, textures, audio voices, and job queues.

Rules:
- bounded caches only,
- bounded generation/persistence queues,
- incremental/yielding generation,
- cheap predictive planning before observation lock,
- only instantiate what presentation requires,
- static deterministic content reconstructs locally from recipes where safe,
- detailed cross-server physics is never routed through coarse messaging services.

Measure before optimizing, but design replaceable boundaries before bottlenecks appear.

## 15. Perceptible Depth rule

Do not simulate complexity merely because it sounds advanced.

A simulation earns complexity when players can see, hear, feel, use, reason about, or discover its consequences.

Prefer useful abstractions:
- simplified airflow over CFD,
- circuit topology over electrical SPICE simulation,
- meaningful water/wetness over universal fluid dynamics,
- active balance/contact over full biomechanics.

## 16. Graphics quality

Internal challenge: **Can you tell it is Roblox because of defaults or jank?**

Reject stock-feeling movement, default-looking lighting, generic Toolbox composition, obvious tiled textures, cheap UI, and inconsistent asset styles.

Visual realism comes from:
- correct real-world scale,
- believable geometry/construction,
- coherent PBR materials,
- multi-scale wear/history,
- restrained atmospheric effects,
- excellent composition,
- light/shadow discipline,
- consistent art direction.

Post-processing is not a substitute for geometry/material/light quality.

## 17. Audio quality

A visual/physics feature is not finished with placeholder stock audio.

Use semantic/material-driven sound definitions and variation. Doors, casters, impacts, scrapes, latches, mechanisms, rooms, HVAC and distant events should sound causally connected to materials and spaces.

Silence is an authored state, not missing content.

## 18. Multiplayer quality

Shared physical truth is server-authoritative/validated. Clients may predict presentation, but do not trust client position, ownership, damage, rare discoveries, inventory, or arbitrary remote payloads.

Remote contracts are narrow and typed. Cross-server coordination is high-level and low-volume.

Reconnects, region authority handoffs and idempotent persistence must be tested before valuable persistent objects/settlements depend on them.

## 19. Content pipeline

Do not let generated content become asset soup.

Use project-owned manifests for meshes, materials, audio and UI assets. Maintain real-scale standards and licensing provenance. Expensive mesh/PBR production can be offline (including Blender); runtime primarily assembles approved families and varies safe parameters/state.

Procedural families must look manufacturable before anomaly.

## 20. Independent Reality-Grade review

A worker should not unilaterally declare its own major Epic finished.

An independent reviewer audits applicable categories:
- architecture,
- functionality,
- determinism,
- physics,
- visuals,
- audio,
- UX/accessibility,
- multiplayer/security,
- persistence,
- performance,
- testing,
- regression risk.

The reviewer may return the Epic to implementation/polish even when CI is green.

## 21. System freeze after proof

Once a framework reaches Reality-Grade, its public contracts become intentionally stable. New workers add families/capabilities through those contracts rather than rewriting them for taste.

A significant rewrite requires an ADR containing measured limitation, alternatives, migration plan, regressions/tests, and why extension is insufficient.

## 22. Avoid the opposite failure: overengineering

Do not pre-build abstractions for hypothetical needs with no evidence.

Use **stable domain contract + simplest production-worthy implementation**. Extend after real requirements appear.

## 23. Development sequence

Broad order:
1. production/tooling foundation,
2. deterministic identity/reality contracts,
3. production Physics Lab,
4. Reality-Grade physical object/door/chair primitives,
5. physical player/body feel,
6. visual/material/audio reality,
7. procedural normality/office grammar,
8. shared two-player physical truth,
9. first impossible spatial rule,
10. persistence/cross-server world,
11. Still Lifes/entities,
12. deep environmental/infrastructure systems,
13. large-scale cultural memory/reality evolution,
14. broad content expansion.

Do not skip lower layers merely because a higher layer is exciting.

## 24. Final standard

A feature is good when it adds a coherent capability to the long-term universe without creating a future rewrite, performance cliff, art inconsistency or persistent jank.

**Do not optimize for closing issues. Optimize for a game where every finished system feels inevitable, physical, eerie and expensive.**
