# Roadmap

Order is based on dependency, rewrite prevention, experiential quality, and performance safety—not visual excitement.

Every phase uses `Docs/QUALITY_STANDARD.md`. Phase exit means the required foundation is strong enough to support the next layer without a planned rewrite; major Hero Features remain open until Reality-Grade.

## Wave 0 — Production foundation
- Rojo/Rokit toolchain and green CI.
- strict Luau boundaries.
- stable source layout.
- project docs/autonomous development contract.
- baseline deterministic core.

Exit: reproducible source build and green CI. **Complete.**

## Wave 1 — Foundation Lock
Active foundation Epics:
- deterministic StableId/hash/scoped RNG + golden repro harness,
- WorldEntity identity + F0–F4 representation lifecycle,
- MaterialDNA + ObjectGenome production contracts.

Exit:
- stable/versioned deterministic contracts,
- identity survives Roblox representation lifecycle,
- invalid material/object recipes are rejected,
- downstream systems can depend on these contracts without copying them.

## Wave 2 — Production Physics Lab / Perfect 5 Minutes foundation
A tiny source-driven office lab using production contracts:
- WorldEntity realization,
- material/object binding,
- fidelity manager,
- floor/walls/ceiling,
- door,
- chair,
- table/cabinet/cart,
- stairs/ramp/ledge,
- flashlight/lighting hooks,
- physical-character spawn/body lab,
- diagnostics.

The lab is permanent regression infrastructure, not a disposable prototype.

Exit: a tiny room can be improved toward shipping quality without replacing its foundations.

## Wave 3 — Reality-Grade Hero Objects
Deeply finish a small number of physical objects before content breadth.

### Hero: Door
- DoorGenome/state,
- hinge/latch/handle/closer,
- grip/peek/obstruction,
- material/audio/light/acoustic behavior,
- damage/wear,
- entity interaction,
- multiplayer/persistence/fidelity,
- permanent DoorLab scenarios.

### Hero: Chair
- construction family,
- casters/rolling/tipping,
- grab/drag/carry,
- material/acoustic response,
- sleep/wake/fidelity,
- entity/player collision,
- persistence/networking,
- FurnitureLab stress cases.

Exit: core physical-object framework is Reality-Grade enough that later furniture families expand through it instead of inventing new systems.

## Wave 4 — Active physical human / BodyLab
- physical skeleton,
- actuator abstraction,
- pose motors,
- support contacts and balance,
- gait/step planner,
- stumble/fall/bracing,
- recovery,
- reach/grip/carry,
- crouch/crawl/lean/climb,
- vestibular camera,
- fatigue/injury hooks,
- accessibility/input abstraction,
- measured Roblox authority/constraint experiments.

Exit: walking across one room, colliding with furniture, opening a door, falling and recovering feel unusually good for Roblox.

## Wave 5 — Visual / material / acoustic reality
- MaterialDNA 1.0 bindings,
- curated PBR asset-family manifests,
- real-scale standards,
- commercial wallpaper/drywall/carpet/painted metal/glass families,
- multi-scale wear/dust/moisture/repair,
- FixtureDNA and fluorescent variation,
- material-driven impact/scrape audio,
- room acoustic contracts,
- MaterialLab/AcousticsLab/graphics reference bays.

Exit: the Perfect 5 Minutes feels photographed/coherent rather than like default Roblox with horror post effects.

## Wave 6 — Procedural normality: first office grammar
Build one architectural language extremely well before adding many environment families.

- RegionIntent / WorldIntent,
- staged topology graph,
- commercial-office grammar,
- construction/service logic,
- SupplyChainDNA,
- furniture population,
- Ghost Traffic / wear / cleaning history,
- fake organizational history / Ghost Census evidence,
- transitions inside the same language,
- procedural rejection/oversampling,
- world explorer/fuzzing.

Exit: multiple generated office clusters feel authored, plausible and varied without obvious random-room grammar.

## Wave 7 — Reality kernel / observation
- WorldId/WorldAddress/RegionId,
- first-observation lock,
- resolved recipe vs dynamic delta,
- RealityConfidence,
- Significance / Informational Mass,
- observer classes,
- planned vs observed distinction,
- local/floating representation origins,
- reconstruction hashes/migrations.

Exit: unobserved potential can become canonical truth, unload, and reconstruct exactly while preserving meaningful changes.

## Wave 8 — Atmosphere / perception / transitions
- VibeVector fields,
- Banality/novelty/risk pacing,
- FixtureDNA/electrical relationships,
- exposure/dark adaptation,
- optical/peripheral/reflection rules,
- dream/renovation/service/hard-threshold transition grammars,
- World Director biases,
- Reality Debt/Familiarity Debt,
- sparse adaptive music hooks.

Exit: five-to-fifteen-minute exploration changes vibe coherently without biome title cards or obvious trigger-volume seams.

## Wave 9 — Shared two-player physical truth
- server-authority/prediction experiment outcome,
- narrow typed remotes,
- shared region reconstruction hash,
- interest management,
- physical object/player replication,
- proximity voice hooks,
- reconnect/idempotency,
- NetworkLab latency/loss cases.

Exit: two players can meet in the same generated office and manipulate the same physical environment without stock multiplayer jank.

## Wave 10 — First impossible spatial rule
Only after normal architecture is trusted.

- one explicit impossible-topology mechanism,
- shared multiplayer truth,
- measurement-tool evidence,
- no cheap screen-glitch explanation,
- exact deterministic repro.

Exit: the first anomaly feels like a violation of an understood reality, not a generator bug.

## Wave 11 — Persistent shared-world routing
- world registry,
- authority cells/leases,
- DataStore durable recipes/deltas,
- MemoryStore transient ownership where appropriate,
- bounded MessagingService coordination,
- Entry Cohorts,
- settlement/anchor foundations,
- server/place handoff and failure recovery.

Exit: one conceptual WorldId can be served by temporary simulation workers without treating a Roblox server as the universe.

## Wave 12 — Still Life engine
- StillLifeGenome,
- scene intent/social geometry,
- pose/contact solve,
- physical settling,
- restrained violation budget,
- observation behaviors,
- candidate oversampling/rejection,
- composition evaluation from player approaches,
- StillLifeLab/contact sheets.

Exit: first Still Life is genuinely unsettling, physically believable and not a random monster prefab.

## Wave 13 — Entity framework
- EntityGenome/anatomy validation,
- shared PhysicalCharacter primitives,
- senses/beliefs/memory,
- utility/goal decisions,
- physical body language,
- locomotion/falls/recovery,
- ecology/persistent individual history,
- sound/object interaction.

Exit: first entity behaves like an inhabitant of the simulated world, not a nearest-player chase NPC.

## Wave 14 — Deep environmental / infrastructure systems
Add only when perceptible consequences justify complexity:
- electrical circuits/power,
- phones/radios/intercoms,
- cameras/recordings/security networks,
- temperature/humidity/wetness/water,
- simplified airflow/pressure,
- ceiling/service/plumbing/HVAC relationships,
- documents/signage/paper,
- settlement infrastructure,
- physical measurement tools.

## Wave 15 — Shared memory / cultural contamination
- MemoryMotifs,
- Cultural Echo,
- Behavioral Contamination,
- Ghost Census social graphs,
- fake corporations/suppliers,
- player symbols and world echo,
- object/relic significance,
- World Personality,
- informational contradictions / Reality Stress.

## Wave 16 — Advanced reality laws
- observer classes / second-order reality,
- semantic gravity/concept collapse,
- temporal confidence,
- causal/false-causal evidence,
- negotiated reconciliation between observed histories,
- reality stress fractures,
- global phenomena,
- anomaly lifecycles,
- conceptual infection.

## Wave 17 — Scale and performance
Performance is continuous from Wave 1, but this wave validates large scale:
- Parallel Luau compute jobs where measured useful,
- streaming/fidelity stress,
- authority-cell churn,
- long server/client soak,
- chaos testing,
- bounded caches/queues,
- quality-tier profiles,
- device budgets,
- content manifests and asset streaming.

## Wave 18 — Content maturity
Expand architecture grammars, materials, furniture families, atmospheres, entities, Still Lifes, music, fictional organizations, narrative incidents, global phenomena and community systems using proven contracts.

Long-term environments may extend far beyond anonymous office space, potentially including convincing hotels, schools, domestic areas, retail, infrastructure, indoor climate, exterior-like spaces and eventually disturbingly normal reconstructed worlds.

## Long-term lore reserve

The yellow anonymous office language is not necessarily “Level 0.” It can function as the Reconstruction's low-information fallback state: when the universe loses semantic confidence, it falls back toward generic carpet, wallpaper, fluorescent grids and anonymous commercial geometry.

The deepest future question is not merely why reality is broken, but what happens as observation, culture and persistent evidence teach the Reconstruction to model humanity increasingly well.
