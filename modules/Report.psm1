# =========================================================
# KONGUARD :: Report Module
# - ASCII-only
# - Auto Light/Dark (prefers-color-scheme)
# - White-label branding via config\branding.json
# - Safe templating (no PowerShell parsing issues)
# =========================================================

Set-StrictMode -Off

function Get-KGBranding {
    param([Parameter(Mandatory=$true)][string] $Root)

    $b = @{
        product_name        = "KONGUARD"
        tagline             = "System Black Box"
        vendor_name         = "KONGUARD Labs"
        website             = ""
        primary             = "#2563eb"
        accent              = "#06b6d4"
        logo_text           = "KONGUARD"
        footer_note         = "Local-only | Read-only | Offline-first | No telemetry"
        report_title_format = "{product_name} Report"
        enable_white_label  = $true
    }

    try {
        $p = Join-Path $Root "config\branding.json"
        if (Test-Path $p) {
            $cfg = (Get-Content $p -Raw) | ConvertFrom-Json
            foreach ($k in $b.Keys) {
                if ($cfg.PSObject.Properties[$k]) { $b[$k] = $cfg.$k }
            }
        }
    } catch {
        # Never fail report generation due to branding issues.
    }

    return $b
}

function Html-Escape {
    param([string]$s)
    if ($null -eq $s) { return "" }
    return [System.Security.SecurityElement]::Escape([string]$s)
}

function Join-Lines {
    param([object]$Items, [int]$Max = 30)

    if ($null -eq $Items) { return "" }

    try {
        $arr = @($Items) | Select-Object -First $Max
        return ($arr -join "`n")
    } catch {
        return ""
    }
}

function New-KonguardHtmlReport {
    param(
        [Parameter(Mandatory=$true)] $Scan,
        [Parameter(Mandatory=$true)] [string] $OutputPath,
        [ValidateSet("user","tech")]
        [string] $Mode = "user"
    )

    # Derive project root from output path: <root>\reports\<file>
    $root = Split-Path -Parent (Split-Path -Parent $OutputPath)
    if (-not $root -or -not (Test-Path $root)) {
        $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $brand  = Get-KGBranding -Root $root

    $meta   = $Scan.meta
    $hw     = $Scan.hardware
    $sw     = $Scan.software
    $sec    = $Scan.security
    $health = $Scan.health

    $product = Html-Escape $brand.product_name
    $tagline = Html-Escape $brand.tagline
    $vendor  = Html-Escape $brand.vendor_name
    $site    = Html-Escape $brand.website
    $primary = Html-Escape $brand.primary
    $accent  = Html-Escape $brand.accent
    $logoTxt = Html-Escape $brand.logo_text
    $footer  = Html-Escape $brand.footer_note

    $machine = Html-Escape $meta.machine
    $ts      = Html-Escape $meta.timestamp
    $ver     = Html-Escape $meta.version

    $title = $brand.report_title_format
    $title = $title -replace "\{product_name\}", $brand.product_name
    $title = Html-Escape $title

    # Hardware values (safe)
    $cpuName = ""
    $cores   = ""
    $threads = ""
    try {
        $cpuName = Html-Escape ("" + $hw.cpu.Name)
        $cores   = Html-Escape ("" + $hw.cpu.NumberOfCores)
        $threads = Html-Escape ("" + $hw.cpu.NumberOfLogicalProcessors)
    } catch { }

    $ramgb = ""
    try { $ramgb = Html-Escape ("" + $hw.ram_gb) } catch { }

    # Disks (ASCII-only formatting)
    $diskLines = ""
    try {
        if ($hw.disks) {
            $diskLines = [string]::Join("`n", ($hw.disks | ForEach-Object {
                $m = Html-Escape ("" + $_.model)
                $s = Html-Escape (("{0} GB" -f $_.size_gb))
                "$m - $s"
            }))
        }
    } catch { $diskLines = "" }

    # Startup items
    $startupLines = ""
    try {
        if ($sw.startup_items) {
            $startupLines = [string]::Join("`n", ($sw.startup_items | Select-Object -First 30 | ForEach-Object {
                $n = Html-Escape ("" + $_.Name)
                $c = Html-Escape ("" + $_.Command)
                "$n :: $c"
            }))
        }
    } catch { $startupLines = "" }

    # Security block: schema-safe
    $securityRows = ""
    try {
        if ($sec.defender) {
            $securityRows = "<div class='row'><div class='k'>Defender</div><div class='v'>" + (Html-Escape ("" + $sec.defender)) + "</div></div>"
        } else {
            $av   = Html-Escape ("" + $sec.antivirus_enabled)
            $rtp  = Html-Escape ("" + $sec.real_time_protection)
            $last = Html-Escape ("" + $sec.last_quick_scan_end_time)

            $securityRows = @"
<div class='row'><div class='k'>Antivirus Enabled</div><div class='v'><span class='pill'>$av</span></div></div>
<div class='row'><div class='k'>Real-time Protection</div><div class='v'><span class='pill'>$rtp</span></div></div>
<div class='row'><div class='k'>Last Quick Scan</div><div class='v'>$last</div></div>
"@
        }
    } catch {
        $securityRows = "<div class='row'><div class='k'>Security</div><div class='v'>Unavailable</div></div>"
    }

    # Health block
    $healthHtml = ""
    if ($health) {
        $score  = Html-Escape ("" + $health.score)
        $rating = Html-Escape ("" + $health.rating)

        $p = ""
        $st = ""
        $se = ""
        try {
            $p  = Html-Escape ("" + $health.breakdown.performance)
            $st = Html-Escape ("" + $health.breakdown.startup)
            $se = Html-Escape ("" + $health.breakdown.security)
        } catch { }

        $reasonsText = ""
        try {
            if ($health.reasons) {
                $reasonsText = [string]::Join("`n", ($health.reasons | ForEach-Object { Html-Escape ("" + $_) }))
            }
        } catch { $reasonsText = "" }

        $healthHtml = @"
<section class="card">
  <div class="card-h">
    <div>
      <div class="h">System Health</div>
      <div class="sub">Explainable score derived from verification signals.</div>
    </div>
    <div class="score">
      <div class="score-num">$score</div>
      <div class="score-den">/ 100</div>
      <div class="score-rating">$rating</div>
    </div>
  </div>

  <div class="grid3">
    <div class="metric">
      <div class="m-k">Performance</div>
      <div class="m-v">$p</div>
    </div>
    <div class="metric">
      <div class="m-k">Startup Load</div>
      <div class="m-v">$st</div>
    </div>
    <div class="metric">
      <div class="m-k">Security</div>
      <div class="m-v">$se</div>
    </div>
  </div>

  <details class="details">
    <summary>Why this score?</summary>
    <pre class="pre">$reasonsText</pre>
  </details>
</section>
"@
    }

    # Tech block
    $techHtml = ""
    if ($Mode -eq "tech") {
        $raw = Html-Escape (($Scan | ConvertTo-Json -Depth 8))
        $techHtml = @"
<section class="card">
  <div class="h">Technician Details</div>
  <div class="sub">Raw snapshot for audits and troubleshooting.</div>
  <pre class="pre">$raw</pre>
</section>
"@
    }

    # HTML template (single-quoted here-string to prevent parsing issues)
    $tpl = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{{TITLE}} - {{MACHINE}}</title>
  <style>
    :root{
      --bg: #ffffff;
      --panel: #f7f7fb;
      --card: #ffffff;
      --text: #0b1220;
      --muted: #4b5563;
      --line: rgba(15, 23, 42, 0.12);
      --shadow: 0 10px 30px rgba(2, 6, 23, 0.08);
      --primary: {{PRIMARY}};
      --accent: {{ACCENT}};
      --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      --sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial, "Noto Sans", "Liberation Sans", sans-serif;
      --radius: 16px;
    }

    @media (prefers-color-scheme: dark){
      :root{
        --bg: #0b1020;
        --panel: #0f1733;
        --card: rgba(255,255,255,0.04);
        --text: rgba(255,255,255,0.92);
        --muted: rgba(255,255,255,0.62);
        --line: rgba(255,255,255,0.12);
        --shadow: 0 18px 44px rgba(0,0,0,0.35);
      }
    }

    *{ box-sizing: border-box; }
    body{
      margin: 0;
      font-family: var(--sans);
      color: var(--text);
      background:
        radial-gradient(1200px 600px at 10% -10%, rgba(37,99,235,0.18), transparent 55%),
        radial-gradient(900px 500px at 110% 0%, rgba(6,182,212,0.16), transparent 60%),
        var(--bg);
    }

    .wrap{
      max-width: 1040px;
      margin: 28px auto;
      padding: 0 18px 40px 18px;
    }

    .topbar{
      display:flex;
      align-items:flex-start;
      justify-content:space-between;
      gap: 16px;
      padding: 18px;
      border: 1px solid var(--line);
      background: linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0.18));
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      backdrop-filter: blur(10px);
    }

    @media (prefers-color-scheme: dark){
      .topbar{
        background: linear-gradient(180deg, rgba(255,255,255,0.08), rgba(255,255,255,0.04));
      }
    }

    .brand{
      display:flex;
      align-items:center;
      gap: 14px;
    }

    .mark{
      width: 44px;
      height: 44px;
      border-radius: 14px;
      border: 1px solid var(--line);
      background:
        radial-gradient(18px 18px at 30% 30%, rgba(255,255,255,0.35), transparent 55%),
        linear-gradient(135deg, var(--primary), var(--accent));
      box-shadow: 0 16px 30px rgba(37,99,235,0.18);
    }

    .brand h1{
      margin: 0;
      font-size: 18px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .brand .tag{
      margin-top: 4px;
      font-size: 12px;
      color: var(--muted);
      letter-spacing: 0.02em;
    }

    .meta{
      text-align:right;
      font-family: var(--mono);
      color: var(--muted);
      font-size: 12px;
      line-height: 1.55;
      white-space: nowrap;
    }

    .pill{
      display:inline-block;
      padding: 2px 10px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: rgba(0,0,0,0.02);
      font-family: var(--mono);
      font-size: 12px;
    }
    @media (prefers-color-scheme: dark){
      .pill{ background: rgba(255,255,255,0.04); }
    }

    .banner{
      margin-top: 16px;
      padding: 12px 14px;
      border-radius: var(--radius);
      border: 1px solid var(--line);
      background: var(--panel);
      color: var(--muted);
      font-size: 13px;
    }
    .banner b{ color: var(--text); }

    .grid{
      display:grid;
      grid-template-columns: 1.25fr 0.75fr;
      gap: 16px;
      margin-top: 16px;
    }
    @media (max-width: 900px){
      .grid{ grid-template-columns: 1fr; }
      .meta{ text-align:left; white-space: normal; }
    }

    .card{
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: var(--card);
      box-shadow: var(--shadow);
      padding: 16px;
    }

    .h{
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 0.02em;
      margin: 0 0 6px 0;
    }

    .sub{
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }

    .row{
      display:flex;
      gap: 14px;
      padding: 8px 0;
      border-bottom: 1px dashed var(--line);
      align-items:flex-start;
    }
    .row:last-child{ border-bottom: none; }

    .k{
      width: 190px;
      color: var(--muted);
      font-family: var(--mono);
      font-size: 12px;
      letter-spacing: 0.02em;
      text-transform: uppercase;
    }
    .v{
      flex: 1;
      font-size: 14px;
      line-height: 1.45;
      word-break: break-word;
    }

    .pre{
      margin: 10px 0 0 0;
      padding: 12px;
      border-radius: 14px;
      border: 1px solid var(--line);
      background: var(--panel);
      font-family: var(--mono);
      font-size: 12px;
      line-height: 1.55;
      overflow-x: auto;
      white-space: pre-wrap;
    }

    .card-h{
      display:flex;
      justify-content:space-between;
      align-items:flex-start;
      gap: 16px;
      margin-bottom: 10px;
    }

    .score{
      display:flex;
      flex-direction:column;
      align-items:flex-end;
      gap: 2px;
      font-family: var(--mono);
    }
    .score-num{
      font-size: 28px;
      font-weight: 800;
      letter-spacing: 0.02em;
    }
    .score-den{
      color: var(--muted);
      font-size: 12px;
      margin-top: -4px;
    }
    .score-rating{
      font-size: 12px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }

    .grid3{
      display:grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-top: 12px;
    }
    @media (max-width: 900px){
      .grid3{ grid-template-columns: 1fr; }
      .score{ align-items:flex-start; }
    }

    .metric{
      border: 1px solid var(--line);
      border-radius: 14px;
      background: var(--panel);
      padding: 12px;
    }
    .m-k{
      font-family: var(--mono);
      text-transform: uppercase;
      font-size: 12px;
      color: var(--muted);
      letter-spacing: 0.06em;
    }
    .m-v{
      margin-top: 6px;
      font-size: 15px;
      font-weight: 700;
    }

    details.details{
      margin-top: 12px;
      border: 1px solid var(--line);
      border-radius: 14px;
      background: var(--panel);
      padding: 10px 12px;
    }
    details.details summary{
      cursor: pointer;
      font-weight: 650;
      outline: none;
    }

    .footer{
      margin-top: 18px;
      color: var(--muted);
      font-family: var(--mono);
      font-size: 12px;
      display:flex;
      justify-content:space-between;
      gap: 10px;
      flex-wrap: wrap;
    }
    .footer a{ color: var(--muted); text-decoration: none; border-bottom: 1px dotted var(--line); }
  </style>
</head>

<body>
  <div class="wrap">
    <div class="topbar">
      <div class="brand">
        <div class="mark" aria-hidden="true"></div>
        <div>
          <h1>{{LOGO_TEXT}}</h1>
          <div class="tag">{{TAGLINE}}</div>
        </div>
      </div>

      <div class="meta">
        <div><span class="pill">{{MACHINE}}</span></div>
        <div>Timestamp: {{TIMESTAMP}}</div>
        <div>Version: {{VERSION}}</div>
        <div>Mode: {{MODE}}</div>
      </div>
    </div>

    <div class="banner">
      <b>Transparency</b>: This report was generated locally on the scanned machine. No data was transmitted or uploaded.
      The scan is read-only and designed for verification and auditability.
    </div>

    {{HEALTH_BLOCK}}

    <div class="grid">
      <section class="card">
        <div class="h">Hardware</div>
        <div class="sub">Core system identification for verification and audit trails.</div>

        <div class="row"><div class="k">CPU</div><div class="v">{{CPU}}</div></div>
        <div class="row"><div class="k">Cores / Threads</div><div class="v">{{CORES}} / {{THREADS}}</div></div>
        <div class="row"><div class="k">Memory</div><div class="v">{{RAM}} GB</div></div>
        <div class="row"><div class="k">Disks</div><div class="v"><pre class="pre">{{DISKS}}</pre></div></div>
      </section>

      <section class="card">
        <div class="h">Security</div>
        <div class="sub">High-level posture signals. Details remain local-only.</div>
        {{SECURITY_BLOCK}}
      </section>
    </div>

    <section class="card" style="margin-top:16px;">
      <div class="h">Startup Items</div>
      <div class="sub">Unknown entries you did not install may indicate unwanted persistence.</div>
      <pre class="pre">{{STARTUP}}</pre>
      <div class="sub" style="margin-top:8px;">Showing first 30 entries.</div>
    </section>

    {{TECH_BLOCK}}

    <div class="footer">
      <div>{{PRODUCT}} | {{VENDOR}}</div>
      <div>{{FOOTER_NOTE}}</div>
      <div>{{WEBSITE}}</div>
    </div>
  </div>
</body>
</html>
'@

    # Token replace
    $out = $tpl
    $out = $out.Replace("{{TITLE}}", $title)
    $out = $out.Replace("{{MACHINE}}", $machine)
    $out = $out.Replace("{{TIMESTAMP}}", $ts)
    $out = $out.Replace("{{VERSION}}", $ver)
    $out = $out.Replace("{{MODE}}", (Html-Escape $Mode))

    $out = $out.Replace("{{PRIMARY}}", $primary)
    $out = $out.Replace("{{ACCENT}}", $accent)

    $out = $out.Replace("{{PRODUCT}}", $product)
    $out = $out.Replace("{{TAGLINE}}", $tagline)
    $out = $out.Replace("{{VENDOR}}", $vendor)
    $out = $out.Replace("{{WEBSITE}}", $site)
    $out = $out.Replace("{{LOGO_TEXT}}", $logoTxt)
    $out = $out.Replace("{{FOOTER_NOTE}}", $footer)

    $out = $out.Replace("{{CPU}}", $cpuName)
    $out = $out.Replace("{{CORES}}", $cores)
    $out = $out.Replace("{{THREADS}}", $threads)
    $out = $out.Replace("{{RAM}}", $ramgb)
    $out = $out.Replace("{{DISKS}}", $diskLines)
    $out = $out.Replace("{{STARTUP}}", $startupLines)

    $out = $out.Replace("{{SECURITY_BLOCK}}", $securityRows)
    $out = $out.Replace("{{HEALTH_BLOCK}}", $healthHtml)
    $out = $out.Replace("{{TECH_BLOCK}}", $techHtml)

    $out | Out-File -Encoding UTF8 $OutputPath
}

function New-KonguardComparisonReport {
    param(
        [Parameter(Mandatory=$true)] $Diff,
        [Parameter(Mandatory=$true)] [string] $OutputPath
    )

    $ramMsg = "No change"
    if ($Diff.ram_change_gb -gt 0) { $ramMsg = "Upgraded (+" + $Diff.ram_change_gb + " GB)" }
    elseif ($Diff.ram_change_gb -lt 0) { $ramMsg = "Reduced (" + $Diff.ram_change_gb + " GB)" }

    $tpl = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Comparison Report</title>
  <style>
    :root{
      --bg:#ffffff; --card:#ffffff; --text:#0b1220; --muted:#4b5563;
      --line:rgba(15,23,42,0.12); --shadow:0 10px 30px rgba(2,6,23,0.08);
      --radius:16px; --sans:ui-sans-serif,system-ui,Segoe UI,Roboto,Arial;
      --mono:ui-monospace,Consolas,Menlo,Monaco,"Courier New",monospace;
    }
    @media (prefers-color-scheme: dark){
      :root{ --bg:#0b1020; --card:rgba(255,255,255,0.04); --text:rgba(255,255,255,0.92);
             --muted:rgba(255,255,255,0.62); --line:rgba(255,255,255,0.12);
             --shadow:0 18px 44px rgba(0,0,0,0.35); }
    }
    body{ margin:0; background:var(--bg); color:var(--text); font-family:var(--sans); }
    .wrap{ max-width:900px; margin:28px auto; padding:0 18px 40px 18px; }
    .card{ border:1px solid var(--line); border-radius:var(--radius); background:var(--card);
           box-shadow:var(--shadow); padding:16px; }
    .h{ font-size:16px; font-weight:800; margin:0 0 8px 0; }
    .sub{ color:var(--muted); font-size:13px; }
    .row{ display:flex; gap:14px; padding:8px 0; border-bottom:1px dashed var(--line); }
    .row:last-child{ border-bottom:none; }
    .k{ width:260px; color:var(--muted); font-family:var(--mono); font-size:12px; text-transform:uppercase; }
    .v{ flex:1; font-size:14px; }
    .banner{ margin:14px 0; padding:12px 14px; border:1px solid var(--line); border-radius:var(--radius);
             background:rgba(0,0,0,0.02); color:var(--muted); }
    @media (prefers-color-scheme: dark){ .banner{ background:rgba(255,255,255,0.04); } }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="h">Comparison Report</div>
      <div class="sub">Before/after signals based on baseline snapshots. Local-only. Read-only.</div>
      <div class="banner"><b>Transparency</b>: This comparison is generated locally. No data uploaded.</div>

      <div class="row"><div class="k">RAM</div><div class="v">{{RAMMSG}}</div></div>
      <div class="row"><div class="k">RAM (before)</div><div class="v">{{RAMB}} GB</div></div>
      <div class="row"><div class="k">RAM (after)</div><div class="v">{{RAMA}} GB</div></div>

      <div class="row"><div class="k">Startup items (before)</div><div class="v">{{SB}}</div></div>
      <div class="row"><div class="k">Startup items (after)</div><div class="v">{{SA}}</div></div>

      <div class="row"><div class="k">Antivirus enabled (before)</div><div class="v">{{AVB}}</div></div>
      <div class="row"><div class="k">Antivirus enabled (after)</div><div class="v">{{AVA}}</div></div>

      <div class="row"><div class="k">Real-time protection (before)</div><div class="v">{{RTPB}}</div></div>
      <div class="row"><div class="k">Real-time protection (after)</div><div class="v">{{RTPA}}</div></div>
    </div>
  </div>
</body>
</html>
'@

    $out = $tpl
    $out = $out.Replace("{{RAMMSG}}", (Html-Escape $ramMsg))
    $out = $out.Replace("{{RAMB}}", (Html-Escape ("" + $Diff.ram_before_gb)))
    $out = $out.Replace("{{RAMA}}", (Html-Escape ("" + $Diff.ram_after_gb)))
    $out = $out.Replace("{{SB}}",   (Html-Escape ("" + $Diff.startup_count_before)))
    $out = $out.Replace("{{SA}}",   (Html-Escape ("" + $Diff.startup_count_after)))
    $out = $out.Replace("{{AVB}}",  (Html-Escape ("" + $Diff.antivirus_before)))
    $out = $out.Replace("{{AVA}}",  (Html-Escape ("" + $Diff.antivirus_after)))
    $out = $out.Replace("{{RTPB}}", (Html-Escape ("" + $Diff.rtp_before)))
    $out = $out.Replace("{{RTPA}}", (Html-Escape ("" + $Diff.rtp_after)))

    $out | Out-File -Encoding UTF8 $OutputPath
}

Export-ModuleMember -Function New-KonguardHtmlReport, New-KonguardComparisonReport
