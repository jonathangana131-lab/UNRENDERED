# Live UNRENDERED swarm state

This directory exists only on the `swarm-control` branch and is never merged into product `main`.

Authoritative live state is `config.json`, `lanes/`, `resources/`, `claims/`, `resource-claims/`, worker records and immutable events. `generated/` is disposable and rebuilt by CI.

Workers must follow `Docs/SWARM_CONTROL_PLANE.md` from product `main`.
