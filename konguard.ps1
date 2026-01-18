# =========================================================
# KONGUARD — Entry Point (Tool-Grade CLI)
# Offline-first • Read-only • Explainable
# =========================================================

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ---------------------------
# Root paths
# ---------------------------
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $Root "modules"

# ---------------------------
# Args / Flags parsing
# ---------------------------
$ArgsText = ($args -join " ")

function Has-Flag {
    param([string]$Name)
    return [regex]::IsMatch($ArgsText, "(?i)(?:^|\s)--$Name(?:\s|$)")
}

function Get-FlagValue {
    param([string]$Name, [string]$Default = "")
    $m = [regex]::Match($ArgsText, "(?i)(?:^|\s)--$Name\s+([^\s]+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return $Default
}

# Version (single source of truth)
$VersionPath = Join-Path $Root "VERSION"
$KG_VERSION = if (Test-Path $VersionPath) { (Get-Content $VersionPath -Raw).Trim() } else { "dev" }

# Flags
$FLAG_VERSION = Has-Flag "version"
$FLAG_NOOPEN  = Has-Flag "no-open"
$FLAG_QUIET   = Has-Flag "quiet"
$FLAG_OUT     = Get-FlagValue "out" ""
$FLAG_FORMAT  = (Get-FlagValue "format" "both").ToLower()
$FLAG_LOG     = Get-FlagValue "log" ""

# Mode is a flag (avoid param() position issues)
$Mode = (Get-FlagValue "mode" "user").ToLower()
if ($Mode -notin @("user","tech")) { $Mode = "user" }

if ($FLAG_VERSION) {
    Write-Host "KONGUARD version $KG_VERSION"
    exit 0
}

if ($FLAG_FORMAT -notin @("html","json","both")) {
    Write-Host "Invalid --format. Use: html | json | both"
    exit 2
}

# Output root
$OutputRoot = if ($FLAG_OUT -and $FLAG_OUT.Trim()) { $FLAG_OUT } else { $Root }

# ---------------------------
# Logging (enterprise-safe)
# ---------------------------
$script:LogPath = $null

function Init-KGLog {
    param(
        [string]$OutputRoot,
        [string]$ExplicitLogPath = ""
    )

    if ($ExplicitLogPath -and $ExplicitLogPath.Trim()) {
        $script:LogPath = $ExplicitLogPath
    } else {
        $logDir = Join-Path $OutputRoot "logs"
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $script:LogPath = Join-Path $logDir "konguard.log"
    }

    $parent = Split-Path -Parent $script:LogPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Write-KGLog {
    param(
        [Parameter(Mandatory=$true)][string]$Level,
        [Parameter(Mandatory=$true)][string]$Message
    )
    try {
        if (-not $script:LogPath) { return }
        $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        "$ts [$Level] $Message" | Out-File -Append -Encoding UTF8 $script:LogPath
    } catch { }
}

function Write-KGLogInfo([string]$Message) { Write-KGLog -Level "INFO"  -Message $Message }
function Write-KGLogWarn([string]$Message) { Write-KGLog -Level "WARN"  -Message $Message }
function Write-KGLogErr ([string]$Message) { Write-KGLog -Level "ERROR" -Message $Message }

function Write-CLI {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    if (-not $FLAG_QUIET) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Initialize log early
Init-KGLog -OutputRoot $OutputRoot -ExplicitLogPath $FLAG_LOG
Write-KGLogInfo ("KONGUARD start | version={0} | mode={1}" -f $KG_VERSION, $Mode)
Write-KGLogInfo ("flags: format={0} out={1} no-open={2} quiet={3} log={4}" -f $FLAG_FORMAT, $OutputRoot, $FLAG_NOOPEN, $FLAG_QUIET, $script:LogPath)

# ---------------------------
# Helpers
# ---------------------------
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
    if ($FLAG_QUIET) { return }
@"
============================================================
  K O N G U A R D   ::   SYSTEM BLACK BOX
------------------------------------------------------------
  Local-only | Read-only | Offline-first | Explainable
============================================================
"@ | Write-Host -ForegroundColor Gray
}

function Write-Step {
    param(
        [Parameter(Mandatory=$true)][string] $Label,
        [Parameter(Mandatory=$true)][scriptblock] $Action
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-CLI ("[*] {0}" -f $Label) ([ConsoleColor]::Cyan)

    try {
        $result = & $Action
        $sw.Stop()
        Write-CLI ("    OK ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) ([ConsoleColor]::Green)
        Write-KGLogInfo ("STEP OK: {0} ({1:n1}s)" -f $Label, $sw.Elapsed.TotalSeconds)
        return $result
    } catch {
        $sw.Stop()
        Write-CLI ("    FAIL ({0:n1}s)" -f $sw.Elapsed.TotalSeconds) ([ConsoleColor]::Red)
        Write-KGLogErr ("STEP FAIL: {0} ({1:n1}s) :: {2}" -f $Label, $sw.Elapsed.TotalSeconds, $_.Exception.Message)
        throw
    }
}

function Write-Info([string]$msg) {
    Write-KGLogInfo $msg
    Write-CLI ("[i] {0}" -f $msg) ([ConsoleColor]::DarkGray)
}

function Write-Warn([string]$msg) {
    Write-KGLogWarn $msg
    Write-CLI ("[!] {0}" -f $msg) ([ConsoleColor]::Yellow)
}

function Write-Bad([string]$msg) {
    Write-KGLogErr $msg
    Write-CLI ("[X] {0}" -f $msg) ([ConsoleColor]::Red)
}

# ---------------------------
# Main execution
# ---------------------------
try {
    Show-KonguardIntro
    Write-Info ("Mode: {0}" -f $Mode)
    Write-Info "Starting secure local scan..."

    # Imports
    Import-KGModule "Hardware.psm1"
    Import-KGModule "Software.psm1"
    Import-KGModule "Security.psm1"
    Import-KGModule "Baseline.psm1"
    Import-KGModule "Scoring.psm1"
    Import-KGModule "Report.psm1"

    # Timestamp + machine
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $machine = $env:COMPUTERNAME

    # Scan object
    $scan = [ordered]@{
        meta = [ordered]@{
            tool      = "KONGUARD"
            version   = $KG_VERSION
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
    $snapDir = Join-Path $OutputRoot "snapshots"
    $repDir  = Join-Path $OutputRoot "reports"
    New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
    New-Item -ItemType Directory -Force -Path $repDir  | Out-Null

    # Deterministic file names
    $snapPath = Join-Path $snapDir ("{0}_{1}_snapshot.json" -f $machine, $timestamp)
    $repPath  = Join-Path $repDir  ("{0}_{1}_report.html"   -f $machine, $timestamp)

    Write-Step "STEP 5/5  Report + Snapshot Export" {
        if ($FLAG_FORMAT -in @("json","both")) {
            $scan | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $snapPath
            Write-CLI ("Saved snapshot: {0}" -f $snapPath) ([ConsoleColor]::Gray)
            Write-KGLogInfo ("Saved snapshot: {0}" -f $snapPath)
        }

        if ($FLAG_FORMAT -in @("html","both")) {
            # Some Report modules accept -Mode, some don't. Call safely.
            try {
                New-KonguardHtmlReport -Scan $scan -OutputPath $repPath -Mode $Mode
            } catch {
                New-KonguardHtmlReport -Scan $scan -OutputPath $repPath
            }
            Write-CLI ("Saved report:   {0}" -f $repPath) ([ConsoleColor]::Gray)
            Write-KGLogInfo ("Saved report: {0}" -f $repPath)

            if (-not $FLAG_NOOPEN -and -not $FLAG_QUIET -and (Test-Path $repPath)) {
                Start-Process $repPath | Out-Null
            }
        }
    } | Out-Null

    # Calm signals (safe property access)
    $startupCount = 0
    $si = Get-PropValue -Obj $scan.software -Name "startup_items"
    if ($si) { $startupCount = @($si).Count }

    if ($startupCount -ge 25) {
        Write-Warn ("Startup load is high ({0} items). Consider disabling unused startup apps." -f $startupCount)
    } elseif ($startupCount -ge 15) {
        Write-Warn ("Startup load is moderate ({0} items). Consider reviewing startup apps." -f $startupCount)
    }

    # Security schema safety
    $defenderMsg = Get-PropValue -Obj $scan.security -Name "defender"
    $avEnabled   = Get-PropValue -Obj $scan.security -Name "antivirus_enabled"
    $rtpEnabled  = Get-PropValue -Obj $scan.security -Name "real_time_protection"

    if ($null -ne $defenderMsg -and $defenderMsg.ToString().Trim()) {
        Write-Info ("Security status: {0}" -f $defenderMsg)
    } else {
        if ($avEnabled -eq $false) { Write-Bad "Antivirus appears disabled. This increases malware risk." }
        if ($rtpEnabled -eq $false) { Write-Bad "Real-time protection is OFF. Threats may not be blocked immediately." }
    }

    Write-CLI "" ([ConsoleColor]::Gray)
    Write-CLI "Done." ([ConsoleColor]::Green)
    Write-KGLogInfo "KONGUARD end (success)"
    exit 0
}
catch {
    Write-KGLogErr ("Unhandled error: {0}" -f $_.Exception.Message)
    try { Write-KGLogErr ($_.ScriptStackTrace) } catch { }
    Write-CLI ("[X] Unhandled error: {0}" -f $_.Exception.Message) ([ConsoleColor]::Red)
    exit 1
}
