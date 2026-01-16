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

Import-KGModule "Hardware.psm1"
Import-KGModule "Software.psm1"
Import-KGModule "Security.psm1"

Write-Host "KONGUARD: Starting scan (offline, read-only)..." -ForegroundColor Cyan

$scan = [ordered]@{
  meta = [ordered]@{
    tool      = "KONGUARD"
    version   = "0.1.0"
    timestamp = (Get-Date).ToString("s")
    machine   = $env:COMPUTERNAME
  }
  hardware = Get-KonguardHardware
  software = Get-KonguardSoftware
  security = Get-KonguardSecurity
}

# Output folders (local-only)
$snapDir = Join-Path $Root "snapshots"
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null

# Save snapshot (JSON)
$snapPath = Join-Path $snapDir ("snapshot_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$scan | ConvertTo-Json -Depth 8 | Out-File -Encoding UTF8 $snapPath

Write-Host "Saved snapshot: $snapPath" -ForegroundColor Green
Write-Host "Done." -ForegroundColor Green
