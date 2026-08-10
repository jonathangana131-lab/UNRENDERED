# UNRENDERED — ChatGPT Project Source

Repository: `jonathangana131-lab/UNRENDERED`
Engine/platform: Roblox Studio / Luau / Rojo
Title: **UNRENDERED**

## Canon

UNRENDERED is a persistent, effectively infinite, multiplayer physics-horror universe in which observation resolves reality. It is not a generic randomized Backrooms game. The world reconstructs human interiors from incomplete spatial/cultural memory and usually gets them right enough that rare violations feel deeply wrong.

Players can traverse office, institutional, domestic, hotel, retail, service, industrial, recreation, flooded and impossible hybrid spaces with no mandatory level screens. Vibes can drift in 30 seconds to minutes or change through rare hard thresholds. Beauty, comfort, nostalgia, silence and boredom are as important as threat.

Everyone conceptually shares a WorldId. Roblox servers are temporary simulation workers for active regions. Most players are far apart; real encounters are meaningful. Unobserved space between them can remain deterministic potential until travel/observation forces it to resolve. When independently observed regions approach, a Reality Reconciliation system must bridge already-established truths.

## Reality model

Truth hierarchy:
1. global truths — seed, versions, anchors, global events,
2. regional truths — canonical topology/grammar/history after first observation,
3. observed truths — exact important objects, damage, traces, recordings,
4. unobserved possibilities — deterministic potential only.

Every important thing has project-owned stable identity independent of Roblox Instances. A chair can exist as F4 articulated physics near a player, F2 proxy at distance, a persistent compact record when unloaded, or deterministic possibility before observation.

Canonical generators use scoped deterministic streams derived from world seed + generation version + region + subsystem + local semantic key. Topology/material/object/anomaly streams are isolated so one subsystem upgrade does not reshuffle unrelated truth.

First observation locks generation recipe/version. Already-established areas must not silently change when algorithms update. Persistent world state is generated base + durable deltas.

RealityConfidence and Significance govern legal forgetting/stability. Player settlements, repeated observation, cameras/anchors, modifications and culturally important objects can stabilize space. High-significance player work is not casually randomized away.

## World generation

Pipeline:
WorldSeed -> macro reality fields -> RegionIntent -> fake building history -> topology graph -> architecture -> MaterialDNA -> furnishing history -> ObjectGenome population -> narrative incidents -> atmosphere -> anomalies -> traces -> entities/Still Lifes -> first-observation lock.

Procedural means constrained grammar, not random selection.

The generator invents apparent purpose, construction era, remodels, maintenance, leaks, replaced materials, electrical circuits, furniture manufacturers, fake human incidents and wear. Normality is constructed first. Anomaly is a restrained pass.

VibeVector axes include normality, familiarity, nostalgia, comfort, loneliness, dreamness, oppression, beauty, sterility, decay, humidity, warmth, darkness, vastness, claustrophobia, temporal wrongness, visual instability, acoustic emptiness, human trace, biological wrongness and electrical instability.

Reality Debt limits concentrated impossible events; Familiarity Debt balances novelty and repetition. MemoryMotifs let later areas incorrectly remember earlier observed features.

Impossible topology is explicit, not a bug: loops, compression, expansion, one-way thresholds, visible-length mismatch, rooms larger than apparent exterior, and observation-gated mutations.

## Graphics / materials

Goal: make screenshots feel photographed and unusually realistic for Roblox through geometry, PBR quality, material scale, light, optical behavior, acoustics, atmosphere and physical interaction.

MaterialDNA layers substrate -> finish -> installation -> age -> maintenance -> environmental exposure -> events -> anomaly. It connects visual family, physical material and acoustic class.

Use curated uploaded PBR map families because Roblox SurfaceAppearance maps are asset-backed/preprocessed. Infinite variety comes from coherent recipes, family variants, geometry, world-space placement, wear/event overlays, lighting and composition—not runtime hallucinated 4K images.

Multi-scale detail:
- micro fibers/pores/grain/scratches,
- meso seams/scuffs/wear/stains,
- macro moisture/batches/repaired sections/traffic paths,
- event fingerprints/impacts/drag marks/footprints/waterlines.

FixtureDNA controls family, tube/bulb, apparent age, output, color temperature/tint, flicker, startup, failure, buzz and circuit. A row of fluorescents must not behave as clones.

Perception uses dark/light adaptation, restrained post effects, physical-head camera stabilization, device-specific sensors and rare rule-based anomalies. No permanent VHS/chromatic-glitch filter.

## Objects / furniture

ObjectGenome defines category/family, fictional manufacturer/product design language, apparent era, dimensions, component construction graph, materials, mass, mechanisms, affordances, wear and damage.

Furniture must look manufacturable before anomaly. Families include chairs, desks, tables, cabinets, lockers, shelves, couches, benches, lamps, carts, partitions, phones, CRTs/computers, printers, trash cans, signage, water coolers, mattresses and maintenance equipment.

Detailed mechanisms promote with proximity/interaction and demote after settling while preserving state: casters, wheels, drawers, hinges, latches, closers, tilts, loose contents.

Roblox ProceduralModel may support parameterized object families at edit/runtime, but ObjectGenome is the project domain source. ProceduralModel generation is not the infinite-world architecture and cannot be assumed to run under Parallel Luau Actors.

## Still Lifes

A Still Life is a generated spatial composition implying frozen/reconstructed life, not simply an enemy prefab.

Generate believable scene intent -> setting -> furniture/participants -> physical pose/contact solution -> settle -> spend small violation budget.

Violations can be social, anatomical, observational, topological or temporal. Realism first. Avoid random spikes/limbs/blood. Tiny proportion errors, impossible attention, repeated arrangements, or a form that catches itself after being shoved can be more disturbing.

Some Still Lifes never activate. Some change only while occluded. Some collapse physically. Some become entities. The game usually does not classify them for the player.

## Entities

EntityGenome defines controlled anatomy, masses, joints, actuators, senses, locomotion, material family and temperament ranges. Individual curiosity/aggression/fear/persistence/territoriality and sensory bias vary.

Sense -> Interpret -> Remember -> Evaluate -> Intend -> Act.

Entities are uncertain rather than omniscient. They can hear actual object impacts, remember approximate positions, interact with furniture, fall/recover, be injured and encounter other entities without player involvement.

## Physical player

Flagship target is an active physical body, not a standard FPS capsule with a death ragdoll.

Intent -> reference pose -> contact planning -> balance -> physical actuation -> collision -> reflex -> recovery.

Subsystems: physical skeleton, motor intent, balance, gait/step planner, foot contacts, reach, grip, brace, fall, recovery, injury/fatigue, vestibular camera.

A foot clipping a chair should produce a physical correction/fall. Hands can grip actual contact points; heavy objects affect the body; multiple players can cooperate. Climbing is contact-based rather than only tagged yellow ledges.

Roblox authority/constraint/animation choices must be validated experimentally; architecture should not hard-wire one actuator before measurements.

## Audio/environment

MaterialDNA drives impact/scrape/acoustic behavior. Use room/portal geometry and practical occlusion/reverb models. Sound can be relevant farther than visual simulation, allowing distant real-player/entity encounters through footsteps, crashes and voice.

Environmental state includes temperature, humidity, water/dampness, air movement, dust, electrical stability and decay. Systems cross-influence visuals, physics, audio and equipment.

Electric circuits connect panels, fixtures, outlets and devices. Radios, phones, intercoms, cameras, security monitors and recording devices are physical systems, not UI skins.

Adaptive music is sparse and driven by vibe rather than enemy aggro. Copyrighted Kane Parsons/Kane Pixels music is not put in distributable source/builds without rights.

## Multiplayer/persistence

Server-authoritative critical state is the direction. Roblox's server-authority/prediction capabilities should be evaluated and used where suitable; client remotes/physics are untrusted.

Network interest is multi-dimensional: visual/physics, acoustic, radio/phone, camera and global-event relevance.

Persistent storage is repository/service abstraction over DataStore; rapid temporary cross-server coordination/leases may use MemoryStore; messaging uses bounded MessagingService patterns. Never scatter cloud calls through gameplay.

Players may build settlements from found physical objects. Observation/anchors can stabilize them. Abandoned sites become emergent archaeology.

Entry Cohorts allow friends to begin nearby without turning the universe into lobbies.

## UI

Main menu remains clear/clickable but is a high-end reactive real-time experience: fluid spatial transitions, clean typography, reactive background, physics/spring motion, excellent settings previews and seamless menu-to-world presentation where possible.

No cheap horror font/VHS menu. In-game HUD is minimal. Accessibility is explicit and usable even when not diegetic.

## Technical Roblox stack

- Luau strict mode.
- Rojo project source.
- Rokit-pinned tools.
- StyLua, Selene, luau-lsp CI.
- Lune for pure deterministic tests.
- Wally available but dependencies remain intentional/minimal.
- Workspace Instance Streaming underneath project-owned region/fidelity management.
- Parallel Luau for suitable immutable compute workloads.
- ProceduralModel for appropriate parametric assets.
- Roblox PBR/SurfaceAppearance/Material systems for visual assets.
- current server authority/prediction evaluated for gameplay-critical physics.

## Anti-rewrite laws

1. Stable IDs independent of Instances.
2. Version all canonical generators/schemas.
3. Scoped deterministic RNG only for canonical generation.
4. Generated base + deltas, never Workspace serialization.
5. Networking/cloud/render APIs behind project boundaries.
6. No giant GameManager.
7. No monolithic generator.
8. No hard-coded Backrooms level enum.
9. No duplicate temporary production framework.
10. Small test labs use production contracts.
11. Architecture-risk changes require ADRs.
12. Every procedural failure gets exact repro key.
13. Main stays buildable.

## Roadmap priority

Foundation -> production Physics Lab -> active physical player -> reality kernel -> architecture grammar -> MaterialDNA -> ObjectGenome/furniture -> atmosphere -> shared multiplayer region -> persistent region routing -> entities -> Still Lifes -> deep equipment/environment -> anomalies -> scale/performance -> content maturity.

Do not start by making a monster or a giant random map.

## Dynamic worker swarm

GitHub is the scheduler. Every `go` worker inspects actual repo state before acting. It fixes red main first, claims non-conflicting critical work, reviews waiting PRs when needed, creates leaf tasks when many workers arrive, and continues to another safe task after completing one rather than stopping automatically. The swarm must gracefully function with one worker or 20+ workers.

The objective is not the fastest demo. Build the systems capable of producing years of believable, physically grounded, eerie procedural content without foundational rewrites.
