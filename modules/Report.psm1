function New-KonguardHtmlReport {
    param(
        [Parameter(Mandatory=$true)] $Scan,
        [Parameter(Mandatory=$true)] [string] $OutputPath
    )

    $meta = $Scan.meta
    $hw   = $Scan.hardware
    $sw   = $Scan.software
    $sec  = $Scan.security

    $diskLines = ""
    if ($hw.disks) {
        $diskLines = [string]::Join("`n", ($hw.disks | ForEach-Object { "$($_.model) - $($_.size_gb) GB" }))
    }

    $startupLines = ""
    if ($sw.startup_items) {
        $startupLines = [string]::Join("`n", ($sw.startup_items | Select-Object -First 25 | ForEach-Object { "$($_.Name) :: $($_.Command)" }))
    }

    $securityHtml = ""
    if ($sec.defender) {
        $securityHtml = "<div class='row'><span class='k'>Defender</span> $($sec.defender)</div>"
    } else {
        $securityHtml = @"
<div class='row'><span class='k'>Antivirus Enabled</span> <b>$($sec.antivirus_enabled)</b></div>
<div class='row'><span class='k'>Real-Time Protection</span> <b>$($sec.real_time_protection)</b></div>
<div class='row'><span class='k'>Last Quick Scan</span> $($sec.last_quick_scan_end_time)</div>
"@
    }

    # Health score section (safe)
    $healthBlock = ""
    if ($Scan.health) {
        $reasonsText = ""
        if ($Scan.health.reasons) {
            $reasonsText = [string]::Join("`n", $Scan.health.reasons)
        }

        $healthBlock = @"
  <div class="card">
    <h2>📊 System Health Score</h2>
    <div class="row"><span class="k">Score</span> <b>$($Scan.health.score) / 100</b> ($($Scan.health.rating))</div>
    <div class="row"><span class="k">Performance</span> $($Scan.health.breakdown.performance)</div>
    <div class="row"><span class="k">Startup Load</span> $($Scan.health.breakdown.startup)</div>
    <div class="row"><span class="k">Security</span> $($Scan.health.breakdown.security)</div>
    <div class="row"><span class="k">Why this score?</span></div>
    <pre>$reasonsText</pre>
  </div>
"@
    }

    $html = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>KONGUARD Report - $($meta.machine)</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
    .banner { padding: 12px 14px; border: 1px solid #ccc; border-radius: 10px; margin: 14px 0 18px 0; }
    .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; margin: 14px 0; }
    .title { font-size: 22px; font-weight: 700; margin: 0 0 6px 0; }
    .muted { color: #555; }
    .row { margin: 6px 0; }
    .k { font-weight: 600; display: inline-block; min-width: 180px; }
    pre { background: #f6f6f6; padding: 10px; border-radius: 10px; overflow-x: auto; }
  </style>
</head>
<body>
  <div class="title">🦍 KONGUARD Report</div>
  <div class="muted">Machine: <b>$($meta.machine)</b> · Timestamp: <b>$($meta.timestamp)</b> · Version: <b>$($meta.version)</b></div>

  <div class="banner">
    <b>Transparency:</b> This scan runs locally. No data leaves your computer. (Read-only)
  </div>

$healthBlock

  <div class="card">
    <h2>✅ Hardware</h2>
    <div class="row"><span class="k">CPU</span> $($hw.cpu.Name)</div>
    <div class="row"><span class="k">Cores / Threads</span> $($hw.cpu.NumberOfCores) / $($hw.cpu.NumberOfLogicalProcessors)</div>
    <div class="row"><span class="k">RAM</span> $($hw.ram_gb) GB</div>
    <div class="row"><span class="k">Disks</span></div>
    <pre>$diskLines</pre>
  </div>

  <div class="card">
    <h2>⚠️ Startup Items</h2>
    <div class="muted">If you see unknown entries you didn’t install, they may slow boot or indicate unwanted software.</div>
    <pre>$startupLines</pre>
    <div class="muted">Showing first 25 entries.</div>
  </div>

  <div class="card">
    <h2>🛡️ Security</h2>
    $securityHtml
  </div>

</body>
</html>
"@

    $html | Out-File -Encoding UTF8 $OutputPath
}

function New-KonguardComparisonReport {
    param(
        [Parameter(Mandatory=$true)] $Diff,
        [Parameter(Mandatory=$true)] [string] $OutputPath
    )

    $ramMsg = "No change"
    if ($Diff.ram_change_gb -gt 0) { $ramMsg = "Upgraded (+$($Diff.ram_change_gb) GB)" }
    elseif ($Diff.ram_change_gb -lt 0) { $ramMsg = "Reduced ($($Diff.ram_change_gb) GB)" }

    $html = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>KONGUARD Comparison Report</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
    .banner { padding: 12px 14px; border: 1px solid #ccc; border-radius: 10px; margin: 14px 0 18px 0; }
    .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; margin: 14px 0; }
    .title { font-size: 22px; font-weight: 700; margin: 0 0 6px 0; }
    .row { margin: 8px 0; }
    .k { font-weight: 600; display: inline-block; min-width: 240px; }
  </style>
</head>
<body>
  <div class="title">🦍 KONGUARD Comparison Report</div>

  <div class="banner">
    <b>Transparency:</b> This comparison is local-only. No data leaves your computer. (Read-only)
  </div>

  <div class="card">
    <h2>Changes Summary</h2>
    <div class="row"><span class="k">RAM</span> $ramMsg</div>
    <div class="row"><span class="k">RAM (before)</span> $($Diff.ram_before_gb) GB</div>
    <div class="row"><span class="k">RAM (after)</span>  $($Diff.ram_after_gb) GB</div>

    <div class="row"><span class="k">Startup items (before)</span> $($Diff.startup_count_before)</div>
    <div class="row"><span class="k">Startup items (after)</span>  $($Diff.startup_count_after)</div>

    <div class="row"><span class="k">Antivirus enabled (before)</span> $($Diff.antivirus_before)</div>
    <div class="row"><span class="k">Antivirus enabled (after)</span>  $($Diff.antivirus_after)</div>

    <div class="row"><span class="k">Real-time protection (before)</span> $($Diff.rtp_before)</div>
    <div class="row"><span class="k">Real-time protection (after)</span>  $($Diff.rtp_after)</div>
  </div>
</body>
</html>
"@

    $html | Out-File -Encoding UTF8 $OutputPath
}

Export-ModuleMember -Function New-KonguardHtmlReport, New-KonguardComparisonReport
