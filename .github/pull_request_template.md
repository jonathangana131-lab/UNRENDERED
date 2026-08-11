## Swarm Control Plane

<!-- Required for new controlled swarm PRs. Copy exact values from the live claim. -->
Swarm-Lane: REPLACE
Swarm-Slot: REPLACE
Swarm-Worker: sol-YYYYMMDD-REPLACE
Swarm-Claim-Token: REPLACE
Control-Schema: 1

<!-- V2.2: mandatory for PRs created on/after the live activation timestamp. -->
Swarm-Self-Review: PASS
Swarm-Self-Review-Head: REPLACE_WITH_EXACT_40_HEX_HEAD_SHA

## What changed

## Why

## Architecture impact
- [ ] No architecture contract changed
- [ ] ADR added/updated if an architecture contract changed

## Validation
- [ ] implementer reread/attacked the exact diff and bound the self-review to this exact head
- [ ] `stylua --check src tests`
- [ ] `selene src tests`
- [ ] Luau analysis
- [ ] relevant tests
- [ ] Rojo build
- [ ] swarm-control scope/claim check
- [ ] independent review depth satisfied when V2.2 risk policy requires it

## Procedural evidence
Seed / region / object genome / repro key, if applicable:

## Visual / physics evidence
Screenshots, clips, metrics, Studio request IDs, or artifacts, if applicable:

## Performance / networking impact

## Handoff / follow-ups
