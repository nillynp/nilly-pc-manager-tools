<#
.SYNOPSIS
    Nilly QuickTools — Hardware & System Specs Pro (Lightweight CPU-Z + GPU-Z + Disk SMART Replacement!)
    Live CPU (Stepping, L2/L3 Cache, Voltage, Load, Virtualization), Motherboard/BIOS,
    RAM SPD (Channels, Slots Used/Total, DDR Gen, MHz, Voltage, Part Number),
    GPU (VRAM, VBIOS, Subvendor, PCIe Device ID, Driver Date, Resolution/Hz),
    Monitors, SSD Health/SMART & Local IP — 0 MB RAM when unused!

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

function Decode-RegUnicodeString($Val) {
    if ($null -eq $Val) { return "" }
    if ($Val -is [byte[]]) {
        return ([System.Text.Encoding]::Unicode.GetString($Val)).Trim([char]0).Trim()
    }
    if ($Val -is [string[]]) { return ($Val -join " ").Trim() }
    return "$Val".Trim()
}

function Get-DdrGenName([int]$SmType) {
    switch ($SmType) {
        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        34 { "DDR5" }
        default { "RAM" }
    }
}

function Get-PciVendorName([string]$SubId) {
    if ([string]::IsNullOrWhiteSpace($SubId) -or $SubId.Length -lt 4) { return "" }
    $vid = $SubId.Substring($SubId.Length - 4).ToUpperInvariant()
    switch ($vid) {
        "1462" { "MSI" }
        "1043" { "ASUS" }
        "1458" { "Gigabyte" }
        "1DA2" { "Sapphire" }
        "1682" { "XFX" }
        "148C" { "PowerColor" }
        "10DE" { "NVIDIA" }
        "1002" { "AMD" }
        "8086" { "Intel" }
        "3842" { "EVGA" }
        "19DA" { "ZOTAC" }
        "1569" { "Palit" }
        "196E" { "PNY" }
        "1028" { "Dell" }
        "103C" { "HP" }
        "17AA" { "Lenovo" }
        default { "" }
    }
}

function Refresh-HardwareSpecs {
    $ui = $script:HWState.Ui
    $ui.TxtHWStatus.Text = "Ανάγνωση υλικού (CPU-Z / GPU-Z / RAM SPD / SSD)..."

    $rows = [System.Collections.Generic.List[object]]::new()
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("=== Nilly PC Manager & Tools — Hardware Report (CPU-Z / GPU-Z) ===")
    [void]$sb.AppendLine("created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/")
    [void]$sb.AppendLine("")

    $addRow = {
        param([string]$Cat, [string]$Item, [string]$Val)
        [void]$rows.Add([PSCustomObject]@{ Category=$Cat; Item=$Item; Value=$Val })
        [void]$sb.AppendLine(("{0,-14} | {1,-24} : {2}" -f $Cat, $Item, $Val))
    }

    # 1. CPU (CPU-Z style)
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cpu) {
        & $addRow "CPU" "Επεξεργαστής" ($cpu.Name.Trim())
        $loadTxt = if ($null -ne $cpu.LoadPercentage) { "  •  Load: $($cpu.LoadPercentage)%" } else { "" }
        & $addRow "CPU" "Πυρήνες / Clock" "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads  •  $($cpu.CurrentClockSpeed) / $($cpu.MaxClockSpeed) MHz$loadTxt"
        $l2 = if ($cpu.L2CacheSize -gt 0) { "$([math]::Round($cpu.L2CacheSize/1024, 1)) MB L2" } else { "-" }
        $l3 = if ($cpu.L3CacheSize -gt 0) { "$([math]::Round($cpu.L3CacheSize/1024, 1)) MB L3" } else { "-" }
        $volt = if ($cpu.CurrentVoltage -gt 0) { "  •  $([math]::Round($cpu.CurrentVoltage / 10.0, 2)) V" } else { "" }
        & $addRow "CPU" "Socket / Cache" "$($cpu.SocketDesignation)  •  $l2  •  $l3$volt"
        $virt = if ($cpu.VirtualizationFirmwareEnabled) { "Virtualization: Ενεργή" } else { "Virtualization: Ανενεργή" }
        & $addRow "CPU" "Stepping / Virt" "$($cpu.Caption)  •  $virt"
    }

    # 2. Motherboard & BIOS (CPU-Z Mainboard tab)
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios  = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($board) { & $addRow "Mainboard" "Μητρική" "$($board.Manufacturer) $($board.Product)" }
    if ($bios)  {
        $bDate = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { "-" }
        & $addRow "BIOS" "Έκδοση / Ημ/νία" "$($bios.SMBIOSBIOSVersion) ($bDate)"
    }

    # 3. RAM Modules & SPD (CPU-Z Memory / SPD tab)
    $memArr = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
    $sticks = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $totRamGB = [math]::Round((($sticks | Measure-Object Capacity -Sum).Sum / 1GB), 1)
    $ddrGen = if ($sticks.Count -gt 0) { Get-DdrGenName ([int]$sticks[0].SMBIOSMemoryType) } else { "RAM" }
    $slotInfo = if ($memArr -and $memArr.MemoryDevices -gt 0) { "$($sticks.Count) / $($memArr.MemoryDevices) slots" } else { "$($sticks.Count) modules" }
    $maxTxt = if ($memArr -and $memArr.MaxCapacityEx -gt 0) { "  •  Max $([math]::Round($memArr.MaxCapacityEx / 1MB, 0)) GB" } else { "" }
    & $addRow "RAM" "Σύνολο ($ddrGen)" "$totRamGB GB ($slotInfo$maxTxt)"
    foreach ($st in $sticks) {
        $gb = [math]::Round($st.Capacity / 1GB, 0)
        $spd = if ($st.ConfiguredClockSpeed) { "$($st.ConfiguredClockSpeed) MHz" } elseif ($st.Speed) { "$($st.Speed) MHz" } else { "-" }
        $vTxt = if ($st.ConfiguredVoltage -gt 0) { "  •  $([math]::Round($st.ConfiguredVoltage / 1000.0, 2)) V" } else { "" }
        $mfg = if ($st.Manufacturer -and $st.Manufacturer.Trim() -notin @('Unknown','Undefined','0000')) { "$($st.Manufacturer.Trim()) " } else { "" }
        $part = if ($st.PartNumber) { $st.PartNumber.Trim() } else { "" }
        $loc = if ($st.BankLabel) { "$($st.BankLabel) / $($st.DeviceLocator)" } else { "$($st.DeviceLocator)" }
        & $addRow "RAM SPD" $loc "$gb GB $(Get-DdrGenName ([int]$st.SMBIOSMemoryType))  •  $spd$vTxt  •  $mfg$part".Trim()
    }

    # 4. GPU (GPU-Z style: 64-bit VRAM, VBIOS, Subvendor, PCIe Device ID, Driver Date, Refresh Rate)
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $regGpus = @(Get-ItemProperty "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -ErrorAction SilentlyContinue)
    foreach ($g in $gpus) {
        $vramGB = if ($g.AdapterRAM -gt 0) { "$([math]::Round($g.AdapterRAM / 1GB, 1)) GB" } else { "Shared/High VRAM" }
        $vbios = ""
        $regGpu = $regGpus | Where-Object { $_.DriverDesc -eq $g.Name } | Select-Object -First 1
        if ($regGpu) {
            if ($regGpu.'HardwareInformation.qwMemorySize') {
                $vramGB = "$([math]::Round($regGpu.'HardwareInformation.qwMemorySize' / 1GB, 0)) GB VRAM"
            }
            $vbios = Decode-RegUnicodeString $regGpu.'HardwareInformation.BiosString'
        }
        $subvendor = ""
        $pciTxt = ""
        if ($g.PNPDeviceID -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})&SUBSYS_([0-9A-F]{8})&REV_([0-9A-F]{2})') {
            $sv = Get-PciVendorName $Matches[3]
            if ($sv) { $subvendor = " ($sv)" }
            $pciTxt = "VEN_$($Matches[1]) • DEV_$($Matches[2]) • SUBSYS_$($Matches[3]) • REV_$($Matches[4])"
        }
        & $addRow "GPU" "$($g.Name)$subvendor" "$vramGB  •  $($g.VideoProcessor)"
        $dDate = if ($g.DriverDate) { " ($($g.DriverDate.ToString('yyyy-MM-dd')))" } else { "" }
        $vbTxt = if ($vbios) { "  •  VBIOS: $vbios" } else { "" }
        & $addRow "GPU Driver" "Driver & VBIOS" "$($g.DriverVersion)$dDate$vbTxt"
        if ($pciTxt) { & $addRow "GPU PCIe" "Device ID" $pciTxt }
        if ($g.CurrentHorizontalResolution -gt 0) {
            & $addRow "GPU Mode" "Ανάλυση / Hz" "$($g.CurrentHorizontalResolution) × $($g.CurrentVerticalResolution) px @ $($g.CurrentRefreshRate) Hz ($($g.CurrentBitsPerPixel)-bit)"
        }
    }

    # 5. Monitors
    $idx = 1
    foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
        $pri = if ($scr.Primary) { " (Κύρια)" } else { "" }
        & $addRow "Οθόνη" "Display $idx$pri" "$($scr.Bounds.Width) × $($scr.Bounds.Height) px"
        $idx++
    }

    # 6. Physical Disks & SMART Health
    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    if ($disks.Count -gt 0) {
        foreach ($d in $disks) {
            $gb = [math]::Round($d.Size / 1GB, 0)
            $extra = ""
            try {
                $rel = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($rel) {
                    if ($rel.Temperature -gt 0) { $extra += "  •  $($rel.Temperature)°C" }
                    if ($null -ne $rel.Wear -and $rel.Wear -ge 0) { $extra += "  •  Wear: $($rel.Wear)%" }
                    if ($rel.PowerOnHours -gt 0) { $extra += "  •  $($rel.PowerOnHours) hrs" }
                }
            } catch {}
            & $addRow "Δίσκος" "$($d.FriendlyName)" "$gb GB  •  $($d.MediaType) ($($d.BusType))  •  Health: $($d.HealthStatus)$extra"
        }
    } else {
        Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | ForEach-Object {
            & $addRow "Δίσκος" "$($_.Model)" "$([math]::Round($_.Size/1GB, 0)) GB  •  Status: $($_.Status)"
        }
    }

    # 7. Laptop Battery Health & Wear % (NillySysInfo — Design vs Full Charge Capacity & Cycles)
    try {
        $bats = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        if ($bats.Count -gt 0) {
            $stat = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
            $full = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
            $cyc  = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue | Select-Object -First 1
            $idxB = 1
            foreach ($b in $bats) {
                $chg = if ($null -ne $b.EstimatedChargeRemaining) { "$($b.EstimatedChargeRemaining)%" } else { "-" }
                $acTxt = switch ([int]$b.BatteryStatus) { 2 { "Φόρτιση / AC" } 1 { "Σε μπαταρία" } 3 { "Πλήρης" } default { "Ενεργή" } }
                $wearTxt = ""
                if ($stat -and $full -and $stat.DesignedCapacity -gt 0 -and $full.FullChargedCapacity -gt 0) {
                    $desWh  = [math]::Round($stat.DesignedCapacity / 1000.0, 1)
                    $fullWh = [math]::Round($full.FullChargedCapacity / 1000.0, 1)
                    $health = [math]::Min(100, [math]::Max(0, [math]::Round(($full.FullChargedCapacity * 100.0) / $stat.DesignedCapacity, 0)))
                    $wear   = [math]::Max(0, 100 - $health)
                    $wearTxt = "  •  Υγεία: $health% (Wear $wear%)  •  $fullWh / $desWh Wh"
                }
                $cycTxt = if ($cyc -and $cyc.CycleCount -gt 0) { "  •  Κύκλοι: $($cyc.CycleCount)" } else { "" }
                & $addRow "Μπαταρία" "Battery $idxB ($acTxt)" "Φόρτιση: $chg$wearTxt$cycTxt"
                $idxB++
            }
        } else {
            & $addRow "Μπαταρία" "Τροφοδοσία" "Desktop / AC Power (χωρίς εσωτερική μπαταρία)"
        }
    } catch { }

    # 8. OS & Local IP
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) { & $addRow "Windows" "Λειτουργικό" "$($os.Caption) (Build $($os.BuildNumber))" }
    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -ExpandProperty IPAddress)
    if ($ips.Count -gt 0) { & $addRow "Δίκτυο" "Local IPv4" ($ips -join ", ") }

    $ui.ListHWSpecs.ItemsSource = $rows
    $script:HWState.ReportText = $sb.ToString()
    $ui.TxtHWStatus.Text = "Εντοπίστηκαν $($rows.Count) στοιχεία υλικού (NillySysInfo · CPU/GPU/RAM/SSD/Battery) — έτοιμο για αντιγραφή!"
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
