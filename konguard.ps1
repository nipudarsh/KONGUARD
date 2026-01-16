# KONGUARD - Portable System Verification Tool (offline, read-only)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $Root "modules"

function Import-KGModule($name) {
    $path = Join-Path $ModulesPath $name
    if (-not (Test-Path $path)) { throw "Missing module: $path" }
    Import-Module $path -Force
}

# Core modules
Import-KGModule "Hardware.psm1"
Import-KGModule "Software.psm1"
Import-KGModule "Security.psm1"

# Report module (NEW)
Import-KGModule "Report.psm1"

Write-Host "KONGUARD: Starting scan (offline, read-only)..." -ForegroundColor Cyan

$scan = [ordered]@{
  meta = [ordered]@{
    tool      = "KONGUARD"
    version   = "0.2.0"
    timestamp = (Get-Date).ToString("s")
    machine   = $env:COMPUTERNAME
  }
  hardware = Get-KonguardHardware
  software = Get-KonguardSoftware
  security = Get-KonguardSecurity
}

# Output folders (local-only)
$snapDir = Join-Path $Root "snapshots"
$repDir  = Join-Path $Root "reports"
New-Item -ItemType Directory -Force -Path $snapDir, $repDir | Out-Null

# Save snapshot (JSON)
$snapPath = Join-Path $snapDir ("snapshot_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$scan | ConvertTo-Json -Depth 8 | Out-File -Encoding UTF8 $snapPath

# Save report (HTML)
$repPath = Join-Path $repDir ("report_{0}.html" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
New-KonguardHtmlReport -Scan $scan -OutputPath $repPath

Write-Host "Saved snapshot: $snapPath" -ForegroundColor Green
Write-Host "Saved report:   $repPath" -ForegroundColor Green
Write-Host "Done." -ForegroundColor Green
