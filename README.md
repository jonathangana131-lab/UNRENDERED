# UNRENDERED

**UNRENDERED** is a Roblox-first persistent procedural physics-horror universe where observation resolves an effectively infinite shared reality.

The game is not a sequence of Backrooms levels. It is a malformed interior universe that reconstructs human places from incomplete logic: offices, schools, hotels, homes, service corridors, waiting rooms, retail shells, industrial spaces, flooded interiors, impossible daylight, and stranger hybrids. Nearby reality is physically simulated; distant reality is compact state or unrealized deterministic potential.

## Development philosophy

- Production architecture from the first playable room.
- Deterministic procedural grammars, not uncontrolled randomness.
- Stable world/entity IDs independent of Roblox Instances.
- Generated base + persistent deltas.
- High-fidelity physics only where observation and interaction require it.
- Server-authoritative critical gameplay, with prediction where Roblox supports it.
- Atmosphere, materials, furniture, entities, Still Lifes, audio, UI, and multiplayer are core systems, not late polish.
- Main stays buildable.

Start with `Docs/GAME_VISION.md`, `Docs/ARCHITECTURE.md`, `Docs/ROADMAP.md`, and `Docs/SWARM_PROTOCOL.md`.

ChatGPT Project files are in `ProjectSource/`.

## Toolchain

Pinned through Rokit:
- Rojo 7.6.1
- StyLua 2.5.2
- Selene 0.31.0
- luau-lsp 1.69.0
- Lune 0.10.5
- Wally 0.3.2

## Build

```bash
rokit install
rojo sourcemap default.project.json --output sourcemap.json
rojo build default.project.json --output build/UNRENDERED.rbxlx
stylua --check src tests
selene src tests
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json src tests
lune run tests/run
```

The generated place is a source-controlled bootstrap shell, not the final world. Roblox Studio is still required for real engine playtests, graphics validation, server-authority validation, and device profiling.
