# UNRENDERED Studio Executor Protocol

This document defines the protocol for submitting automated Roblox Studio test requests, capturing native 3D engine renders, taking targeted window screenshots, executing custom Luau scripts, dumping DataModel trees, and consuming real engine evidence via the private Mac ↔ GitHub execution bridge.

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
  "requestId": "20260810-004-native-viewport",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "766c5b05defbfe505cab61c0ff87cc984464e8de",
  "jobType": "studio-render-viewport",
  "captureScreenshot": true,
  "dumpDataModel": true,
  "customScript": "local Workspace = game:GetService('Workspace'); print('PARTS_COUNT=' .. tostring(#Workspace:GetDescendants()))",
  "requestedBy": "chatgpt-developer",
  "notes": "Native 3D engine viewport rendering test"
}
```

---

## Supported Job Types & Developer Capabilities

1. **`studio-smoke`**: DataModel & Rojo build sanity check.
2. **`studio-render-viewport`**: Uses Roblox's native `ThumbnailGenerator` engine renderer to generate a 1080p 3D Viewport PNG directly from the graphics pipeline, completely independent of OS window focus, z-order, or occlusion.
3. **`studio-screenshot`**: Captures a targeted screenshot of Roblox Studio and embeds it in `summary.md`.
4. **`studio-datamodel-dump`**: Serializes the DataModel instance hierarchy (`Workspace`, `ReplicatedStorage`, `ServerScriptService`) into structured JSON.
5. **`studio-custom-luau`**: Executes custom developer Luau code passed in `customScript` inside Roblox Studio's server environment.
6. **`physics-lab-lifecycle`**: Drives the source-owned 20-cycle F2 -> F0 -> F2 lifecycle sweep inside Roblox Studio.
7. **`physics-lab-server-smoke`**: Verifies server realizer and harness check.
8. **`physics-lab-two-client`**: Launches multi-client topology checks via `StudioTestService`.
9. **`physics-lab-hero-gate`**: Full physical envelope & lifecycle evidence validation for Hero Gate #151.

---

## Occlusion-Free Screenshot & Rendering Engine

The bridge implements a **3-layer screenshot capture pipeline** so developers get clear visual feedback even while you are actively working on your Mac:

- **Layer 1 (Native Engine 3D Viewport Render)**: Luau driver calls `ThumbnailGenerator:Click("PNG", 1920, 1080, false)` inside Roblox Studio to capture a 1080p render directly from Roblox's graphics engine. It is **100% independent of OS windowing or focus** — Roblox Studio does not need to be on top or visible.
- **Layer 2 (Targeted macOS CGWindowID Capture)**: `get_roblox_window_id.py` queries macOS Quartz for Roblox Studio's specific window ID (`screencapture -x -l <window_id>`) to capture ONLY the Roblox Studio window without capturing overlapping applications.
- **Layer 3 (Display Fallback)**: Full desktop screen capture (`screencapture -x`).

---

## Developer Abilities & Controls

- **`captureScreenshot` (boolean)**: Set `true` to capture and embed `screenshot.png` in `summary.md`.
- **`customScript` (string)**: Supply arbitrary Luau code to inspect instance states, query properties, trigger events, or run bespoke diagnostic checks inside Roblox Studio.
- **`dumpDataModel` (boolean)**: Set `true` to extract an instance tree dump of the open place DataModel.

---

## Consuming Execution Results

Upon completion, the bridge automatically commits the machine-readable result to `results/<requestId>/`:

- `results/<requestId>/result.json`: Machine-readable evidence payload, environment metadata, and screenshot flag.
- `results/<requestId>/summary.md`: Markdown summary with embedded viewport screenshots (`![Roblox Studio Viewport](screenshot.png)`).
- `results/<requestId>/screenshot.png`: High-resolution PNG screenshot / native 3D engine render.
- GitHub Actions Artifact: `studio-execution-log-<run_id>` contains full raw Roblox Studio console logs.
