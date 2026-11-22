<#
.SYNOPSIS
    Nilly QuickTools — Windows Startup Manager (Lightweight Autoruns / Task Manager Startup Replacement!)
    Lists HKCU\Run, HKLM\Run, HKLM\WOW6432Node\Run & Startup folder items with exact Windows StartupApproved status,
    live RAM usage if running, and safe 1-click Enable / Disable (100% reversible — never deletes apps!).

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:SMState = @{
    Initialized = $false
    Ui          = $null
    Items       = @()
}

function Get-StartupApprovedState {
    param([string]$RegPath, [string]$Name)
    try {
        $props = Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue
        if ($props -and $null -ne $props.$Name) {
            $bytes = [byte[]]$props.$Name
            if ($bytes.Length -ge 1) {
                # 2 or 6 = Enabled in Windows StartupApproved; 3 or 1 or odd = Disabled
                return (($bytes[0] % 2) -eq 0)
            }
        }
    } catch {}
    return $true
}

function Get-RunningRamForCmd([string]$Cmd) {
    if ([string]::IsNullOrWhiteSpace($Cmd)) { return "—" }
    $exe = ""
    if ($Cmd -match '^\s*"([^"]+)"') { $exe = $Matches[1] }
    elseif ($Cmd -match '^\s*([^\s]+)') { $exe = $Matches[1] }
    if (-not $exe) { return "—" }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    if (-not $base -or $base -in @('wscript','cscript','cmd','powershell','explorer')) { return "—" }
    $ps = @(Get-Process -Name $base -ErrorAction SilentlyContinue)
    if ($ps.Count -eq 0) { return "0 MB" }
    $mb = [math]::Round((($ps | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
    return "$mb MB"
}

function Refresh-StartupManager {
    $ui = $script:SMState.Ui
    $list = [System.Collections.Generic.List[object]]::new()

    $sources = @(
        @{ Label="User (HKCU)";      Run="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run";            App="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";   NeedsAdmin=$false },
        @{ Label="System (HKLM)";    Run="HKLM:\Software\Microsoft\Windows\CurrentVersion\Run";            App="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";   NeedsAdmin=$true  },
        @{ Label="System32 (HKLM32)";Run="HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; App="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"; NeedsAdmin=$true  }
    )

    foreach ($src in $sources) {
        if (-not (Test-Path $src.Run)) { continue }
        $props = Get-ItemProperty -Path $src.Run -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($p in ($props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
            $enabled = Get-StartupApprovedState -RegPath $src.App -Name $p.Name
            $cmd = "$($p.Value)"
            [void]$list.Add([PSCustomObject]@{
                Name        = $p.Name
                Status      = if ($enabled) { "Ενεργό" } else { "Απενεργοποιημένο" }
                Enabled     = $enabled
                Location    = $src.Label
                LiveRam     = Get-RunningRamForCmd $cmd
                Command     = $cmd
                ApprovedKey = $src.App
                NeedsAdmin  = $src.NeedsAdmin
                Kind        = "Reg"
                FilePath    = ""
            })
        }
    }

    # User Startup Folder (enabled .lnk/.vbs/.bat AND our safe disabled subfolder if any)
    $stDir = [Environment]::GetFolderPath('Startup')
    $stApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
    if (Test-Path $stDir) {
        Get-ChildItem -Path $stDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $enabled = Get-StartupApprovedState -RegPath $stApp -Name $_.Name
            $target = $_.FullName
            if ($_.Extension -ieq '.lnk') {
                try {
                    $sh = New-Object -ComObject WScript.Shell
                    $target = $sh.CreateShortcut($_.FullName).TargetPath
                } catch {}
            }
            [void]$list.Add([PSCustomObject]@{
                Name        = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                RawName     = $_.Name
                Status      = if ($enabled) { "Ενεργό" } else { "Απενεργοποιημένο" }
                Enabled     = $enabled
                Location    = "Startup Folder"
                LiveRam     = Get-RunningRamForCmd $target
                Command     = $target
                ApprovedKey = $stApp
                NeedsAdmin  = $false
                Kind        = "Folder"
                FilePath    = $_.FullName
            })
        }
    }

    $sorted = @($list | Sort-Object @{Expression='Enabled';Descending=$true}, Name)
    $script:SMState.Items = $sorted
    $ui.ListSMItems.ItemsSource = $sorted
    $enCnt = @($sorted | Where-Object { $_.Enabled }).Count
    $ui.TxtSMStatus.Text = "Εντοπίστηκαν $($sorted.Count) προγράμματα εκκίνησης ($enCnt ενεργά). Επίλεξε ένα και πάτα 'Εναλλαγή On / Off' (100% αναστρέψιμο)."
}

function Toggle-SelectedStartupItem {
    $ui = $script:SMState.Ui
    $sel = $ui.ListSMItems.SelectedItem
    if (-not $sel) {
        $ui.TxtSMStatus.Text = "Επίλεξε πρώτα ένα πρόγραμμα από τη λίστα."
        return
    }
    $valName = if ($sel.Kind -eq 'Folder') { $sel.RawName } else { $sel.Name }
    $newEnabled = -not $sel.Enabled
    $firstByte = if ($newEnabled) { 2 } else { 3 }
    $bytes = [byte[]]@($firstByte,0,0,0,0,0,0,0,0,0,0,0)

    if (-not $sel.NeedsAdmin) {
        try {
            if (-not (Test-Path $sel.ApprovedKey)) { New-Item -Path $sel.ApprovedKey -Force | Out-Null }
            Set-ItemProperty -Path $sel.ApprovedKey -Name $valName -Value $bytes -Type Binary -ErrorAction Stop
            $stTxt = if ($newEnabled) { "ΕΝΕΡΓΟΠΟΙΗΘΗΚΕ" } else { "ΑΠΕΝΕΡΓΟΠΟΙΗΘΗΚΕ" }
            $ui.TxtSMStatus.Text = "[OK] Το '$($sel.Name)' $stTxt στο Startup! (Ισχύει από το επόμενο restart — 100% αναστρέψιμο)."
            Refresh-StartupManager
        } catch {
            $ui.TxtSMStatus.Text = "Σφάλμα ενημέρωσης Startup: $($_.Exception.Message)"
        }
    } else {
        # HKLM requires standard UAC elevation
        $regNative = $sel.ApprovedKey -replace '^HKLM:\\','HKLM:\'
        $bStr = ($bytes -join ',')
        $cmd = "if (-not (Test-Path '$regNative')) { New-Item -Path '$regNative' -Force | Out-Null }; Set-ItemProperty -Path '$regNative' -Name '$valName' -Value ([byte[]]@($bStr)) -Type Binary"
        try {
            $p = Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -PassThru -Wait
            Refresh-StartupManager
            $ui.TxtSMStatus.Text = "Ενημερώθηκε η κατάσταση Startup για '$($sel.Name)' (System/HKLM)."
        } catch {
            $ui.TxtSMStatus.Text = "Ακυρώθηκε το UAC για '$($sel.Name)'."
        }
    }
}

function Initialize-StartupManagerTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:SMState.Initialized) { Refresh-StartupManager; return }
    $script:SMState.Initialized = $true
    $script:SMState.Ui          = $UiMap

    $UiMap.BtnSMRefresh.Add_Click({ Refresh-StartupManager })
    $UiMap.BtnSMToggle.Add_Click({ Toggle-SelectedStartupItem })
    $UiMap.BtnSMOpenWin.Add_Click({ Start-Process "ms-settings:startupapps" })

    Refresh-StartupManager
}

Export-ModuleMember -Function Initialize-StartupManagerTool, Refresh-StartupManager
