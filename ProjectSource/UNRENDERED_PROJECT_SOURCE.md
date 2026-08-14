# UNRENDERED — Canonical ChatGPT Project Source

Repository: `jonathangana131-lab/UNRENDERED`
Platform: Roblox Studio / Luau / Rojo
Title: **UNRENDERED**

This file defines the long-term product/engineering canon. Current implementation priority lives in `Docs/PROJECT_STATE.md`; quality/process canon lives in `Docs/QUALITY_STANDARD.md` and `Docs/SWARM_PROTOCOL.md`.

---

# 1. Core premise

UNRENDERED is a persistent, effectively infinite, always-multiplayer physics-horror universe in which **observation resolves reality**.

It is not a generic randomized Backrooms game and not a sequence of numbered levels. The world behaves like a malformed reconstruction system trying to rebuild human places, objects, institutions, history and behavior from incomplete memory. Usually it gets reality almost right. Rare violations therefore feel much more disturbing than constant chaos.

The anonymous fluorescent/carpet/wallpaper office language is not necessarily “Level 0.” Long-term canon may treat it as the Reconstruction's **low-information fallback state**: when semantic confidence collapses, reality falls back toward generic commercial interior geometry because it is easy to reconstruct without context.

The deepest long-term question is not only “why is reality broken?” but: **what happens as millions of observations teach the Reconstruction to model humanity increasingly well?**

---

# 2. Emotional / experiential targets

The player should repeatedly feel:
- uncanny familiarity,
- dream logic,
- impossible isolation,
- physical vulnerability,
- quiet paranoia,
- awe at huge/beautiful spaces,
- nostalgia for places never visited,
- relief when another real human is found,
- uncertainty over whether evidence is real/player-made/generated,
- curiosity strong enough that hours can pass without combat.

Fear is not constant. Beauty, comfort, silence, boredom, warmth and normality are required because horror needs contrast.

The world should ask questions more often than it gives answers.

---

# 3. Three-world architecture

Never confuse these layers.

## Conceptual World
The mathematical universe: WorldId, seed, world addresses, macro fields, semantic relationships, possible topology, global phenomena, players, anchors. No Roblox Instances required.

## Resolved World
Truth forced into existence through observation: region recipes, stable IDs, topology anchors, MaterialDNA, ObjectGenome, fake history, traces, anomalies, durable deltas. Mostly plain/versioned data.

## Physical World
The currently instantiated Roblox representation around active observers: Parts, MeshParts, constraints, lights, sounds, physical characters, effects.

Workspace is never the canonical universe database.

A chair can be deterministic potential, a compact resolved record, a cheap proxy, or full articulated physics while remaining the same WorldEntity.

---

# 4. Truth / observation model

Truth hierarchy:
1. **Global truth** — WorldId, seed, generator versions, global events, major anchors.
2. **Regional truth** — region intent, canonical topology/history after first observation.
3. **Observed truth** — exact important objects, modifications, recordings, damage, traces.
4. **Unobserved possibility** — deterministic potential constrained by seed/rules but not fully stored or simulated.

First meaningful observation locks a generation recipe/version. Algorithm updates must not silently rewrite already-established truth.

Persistent world state is:

**generated base recipe + meaningful durable deltas**

not serialized Workspace.

## RealityConfidence
How strongly a region is established by observation, recency, anchors, inhabitants and history.

## Significance / Informational Mass
Important objects/places gain stability through repeated observation, modifications, recordings, maps, player culture, settlements and historical meaning.

A random untouched pen may remain reproducible from seed; an old camera carried for 100 hours or used in a famous expedition becomes a durable artifact/relic.

## Observer Classes
Different observers may contribute different kinds/strengths of evidence:
- human direct vision,
- digital/analog cameras,
- CCTV,
- recordings,
- mirrors/reflections,
- entity perception,
- potentially maps/photographs as secondary representations.

## Second-Order Reality
Indirect observations such as mirrors/cameras may have weaker/different truth rules than direct observation. Shared physical geometry must remain coherent across players unless a specific anomaly explicitly defines a controlled perception-only difference.

## Contradiction / Reality Stress
Conflicting independent evidence can create Reality Stress. A photograph says a doorway existed; current observation says wall; old map says hall. High contradiction can make special reconciliation behaviors eligible.

---

# 5. Deterministic generation

Canonical generation uses scoped, versioned random streams derived from stable keys such as:

`WorldSeed + GenerationVersion + RegionId + SubsystemSalt + LocalSemanticKey`

Topology/material/object/anomaly streams remain isolated so upgrading chair generation does not reshuffle buildings.

Every procedural failure must have an exact repro key.

Generator/schema versions are independent where useful: reality, topology, architecture, material, object, entity, Still Life, persistence, etc.

---

# 6. Staged Reconstruction Engine

Never create one giant random `GenerateRegion` function.

Canonical pipeline:
1. WorldSeed / global Reality Fields,
2. RegionIntent / WorldIntent,
3. fake construction/institutional history,
4. semantic topology graph,
5. structural plan,
6. building-services logic (ceiling/HVAC/electrical/plumbing where appropriate),
7. MaterialDNA/history,
8. FixtureDNA / electrical/lighting plan,
9. SupplyChainDNA / procurement/manufacturer logic,
10. ObjectGenome furnishing,
11. Ghost Traffic / cleaning/wear history,
12. Ghost Census / fake people/organizations/documents,
13. narrative incidents and traces,
14. VibeVector / atmosphere,
15. anomaly budget pass,
16. Still Life/entity eligibility,
17. first-observation lock,
18. Roblox realization/fidelity promotion.

Each stage is independently testable, versionable and profileable.

For rare/high-significance content, oversample multiple cheap candidates, validate/score them, and choose the strongest. Procedural generation includes procedural rejection.

---

# 7. Architectural normality

Normality is more important than anomaly.

The generator must understand why real spaces exist and how they are built:
- circulation/hallway hierarchy,
- receptions/entrances,
- conference/waiting/private/service relationships,
- bathrooms/storage/maintenance,
- ceiling grids,
- structural supports,
- fire doors/signage,
- HVAC/duct/service access,
- electrical panels/circuits,
- plumbing/drainage where relevant.

Start with one anonymous late-80s/90s commercial-office grammar and make it extremely convincing before adding many environment families.

Real buildings repeat. Local variety should be constrained by plausible suppliers/material batches rather than maximizing uniqueness.

---

# 8. Fake history / archaeology

Every region can invent a coherent apparent past:
- construction era,
- renovations,
- partial conversions,
- maintenance failures,
- water damage,
- old doorway scars,
- replaced ceiling tiles,
- patched drywall,
- mismatched carpet batches,
- removed signs,
- equipment upgrades,
- abandoned work.

The horror is that none of this history necessarily happened, yet evidence makes it feel real.

## Ghost Traffic
Cheap abstract simulation of fictive historical human routes/usage creates causal wear:
- hallway traffic,
- carpet wear,
- dirty handles,
- chair positions,
- cleaning patterns,
- trash likelihood,
- equipment usage.

## Cleaning / dust history
Dust accumulates on unmoved objects; moving furniture reveals cleaner outlines; traffic/cleaning/leaks create believable surface state rather than random dirt masks.

---

# 9. MaterialDNA / graphical realism

Goal: screenshots should feel photographed and unusually realistic for Roblox through scale, construction, PBR materials, light, atmosphere, acoustics and physical interaction—not excessive post processing.

MaterialDNA layers:
**substrate -> manufactured finish -> installation -> apparent age -> maintenance -> environmental exposure -> events -> anomaly**

One material identity should inform:
- visual family,
- physical response/friction,
- acoustic class,
- wetness/damage/wear behavior.

Use curated/licensed/project-owned PBR families because Roblox maps are asset-backed. Infinite-looking variation comes from recipes, color/roughness variation, geometry, world-space placement, decals/masks, history and lighting—not hallucinating a unique 4K bitmap for every wall.

Multi-scale variation:
- micro: fibers/pores/grain/roller texture/scratches,
- meso: seams/scuffs/stains/tile variation,
- macro: moisture/batches/repair/traffic paths,
- event: fingerprints/impacts/drag marks/footprints/waterlines.

Materials should reflect manufacturing process: printed vinyl, paint rollers, injection-molded plastic seams, stamped metal, carpet-roll seams, tile batches. Rare ordinary manufacturing defects help realism.

HumanContactZones drive touch wear on handles, armrests, switches, phones and drawer pulls.

Asset IDs belong in project manifests/adapters, never scattered gameplay code.

---

# 10. Light / optics / atmosphere

FixtureDNA can control:
- fixture family,
- lamp/tube type,
- apparent age,
- output,
- color temperature/tint,
- startup,
- flicker spectrum,
- failure state,
- buzz profile,
- circuit relationship.

Rows of lights must not behave like clones.

VibeVector may include:
normality, familiarity, nostalgia, comfort, loneliness, dreamness, oppression, beauty, sterility, decay, humidity, warmth, darkness, vastness, claustrophobia, temporal wrongness, visual instability, acoustic emptiness, human trace, biological wrongness and electrical instability.

Atmosphere can drift meaningfully over 30 seconds to minutes or jump across rare hard thresholds. No “LEVEL CHANGED” card.

Perception includes restrained exposure/dark adaptation, physical-head stabilization, device-specific cameras and rare rule-driven anomalies. Avoid permanent VHS/chromatic-aberration horror filters.

Windows are a major system: reachable/unreachable views, parallax, reflection, lighting contribution, exterior-like spaces, impossible sun direction and second-order truth.

---

# 11. ObjectGenome / furniture

ObjectGenome defines believable manufactured objects independently from one MeshPart/prefab:
- category/family,
- fictional manufacturer/product line,
- apparent era,
- dimensions/plausibility ranges,
- component/support graph,
- materials by component,
- mass/center-of-mass metadata,
- mechanisms,
- affordances/grip regions,
- immutable genome vs mutable wear/damage/state.

Families eventually include chairs, desks, cabinets, shelving, couches, carts, lamps, phones, CRTs/computers, printers, bins, signage, water coolers, mattresses, maintenance equipment and stranger pseudo-furniture.

Construction must look manufacturable before anomaly.

Detailed mechanisms promote with relevance: casters/wheels/drawers/hinges/latches/closers/tilts/loose contents. After settling/unobserved, representations can demote while preserving meaningful state.

Object damage should follow construction graphs/constraints where practical rather than generic hit points.

---

# 12. SupplyChainDNA / material culture

Regions can generate fake suppliers/manufacturers/product eras so nearby furniture/materials repeat coherently the way real procurement works.

One building might use two chair lines, one lighting supplier, several carpet batches and a maintenance vendor. This prevents asset-pack soup and creates recognizable fictional industrial culture.

Objects can carry fake provenance: manufacturer, model family, apparent manufacture/repair dates, room assignment, use history.

---

# 13. Ghost Census / procedural people-without-people

The Reconstruction can generate fictional identities without necessarily generating NPCs.

A Ghost Census identity can have:
- name,
- role/department,
- badge/extension,
- desk/locker,
- handwriting profile,
- habits/object preferences,
- work schedule,
- relationships to other fake identities.

Evidence can appear across nameplates, maintenance forms, mugs, documents, lockers and signage.

Procedural social graphs let fake employees reference one another consistently. Rare chronology/identity contradictions become subtle anomalies.

A player may spend dozens of hours seeing evidence of “Marcus Vale — Facilities” without ever seeing Marcus.

---

# 14. Documents / language / symbols

Use structured semantic templates rather than generating endless prose:
- maintenance forms,
- schedules,
- inventory sheets,
- meeting agendas,
- notices,
- safety signs,
- delivery slips,
- personnel/department references.

Procedural handwriting profiles allow recurring identities to leave recognizable writing.

Language corruption should be semantic, not random gibberish: plausible phrases gradually drift toward near-correct meanings such as “PERSONNEL CONTINUE ONLY.”

Symbols/signage can be subtly wrong. Player-created markings/symbols may later enter Cultural Echo.

---

# 15. Physical player

Flagship target: an always-physical player, not a floating FPS camera plus death ragdoll.

Intent -> reference pose -> contact planning -> balance -> physical actuation -> collisions -> reflex -> recovery.

Subsystems:
- physical skeleton,
- motor intent,
- support contacts/center of mass,
- gait/step planning,
- foot placement,
- reach/grip,
- brace/fall prediction,
- recovery,
- crouch/crawl/lean/climb,
- injury/fatigue hooks,
- vestibular camera/accessibility.

A foot clipping a real chair should affect balance and potentially produce a unique recovery/fall. Heavy objects affect the body. Hands grip physical contact points. Hiding/climbing/peeking should emerge from actual geometry where possible rather than tagged animation spots.

Player movement must become one of the best-feeling systems in Roblox before world scale is treated as success.

---

# 16. PhysicalCharacter / entities

Do not build separate unrelated player/monster/still-life physics frameworks. Shared physical-character primitives should support different anatomy/control profiles.

EntityGenome defines:
- body plan/anatomy,
- masses/joints/limits,
- actuators,
- senses,
- locomotion capabilities,
- material/skin family,
- temperament ranges.

Entity cognition:
**Sense -> Interpret -> Remember -> Evaluate -> Intend -> Act**

Entities are uncertain rather than omniscient. They can hear actual impacts, remember approximate locations, interact with physical objects, fall/recover, be injured and encounter each other without player involvement.

Individual temperament changes both decisions and physical body language: curiosity, fear, aggression, persistence, territoriality, sensory bias.

Important individuals may persist injuries/history and become recognizable over time.

---

# 17. Still Lifes

A Still Life is a generated spatial/social composition implying frozen or reconstructed life; it is not simply an enemy prefab.

Pipeline:
1. believable scene intent,
2. plausible setting/furniture,
3. participant/object roles,
4. physical pose/contact solve,
5. settle/validate,
6. spend a small violation budget,
7. evaluate composition from likely player approaches,
8. reject weak/comedic/broken candidates.

Violation types may be social, anatomical, observational, topological or temporal.

Examples of stronger horror are tiny proportion errors, impossible attention arrangements, repeated social geometry, or a supposedly inert form reflexively catching itself when pushed—not random spikes/blood.

Some Still Lifes never activate; some move only while occluded; some collapse physically; some may become entities. Do not classify them for the player.

Long-term possibility: repeated documentation/observation could make certain anomalous forms more consistent—players may be teaching the Reconstruction how to create them.

---

# 18. Audio / acoustics

Audio is equal to graphics in quality priority.

MaterialDNA drives impact/scrape/acoustic classes. Collision events use materials, impulse/contact speed, mass and resonance rather than one sound per prefab.

Room/portal geometry provides practical occlusion/reverb propagation. Sound can remain relevant farther than visual simulation, allowing footsteps/voice/crashes from distant real players/entities before they are rendered.

Generated areas should have acoustic signatures: HVAC hum, electrical tone, machinery, room resonances, pipe noise, ventilation.

Silence is a deliberate state.

Acoustic Persistence may very rarely cause unstable areas to retain/reproduce fragments of old sounds under explicit rules.

Do not use copyrighted Kane Parsons/Kane Pixels music in distributable source/builds without rights. Use original/licensed/placeholder work and a sparse adaptive score driven by vibe rather than enemy aggro.

---

# 19. Environmental / infrastructure systems

Only simulate what produces perceptible consequences.

Potential systems:
- electrical circuits/panels/outlets/fixtures,
- doors/locks/closers,
- elevators/escalators/machinery,
- HVAC/fans/pumps,
- temperature/humidity,
- wetness/puddles/leaks/standing water,
- simplified airflow/pressure,
- dust/paper movement,
- ceilings/plenums/service cavities,
- selected destructible drywall/building layers,
- radios/phones/intercoms,
- CCTV/cameras/recordings,
- physical measurement tools.

Prefer useful abstractions over invisible overengineering: airflow field over CFD, circuit topology over full electrical simulation, meaningful wetness over universal fluids.

Normal tools such as laser distance meters, thermometers, clocks, compasses and voltage testers are stronger anomaly detectors than a generic “reality scanner.”

---

# 20. Evidence / traces / false evidence

Evidence can originate from:
- real players,
- entities,
- generated fake history,
- Cultural Echo,
- temporal/reality contradictions.

Player usually does not know provenance.

Trace types include footprints, wet prints, dust disturbance, drag marks, impact damage, moved furniture, open/broken doors, writing, dropped equipment, recordings and environmental changes.

The world can generate **false causality**: a plausible aftermath whose evidence cannot be explained by any physically possible event chain.

Causal chains from real physics can also persist, letting future players reconstruct what happened.

---

# 21. Reality laws / advanced dream logic

Regions may possess rare generated Reality Laws. Most physics remains normal; occasional controlled deviations create systemic horror.

Possible rule families:
- persistence rules,
- distance/travel mismatch,
- sound-order/reflection anomalies,
- observation-gated mutations,
- threshold rules based on origin/history,
- memory rules,
- scale errors,
- temporal confidence changes,
- semantic/identity relationships.

The world itself has consistent laws even when those laws differ from normal reality. Do not break a known anomaly rule merely for a jumpscare.

## Semantic Gravity
Under dreamlike conditions, spaces can organize around concepts rather than literal building types. “Waiting” may blend airport/hospital/office/hotel motifs because they share meaning.

## Concept Collapse
A region can gradually reinterpret itself: office -> workplace -> institutional -> waiting -> transportation -> airport, with architecture/materials/signage drifting coherently rather than a biome seam.

## Continuity Compression
Controlled dream transitions may skip/reconcile unimportant spatial continuity without flashy teleport effects.

## Temporal Confidence
Actual networking time remains sane, but clocks/evidence/recordings may disagree under explicit anomaly rules.

---

# 22. Memory systems

## MemoryMotifs
Later areas can imperfectly reconstruct earlier observed features: same couch, clock time, room motif or furniture family with increasing errors.

## Cultural Echo
Shared player culture/history can influence future unresolved content through controlled abstract motifs—not by copying private data.

A famous settlement's blue chair, broken vending machine or symbolic marking might echo elsewhere as distorted conceptual reconstruction.

## Behavioral Contamination
The Reconstruction may learn broad human behaviors: barricading doors, circling chairs, leaving arrows, building sleeping areas. Newly generated fake history may reproduce those arrangements, making it hard to tell if humans visited.

## World Personality
A WorldId can accumulate persistent biases from its history and cultural echoes: more hotel transitions, certain colors, phone anomalies, particular object families. Different world histories can develop distinct character.

## Conceptual infection
Some motifs/anomalies may spread through semantic relationships such as shared fictional supplier/corporation rather than geographic distance.

---

# 23. Negotiated reality / reconciliation

Two players can approach one another through large regions that were never fully generated between them.

Their observed bubbles eventually need to connect. Reality Reconciliation receives established boundary truths and generates a bridge that preserves both histories.

Possible connectors include normal corridor, service passage, stairs, huge transition room, hard threshold or explicit impossible topology.

When two histories impose incompatible constraints, observation strength, significance, anchors, recordings and age can influence a negotiated solution rather than deleting established truth.

Extreme contradiction can create Reality Stress Fractures such as duplicated doors, loops, repeated objects or strange hybrid architecture.

Multiplayer therefore can literally create unique spaces through the collision of independent observations.

---

# 24. Multiplayer universe

Everyone conceptually shares one WorldId. Roblox servers are temporary simulation workers for active authority regions, not separate lore worlds/lobbies.

Most players should often remain extremely far apart. Real encounters should feel meaningful.

Entry Cohorts let friends begin nearby without making every session a conventional lobby.

Network interest is multi-dimensional:
- visual/physical proximity,
- acoustic relevance,
- radio/phone connection,
- camera observation,
- global event relevance.

Static deterministic environment should be reconstructed from versioned recipes where practical; network bandwidth focuses on dynamic deltas/players/entities/physics.

Server validates critical movement/actions/ownership/damage/inventory. Remotes are narrow and typed. Do not trust generic client requests or client-owned physics as truth.

Cross-server coordination remains high-level and low-volume: region leases/ownership, global events, player transfers, persistent updates, phone/radio routing metadata—not frame-level physics.

---

# 25. Settlements / anchors / civilization

Players build camps from found physical objects rather than a generic building mode.

Possible infrastructure:
- furniture barricades,
- lighting/power,
- radio repeaters,
- CCTV/observation networks,
- storage,
- maps/archives,
- medical/rest areas,
- signal beacons.

Repeated habitation/observation/recording can increase RealityConfidence.

Abandoned settlements slowly become archaeology. The surrounding world may drift while high-significance artifacts remain.

Community culture can create place names, routes, radio frequencies, symbols, legends and Relics without a developer-defined quest system.

Persistent multiplayer safety still requires moderation, mute/block/report and anti-grief/ownership strategies.

---

# 26. Recordings / cameras / archive

Physical cameras have their own SensorGenome: lens, exposure, noise, focus, battery, microphone, damage, storage.

A dropped camera can continue recording. Recoverable recordings can become found-footage history.

Storage must be bounded; not every second of every camera can become permanent full-resolution video. Significance can promote important recordings.

Recordings may preserve evidence of geometry/events and contribute to informational mass. Rare explicit anomalies can create mismatches between recording/current observation.

Personal/community Archives store photographs, maps, frequencies, notes and discoveries without declaring every interpretation true.

---

# 27. Banality / pacing / World Director

A **Banality Engine** must intentionally create stretches where nothing special is hidden. Ordinary rooms must genuinely be ordinary.

The World Director tracks broad pacing variables such as recent novelty, threat, isolation, social contact, silence, comfort and anomaly debt. It biases unresolved future content; it does not teleport monsters behind players or force a scare every minute.

Reality Debt limits concentrated weirdness. Familiarity Debt balances repetition and novelty.

A suspicious buildup can resolve to a broken fan and nothing more. False payoff teaches players that the world is not a theme-park scare machine.

---

# 28. Global / slow phenomena

Rare world-scale phenomena may affect many active servers through shared high-level state:
- brownouts,
- quiet periods,
- pressure/humidity shifts,
- signal blooms,
- reconstruction surges,
- entity stillness,
- indoor climate fronts.

Some regions can evolve slowly over real days: damp -> leak -> standing water -> flooding. Simulation history therefore matters after initial procedural generation.

Entities/environment/player settlements can gradually alter regional ecology.

---

# 29. UI / menu / accessibility

The main menu remains clear and clickable but should feel unusually fluid, reactive and integrated with the game's visual language:
- real-time rendered/reactive background,
- excellent clean typography,
- spring/inertia motion,
- spatial transitions,
- settings previews,
- potentially seamless menu-to-entry presentation.

Do not use a cheap horror font or permanent VHS skin.

In-game HUD is minimal. Accessibility is explicit even when not diegetic:
- reduced camera inertia/roll,
- flicker reduction,
- motion blur settings,
- visual anomaly intensity,
- subtitles/spatial sound aids,
- voice controls,
- input-device abstraction.

Physical realism must not become frustrating UX.

---

# 30. Performance / scalability canon

Infinity is possible only because fidelity is bounded.

Simulation LOD applies to:
- rendering,
- physics articulation,
- mechanisms,
- entity cognition,
- audio propagation,
- networking frequency,
- persistence detail.

Fidelity policy uses distance, visibility, observation, motion, interaction recency, significance and network relevance. Hysteresis prevents thrashing.

Maintain configurable budgets for CPU/frame time, memory, Instances, rigidbodies, constraints, lights/shadows, textures, audio voices, network bytes and generation queues.

Rules:
- bounded caches,
- bounded queues,
- incremental/yielding generation,
- predictive cheap planning before observation lock,
- explicit cancellation/version tokens for stale jobs,
- metrics before optimization,
- long soak/chaos tests,
- deterministic bug repro.

Parallel Luau is used only where measured/thread-safe; immutable compute with a serial Instance-realization phase is preferred.

---

# 31. Roblox-specific technical baseline

- strict Luau,
- Rojo source workflow,
- Rokit-pinned tools,
- StyLua/Selene/luau-lsp CI,
- Lune pure deterministic tests,
- Wally only for intentional dependencies,
- Roblox Instance Streaming below project-owned region/fidelity management,
- Roblox PBR/SurfaceAppearance/Material systems through project manifests/adapters,
- server authority/prediction experimentally validated before hard dependence,
- ProceduralModel only where useful for parametric assets; it is not the universe model.

Experimental/beta features stay behind adapters/flags until proven.

---

# 32. Quality canon: REALITY-GRADE

UNRENDERED follows:

> **Depth before breadth. Normality before anomaly. Data before representation. Measure before optimize. Never normalize jank. Finish deeply. Expand carefully.**

A major feature is not done just because it works. Applicable gates include:
- stable contract/IDs/versioning,
- deterministic repro,
- physical/functional edge cases,
- subsystem integration,
- graphics/material finish,
- audio finish,
- UX/accessibility,
- multiplayer/security,
- persistence/streaming lifecycle,
- performance/memory budgets,
- automated tests/fuzzing,
- permanent experience scenarios,
- independent Reality-Grade review/polish.

The project allows at most **3 active major Feature Epics** even with 20 chats. Extra admitted workers deepen those epics through strike-team roles rather than create breadth; unneeded chats park instead of manufacturing work. Exact repository pressure is governed by `Docs/SWARM_FOUNDRY_V17.md` before any new product branch.

Open issue != unlocked work. `Docs/PROJECT_STATE.md` decides what can be implemented now.

---

# 33. Hero development order

Build complexity on finished foundations:
1. deterministic identity/reality contracts,
2. permanent Physics/Body/Material labs,
3. Reality-Grade door,
4. Reality-Grade chair,
5. excellent physical player movement/body,
6. Perfect 5 Minutes office cluster,
7. procedural normality,
8. shared two-player physical truth,
9. first impossible spatial rule,
10. persistent WorldId/server routing,
11. first Still Life,
12. first entity,
13. settlement/infrastructure systems,
14. cultural memory/reality evolution,
15. broad content.

Do not build a giant map or monster roster to compensate for weak movement, physics, material, audio or architectural quality.

---

# 34. Anti-rewrite laws

1. Stable project IDs independent of Roblox Instances.
2. Conceptual/resolved/physical world layers remain separate.
3. Version canonical generator/schema contracts.
4. Scoped deterministic RNG only for canonical generation.
5. Generated base + meaningful deltas; never Workspace serialization.
6. Networking/cloud/render/package calls stay behind project boundaries.
7. No giant GameManager or monolithic generator.
8. No hard-coded Backrooms level enum as world architecture.
9. No competing temporary production frameworks.
10. Small labs use production contracts.
11. Architecture-risk changes require ADR + measured limitation + migration/test plan.
12. Every procedural failure gets exact repro.
13. Caches/queues/budgets are bounded/observable.
14. Do not overengineer hypothetical systems: stable domain contract + simplest production-worthy implementation.
15. Main stays buildable.

---

# 35. Long-term escalation reserve

As the Reconstruction accumulates evidence, player culture and observation, it may become increasingly capable of reconstructing specific human reality:
- richer institutions,
- believable fake occupants,
- increasingly normal exterior-like spaces,
- potentially roads/houses/cities/people that appear almost ordinary.

The ultimate horror may not be an endless dark maze. It may be a perfectly normal-looking world that experienced players know is reconstructed and false.

If that false reality ever loses confidence, it may decay back toward the anonymous fluorescent fallback memory beneath it.

Do not rush this. It is a years-deep direction enabled by mature systems, not an early content target.

---

# 36. Worker canon

GitHub is the durable scheduler. Every `go` worker reads current state before acting. It fixes red main first, finishes active unlocked work, avoids duplicate frameworks, validates deeply, publishes evidence, and continues to another safe unlocked task/review when useful.

The objective is not the fastest impressive demo or the most closed issues.

**Build the systems capable of producing years of believable, physically grounded, eerie content while making every finished feature feel intentional, polished and permanent.**
