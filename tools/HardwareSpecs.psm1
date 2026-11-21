<#
.SYNOPSIS
    Nilly QuickTools — Hardware & System Specs (Lightweight CPU-Z + GPU-Z Replacement!)
    Live CPU, Motherboard, BIOS, RAM Sticks (MHz/Slots), GPU/Driver, Monitors, SSD Health & IP
    Lazy-loaded PowerShell Module (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$script:HWState = @{
    Initialized = $false
    Ui          = $null
    ReportText  = ""
}

function Refresh-HardwareSpecs {
    $ui = $script:HWState.Ui
    $ui.TxtHWStatus.Text = "Ανάγνωση υλικού (CPU, RAM, GPU, SSD)..."

    $rows = [System.Collections.Generic.List[object]]::new()
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("=== Nilly PC Manager & Tools — Hardware Report ===")
    [void]$sb.AppendLine("created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/")
    [void]$sb.AppendLine("")

    $addRow = {
        param([string]$Cat, [string]$Item, [string]$Val)
        [void]$rows.Add([PSCustomObject]@{ Category=$Cat; Item=$Item; Value=$Val })
        [void]$sb.AppendLine(("{0,-14} | {1,-22} : {2}" -f $Cat, $Item, $Val))
    }

    # CPU
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cpu) {
        & $addRow "CPU" "Επεξεργαστής" ($cpu.Name.Trim())
        & $addRow "CPU" "Πυρήνες / Threads" "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads @ $($cpu.MaxClockSpeed) MHz"
        & $addRow "CPU" "Socket / L3 Cache" "$($cpu.SocketDesignation)  •  $([math]::Round($cpu.L3CacheSize/1024, 1)) MB L3"
    }

    # Motherboard & BIOS
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios  = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($board) { & $addRow "Motherboard" "Μητρική" "$($board.Manufacturer) $($board.Product)" }
    if ($bios)  { & $addRow "BIOS" "Έκδοση" "$($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate.ToString('yyyy-MM-dd')))" }

    # RAM Modules (Slot by slot!)
    $sticks = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $totRamGB = [math]::Round((($sticks | Measure-Object Capacity -Sum).Sum / 1GB), 1)
    & $addRow "RAM" "Σύνολο Μνήμης" "$totRamGB GB ($($sticks.Count) modules)"
    foreach ($st in $sticks) {
        $gb = [math]::Round($st.Capacity / 1GB, 0)
        $spd = if ($st.ConfiguredClockSpeed) { "$($st.ConfiguredClockSpeed) MHz" } elseif ($st.Speed) { "$($st.Speed) MHz" } else { "-" }
        $mfg = if ($st.Manufacturer) { $st.Manufacturer.Trim() } else { "RAM" }
        & $addRow "RAM Slot" "$($st.DeviceLocator)" "$gb GB  •  $spd  •  $mfg ($($st.PartNumber.Trim()))"
    }

    # GPU
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    foreach ($g in $gpus) {
        $vramGB = if ($g.AdapterRAM -gt 0) { "$([math]::Round($g.AdapterRAM / 1GB, 1)) GB" } else { "Shared/High VRAM" }
        # Read 64-bit VRAM from registry if > 4GB (Win32_VideoController caps at 4GB uint32!)
        try {
            $regGpu = Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -ErrorAction SilentlyContinue |
                Where-Object { $_.DriverDesc -eq $g.Name } | Select-Object -First 1
            if ($regGpu -and $regGpu.'HardwareInformation.qwMemorySize') {
                $vramGB = "$([math]::Round($regGpu.'HardwareInformation.qwMemorySize' / 1GB, 0)) GB VRAM"
            }
        } catch {}
        & $addRow "GPU" "$($g.Name)" "$vramGB  •  Driver $($g.DriverVersion)"
    }

    # Monitors
    $idx = 1
    foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
        $pri = if ($scr.Primary) { " (Κύρια)" } else { "" }
        & $addRow "Οθόνη" "Display $idx$pri" "$($scr.Bounds.Width) × $($scr.Bounds.Height) px"
        $idx++
    }

    # Physical Disks & SMART Health
    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    if ($disks.Count -gt 0) {
        foreach ($d in $disks) {
            $gb = [math]::Round($d.Size / 1GB, 0)
            & $addRow "Δίσκος" "$($d.FriendlyName)" "$gb GB  •  $($d.MediaType) ($($d.BusType))  •  Health: $($d.HealthStatus)"
        }
    } else {
        Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | ForEach-Object {
            & $addRow "Δίσκος" "$($_.Model)" "$([math]::Round($_.Size/1GB, 0)) GB  •  Status: $($_.Status)"
        }
    }

    # OS & Local IP
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) { & $addRow "Windows" "Λειτουργικό" "$($os.Caption) (Build $($os.BuildNumber))" }
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -ExpandProperty IPAddress)
    if ($ips.Count -gt 0) { & $addRow "Δίκτυο" "Local IPv4" ($ips -join ", ") }

    $ui.ListHWSpecs.ItemsSource = $rows
    $script:HWState.ReportText = $sb.ToString()
    $ui.TxtHWStatus.Text = "Εντοπίστηκαν $($rows.Count) στοιχεία υλικού — έτοιμο για αντιγραφή (αντικαθιστά CPU-Z & GPU-Z)!"
}

function Initialize-HardwareSpecsTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:HWState.Initialized) { Refresh-HardwareSpecs; return }
    $script:HWState.Initialized = $true
    $script:HWState.Ui          = $UiMap

    $UiMap.BtnHWRefresh.Add_Click({ Refresh-HardwareSpecs })
    $UiMap.BtnHWCopy.Add_Click({
        if ($script:HWState.ReportText) {
            try {
                [System.Windows.Clipboard]::SetDataObject($script:HWState.ReportText, $true)
                $script:HWState.Ui.TxtHWStatus.Text = "Η πλήρης αναφορά υλικού αντιγράφηκε στο Clipboard!"
            } catch {}
        }
    })

    Refresh-HardwareSpecs
}

Export-ModuleMember -Function Initialize-HardwareSpecsTool, Refresh-HardwareSpecs
