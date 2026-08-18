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

For Codex, ChatGPT, and other coding agents, start with root `AGENTS.md`. A broad prompt such as `Go`, `continue`, or `work on UNRENDERED` means to refresh live GitHub, make real product progress, test/review it, merge accepted work, refresh, and continue. The old custom swarm scheduler/claim/lease system is retired for normal development.

Product direction and quality live in `Docs/GAME_VISION.md`, `Docs/ARCHITECTURE.md`, `Docs/ROADMAP.md`, `Docs/QUALITY_STANDARD.md`, and `Docs/PROJECT_STATE.md`.

Historical swarm documents remain in `Docs/` only as prior coordination evidence; they are not current execution authority.

ChatGPT Project files are in `ProjectSource/`.

## Toolchain

Pinned through Rokit:
- Rojo 7.6.1
- StyLua 2.5.2
- Selene 0.31.0
- luau-lsp 1.69.0
- Lune 0.10.5
- Wally 0.3.2

## Build / validate locally

```bash
rokit install
rojo sourcemap default.project.json --output sourcemap.json
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau \
  -o globalTypes.d.luau
stylua --check src tests
selene src tests
luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
lune run tests/run
mkdir -p build
rojo build default.project.json --output build/UNRENDERED.rbxlx
```

CI uses the same pinned Roblox definitions and source checks. The generated place is a source-controlled bootstrap shell, not the final world. Roblox Studio is still required for real engine playtests, graphics validation, server-authority validation, and device profiling.
