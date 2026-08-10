# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio test requests, capturing engine evidence, executing fixed drivers in real simulation mode, and consuming typed fail-closed evidence via the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical source code & public CI).
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated local Mac running Roblox Studio and pinned project tools.
- **Security Boundary**: Zero remote code execution. Requests carry pure DATA (`jobType`, SHA, ref). No executable text, shell commands, or arbitrary paths are permitted.
- **Evidence Boundary**: A successful bridge execution is evidence only for the rows its fixed driver and evaluator actually prove. It is never permission to infer unobserved Hero Gate rows.

---

## Submitting a Studio Test Request

To request a Roblox Studio test run, commit a single JSON file under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`:

### Request File Path
`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Request Shape

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-005-reality-hero-gate",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "<exact 40-character canonical commit SHA>",
  "jobType": "physics-lab-lifecycle",
  "captureScreenshot": true,
  "requestedBy": "worker-id",
  "notes": "Row-scoped evidence purpose; no broader PASS claim"
}
```

The source SHA is part of the evidence identity. Do not silently retarget a failed run to another commit and describe it as the same observation.

---

## Supported Job Types (Fixed Presets)

Every allowed `jobType` maps to a fixed, versioned driver implementation stored in the private bridge repository:

1. **`studio-smoke`**: DataModel / Rojo build sanity evidence.
2. **`studio-render-viewport`**: Fixed viewport/render evidence path.
3. **`studio-screenshot`**: Captures a targeted Roblox Studio screenshot.
4. **`studio-datamodel-dump`**: Fixed DataModel inspection evidence.
5. **`physics-lab-lifecycle`**: Source-owned 20-cycle F2 -> F0 -> F2 representation/resource/envelope sweep in Studio.
6. **`physics-lab-server-smoke`**: Server-side Physics Lab realization/baseline smoke in real simulation mode.
7. **`physics-lab-two-client`**: Evaluates two-client evidence only when the execution topology actually contains at least two observed players; a single-server run cannot satisfy this row.
8. **`physics-lab-hero-gate`**: Composite-gate label. The current lifecycle driver cannot by itself prove the complete #151 Hero Gate, so the evaluator intentionally fails closed rather than manufacturing a composite PASS.

---

## Fail-Closed Status Derivation

Top-level status is derived from mandatory typed evidence. A finish sentinel, screenshot, green GitHub job, or partial row **never** produces a broader PASS by itself.

Current Physics Lab rules are aligned to the bridge evaluator:

| Job Type | Accepted evidence scope |
|---|---|
| **`physics-lab-lifecycle`** | Requires the fixed Physics Lab driver/sentinel, captured baseline, `lifecycleOk == true`, schema-v1 compact lifecycle proof, 20 cycles, checkpoints at 1/5/10/20, zero tracked resource deltas at checkpoints, valid envelope comparisons, canonical baseline identity, and primitive + ObjectGenome entity revision samples. |
| **`physics-lab-server-smoke`** | Requires the fixed server driver/sentinel plus server execution, valid lab model, completed baseline validation, and a non-negative observed player count. |
| **`physics-lab-two-client`** | Requires the same server evidence and **at least two observed players**. `partiallySupported` or a zero/one-player run does not become PASS. |
| **`physics-lab-hero-gate`** | Intentionally returns FAIL after validating lifecycle evidence because lifecycle alone does not prove contact/traversability, diagnostics behavior, two-client authority, or device/performance rows. Composite acceptance remains governed by #151 and `Docs/PHYSICS_LAB_VALIDATION.md`. |

For non-Physics-Lab jobs, consume only the evidence explicitly produced by that fixed preset. Do not use them to unlock #151.

### Durable result truth wins

When prose, a workflow conclusion, a screenshot, or an older comment disagrees with the current durable `results/<requestId>/result.json`, treat the durable fail-closed result plus its evaluator reason as authoritative for that request until an explicitly reviewed correction supersedes it.

As of this protocol correction, `20260810-005-reality-hero-gate` contains valuable real Studio lifecycle observations but its durable top-level status is **FAIL**, because those observations do not satisfy the complete composite Hero Gate.

---

## Truthful Capture Mode Reporting

Results may declare a capture mode such as:

- **`NATIVE_ENGINE_RENDER`**: Engine-produced viewport image when the fixed preset successfully emits one.
- **`STUDIO_WINDOW_CAPTURE`**: Targeted macOS window capture of Roblox Studio.
- **`DISPLAY_FALLBACK`**: Full desktop screen capture fallback.
- **`NO_CAPTURE`**: No accepted image was captured.

A screenshot is supporting evidence, not a substitute for typed engine assertions.

---

## Consuming Execution Results

Results are published back to `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `results/<requestId>/result.json`: Machine-readable evidence payload, exact source identity, environment metadata, capture mode, evaluator reason, and derived status.
- `results/<requestId>/summary.md`: Human-readable summary when publication succeeds.
- `results/<requestId>/screenshot.png`: Optional supporting image.
- GitHub Actions raw-log artifacts: request-bound Studio output used to diagnose runner/plugin failures or publication races.

If the runner fails before Studio launches, classify it as executor/infrastructure failure, not game evidence. If Studio runs but the evaluator rejects the payload, preserve the rejected observation and fix the smallest concrete contract/transport defect; never weaken the check merely to get PASS.

---

## Hero Gate closeout

The bridge is a measurement mechanism, not the scheduler. Close #151 and unlock the next Hero feature only after the issue's required engine-facing rows have actual recorded evidence and `Docs/PROJECT_STATE.md` is explicitly updated after review. Until then, door, chair, physical-player, and broader feature work remain gated.