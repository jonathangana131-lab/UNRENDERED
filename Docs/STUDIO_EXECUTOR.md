# UNRENDERED Studio Executor Protocol

This document defines the protocol for submitting automated Roblox Studio test requests, capturing screenshots, executing custom Luau scripts, dumping DataModel trees, and consuming real engine evidence via the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical content & source CI).
- **Private Bridge Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated local Mac running Roblox Studio and pinned project tools (`rojo 7.6.1`).
- **Steady-State Transport**: ChatGPT "Go" Worker -> GitHub Push (`requests/*.json`) -> Mac Self-Hosted Runner -> Real Roblox Studio Execution -> GitHub Push (`results/<requestId>/result.json`).

---

## Submitting a Studio Test Request

To request a Roblox Studio test run, commit a single JSON file under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`:

### Request File Path
`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Complete Request Schema

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-003-custom-inspection",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "e035306c301d93cd1162282a6c5bb5d373b4657e",
  "jobType": "studio-custom-luau",
  "captureScreenshot": true,
  "dumpDataModel": true,
  "customScript": "local Workspace = game:GetService('Workspace'); print('PARTS_COUNT=' .. tostring(#Workspace:GetDescendants()))",
  "requestedBy": "chatgpt-developer",
  "notes": "Custom Luau execution with screenshot capture and DataModel dump"
}
```

---

## Supported Job Types & Developer Capabilities

1. **`studio-smoke`**: DataModel & Rojo build sanity check.
2. **`studio-screenshot`**: Captures a full high-resolution PNG screenshot of the Roblox Studio viewport during execution and embeds it in `summary.md`.
3. **`studio-datamodel-dump`**: Serializes the DataModel instance hierarchy (`Workspace`, `ReplicatedStorage`, `ServerScriptService`) into structured JSON.
4. **`studio-custom-luau`**: Executes custom developer Luau code passed in `customScript` inside Roblox Studio's server environment.
5. **`physics-lab-lifecycle`**: Drives the source-owned 20-cycle F2 -> F0 -> F2 lifecycle sweep inside Roblox Studio.
6. **`physics-lab-server-smoke`**: Verifies server realizer and harness check.
7. **`physics-lab-two-client`**: Launches multi-client topology checks via `StudioTestService`.
8. **`physics-lab-hero-gate`**: Full physical envelope & lifecycle evidence validation for Hero Gate #151.

---

## Developer Abilities & Controls

- **`captureScreenshot` (boolean)**: Set `true` to take a real macOS window screenshot (`screencapture -x`) of Roblox Studio during execution. The image is published as `results/<requestId>/screenshot.png` and embedded directly in `summary.md`.
- **`customScript` (string)**: Supply arbitrary Luau code to inspect instance states, query properties, trigger events, or run bespoke diagnostic checks inside Roblox Studio.
- **`dumpDataModel` (boolean)**: Set `true` to extract an instance tree dump of the open place DataModel.

---

## Consuming Execution Results

Upon completion, the bridge automatically commits the machine-readable result to `results/<requestId>/`:

- `results/<requestId>/result.json`: Machine-readable evidence payload, environment metadata, and screenshot flag.
- `results/<requestId>/summary.md`: Markdown summary with embedded viewport screenshots (`![Roblox Studio Viewport](screenshot.png)`).
- `results/<requestId>/screenshot.png`: High-resolution PNG screenshot (when requested).
- GitHub Actions Artifact: `studio-execution-log-<run_id>` contains full raw Roblox Studio console logs.

---

## Swarm Rules for ChatGPT "Go" Workers

1. **Never Fake Evidence**: Never record a Studio row as `PASS` based solely on source code inspection or Ubuntu CI logs.
2. **Submit One Request Per SHA**: Create exactly one request JSON per commit SHA to be tested.
3. **Review Output Before Gate Changes**: Verify `result.json` shows `status: PASS` and valid `evidence` before advancing project scheduler gates.
4. **Resubmit on Failure**: If `status: FAIL`, fix the defect on a new branch, push to `UNRENDERED`, and submit a new request against the new SHA.
