function Get-KonguardSoftware {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User

    [ordered]@{
        startup_items = $startup
        note = "Installed apps inventory will be added later for stability and speed."
    }
}

Export-ModuleMember -Function Get-KonguardSoftware
