function Get-KonguardHealthScore {
    param(
        [Parameter(Mandatory=$true)] $Scan
    )

    $score = 100
    $reasons = New-Object System.Collections.Generic.List[string]

    # --- Performance scoring ---
    # RAM thresholds (simple, explainable)
    $ram = [double]$Scan.hardware.ram_gb
    if ($ram -lt 4) {
        $score -= 30
        $reasons.Add("Performance: Very low RAM ($ram GB). Expect slowdowns and app freezes.")
    } elseif ($ram -lt 8) {
        $score -= 15
        $reasons.Add("Performance: Low RAM ($ram GB). Multitasking may feel slow.")
    } elseif ($ram -lt 16) {
        $score -= 5
        $reasons.Add("Performance: OK RAM ($ram GB). Heavy multitasking may be limited.")
    }

    # Disk: try to detect SSD/HDD using MediaType/Model hints (best-effort)
    $diskPenalty = 0
    $disks = @($Scan.hardware.disks)
    foreach ($d in $disks) {
        $mt = ""
        if ($d.media_type) { $mt = [string]$d.media_type }
        $model = ""
        if ($d.model) { $model = [string]$d.model }

        $isHDDHint = ($mt -match "HDD") -or ($model -match "HDD") -or ($mt -match "Hard Disk")
        $isSSDHint = ($mt -match "SSD") -or ($model -match "SSD") -or ($mt -match "Solid")

        if ($isHDDHint -and -not $isSSDHint) {
            $diskPenalty = [math]::Max($diskPenalty, 12)
        }
    }
    if ($diskPenalty -gt 0) {
        $score -= $diskPenalty
        $reasons.Add("Performance: HDD detected. Upgrading to SSD can significantly improve boot and app speed.")
    }

    # --- Startup load scoring ---
    $startupCount = 0
    if ($Scan.software.startup_items) { $startupCount = @($Scan.software.startup_items).Count }

    if ($startupCount -ge 25) {
        $score -= 15
        $reasons.Add("Startup Load: High ($startupCount items). This can slow boot time.")
    } elseif ($startupCount -ge 15) {
        $score -= 8
        $reasons.Add("Startup Load: Moderate ($startupCount items). Consider disabling unused startup apps.")
    }

    # --- Security scoring ---
    # Handle Defender unavailable case
    if ($Scan.security.defender) {
        $score -= 15
        $reasons.Add("Security: Defender status unavailable. Ensure antivirus protection is enabled.")
    } else {
        if (-not $Scan.security.antivirus_enabled) {
            $score -= 25
            $reasons.Add("Security: Antivirus appears disabled. This increases malware risk.")
        }
        if (-not $Scan.security.real_time_protection) {
            $score -= 20
            $reasons.Add("Security: Real-time protection is off. Threats may not be blocked immediately.")
        }
    }

    # Clamp score 0..100
    if ($score -lt 0) { $score = 0 }
    if ($score -gt 100) { $score = 100 }

    $rating = "GOOD"
    if ($score -lt 70) { $rating = "FAIR" }
    if ($score -lt 45) { $rating = "POOR" }

    # Breakdown (simple buckets)
    $breakdown = [ordered]@{
        performance = "OK"
        startup     = "OK"
        security    = "OK"
    }

    if ($ram -lt 8 -or $diskPenalty -gt 0) { $breakdown.performance = "Needs attention" }
    if ($startupCount -ge 15) { $breakdown.startup = "Needs attention" }
    if ($Scan.security.defender -or (-not $Scan.security.antivirus_enabled) -or (-not $Scan.security.real_time_protection)) {
        $breakdown.security = "Needs attention"
    }

    [ordered]@{
        score   = $score
        rating  = $rating
        breakdown = $breakdown
        reasons = $reasons
    }
}

Export-ModuleMember -Function Get-KonguardHealthScore
