# UNRENDERED Studio Executor Protocol — Reality-Grade Specification

This document defines the production protocol for submitting automated Roblox Studio test requests, capturing native engine renders, executing fixed drivers in real simulation mode, and consuming typed fail-closed evidence via the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical source code & public CI).
- **Private Control Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated local Mac running Roblox Studio (`0.732.0`) and pinned project tools (`rojo 7.6.1`).
- **Security Boundary**: Zero remote code execution. Requests carry pure DATA (`jobType`, SHA, ref). No executable text, shell commands, or arbitrary paths are permitted.

---

## Submitting a Studio Test Request

To request a Roblox Studio test run, commit a single JSON file under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`:

### Request File Path
`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Complete Request Schema

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-005-reality-hero-gate",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "f348acb8dae2f98f7a75c8085539eab49b435b56",
  "jobType": "physics-lab-hero-gate",
  "captureScreenshot": true,
  "requestedBy": "chatgpt-developer",
  "notes": "Full Physics Lab Hero Gate reality-grade engine execution"
}
```

---

## Supported Job Types (Fixed Presets)

Every allowed `jobType` maps to a fixed, versioned driver implementation stored in the private bridge repository:

1. **`studio-smoke`**: DataModel & Rojo build sanity check.
2. **`studio-render-viewport`**: Uses Roblox's native `ThumbnailGenerator` engine renderer to generate a 1080p 3D Viewport PNG directly from the graphics pipeline, completely independent of OS window focus or occlusion.
3. **`studio-screenshot`**: Captures a targeted screenshot of Roblox Studio.
4. **`studio-datamodel-dump`**: Serializes the DataModel instance hierarchy (`Workspace`, `ReplicatedStorage`, `ServerScriptService`) and memory stats into structured JSON.
5. **`physics-lab-hero-gate`**: Drives the source-owned 20-cycle F2 -> F0 -> F2 lifecycle sweep inside Roblox Studio in real simulation mode (`RunService:IsRunning() == true`, `RunService:IsServer() == true`).
6. **`physics-lab-lifecycle`**: Standalone 20-cycle representation & envelope sweep.
7. **`physics-lab-server-smoke`**: Verifies server realizer and harness check in simulation mode.
8. **`physics-lab-two-client`**: Launches multi-client topology checks via `StudioTestService`.

---

## Fail-Closed Status Derivation Engine

Top-level status is mathematically derived from mandatory typed evidence. A sentinel string alone **never** produces `PASS`.

| Job Type | Status Derivation Rule |
|---|---|
| **`physics-lab-hero-gate`** | Requires `lifecycleOk == true`, `isRunning == true`, `isServer == true`, `baselineCaptured == true`, and `checkpointCount == 4`. If any condition fails, status is `FAIL`. |
| **`physics-lab-server-smoke`** | Requires `baselineCaptured == true`, `isRunning == true`, and `isServer == true`. |
| **`physics-lab-two-client`** | Returns `PASS` if `twoClientOk == true`; returns `UNVERIFIED` if `partiallySupported == true`. |
| **`studio-smoke` / `studio-screenshot` / `studio-render-viewport`** | Requires valid sentinel or `baselineCaptured == true`. |

---

## Truthful Capture Mode Reporting

Results explicitly declare `captureMode` in `result.json` and `summary.md`:

- **`NATIVE_ENGINE_RENDER`**: Base64 3D Viewport PNG generated directly by Roblox's internal `ThumbnailGenerator` engine pipeline (occlusion-free).
- **`STUDIO_WINDOW_CAPTURE`**: Targeted macOS Quartz CGWindowID window capture (`screencapture -x -l <window_id>`) capturing only the Roblox Studio window.
- **`DISPLAY_FALLBACK`**: Full desktop screen capture.
- **`NO_CAPTURE`**: No image requested or captured.

---

## Consuming Execution Results

Results are published back to `results/<requestId>/` in `UNRENDERED-STUDIO-BRIDGE`:

- `results/<requestId>/result.json`: Machine-readable evidence payload, environment metadata, `captureMode`, and derived `status`.
- `results/<requestId>/summary.md`: Human-readable summary with embedded viewport screenshots.
- `results/<requestId>/screenshot.png`: High-resolution PNG image.
