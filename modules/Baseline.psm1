function Export-KonguardBaseline {
    param(
        [Parameter(Mandatory=$true)] $Scan,
        [Parameter(Mandatory=$true)] [string] $BaselinePath
    )

    $dir = Split-Path -Parent $BaselinePath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $Scan | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 $BaselinePath
    return $BaselinePath
}

function Import-KonguardBaseline {
    param(
        [Parameter(Mandatory=$true)] [string] $BaselinePath
    )

    if (-not (Test-Path $BaselinePath)) { return $null }
    (Get-Content $BaselinePath -Raw -Encoding UTF8) | ConvertFrom-Json
}

function Compare-KonguardBaseline {
    param(
        [Parameter(Mandatory=$true)] $Baseline,
        [Parameter(Mandatory=$true)] $Current
    )

    $baselineRam = [double]$Baseline.hardware.ram_gb
    $currentRam  = [double]$Current.hardware.ram_gb

    $baselineStartupCount = 0
    if ($Baseline.software.startup_items) { $baselineStartupCount = @($Baseline.software.startup_items).Count }

    $currentStartupCount = 0
    if ($Current.software.startup_items) { $currentStartupCount = @($Current.software.startup_items).Count }

    $baselineAV  = $Baseline.security.antivirus_enabled
    $currentAV   = $Current.security.antivirus_enabled
    $baselineRTP = $Baseline.security.real_time_protection
    $currentRTP  = $Current.security.real_time_protection

    [ordered]@{
        ram_before_gb = $baselineRam
        ram_after_gb  = $currentRam
        ram_change_gb = [math]::Round(($currentRam - $baselineRam), 2)

        startup_count_before = $baselineStartupCount
        startup_count_after  = $currentStartupCount

        antivirus_before = $baselineAV
        antivirus_after  = $currentAV

        rtp_before = $baselineRTP
        rtp_after  = $currentRTP
    }
}

Export-ModuleMember -Function Export-KonguardBaseline, Import-KonguardBaseline, Compare-KonguardBaseline
