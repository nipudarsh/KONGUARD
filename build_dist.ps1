# build_dist.ps1
# Creates a clean USB-ready distributable folder: dist/KONGUARD

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistRoot = Join-Path $Root "dist"
$Out = Join-Path $DistRoot "KONGUARD"

function Ensure-EmptyDir($Path) {
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

Write-Host "Building KONGUARD distribution..." -ForegroundColor Cyan

Ensure-EmptyDir $Out

# Copy core entry + launcher
Copy-Item (Join-Path $Root "konguard.ps1") (Join-Path $Out "konguard.ps1") -Force
Copy-Item (Join-Path $Root "START_CHECK.bat") (Join-Path $Out "START_CHECK.bat") -Force

# Copy modules + docs
Copy-Item (Join-Path $Root "modules") (Join-Path $Out "modules") -Recurse -Force
Copy-Item (Join-Path $Root "docs")    (Join-Path $Out "docs")    -Recurse -Force

# Copy license + readme + version
Copy-Item (Join-Path $Root "LICENSE") (Join-Path $Out "LICENSE") -Force
Copy-Item (Join-Path $Root "README.md") (Join-Path $Out "README.md") -Force
Copy-Item (Join-Path $Root "VERSION") (Join-Path $Out "VERSION") -Force

# Create empty local-only folders (not in git)
New-Item -ItemType Directory -Force -Path (Join-Path $Out "snapshots") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Out "reports")   | Out-Null

# Write a small "RUN_ME.txt" for non-technical users
@"
KONGUARD - Quick Run

1) Double-click START_CHECK.bat
2) Wait for scan to finish
3) Report will open automatically (user mode)

Outputs:
- snapshots\  (JSON snapshots + baseline.json)
- reports\    (HTML report + comparison report)

Trust guarantees:
- Offline-first
- Read-only
- No data uploaded anywhere
"@ | Out-File -Encoding UTF8 (Join-Path $Out "RUN_ME.txt")

Write-Host "Done." -ForegroundColor Green
Write-Host ("Output: {0}" -f $Out) -ForegroundColor Green
