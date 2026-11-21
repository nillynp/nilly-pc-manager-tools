<#
.SYNOPSIS
    Nilly QuickTools — My Hub (Clean RAM Purge + Firefox Cache Clean & Restart + Backups + G-Phonor)
    Replaces Clean_RAM.bat, RUN_Clean_Firefox_Cache.bat, and unifies Backup & G-Phonor controls!
    100% portable: gracefully adapts on any Windows 10/11 PC (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:HubState = @{
    Initialized = $false
    MainWindow  = $null
    Ui          = $null
}

function Get-GPhonorProc {
    return @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*g_phonor.py*' })
}

function Refresh-MyHubPage {
    $ui = $script:HubState.Ui

    # 1. RAM live status
    $mem = [NillyNative]::GetMemory()
    $availGB = [math]::Round($mem.ullAvailPhys / 1GB, 2)
    $totGB   = [math]::Round($mem.ullTotalPhys / 1GB, 1)
    $ui.TxtHubRamInfo.Text = "Ελεύθερη RAM τώρα: $availGB GB από $totGB GB ($($mem.dwMemoryLoad)% σε χρήση)"

    # 2. Firefox cache live size
    $ffRoot = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    [long]$ffBytes = 0
    if (Test-Path $ffRoot) {
        Get-ChildItem $ffRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($sub in @("cache2","startupCache")) {
                $p = Join-Path $_.FullName $sub
                if (Test-Path $p) { $ffBytes += [NillyNative]::GetDirSize($p) }
            }
        }
    }
    $ffMB = [math]::Round($ffBytes / 1MB, 1)
    $ffRunning = @(Get-Process -Name "firefox" -ErrorAction SilentlyContinue).Count
    $ui.TxtHubFFInfo.Text = "Firefox Cache (cache2 + startupCache): $ffMB MB  •  " + $(if ($ffRunning -gt 0) { "Ανοιχτό ($ffRunning διεργασίες — τα tabs επανέρχονται αυτόματα)" } else { "Κλειστό" })

    # 3. Backup status (portable detection)
    $bkZip = "H:\Backup_NillyGraphics.zip"
    $bkBat = "H:\NillyGraphics_Backup_Now.bat"
    $bkPs1 = Join-Path $env:USERPROFILE "Scripts\Wednesday_H_Backup.ps1"
    $usbProc = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*usb_watcher_backup.ps1*' })
    $usbTxt = if ($usbProc.Count -gt 0) { "USB Watcher: ΕΝΕΡΓΟ" } else { "USB Watcher: Ανενεργό" }

    if ((Test-Path $bkBat) -or (Test-Path $bkPs1)) {
        if ($ui.CardHubBackup) { $ui.CardHubBackup.Visibility = 'Visible' }
        $ui.BtnHubRunBackup.IsEnabled = $true
        if (Test-Path $bkZip) {
            $fi = Get-Item $bkZip
            $szGB = [math]::Round($fi.Length / 1GB, 2)
            $ui.TxtHubBackupInfo.Text = "Τελευταίο Backup: $($fi.LastWriteTime.ToString('dd/MM/yyyy HH:mm')) ($szGB GB στο H:)  •  $usbTxt"
        } else {
            $ui.TxtHubBackupInfo.Text = "Έτοιμο για Backup (H:\NillyGraphics_Backup_Now.bat)  •  $usbTxt"
        }
    } else {
        if ($ui.CardHubBackup) { $ui.CardHubBackup.Visibility = 'Collapsed' }
        $ui.BtnHubRunBackup.IsEnabled = $false
        $ui.TxtHubBackupInfo.Text = ""
    }

    # 4. G-Phonor status (portable detection — auto-hides on PCs without G-Phonor!)
    $gpDir = Join-Path $env:USERPROFILE "Documents\G-Phonor"
    $gpPy  = Join-Path $gpDir "g_phonor.py"
    $gpVbs = Join-Path $gpDir "run_silent.vbs"
    if (Test-Path $gpPy) {
        if ($ui.CardHubGPhonor) { $ui.CardHubGPhonor.Visibility = 'Visible' }
        $ui.BtnHubToggleGPhonor.IsEnabled = $true
        $gpProcs = Get-GPhonorProc
        if ($gpProcs.Count -gt 0) {
            $ram = [math]::Round((($gpProcs | Measure-Object WorkingSetSize -Sum).Sum / 1MB), 1)
            $ui.TxtHubGPhonorInfo.Text = "Κατάσταση: ΕΝΕΡΓΟ ($ram MB RAM)"
            $ui.BtnHubToggleGPhonor.Content = "Τερματισμός G-Phonor"
        } else {
            $ui.TxtHubGPhonorInfo.Text = "Κατάσταση: ΚΛΕΙΣΤΟ (0 MB RAM)"
            $ui.BtnHubToggleGPhonor.Content = "Εκκίνηση G-Phonor"
        }
    } else {
        if ($ui.CardHubGPhonor) { $ui.CardHubGPhonor.Visibility = 'Collapsed' }
        $ui.BtnHubToggleGPhonor.IsEnabled = $false
        $ui.TxtHubGPhonorInfo.Text = ""
    }
}

function Initialize-MyHubTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:HubState.Initialized) { Refresh-MyHubPage; return }
    $script:HubState.Initialized = $true
    $script:HubState.MainWindow  = $MainWindow
    $script:HubState.Ui          = $UiMap

    $UiMap.BtnHubRefresh.Add_Click({ Refresh-MyHubPage })

    # 1. Clean RAM Now (exact Clean_RAM.bat working-set purge, safer & built-in!)
    $UiMap.BtnHubCleanRam.Add_Click({
        $ui = $script:HubState.Ui
        $ui.BtnHubCleanRam.IsEnabled = $false
        $ui.TxtHubStatus.Text = "Εκτέλεση αστραπιαίου καθαρισμού RAM (Working Set Purge)..."
        $script:HubState.MainWindow.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)

        $before = [NillyNative]::GetMemory().ullAvailPhys
        Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
            try { if ($_.Handle) { [void][NillyNative]::EmptyWorkingSet($_.Handle) } } catch {}
        }
        Start-Sleep -Milliseconds 350
        $after = [NillyNative]::GetMemory().ullAvailPhys
        $freedMB = [math]::Max(0, [math]::Round(($after - $before) / 1MB, 1))
        $totalFreeGB = [math]::Round($after / 1GB, 2)

        Refresh-MyHubPage
        $ui.TxtHubStatus.Text = "[OK] Ελευθερώθηκαν ~$freedMB MB RAM! Συνολική ελεύθερη RAM τώρα: $totalFreeGB GB."
        $ui.BtnHubCleanRam.IsEnabled = $true
    })

    # 2. Clean Firefox Cache & Restart (exact Clean_Firefox_Cache.ps1 behavior!)
    $UiMap.BtnHubCleanFF.Add_Click({
        $ui = $script:HubState.Ui
        $ui.BtnHubCleanFF.IsEnabled = $false
        $ui.TxtHubStatus.Text = "Κλείσιμο Firefox (τα tabs θα επανέλθουν αυτόματα) & καθαρισμός cache2 + startupCache..."
        $script:HubState.MainWindow.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)

        $wasRunning = $false
        $ff = Get-Process -Name "firefox" -ErrorAction SilentlyContinue
        if ($ff) {
            $wasRunning = $true
            $ff | ForEach-Object { try { [void]$_.CloseMainWindow() } catch {} }
            Start-Sleep -Seconds 3
            $still = Get-Process -Name "firefox" -ErrorAction SilentlyContinue
            if ($still) {
                $still | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
        }

        $beforeFree = ([System.IO.DriveInfo]::new("C")).AvailableFreeSpace
        $ffLocal = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path $ffLocal) {
            Get-ChildItem $ffLocal -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                foreach ($sub in @("cache2","startupCache")) {
                    $p = Join-Path $_.FullName $sub
                    if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        $freedMB = [math]::Max(0, [math]::Round((([System.IO.DriveInfo]::new("C")).AvailableFreeSpace - $beforeFree) / 1MB, 1))

        $ffExe = "C:\Program Files\Mozilla Firefox\firefox.exe"
        if ($wasRunning -and (Test-Path $ffExe)) {
            Start-Process -FilePath $ffExe
            Start-Sleep -Milliseconds 600
        }

        Refresh-MyHubPage
        $ui.TxtHubStatus.Text = "[OK] Καθαρίστηκε το Firefox Cache (~$freedMB MB ελεύθερα — cookies, κωδικοί & tabs ανέπαφα!)."
        $ui.BtnHubCleanFF.IsEnabled = $true
    })

    # 3. Run Backup Now (launches existing script without modifying it!)
    $UiMap.BtnHubRunBackup.Add_Click({
        $bkBat = "H:\NillyGraphics_Backup_Now.bat"
        $bkPs1 = Join-Path $env:USERPROFILE "Scripts\Wednesday_H_Backup.ps1"
        if (Test-Path $bkBat) {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$bkBat`"" -WorkingDirectory "H:\"
            $script:HubState.Ui.TxtHubStatus.Text = "Ξεκίνησε το NillyGraphics Master ZIP Backup (H:) σε νέο παράθυρο."
        } elseif (Test-Path $bkPs1) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$bkPs1`" -ShowProgress"
            $script:HubState.Ui.TxtHubStatus.Text = "Ξεκίνησε το Backup script σε νέο παράθυρο."
        }
    })

    # 4. Toggle G-Phonor Start / Stop
    $UiMap.BtnHubToggleGPhonor.Add_Click({
        $gpProcs = Get-GPhonorProc
        if ($gpProcs.Count -gt 0) {
            foreach ($p in $gpProcs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Milliseconds 400
            $script:HubState.Ui.TxtHubStatus.Text = "Τερματίστηκε το G-Phonor (0 MB RAM)."
        } else {
            $gpDir = Join-Path $env:USERPROFILE "Documents\G-Phonor"
            $gpVbs = Join-Path $gpDir "run_silent.vbs"
            if (Test-Path $gpVbs) {
                Start-Process -FilePath "wscript.exe" -ArgumentList "`"$gpVbs`"" -WorkingDirectory $gpDir
                Start-Sleep -Milliseconds 900
                $script:HubState.Ui.TxtHubStatus.Text = "Ξεκίνησε το G-Phonor στο παρασκήνιο (έτοιμο με G5 / F13)!"
            }
        }
        Refresh-MyHubPage
    })

    Refresh-MyHubPage
}

Export-ModuleMember -Function Initialize-MyHubTool, Refresh-MyHubPage
