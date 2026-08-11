# Swarm Control Plane V2 Activation

This marker records the first real end-to-end activation proof for UNRENDERED's GitHub-native swarm control plane.

It does **not** change the Hero Gate, reinterpret Roblox Studio evidence, or unlock Door/Chair/Physical Player work.

## Proven activation path

The rollout uses the live `swarm-control` branch as operational state and product `main` as source/control-plane implementation truth.

The first protected-scope activation PR is required to prove all of the following rather than relying on documentation alone:

- a GPT-5.6 Sol worker session has a distinct swarm worker ID;
- `SWARM-V2-ROLLOUT/primary` is owned by an atomically created live claim;
- that claim carries a non-secret fencing token and exact branch name;
- the same worker/lane/token owns the exclusive `PROJECT-STATE` resource lease;
- the PR body carries the exact lane/slot/worker/token/schema metadata;
- the PR changes only lane-authorized scope;
- CI reads authoritative claim/resource state from `swarm-control` and rejects mismatches;
- canonical UNRENDERED CI remains green alongside the control-plane checks.

After the activation PR merges, the rollout claim/resource lease must be released and the rollout lane finalized on `swarm-control`.

## Worker contract

Future workers follow `Docs/SWARM_PROTOCOL.md` and `Docs/SWARM_CONTROL_PLANE.md`:

**claim first, branch second.**

If an exclusive claim conflicts, the losing worker selects another useful slot instead of creating a competing implementation.

If ownership cannot be proven, the worker fails closed.

## Strategic state

`Docs/PROJECT_STATE.md` remains the authoritative feature-unlock board. Swarm V2 coordinates work; it does not grant feature permission by itself.
