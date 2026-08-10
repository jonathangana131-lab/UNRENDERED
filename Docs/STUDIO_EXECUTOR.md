# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio test requests, capturing native engine renders, executing fixed drivers in real simulation mode, and consuming typed fail-closed evidence via the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical source code & public CI).
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated local Mac running Roblox Studio and pinned project tools.
- **Security Boundary**: Zero remote code execution. Requests carry pure data (`jobType`, SHA, ref). No executable text, shell commands, arbitrary Luau, or arbitrary paths are permitted.
- **Simulation Boundary**: A bridge-owned managed Studio plugin starts fixed drivers through `StudioTestService` RunMode; request identity in CreatorOutput binds completion to the submitted request.

---

## Submitting a Studio Test Request

To request a Roblox Studio test run, commit a single JSON file under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`:

### Request File Path
`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Example Request Schema

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-016-server-smoke-example",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "<exact 40-character canonical commit SHA>",
  "jobType": "physics-lab-server-smoke",
  "captureScreenshot": true,
  "dumpDataModel": false,
  "requestedBy": "chatgpt-worker",
  "notes": "Row-specific engine evidence only"
}
```

The validator rejects unknown fields and verifies the exact canonical ref/SHA before Studio is launched.

---

## Supported Job Types (Fixed Presets)

Every allowed `jobType` maps to a fixed, versioned driver implementation stored in the private bridge repository:

1. **`studio-smoke`**: DataModel & Rojo build sanity check.
2. **`studio-render-viewport`**: Native/render-path viewport evidence where supported.
3. **`studio-screenshot`**: Captures a targeted screenshot of Roblox Studio.
4. **`studio-datamodel-dump`**: Serializes selected DataModel/runtime diagnostics into structured evidence.
5. **`physics-lab-lifecycle`**: Source-owned 20-cycle F2 -> F0 -> F2 lifecycle/resource/envelope sweep.
6. **`physics-lab-server-smoke`**: Server realizer/harness bootstrap and canonical baseline check in simulation mode.
7. **`physics-lab-two-client`**: Multi-client/server-authority evidence preset.
8. **`physics-lab-hero-gate`**: Composite gate identifier. **A lifecycle run is only one row and cannot by itself satisfy this job.** The current evaluator deliberately rejects lifecycle-only composite evidence.

---

## Fail-Closed Status Derivation

Top-level status is derived by the job-specific semantic evaluator. Transport completion or a sentinel string alone **never** produces a durable `PASS`.

| Job Type | Current acceptance meaning |
|---|---|
| **`physics-lab-lifecycle`** | Requires the evaluator-owned lifecycle object: schema/version, canonical repro identity, exactly 20 cycles, checkpoints 1/5/10/20, zero resource deltas, envelope success, and representative primitive/ObjectGenome revision evidence. |
| **`physics-lab-server-smoke`** | Requires the server-smoke driver contract and a valid canonical baseline/model on the server. |
| **`physics-lab-two-client`** | Requires at least two actually observed players plus the server/baseline contract; a server-only run cannot masquerade as two-client evidence. |
| **`physics-lab-hero-gate`** | Lifecycle-only evidence is rejected. #151 remains composite until contact/traversability, applicable mechanism behavior, diagnostics, server/two-client authority, and device/performance rows are independently gathered and reviewed. |

The historical `20260810-005-reality-hero-gate` result is specifically **not** a composite PASS. It captured a useful Run-mode lifecycle signal, but its original top-level `PASS` was invalidated in the bridge after fail-closed review because the required independent Hero Gate rows were absent and the result did not carry the evaluator-owned canonical lifecycle proof.

---

## Evidence Transport and Provenance

CreatorOutput can truncate long lines. Physics Lab lifecycle proof is therefore emitted as bounded chunks with declared byte/chunk counts, reassembled fail-closed by the bridge, and merged into the compact verdict before semantic evaluation. Missing, conflicting, malformed, or truncated chunks fail the row.

Completion is request-bound: the runner injects a request ID marker and accepts `[STUDIO_EXECUTOR_FINISHED]` only from a post-launch Studio log containing that same marker. The exact canonical source SHA is checked out before the place is built.

---

## Truthful Capture Mode Reporting

Results explicitly declare `captureMode` in `result.json` and `summary.md`:

- **`NATIVE_ENGINE_RENDER`**: Native engine/render-path image evidence when available.
- **`STUDIO_WINDOW_CAPTURE`**: Targeted macOS Roblox Studio window capture.
- **`DISPLAY_FALLBACK`**: Full desktop display capture.
- **`NO_CAPTURE`**: No image requested or captured.

A screenshot is supporting visual evidence; it does not replace typed physics, authority, lifecycle, or performance evidence.

---

## Consuming Execution Results

Results are published back to `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `results/<requestId>/result.json`: Machine-readable source SHA, environment/capture metadata, job-specific evidence, evaluation reason, and derived status.
- `results/<requestId>/summary.md`: Human-readable summary and evidence interpretation.
- `results/<requestId>/screenshot.png`: Screenshot when capture succeeded.
- GitHub Actions artifact: raw request-bound Studio log for audit/repro.

Consumers must use the row-specific derived status and evidence payload. Never promote one row into another row or into the composite Hero Gate by inference. `Docs/PROJECT_STATE.md` remains the authoritative unlock board.
