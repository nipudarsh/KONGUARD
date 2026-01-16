function Get-KonguardSoftware {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User

    [ordered]@{
        startup_items = $startup
        note = "Installed apps inventory will be added in a later phase (to avoid slow/unstable registry queries in v0.1)."
    }
}

Export-ModuleMember -Function Get-KonguardSoftware
