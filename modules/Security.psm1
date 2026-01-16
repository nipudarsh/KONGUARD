function Get-KonguardSecurity {
    $def = Get-MpComputerStatus -ErrorAction SilentlyContinue

    if ($null -eq $def) {
        return [ordered]@{
            defender = "Unavailable (Windows Defender not present or insufficient permission)"
        }
    }

    [ordered]@{
        antivirus_enabled         = $def.AntivirusEnabled
        real_time_protection      = $def.RealTimeProtectionEnabled
        behavior_monitor_enabled  = $def.BehaviorMonitorEnabled
        last_quick_scan_end_time  = $def.QuickScanEndTime
        last_full_scan_end_time   = $def.FullScanEndTime
    }
}

Export-ModuleMember -Function Get-KonguardSecurity
