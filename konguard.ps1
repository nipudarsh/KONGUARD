param(
    [ValidateSet("user","tech")]
    [string] $Mode = "user"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $Root "modules"

function Import-KGModule([string]$name) {
    $path = Join-Path $ModulesPath $name
    if (-not (Test-Path $path)) { throw "Missing module: $path" }
    Import-Module $path -Force
}

function Get-PropValue {
    param(
        [Parameter(Mandatory=$true)] $Obj,
        [Parameter(Mandatory=$true)] [string] $Name
    )
    if ($null -eq $Obj) { return $null }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Show-KonguardIntro {
    Clear-Host
@"
============================================================
  K O N G U A R D   ::   THE SYSTEM BLACK BOX
------------------------------------------------------------
  Local-only    Read-only    Offline-first    Explainable
============================================================
"@ | Write-Host -ForegroundColor Gray

    Start-Sleep -Milliseconds 450
}

function Write-Step {
    param(
        [Parameter(Mandatory=$true)][string] $Label,
        [Parameter(Mandatory=$true)][scriptblock] $Action
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ("[*] {0}" -f $Label) -ForegroundColor Cyan -NoNewline

    try {
        $result = & $Action
        $sw.Stop()
        Write-Host ("  OK  ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
        return $result
    } catch {
        $sw.Stop()
        Write-Host ("  FAIL ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Red
        throw
    }
}

function Write-Info([string]$msg) {
    Write-Host ("[i] {0}" -f $msg) -ForegroundColor DarkGray
}

function Write-Warn([string]$msg) {
    Write-Host ("[!] {0}" -f $msg) -ForegroundColor Yellow
}

function Write-Bad([string]$msg) {
    Write-Host ("[X] {0}" -f $msg) -ForegroundColor Red
}

# ---- Intro ----
Show-KonguardIntro
Write-Info ("Mode: {0}" -f $Mode)
Write-Info "Starting secure local scan..."
Write-Host ""

# ---- Imports ----
Import-KGModule "Hardware.psm1"
Import-KGModule "Software.psm1"
Import-KGModule "Security.psm1"
Import-KGModule "Baseline.psm1"
Import-KGModule "Scoring.psm1"
Import-KGModule "Report.psm1"

# ---- Scan steps ----
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$machine = $env:COMPUTERNAME

$scan = [ordered]@{
  meta = [ordered]@{
    tool      = "KONGUARD"
    version   = "0.3.0"
    timestamp = (Get-Date).ToString("s")
    machine   = $machine
    mode      = $Mode
  }
}

$scan.hardware = Write-Step "STEP 1/5  Hardware Scan" { Get-KonguardHardware }
$scan.software = Write-Step "STEP 2/5  Startup Integrity" { Get-KonguardSoftware }
$scan.security = Write-Step "STEP 3/5  Security Status" { Get-KonguardSecurity }

$scan.health   = Write-Step "STEP 4/5  Health Score" { Get-KonguardHealthScore -Scan $scan }

# Output folders
$snapDir = Join-Path $Root "snapshots"
$repDir  = Join-Path $Root "reports"
New-Item -ItemType Directory -Force -Path $snapDir, $repDir | Out-Null

# Deterministic filenames
$snapPath = Join-Path $snapDir ("{0}_{1}_snapshot.json" -f $machine, $timestamp)
$repPath  = Join-Path $repDir  ("{0}_{1}_report.html"   -f $machine, $timestamp)

Write-Step "STEP 5/5  Report + Snapshot Export" {
    $scan | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $snapPath
    New-KonguardHtmlReport -Scan $scan -OutputPath $repPath -Mode $Mode
    return $true
} | Out-Null

# ---- Baseline + comparison (kept outside the 5-step UX) ----
$baselinePath = Join-Path $Root "snapshots\baseline.json"
$baseline = Import-KonguardBaseline -BaselinePath $baselinePath

if ($null -eq $baseline) {
    $saved = Export-KonguardBaseline -Scan $scan -BaselinePath $baselinePath
    Write-Warn ("Baseline created: {0} (next run will produce comparison)" -f $saved)
} else {
    $diff = Compare-KonguardBaseline -Baseline $baseline -Current $scan
    $cmpPath = Join-Path $repDir ("{0}_{1}_comparison.html" -f $machine, $timestamp)
    New-KonguardComparisonReport -Diff $diff -OutputPath $cmpPath
    Write-Info ("Comparison report: {0}" -f $cmpPath)
}

# ---- Calm signals (no StrictMode property crashes) ----
$startupCount = 0
if ($scan.software.startup_items) { $startupCount = @($scan.software.startup_items).Count }
if ($startupCount -ge 25) {
    Write-Warn ("Startup load is high ({0} items). Consider disabling unused startup apps." -f $startupCount)
} elseif ($startupCount -ge 15) {
    Write-Warn ("Startup load is moderate ({0} items). Consider reviewing startup apps." -f $startupCount)
}

# Security checks: handle both possible schemas safely
$defenderMsg = Get-PropValue -Obj $scan.security -Name "defender"
$avEnabled   = Get-PropValue -Obj $scan.security -Name "antivirus_enabled"
$rtpEnabled  = Get-PropValue -Obj $scan.security -Name "real_time_protection"

if ($null -ne $defenderMsg) {
    Write-Warn ("Security status note: {0}" -f $defenderMsg)
} else {
    if ($avEnabled -eq $false) { Write-Bad "Antivirus appears disabled. This increases malware risk." }
    if ($rtpEnabled -eq $false) { Write-Bad "Real-time protection is OFF. Threats may not be blocked immediately." }
}

Write-Host ""
Write-Host ("Saved snapshot: {0}" -f $snapPath) -ForegroundColor Green
Write-Host ("Saved report:   {0}" -f $repPath)  -ForegroundColor Green

if ($Mode -eq "user") {
    Start-Process $repPath | Out-Null
}

Write-Host "Done." -ForegroundColor Green
