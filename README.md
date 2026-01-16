# KONGUARD 🦍🛡️
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
