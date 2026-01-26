# =========================================================
# KONGUARD :: SYSTEM BLACK BOX (Stable Entrypoint)
# Local-only | Read-only | Offline-first | Explainable
# =========================================================

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# -------------------------
# Root / Version
# -------------------------
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $Root "modules"

$VersionPath = Join-Path $Root "VERSION"
$KG_VERSION = if (Test-Path $VersionPath) { (Get-Content $VersionPath -Raw).Trim() } else { "dev" }

# -------------------------
# CLI flags (simple + robust)
# -------------------------
$ArgsText = ($args -join " ")

function Has-Flag([string]$Name) {
    return [regex]::IsMatch($ArgsText, "(?i)(?:^|\s)--$Name(?:\s|$)")
}
function Get-FlagValue([string]$Name, [string]$Default = "") {
    $m = [regex]::Match($ArgsText, "(?i)(?:^|\s)--$Name\s+([^\s]+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return $Default
}

$FLAG_VERSION = Has-Flag "version"
$FLAG_NOOPEN  = Has-Flag "no-open"
$FLAG_OUT     = Get-FlagValue "out" ""
$FLAG_FORMAT  = (Get-FlagValue "format" "both").ToLower()
$FLAG_MODE    = (Get-FlagValue "mode" "user").ToLower()

if ($FLAG_VERSION) {
    Write-Host "KONGUARD version $KG_VERSION"
    exit 0
}

if ($FLAG_FORMAT -notin @("html","json","both")) {
    Write-Host "Invalid --format. Use: html | json | both"
    exit 2
}

if ($FLAG_MODE -notin @("user","tech")) {
    Write-Host "Invalid --mode. Use: user | tech"
    exit 2
}

# -------------------------
# Helpers
# -------------------------
function Import-KGModule([string]$Name) {
    $Path = Join-Path $ModulesPath $Name
    if (-not (Test-Path $Path)) { throw "Missing module: $Path" }
    Import-Module $Path -Force
}

function Run-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][scriptblock]$Action
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ("[*] {0}" -f $Label) -NoNewline -ForegroundColor Cyan
    try {
        $r = & $Action
        $sw.Stop()
        Write-Host ("  OK ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
        return $r
    } catch {
        $sw.Stop()
        Write-Host ("  FAIL ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Red
        throw
    }
}

function Show-Banner {
    Clear-Host
@"
============================================================
  K O N G U A R D   ::   SYSTEM BLACK BOX
------------------------------------------------------------
  Local-only | Read-only | Offline-first | Explainable
============================================================
"@ | Write-Host -ForegroundColor Gray
    Write-Host ("[i] Mode: {0}" -f $FLAG_MODE) -ForegroundColor DarkGray
    Write-Host "[i] Starting secure local scan..." -ForegroundColor DarkGray
    Write-Host ""
}

# -------------------------
# Start
# -------------------------
Show-Banner

# Imports (must exist)
Import-KGModule "Hardware.psm1"
Import-KGModule "Software.psm1"
Import-KGModule "Security.psm1"
Import-KGModule "Baseline.psm1"
Import-KGModule "Scoring.psm1"
Import-KGModule "Report.psm1"

# Scan
$machine   = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$scan = [ordered]@{
    meta = [ordered]@{
        tool      = "KONGUARD"
        version   = $KG_VERSION
        timestamp = (Get-Date).ToString("s")
        machine   = $machine
        mode      = $FLAG_MODE
    }
}

$scan.hardware = Run-Step "STEP 1/5  Hardware Scan"     { Get-KonguardHardware }
$scan.software = Run-Step "STEP 2/5  Startup Integrity" { Get-KonguardSoftware }
$scan.security = Run-Step "STEP 3/5  Security Status"   { Get-KonguardSecurity }
$scan.health   = Run-Step "STEP 4/5  Health Score"      { Get-KonguardHealthScore -Scan $scan }

# Output root
$OutputRoot = if ($FLAG_OUT -and $FLAG_OUT.Trim()) { $FLAG_OUT } else { $Root }

$snapDir = Join-Path $OutputRoot "snapshots"
$repDir  = Join-Path $OutputRoot "reports"
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
New-Item -ItemType Directory -Force -Path $repDir  | Out-Null

$snapPath = Join-Path $snapDir ("{0}_{1}_snapshot.json" -f $machine, $timestamp)
$repPath  = Join-Path $repDir  ("{0}_{1}_report.html"   -f $machine, $timestamp)

# Export
Run-Step "STEP 5/5  Report + Snapshot Export" {

    if ($FLAG_FORMAT -in @("json","both")) {
        $scan | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $snapPath
        Write-Host "Saved snapshot: $snapPath"
    }

    if ($FLAG_FORMAT -in @("html","both")) {
        New-KonguardHtmlReport -Scan $scan -OutputPath $repPath -Mode $FLAG_MODE
        Write-Host "Saved report:   $repPath"
        if (-not $FLAG_NOOPEN -and (Test-Path $repPath)) { Start-Process $repPath }
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
