# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio test requests, capturing native engine evidence, executing fixed drivers in simulation mode, and consuming typed fail-closed results through the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical source code and public CI).
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated Mac running Roblox Studio and pinned project tools.
- **Security Boundary**: Requests are data only. `customScript`, arbitrary Luau, shell commands, executable payloads, and arbitrary source repositories are rejected.
- **Source Boundary**: `sourceSha` must be an exact 40-character commit reachable as an ancestor of the requested canonical `sourceRef`. A queued immutable request remains valid if the canonical ref advances after submission; unknown, unrelated, or diverged commits fail before Studio execution.
- **Evidence Boundary**: A completion sentinel or screenshot is transport evidence, not semantic PASS evidence. Job-specific evaluators own PASS.

---

## Submitting a Studio Test Request

Commit one JSON request under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`.

### Request File Path

`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Request Schema

Resolve and pin the canonical `main` commit intended for the evidence request immediately before creating it. The request keeps that exact immutable SHA even if `main` advances while the job is queued; execution later proves that the pinned commit is still reachable from the named canonical ref.

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-001-lifecycle-example-a1",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "<exact-40-char-pinned-canonical-sha>",
  "jobType": "physics-lab-lifecycle",
  "captureScreenshot": true,
  "requestedBy": "chatgpt-worker",
  "notes": "Exact-SHA Physics Lab lifecycle evidence only; no composite Hero Gate claim."
}
```

The production request validator also rejects duplicate result IDs, unsafe refs/strings, unsupported keys, unsupported job types, and a `sourceSha` that is not a commit reachable from the named canonical remote ref.

---

## Supported Job Types — Fixed Presets Only

Every allowed `jobType` maps to a fixed, versioned driver in the private bridge. Requests cannot inject executable code.

1. **`studio-smoke`** — basic DataModel/Rojo execution sanity.
2. **`studio-render-viewport`** — native/managed viewport capture path where supported.
3. **`studio-screenshot`** — Studio-window capture evidence.
4. **`studio-datamodel-dump`** — fixed DataModel inspection driver.
5. **`physics-lab-lifecycle`** — source-owned 20-cycle F2 → F0 → F2 lifecycle/resource/envelope/rebuild proof.
6. **`physics-lab-server-smoke`** — narrow server-side Physics Lab harness/realizer smoke proof.
7. **`physics-lab-two-client`** — true Studio multiplayer/server-authority proof requiring at least two observed clients to agree on one canonical lab truth.
8. **`physics-lab-physical-sanity`** — managed RunMode contact/traversability sanity across the canonical floor, stairs, ramp, ledge, and F2 ObjectGenome proxy set, with cleanup/resource/envelope checks.
9. **`physics-lab-diagnostics`** — source-owned diagnostics default-off/on/off behavior, inspectable identity readouts, bounded 20-cycle toggle/cleanup stability, request-bound runtime logs, and live diagnostics-on capture evidence.
10. **`physics-lab-performance-observation`** — bounded Studio/server RunMode measurement preset: engine version, canonical repro identity, 30 warmup + 120 measured Heartbeats, full-capture/restart observations, and restart resource/envelope stability. It deliberately reports `OBSERVED_NO_BUDGET`; PASS means the observations were captured and internally valid, not that a permanent frame/startup/device budget was met.
11. **`physics-lab-hero-gate`** — composite gate identifier. A lifecycle driver result alone is deliberately insufficient to PASS this job.

The managed Studio executor plugin is installed from versioned bridge source before jobs and is responsible for entering the supported Studio simulation path. The runner still requires request-bound engine logs before accepting a completion sentinel.

---

## Request-Bound Evidence Transport

Studio logs are not treated as a trustworthy global mailbox.

For each request the runner:

- injects a unique `STUDIO_EXECUTOR_REQUEST_ID=<requestId>` marker into the fixed driver,
- establishes a post-launch log epoch,
- accepts `STUDIO_EXECUTOR_FINISHED` only from a log containing the same request marker,
- preserves the request-bound raw log for failure diagnosis,
- transports large Physics Lab lifecycle, diagnostics, and performance payloads through bounded CreatorOutput chunks,
- checks chunk count/ordering/content consistency before reassembly,
- merges the reassembled row-specific proof into the compact verdict before semantic evaluation.

A stale Studio log, truncated chunk stream, missing result payload, timeout, source-SHA mismatch, or evaluator rejection must fail closed.

---

## Fail-Closed Status Semantics

`evaluate_evidence.py` is the single semantic PASS authority. The publisher may preserve explicit failure classes such as timeout/infrastructure failure, but it must never independently invent PASS from convenient booleans.

| Job Type | Required semantic evidence |
|---|---|
| **`physics-lab-lifecycle`** | Schema-v1 lifecycle result; exactly 20 cycles; canonical baseline identity/repro fields; checkpoints exactly at 1/5/10/20; zero deltas for tracked Instances/models/parts/assemblies/attachments/constraints/joints; checkpoint envelope success; both primitive and ObjectGenome samples; stable entity IDs; +20 state-revision and +40 representation-revision continuity. |
| **`physics-lab-server-smoke`** | Fixed server driver identity and sentinel; server execution; valid Physics Lab model; baseline validation; non-negative integer observed player count. |
| **`physics-lab-two-client`** | Same server foundation plus at least two observed players and two client observation reports; exactly one canonical lab root; non-empty canonical identity/entity-ID evidence per client; matching root count, identity, structure, and canonical truth across clients; managed Studio test teardown accepted. |
| **`physics-lab-physical-sanity`** | Managed server simulation; exactly one canonical lab root; full baseline validation; required floor/stair/ramp/ledge contact target set in canonical order; every contact succeeds; stair surface order remains traversable; five F2 ObjectGenome proxies present; temporary probes cleanly removed; zero canonical resource drift; canonical envelope preserved; exact world/region/fingerprint/repro identity present. |
| **`physics-lab-diagnostics`** | Studio server RunMode; diagnostics off by default and off at finish; live visible-readout phase reached; represented entity count matches owned BillboardGui readouts; structural and ObjectGenome identity/fidelity/revision samples are inspectable and distinct; required labels contain canonical fingerprint/repro values; 20 off-to-off toggle cycles with checkpoints at 1/5/10/20, zero tracked resource drift and envelope success; request-bound foundation/realization/visual-ready/result markers occur exactly once; a live diagnostics-on Studio capture is present. |
| **`physics-lab-performance-observation`** | Fixed performance driver/sentinel in Studio server RunMode; explicit `OBSERVED_NO_BUDGET`; engine version plus exact canonical world/region/recipe/fingerprint/repro identity; 30 warmup and 120 measured finite positive Heartbeat samples with internally consistent min/median/mean/p95/max/total statistics; finite capture/restart observations; zero tracked restart resource drift; documented 0.001-stud envelope preserved. This row records measurements only and must not be cited as proof of a permanent performance/device budget. |
| **`physics-lab-hero-gate`** | First validates the same strong lifecycle proof, then still fails closed because lifecycle alone does not prove the composite gate. #151 additionally requires independently reviewed contact/traversability, diagnostics behavior, two-client/server-authority behavior, and device/performance observations before scheduler unlock. |
| Other supported smoke/capture jobs | Their fixed driver/evaluator contract; a sentinel or image alone must not be interpreted as Hero Gate evidence. |

Transport state such as `COMPLETED` is not a semantic status. Unknown/non-PASS transport state cannot bypass the evaluator.

### Historical invalid result

`20260810-005-reality-hero-gate` emitted a useful lifecycle-style simulation signal, but an earlier bridge status layer incorrectly promoted it to composite `PASS`. The bridge durable record has been corrected to `FAIL`. Do not cite that request as #151 closure or as permission to unlock the door/chair/player epics.

---

## Truthful Capture Mode Reporting

Results identify how an image was obtained:

- **`NATIVE_ENGINE_RENDER`** — image generated through the supported engine render path.
- **`STUDIO_WINDOW_CAPTURE`** — targeted macOS Roblox Studio window capture.
- **`STUDIO_WINDOW_CAPTURE_DIAGNOSTICS_ON`** — targeted Studio-window capture taken while source-owned Physics Lab diagnostics were visibly enabled.
- **`DISPLAY_FALLBACK`** — full-display fallback capture.
- **`NO_CAPTURE`** — no image was captured.

Capture provenance does not replace behavioral evidence. A screenshot can support visual inspection while the machine evidence separately proves lifecycle/server contracts. For diagnostics, the row evaluator additionally requires capture evidence tied to the live diagnostics-on phase; a post-finish screenshot cannot substitute for it.

---

## Consuming Execution Results

Durable results are published to `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `result.json` — source SHA, job type, evaluator-derived status, environment/capture metadata, and machine evidence.
- `summary.md` — human-readable interpretation and evidence summary.
- `screenshot.png` — when capture was requested and succeeded.
- GitHub Actions raw-log artifact — request-bound Studio output used for diagnosis/review.

When consuming a result for `Docs/PROJECT_STATE.md` or issue #151, verify all of the following rather than copying the top-level word `PASS` blindly:

1. the result targets the intended exact pinned source SHA and that commit is canonical under the named source ref,
2. the job type proves the row being claimed,
3. the evaluator contract was active for that bridge revision,
4. raw/log provenance belongs to the same request,
5. the evidence payload contains the required semantic fields,
6. composite Hero Gate rows have independent evidence rather than being inferred from lifecycle success.

Only after the full Hero Gate evidence has been gathered and independently reviewed should `Docs/PROJECT_STATE.md` explicitly unlock the next narrow Hero Feature.
