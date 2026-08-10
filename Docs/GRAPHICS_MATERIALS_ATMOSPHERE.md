# Graphics, Materials, and Atmosphere

## Goal

Make players question whether a screenshot is Roblox, without pretending Roblox has arbitrary desktop-engine shader freedom. Win through composition, PBR assets, geometry, lighting, texture scale, optical behavior, acoustics, physicality, and coherent procedural history.

## MaterialDNA

Each surface recipe conceptually layers:
1. substrate,
2. manufactured finish,
3. installation batch/quality,
4. age,
5. maintenance,
6. environmental exposure,
7. local events,
8. anomaly modifiers.

A wall can therefore be drywall -> vinyl wallpaper -> batch 18 -> 13 apparent years -> cleaned lower strip -> cabinet shadow -> moisture at baseboard -> one impossible repair patch.

## Multi-scale variation

Micro: fiber, pores, paint roller, plastic grain, scratches.
Meso: seams, scuffs, tile variation, worn paths, stains.
Macro: room moisture gradients, installation batches, replaced sections, traffic routes.
Event: fingerprints, impacts, drag marks, footprints, waterlines, player damage.

Avoid `more noise = more detail`.

## Roblox PBR strategy

Use curated uploaded PBR map families with `SurfaceAppearance`/MaterialVariant-compatible assets. Runtime recipes choose coherent families and parameters. Because PBR maps are asset-backed and generally preprocessed, do not design around runtime-generating arbitrary unique 4K maps.

Infinite visual variety comes from:
- family selection,
- color/material variants,
- geometry variation,
- world-space placement logic,
- decals/overlays where viable,
- wear/event state,
- lighting,
- object composition,
- architecture history.

## Surface continuity

Texture/material phase must not reset visibly at procedural cell boundaries. Canonical surfaces have stable IDs and world-space semantic coordinates so wallpaper/carpet patterns and wear trajectories remain coherent across cells.

## Physical linkage

MaterialDNA also maps to:
- friction/restitution,
- wetness response,
- impact/scrape audio class,
- acoustic absorption,
- damage response.

One material identity should not look like metal, sound like plastic, and grip like carpet.

## Fixture DNA

Generated light fixtures carry:
- family,
- bulb/tube type,
- apparent age,
- output,
- color temperature/tint,
- flicker profile,
- startup state,
- failure state,
- buzz profile,
- circuit ID.

Forty fluorescent fixtures should not be forty identical lights.

## Optical atmosphere

The first-person visual stack should support:
- dark/light adaptation,
- restrained bloom/exposure response,
- volumetric depth where performance allows,
- body-driven camera inertia and vestibular stabilization,
- device-specific camera sensors,
- rare rule-based perception anomalies.

Do not use constant chromatic aberration/VHS noise as horror.

## Vibe examples

- Fluorescent Null
- Warm False Safety
- Damp Memory
- Corporate Dusk
- Impossible Daylight
- Mechanical Cathedral
- Empty Celebration
- Domestic Misremembering
- Institutional Dream
- Windowless Sunset

Atmosphere should be capable of visibly/audibly drifting within 30 seconds to a few minutes, as well as hard-threshold transitions.
