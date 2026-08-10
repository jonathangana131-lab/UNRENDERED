# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio test requests, capturing native engine evidence, executing fixed drivers in simulation mode, and consuming typed fail-closed results through the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical source code and public CI).
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated Mac running Roblox Studio and pinned project tools.
- **Security Boundary**: Requests are data only. `customScript`, arbitrary Luau, shell commands, executable payloads, and arbitrary source repositories are rejected.
- **Source Boundary**: `sourceSha` must be the exact current commit resolved by the requested canonical `sourceRef`; stale or mismatched requests fail before Studio execution.
- **Evidence Boundary**: A completion sentinel or screenshot is transport evidence, not semantic PASS evidence. Job-specific evaluators own PASS.

---

## Submitting a Studio Test Request

Commit one JSON request under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`.

### Request File Path

`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Request Schema

Resolve the canonical `main` SHA immediately before creating the request; the value below is intentionally shown as a placeholder because a hard-coded example becomes stale as soon as `main` advances.

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-001-lifecycle-example-a1",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "<exact-40-char-current-main-sha>",
  "jobType": "physics-lab-lifecycle",
  "captureScreenshot": true,
  "requestedBy": "chatgpt-worker",
  "notes": "Exact-SHA Physics Lab lifecycle evidence only; no composite Hero Gate claim."
}
```

The production request validator also rejects duplicate result IDs, unsafe refs/strings, unsupported keys, unsupported job types, and a `sourceSha` that does not match the canonical remote ref.

---

## Supported Job Types — Fixed Presets Only

Every allowed `jobType` maps to a fixed, versioned driver in the private bridge. Requests cannot inject executable code.

1. **`studio-smoke`** — basic DataModel/Rojo execution sanity.
2. **`studio-render-viewport`** — native/managed viewport capture path where supported.
3. **`studio-screenshot`** — Studio-window capture evidence.
4. **`studio-datamodel-dump`** — fixed DataModel inspection driver.
5. **`physics-lab-lifecycle`** — source-owned 20-cycle F2 → F0 → F2 lifecycle/resource/envelope/rebuild proof.
6. **`physics-lab-server-smoke`** — narrow server-side Physics Lab harness/realizer smoke proof.
7. **`physics-lab-two-client`** — multi-client/server-authority topology proof.
8. **`physics-lab-hero-gate`** — composite gate identifier. A lifecycle driver result alone is deliberately insufficient to PASS this job.

The managed Studio executor plugin is installed from versioned bridge source before jobs and is responsible for entering the supported Studio simulation path. The runner still requires request-bound engine logs before accepting a completion sentinel.

---

## Request-Bound Evidence Transport

Studio logs are not treated as a trustworthy global mailbox.

For each request the runner:

- injects a unique `STUDIO_EXECUTOR_REQUEST_ID=<requestId>` marker into the fixed driver,
- establishes a post-launch log epoch,
- accepts `STUDIO_EXECUTOR_FINISHED` only from a log containing the same request marker,
- preserves the request-bound raw log for failure diagnosis,
- transports large Physics Lab lifecycle proof through bounded CreatorOutput chunks,
- checks chunk count/ordering/content consistency before reassembly,
- merges the reassembled lifecycle proof into the compact verdict before semantic evaluation.

A stale Studio log, truncated chunk stream, missing result payload, timeout, source-SHA mismatch, or evaluator rejection must fail closed.

---

## Fail-Closed Status Semantics

`evaluate_evidence.py` is the single semantic PASS authority. The publisher may preserve explicit failure classes such as timeout/infrastructure failure, but it must never independently invent PASS from convenient booleans.

| Job Type | Required semantic evidence |
|---|---|
| **`physics-lab-lifecycle`** | Schema-v1 lifecycle result; exactly 20 cycles; canonical baseline identity/repro fields; checkpoints exactly at 1/5/10/20; zero deltas for tracked Instances/models/parts/assemblies/attachments/constraints/joints; checkpoint envelope success; both primitive and ObjectGenome samples; stable entity IDs; +20 state-revision and +40 representation-revision continuity. |
| **`physics-lab-hero-gate`** | First validates the same strong lifecycle proof, then still fails closed because lifecycle alone does not prove the composite gate. #151 additionally requires independently reviewed contact/traversability, diagnostics behavior, two-client/server-authority behavior, and device/performance observations before scheduler unlock. |
| **`physics-lab-server-smoke`** | Fixed server driver identity and sentinel; server execution; valid Physics Lab model; baseline validation; non-negative integer observed player count. |
| **`physics-lab-two-client`** | Same server evidence plus at least two observed players. |
| Other supported smoke/capture jobs | Their fixed driver/evaluator contract; a sentinel or image alone must not be interpreted as Hero Gate evidence. |

Transport state such as `COMPLETED` is not a semantic status. Unknown/non-PASS transport state cannot bypass the evaluator.

### Historical invalid result

`20260810-005-reality-hero-gate` emitted a useful lifecycle-style simulation signal, but an earlier bridge status layer incorrectly promoted it to composite `PASS`. The bridge durable record has been corrected to `FAIL`. Do not cite that request as #151 closure or as permission to unlock the door/chair/player epics.

---

## Truthful Capture Mode Reporting

Results identify how an image was obtained:

- **`NATIVE_ENGINE_RENDER`** — image generated through the supported engine render path.
- **`STUDIO_WINDOW_CAPTURE`** — targeted macOS Roblox Studio window capture.
- **`DISPLAY_FALLBACK`** — full-display fallback capture.
- **`NO_CAPTURE`** — no image was captured.

Capture provenance does not replace behavioral evidence. A screenshot can support visual inspection while the machine evidence separately proves lifecycle/server contracts.

---

## Consuming Execution Results

Durable results are published to `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `result.json` — source SHA, job type, evaluator-derived status, environment/capture metadata, and machine evidence.
- `summary.md` — human-readable interpretation and evidence summary.
- `screenshot.png` — when capture was requested and succeeded.
- GitHub Actions raw-log artifact — request-bound Studio output used for diagnosis/review.

When consuming a result for `Docs/PROJECT_STATE.md` or issue #151, verify all of the following rather than copying the top-level word `PASS` blindly:

1. the result targets the intended exact canonical source SHA,
2. the job type proves the row being claimed,
3. the evaluator contract was active for that bridge revision,
4. raw/log provenance belongs to the same request,
5. the evidence payload contains the required semantic fields,
6. composite Hero Gate rows have independent evidence rather than being inferred from lifecycle success.

Only after the full Hero Gate evidence has been gathered and independently reviewed should `Docs/PROJECT_STATE.md` explicitly unlock the next narrow Hero Feature.
