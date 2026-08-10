# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio evidence requests, capturing native engine output, executing fixed project-owned drivers in managed simulation, and consuming typed fail-closed results through the private Mac ↔ GitHub bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` — canonical source, scheduler, and source CI.
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` — request/result transport and the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`.
- **Runner Machine**: dedicated local Mac with Roblox Studio and pinned project tools.
- **Security Boundary**: requests are DATA only. Arbitrary remote Luau, shell commands, executable text, and arbitrary source repositories are forbidden.
- **Evidence Boundary**: Studio execution can provide one or more #151 evidence rows; no individual driver may silently promote a partial row into the composite Hero Gate.

---

## Submitting a Studio Test Request

Commit one JSON request under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`.

### Request File Path

`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Example

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-015-lifecycle-requestbound-example",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "<exact 40-char canonical main SHA>",
  "jobType": "physics-lab-lifecycle",
  "captureScreenshot": false,
  "dumpDataModel": false,
  "requestedBy": "chatgpt-go-worker",
  "notes": "Row-scoped #151 lifecycle evidence only; does not close the composite Hero Gate."
}
```

The validator verifies the canonical repository/ref/SHA relationship and rejects unknown fields or executable request content.

---

## Supported Job Types — Fixed Presets

Every allowed `jobType` maps to a fixed, versioned driver stored in the bridge repository.

1. **`studio-smoke`** — DataModel/Rojo launch sanity.
2. **`studio-render-viewport`** — native/render viewport capture path where supported.
3. **`studio-screenshot`** — targeted Studio screenshot evidence.
4. **`studio-datamodel-dump`** — fixed DataModel diagnostic dump.
5. **`physics-lab-lifecycle`** — source-owned 20-cycle F2 -> F0 -> F2 lifecycle/rebuild/resource/envelope evidence.
6. **`physics-lab-server-smoke`** — row-scoped server/bootstrap/model-validity evidence.
7. **`physics-lab-two-client`** — row-scoped multiplayer/authority evidence; it must observe the required client topology rather than infer it from a single server process.
8. **`physics-lab-hero-gate`** — composite-gate probe. Under the current contract, lifecycle-only output from this driver is deliberately insufficient to produce a composite PASS.

No preset is permission to bypass `Docs/PROJECT_STATE.md` or #151's row-specific acceptance requirements.

---

## Request-Bound Log Ownership

Roblox Studio writes shared host logs, so timestamp recency alone is not sufficient evidence ownership.

The runner injects a request marker into the fixed driver:

`STUDIO_EXECUTOR_REQUEST_ID=<requestId>`

A completion sentinel is accepted only from a log that:

1. was written after the current launch marker,
2. contains this exact request ID, and
3. contains the expected completion sentinel/result payload.

A different Studio log may be retained for timeout diagnostics, but it can never produce PASS evidence for the current request.

---

## CreatorOutput Transport

Roblox CreatorOutput has demonstrated per-line truncation around 1 KiB. Evidence larger than the safe line budget must therefore use bounded numbered chunks plus metadata.

For Physics Lab lifecycle evidence the bridge:

1. emits a compact evaluator-ready lifecycle object as bounded chunks,
2. records expected chunk count and byte count,
3. reassembles the exact payload outside Studio,
4. rejects missing, conflicting, unexpected, truncated, or oversized chunks,
5. merges that payload into the compact transport verdict before semantic evaluation.

The strong lifecycle payload includes canonical baseline/repro identity, checkpoints 1/5/10/20, zero resource deltas, envelope results, and representative primitive/ObjectGenome revision evidence. A coarse `cycleCount`/`checkpointCount` summary is not an equivalent substitute.

---

## Fail-Closed Status Derivation

Top-level PASS is owned by the bridge's semantic evaluator, not by a sentinel or transport completion state.

| Job Type | PASS boundary |
|---|---|
| **`physics-lab-lifecycle`** | Strong reassembled lifecycle schema passes canonical identity/repro, 20-cycle checkpoint, zero-delta, envelope, and representative revision checks. |
| **`physics-lab-server-smoke`** | Fixed server-smoke evidence proves the expected server driver/sentinel, server context, lab model validity, and baseline validity. |
| **`physics-lab-two-client`** | Fixed multiplayer evidence proves the expected server driver/sentinel plus the required observed player/client count and authority conditions. |
| **`physics-lab-hero-gate`** | **Composite gate: lifecycle-only evidence is rejected.** Contact/traversability, diagnostics, multiplayer/authority, and device/performance rows remain independently required by #151. |
| **non-Physics smoke/render jobs** | Their own fixed-driver semantic contract must pass; transport completion alone is not a blanket Physics Lab PASS. |

Transport states such as timeout/build/Studio/infrastructure failure remain failures. Legacy/coarse `COMPLETED` must not be treated as semantic PASS.

---

## Truthful Capture Mode Reporting

Results declare capture provenance explicitly:

- **`NATIVE_ENGINE_RENDER`** — image originated from the engine/native render path.
- **`STUDIO_WINDOW_CAPTURE`** — targeted macOS Studio-window capture.
- **`DISPLAY_FALLBACK`** — full-display fallback capture.
- **`NO_CAPTURE`** — no image requested/captured.

A screenshot is supporting visual evidence, not a substitute for typed semantic proof.

---

## Consuming Execution Results

Results are published under `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `result.json` — typed machine-readable status, exact source SHA, environment, job type, capture provenance, semantic evaluation, and evidence payload.
- `summary.md` — human-readable interpretation of that result.
- `screenshot.png` — optional supporting Studio capture.
- GitHub Actions artifact — request-scoped raw Studio log when the workflow reaches artifact upload.

Before recording a row as PASS in #151 or `Docs/PROJECT_STATE.md`, verify:

1. the result belongs to the exact request ID and exact canonical source SHA,
2. the job type matches the row being claimed,
3. the semantic evaluator accepted the strong typed payload,
4. no separate #151 row is being inferred from that result,
5. the raw/screenshot provenance is truthful,
6. any failure/timeout remains fail-closed.

---

## Historical Evidence Correction

`20260810-005-reality-hero-gate` on source SHA `f348acb8dae2f98f7a75c8085539eab49b435b56` demonstrated useful coarse facts: managed Studio simulation reached `IsRunning = true`, `IsServer = true`, and the lifecycle driver reported 20 cycles / four checkpoints.

Its original top-level `physics-lab-hero-gate` PASS was invalid because the payload was lifecycle-only and did not contain the strong reassembled lifecycle schema or the other composite #151 rows. The bridge has downgraded that result to `FAIL`. Do not cite the historical coarse result as Hero Gate closure.

---

## Scheduler Rule

`Docs/PROJECT_STATE.md` remains authoritative. The Studio bridge is an evidence mechanism, not an unlock mechanism. Door, chair, physical-player, world-generation, or other major feature work remains locked until the scheduler explicitly says otherwise after accepted Hero Gate evidence and review.
