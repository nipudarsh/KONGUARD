# KONGUARD🦍🛡️
![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue.svg)
![Read-only](https://img.shields.io/badge/read--only-yes-brightgreen.svg)

## CLI Demo

```text
  K O N G U A R D   ::   SYSTEM BLACK BOX
------------------------------------------------------------
  Local-only    Read-only    Offline-first    Explainable

[i] Mode: user
[i] Starting secure local scan...

[*] STEP 1/5  Hardware Scan               OK  (3.4s)
[*] STEP 2/5  Startup Integrity           OK  (0.2s)
[*] STEP 3/5  Security Status             OK  (2.1s)
[*] STEP 4/5  Health Score                OK  (0.2s)
[*] STEP 5/5  Report + Snapshot Export    OK  (0.7s)

[i] Comparison report: reports/<MACHINE>_<TIME>_comparison.html
Saved snapshot: snapshots/<MACHINE>_<TIME>_snapshot.json
Saved report:   reports/<MACHINE>_<TIME>_report.html
Done.
🦍🛡️
```
## Quick Start (Windows)

### Run (recommended)
``` powershell
powershell -ExecutionPolicy Bypass -File .\konguard.ps1
```
###What it generates
* snapshots/snapshot_*.json — scan output

* snapshots/baseline.json — baseline (first run if missing)

* reports/report_*.html — readable report

* reports/comparison_*.html — before/after comparison (when baseline exists)

### Trust guarantees
* Runs locally (no data leaves your computer)

* Read-only (does not change system settings)

* Offline-first
