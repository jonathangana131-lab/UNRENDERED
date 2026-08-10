# Physics, Characters, and Entities

## Physics philosophy

Nearby important matter behaves like matter. Distant matter is simplified. Fidelity is a representation decision, not a different object identity.

## Active physical player

The body is not `ragdoll only on death`.

Intent -> reference pose -> contact planning -> balance -> physical actuation -> collision -> reactive behavior -> recovery.

Subsystems:
- PhysicalSkeleton
- MotorIntent
- BalanceController
- StepPlanner
- FootContact
- ReachPlanner
- GripController
- BraceReflex
- FallController
- RecoveryController
- Injury/Fatigue state
- VestibularCamera

Roblox constraints/physics and current animation/authority systems should be evaluated experimentally before locking exact actuator implementation.

## Movement goals

A shin contacting a chair should affect the body through physics. The controller may attempt an emergency step or wall brace; if support fails, the fall emerges from contacts and momentum rather than selecting `TripAnimation04`.

## Camera

Camera follows the physical head through a stabilization layer. Impacts originate from body motion rather than generic camera-shake calls. Accessibility can reduce roll, inertia, bob, flicker, distortion and motion blur independently.

## Grabbing / carrying

Affordances advertise actions such as grab, push, pull, open, rotate, press, carry, drag, climb, sit, connect and record.

A grip has contact point, orientation, strength and leverage. Heavy objects affect the body. Multiple players can combine forces for cooperative carries/pulls.

## Furniture mechanisms

Detailed mechanisms promote when relevant:
- door hinge/latch/closer,
- drawers and rails,
- office chair casters/tilt,
- carts and wheel assemblies,
- lamps and joints.

After settling and losing relevance they can demote while preserving state.

## Entities

Sense -> Interpret -> Remember -> Evaluate -> Intend -> Act.

No omniscient nearest-player chase by default.

Entities can hear impacts, remember approximate player positions, interact with objects, be injured, fall, recover, avoid or interact with other entities, and continue activities unrelated to the player.

## Still Lifes

Still Lifes are not ordinary NPCs. They use a scene grammar and observation rules. A physically realistic human-like form that catches itself after being shoved can be more frightening than an obviously monstrous mesh.

## Security

Treat client-owned physics as untrusted. Gameplay-critical consequences are server-validated/authoritative. Current Roblox server authority/prediction should be used where it fits after dedicated prototype validation; do not scatter authority assumptions throughout gameplay modules.
