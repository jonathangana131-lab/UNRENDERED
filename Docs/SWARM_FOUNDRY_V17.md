# Swarm Foundry 17 congestion control

Foundry 17 keeps UNRENDERED V16, trusted history, live `swarm-control`, the private Studio bridge, evidence fencing, and the serialized merge train authoritative. It makes repository pressure an admission gate instead of a dashboard warning.

## Activation truth

The 2026-08-14 audit found 102 open PRs and 971 branches while no open PR remained selected by the live Mission Graph. The graph could detect branch explosion, but a requested worker count was still converted into a full role quota. Foundry treats incoming chats as optional capacity.

## Admission law

- Normal ChatGPT Project capacity ceiling: 20 chats.
- At most 3 active major Feature Epics.
- At most 6 primary implementation lanes, reduced by actual ready work.
- Open product PR ceiling: 18.
- Active non-protected product branch ceiling: 24.
- Review backlog >= 4 throttles new builders to 2.
- Integration backlog >= 3 throttles new builders to 1.
- Exhausted PR or branch headroom admits no new product builder.
- Red `main` may receive one emergency repair exception.
- Integration, review, exact-head verification, evidence transfer, and bounded retirement receive priority.
- Excess chats park instead of creating speculative capacity work.

`tools/swarm/foundry_v17.py` computes the gate and never grants claim authority. Claim-first/branch-second, fencing, protected resources, independent review, and exact-head integration remain mandatory.

## Recoverable reset

Activation closes open PRs not selected by live V16 authority and labels them `swarm-foundry-retired`. PR discussion, commits, and branches remain available for recovery; activation deletes no branch. Reopening requires a current non-duplicate work item, Mission Graph selection, fresh claim, exact-head evidence, and repository headroom.

The private Studio bridge and external-runtime truth classes are unchanged. Cleanup cannot reinterpret missing Studio, two-client, viewport, device, or performance evidence.

## Validation

```sh
python3 tools/swarm/test_foundry_v17.py
```

The audited-pressure test proves a 30-chat arrival under pre-reset pressure admits zero new primary builders and prioritizes retirement/review/integration.
