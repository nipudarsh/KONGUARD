function Get-KonguardHardware {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors
    $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $ramGB = [math]::Round($ramBytes / 1GB, 2)

    $disks = Get-CimInstance Win32_DiskDrive | ForEach-Object {
        [ordered]@{
            model = $_.Model
            size_gb = [math]::Round($_.Size / 1GB, 2)
            media_type = $_.MediaType
            interface = $_.InterfaceType
        }
    }

    [ordered]@{
        cpu = $cpu
        ram_gb = $ramGB
        disks = $disks
    }
}

Export-ModuleMember -Function Get-KonguardHardware
