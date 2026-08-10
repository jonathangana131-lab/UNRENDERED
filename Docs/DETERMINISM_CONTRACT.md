# Determinism Contract v1

This document locks the byte-level deterministic contract used by canonical UNRENDERED generation. It is intentionally small. Once observed world content depends on a version, its behavior is historical data and must not be silently edited.

## Canonical string-list encoding

`DeterminismContract.encodeParts` encodes an ordered list of Luau strings as raw bytes:

`u1;<count>;<byteLength>:<bytes><byteLength>:<bytes>...`

Rules:
- `u1` is encoding version 1.
- Count and lengths are canonical base-10 integers with no padding.
- Length is the Luau string byte count (`#value`), not Unicode character count.
- Bytes are copied verbatim, so separators/control bytes inside a value are safe.
- The list must be a dense 1-based array.
- Empty lists and empty strings are representable by the generic encoder; higher-level semantic contracts may reject them.

Examples:
- `{}` -> `u1;0;`
- `{ "" }` -> `u1;1;0:`
- `{ "a", "bc" }` -> `u1;2;1:a2:bc`

Never replace this with delimiter concatenation. Length-prefixing is what makes different part boundaries unambiguous.

## Hash32 v1

`Hash32.jenkins` is the existing 32-bit Jenkins one-at-a-time implementation, now locked by golden vectors. Seeds are explicit unsigned 32-bit integers. `Hash32.combine(seed, ...)` hashes the v1 canonical list encoding once with that seed.

Hash32 is a 32-bit deterministic primitive, so collisions are an expected mathematical possibility at scale. It must not be used as the sole persistent identity. It is also not a security primitive: do not use it for signatures, passwords, authentication, adversarial content addressing, or proof that two untrusted payloads are equal.

## StableId v1

Format:

`<namespace>:v1:<32 lowercase hex digits>`

The digest is 128 bits assembled from four fixed, differently seeded Hash32 passes over the same canonical payload:

`{ "stable-id", "1", namespace, semanticPart1, ... }`

Namespace rules:
- 1-64 bytes,
- lowercase ASCII,
- starts with `a-z`,
- remaining characters are `a-z`, `0-9`, `_`, `.`, or `-`.

StableId semantic parts are a non-empty dense array of at most 32 non-empty strings, each at most 512 bytes. Callers must use stable semantic identity such as WorldId/RegionId/object-family/local key, never Roblox Instance names, creation order, memory addresses, or transient Workspace paths.

StableId v1 is designed to make accidental collisions extremely unlikely, but it is still non-cryptographic. Persistent registries should detect duplicate IDs whose canonical identity differs and treat that as a hard diagnostic rather than silently aliasing two entities. StableId is not suitable for authentication, secrecy, anti-cheat trust, or hostile user-controlled collision resistance.

## RNG v1

`DeterministicRng` uses xorshift32. State and outputs are unsigned 32-bit values. Seed `0` deterministically normalizes to `0x6d2b79f5` because xorshift32's zero state is absorbing. Canonical generators therefore occupy the nonzero xorshift cycle: exactly `2^32 - 1` reachable states.

`nextInteger` maps each reachable state `1..2^32-1` to a zero-based sample `0..2^32-2`, then uses rejection sampling against that `2^32 - 1`-value domain so bounded draws do not introduce modulo bias. An exactly uniform one-draw range may therefore contain at most `2^32 - 1` integer values. Changing draw count or call order changes that stream by design; it must not affect another derived stream.

The bounded-draw mapping was corrected during Foundation Lock before first-observation recipe locking was unlocked. No observed-world compatibility promise exists for the briefly merged biased mapping; the corrected mapping is the normative RNG v1 contract and its golden vectors are checked in CI.

## SeedStream v1

Canonical stream derivation is:

`SeedStream.derive(worldSeed, generationVersion, subsystemSalt, scopes)`

The seed hashes:

`{ "seed-stream", "1", worldSeed, generationVersion, subsystemSalt, scope1, ... }`

with root seed `0x9e3779b9` and the v1 canonical list encoding.

Rules:
- `worldSeed` is 1-512 bytes.
- `generationVersion` is an explicit integer in `[1, 2147483647]`. Use the version of the generator/schema whose result the stream controls.
- `subsystemSalt` is 3-128 bytes, uses at least two lowercase dotted components, and may use `a-z`, `0-9`, `_`, and `-` within each component; examples include `worldgen.topology`, `worldgen.material`, `objects.chair`, and `system.bootstrap`.
- 1-32 semantic scopes are required; each is a non-empty stable semantic key of at most 512 bytes.
- Scope order is meaningful and must proceed from broad/stable identity toward local identity.

Recommended shape:

`WorldSeed -> GenerationVersion -> SubsystemSalt -> RegionId -> LocalSemanticKey`

Do not derive one subsystem by consuming values from another subsystem's generator. Derive each stream independently from stable inputs. Advancing a furniture stream must therefore be incapable of reshuffling topology.

## Version and migration law

Golden vectors in `tests/run.luau` are normative fixtures. A changed vector is not a normal refactor.

After canonical world content exists:
1. Never edit v1 behavior in place.
2. Add a new explicit contract/version path.
3. Persist enough generator/contract version information with resolved recipes to reconstruct historical truth.
4. New unobserved content may opt into a newer version only through an explicit generator-version change.
5. Existing observed content migrates only through a deliberate migration with regression evidence.

A reproducibility bug report should eventually carry WorldId/seed, generator version, subsystem salt, semantic scopes, and the relevant contract versions so the exact stream can be replayed.
