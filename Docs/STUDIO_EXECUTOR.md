# UNRENDERED Studio Executor Protocol

This document defines the protocol for submitting automated Roblox Studio test requests and consuming real engine evidence via the private Mac ↔ GitHub execution bridge.

## Overview

- **Public Repository**: `jonathangana131-lab/UNRENDERED` (canonical content & source CI).
- **Private Bridge Repository**: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE` (hosts the dedicated macOS self-hosted runner `UNRENDERED-STUDIO-MAC`).
- **Runner Machine**: Dedicated local Mac running Roblox Studio and pinned project tools (`rojo 7.6.1`).
- **Steady-State Transport**: ChatGPT "Go" Worker -> GitHub Push (`requests/*.json`) -> Mac Self-Hosted Runner -> Real Roblox Studio Execution -> GitHub Push (`results/<requestId>/result.json`).

> [!IMPORTANT]
> Self-hosted runners are **never** attached directly to the public repository. All Studio requests are processed through the private bridge repository.

---

## Submitting a Studio Test Request

To request a Roblox Studio test run, commit a JSON file under `requests/` in `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`:

### Request File Path
`requests/YYYYMMDD-HHMMSS-<jobType>-<nonce>.json`

### Fixed Request Schema

```json
{
  "schemaVersion": 1,
  "requestId": "20260810-002-hero-gate",
  "sourceRepo": "jonathangana131-lab/UNRENDERED",
  "sourceRef": "main",
  "sourceSha": "71523fcdc82e44b485c46a0fd0e6759b83d8ff6f",
  "jobType": "physics-lab-hero-gate",
  "requestedBy": "chatgpt-go-worker",
  "notes": "Full Studio Physics Lab 20-cycle lifecycle sweep"
}
```

### Schema Rules & Validation

1. `sourceRepo` MUST equal `jonathangana131-lab/UNRENDERED`.
2. `sourceSha` MUST be an exact 40-character hex commit SHA.
3. `sourceRef` MUST be `main` or an allowed `agent/...` branch on the canonical repository.
4. `jobType` MUST be one of the allowlisted types:
   - `studio-smoke`: DataModel & Rojo build sanity check.
   - `physics-lab-lifecycle`: 20-cycle F2 -> F0 -> F2 sweep.
   - `physics-lab-server-smoke`: Server realizer and harness check.
   - `physics-lab-two-client`: Multi-client topology check.
   - `physics-lab-hero-gate`: Full physical envelope & lifecycle validation.
5. Path traversal, shell metacharacters, or arbitrary executable options are strictly rejected.

---

## Consuming Execution Results

Upon completion, the bridge automatically commits the machine-readable result to `results/<requestId>/`:

- `results/<requestId>/result.json`: Machine-readable evidence payload and environment metadata.
- `results/<requestId>/summary.md`: Human/LLM-readable summary.
- GitHub Actions Artifact: `studio-execution-log-<run_id>` contains full raw Roblox Studio console logs.

### Result Status Values

- `PASS`: Roblox Studio executed successfully and all Luau driver assertions passed.
- `FAIL`: Luau driver assertion failed or game evidence check failed.
- `INFRA_ERROR`: Build failure, invalid request, or Studio launch error.
- `TIMEOUT`: Execution exceeded the maximum allowed time limit.

---

## Swarm Rules for ChatGPT "Go" Workers

1. **Never Fake Evidence**: Never record a Studio row as `PASS` based solely on source code inspection or Ubuntu CI logs.
2. **Submit One Request Per SHA**: Create exactly one request JSON per commit SHA to be tested.
3. **Review Output Before Gate Changes**: Verify `result.json` shows `status: PASS` and valid `evidence` before advancing project scheduler gates.
4. **Resubmit on Failure**: If `status: FAIL`, fix the defect on a new branch, push to `UNRENDERED`, and submit a new request against the new SHA.
