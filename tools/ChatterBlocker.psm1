<#
.SYNOPSIS
    Nilly QuickTools — Keyboard Chatter Blocker Pro (Ultra-Light Native Win32 Daemon Manager)
    Replaces heavy 47 MB KeyboardChatterBlocker with a ~33 KB pure Win32 daemon (~0.5-2 MB RAM!)
    Full per-key analytics table (presses, blocked, %, min/max ms, fault indicator),
    live auto-refresh while open, per-key ms overrides, 50-event chatter log & Startup toggle.

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

if (-not ([System.Management.Automation.PSTypeName]'NillyChatterIpc').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class NillyChatterIpc {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindowW(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool PostMessageW(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref bool pvParam, uint fWinIni);

    [DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
    public static extern bool SystemParametersInfoPtr(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

    public static bool GetMouseVanish() {
        bool v = false;
        SystemParametersInfo(0x1020, 0, ref v, 0);
        return v;
    }

    public static void SetMouseVanish(bool hideWhileTyping) {
        SystemParametersInfoPtr(0x1021, 0, hideWhileTyping ? (IntPtr)1 : IntPtr.Zero, 3);
    }
}
"@
}

$script:CBState = @{
    Initialized = $false
    Ui          = $null
    RootDir     = $null
    ExePath     = $null
    SrcPath     = $null
    CfgPath     = $null
    StatsPath   = $null
    StartupLnk  = (Join-Path ([Environment]::GetFolderPath('Startup')) 'NillyChatterBlocker.lnk')
    PerKeys     = [System.Collections.Generic.List[object]]::new()
    BlockedMap  = @{}
    IsEnabled   = $true
    UpdatingUi  = $false
    LiveTimer   = $null
}

function Ensure-ChatterDaemonCompiled {
    param([switch]$ForceRebuild)
    $exe = $script:CBState.ExePath
    $src = $script:CBState.SrcPath
    if (-not (Test-Path $src)) { return $false }

    $needBuild = $ForceRebuild -or (-not (Test-Path $exe))
    if (-not $needBuild) {
        if ((Get-Item $src).LastWriteTimeUtc -gt (Get-Item $exe).LastWriteTimeUtc) {
            $needBuild = $true
        }
    }
    if (-not $needBuild) { return $true }

    $running = @(Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        Stop-ChatterDaemon
        Start-Sleep -Milliseconds 350
    }

    $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) { $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
    if (-not (Test-Path $csc)) { return $false }

    $ico = Join-Path $script:CBState.RootDir "PCManagerLite.ico"
    $args = @('/nologo','/target:winexe','/optimize+','/platform:x64')
    if (Test-Path $ico) { $args += "/win32icon:`"$ico`"" }
    $args += "/out:`"$exe`""
    $args += "`"$src`""

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $csc
    $psi.Arguments = ($args -join ' ')
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit(15000) | Out-Null
    return (Test-Path $exe)
}

function Send-ChatterIpc([uint32]$Msg) {
    $hw = [NillyChatterIpc]::FindWindowW("NillyChatterBlocker_MsgWnd", "NillyChatterBlocker")
    if ($hw -ne [IntPtr]::Zero) {
        [void][NillyChatterIpc]::PostMessageW($hw, $Msg, [IntPtr]::Zero, [IntPtr]::Zero)
        return $true
    }
    return $false
}

function Start-ChatterDaemon {
    if (-not (Ensure-ChatterDaemonCompiled)) {
        $script:CBState.Ui.TxtCBFooterStatus.Text = "Αποτυχία compile του NillyChatterBlocker.exe."
        return $false
    }
    if (-not (Test-Path $script:CBState.CfgPath)) { Save-ChatterConfigFromUi }
    if (-not (Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $script:CBState.ExePath -WorkingDirectory $script:CBState.RootDir
        Start-Sleep -Milliseconds 500
    }
    return $true
}

function Stop-ChatterDaemon {
    if (Send-ChatterIpc 0x8004) {
        Start-Sleep -Milliseconds 350
    }
    Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Set-ChatterStartupShortcut([bool]$Enable) {
    $lnk = $script:CBState.StartupLnk
    if ($Enable) {
        if (-not (Ensure-ChatterDaemonCompiled)) { return }
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($lnk)
        $sc.TargetPath = $script:CBState.ExePath
        $sc.WorkingDirectory = $script:CBState.RootDir
        $ico = Join-Path $script:CBState.RootDir "PCManagerLite.ico"
        if (Test-Path $ico) { $sc.IconLocation = "$ico,0" }
        $sc.Description = "Nilly Keyboard Chatter Blocker (Ultra-Light) - created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/"
        $sc.Save()
    } else {
        if (Test-Path $lnk) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
    }
}

function Load-ChatterConfigToUi {
    $ui = $script:CBState.Ui
    $script:CBState.UpdatingUi = $true
    $script:CBState.PerKeys.Clear()

    $script:CBState.IsEnabled = $true
    $ui.TxtCBGlobalMs.Text = "50"
    $ui.TxtCBMinMs.Text    = "0"
    $ui.CmbCBMeasure.SelectedIndex = 0
    $ui.ChkCBFullscreen.IsChecked  = $true
    $ui.ChkCBOtherResets.IsChecked = $false
    $ui.ChkCBExcludeInj.IsChecked  = $false
    $ui.TxtCBAutoProgs.Text = ""

    if (Test-Path $script:CBState.CfgPath) {
        $lines = Get-Content -Path $script:CBState.CfgPath -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($raw in $lines) {
            $line = $raw.Trim()
            if (-not $line -or $line.StartsWith('#')) { continue }
            $idx = $line.IndexOf(':')
            if ($idx -le 0) { continue }
            $k = $line.Substring(0, $idx).Trim()
            $v = $line.Substring($idx + 1).Trim()
            switch -Regex ($k) {
                '^is_enabled$'                 { $script:CBState.IsEnabled = ($v -ieq 'true') }
                '^global_chatter$'             { $ui.TxtCBGlobalMs.Text = $v }
                '^minimum_chatter_time$'       { $ui.TxtCBMinMs.Text = $v }
                '^measure_from$'               { $ui.CmbCBMeasure.SelectedIndex = if ($v -ieq 'Release') { 1 } else { 0 } }
                '^auto_disable_on_fullscreen$' { $ui.ChkCBFullscreen.IsChecked = ($v -ieq 'true') }
                '^other_key_resets_timeout$'   { $ui.ChkCBOtherResets.IsChecked = ($v -ieq 'true') }
                '^exclude_injected$'           { $ui.ChkCBExcludeInj.IsChecked = ($v -ieq 'true') }
                '^auto_disable_programs$'      { $ui.TxtCBAutoProgs.Text = $v }
                '^key\.(.+)$' {
                    $kName = $Matches[1].Trim()
                    $ms = 0
                    if ([int]::TryParse($v, [ref]$ms)) {
                        [void]$script:CBState.PerKeys.Add([PSCustomObject]@{ Key=$kName; ThresholdMs=$ms; BlockedCount=0 })
                    }
                }
            }
        }
    }

    $ui.ChkCBStartup.IsChecked = (Test-Path $script:CBState.StartupLnk)
    $ui.ChkCBStableCursor.IsChecked = (-not [NillyChatterIpc]::GetMouseVanish())
    $script:CBState.UpdatingUi = $false
    Bind-ChatterKeyGrid
}

function Bind-ChatterKeyGrid {
    $rows = @()
    foreach ($item in $script:CBState.PerKeys) {
        $cnt = if ($script:CBState.BlockedMap.ContainsKey($item.Key)) { $script:CBState.BlockedMap[$item.Key] } else { 0 }
        $rows += [PSCustomObject]@{ Key=$item.Key; ThresholdMs="$($item.ThresholdMs) ms"; RawMs=$item.ThresholdMs; BlockedCount=$cnt }
    }
    $script:CBState.Ui.ListCBKeys.ItemsSource = $rows
}

function Save-ChatterConfigFromUi {
    $ui = $script:CBState.Ui
    $gMs = 50; [void][int]::TryParse($ui.TxtCBGlobalMs.Text.Trim(), [ref]$gMs)
    $mMs = 0;  [void][int]::TryParse($ui.TxtCBMinMs.Text.Trim(), [ref]$mMs)
    $meas = if ($ui.CmbCBMeasure.SelectedIndex -eq 1) { "Release" } else { "Press" }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Nilly Keyboard Chatter Blocker configuration")
    [void]$sb.AppendLine("# created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("is_enabled: " + $(if ($script:CBState.IsEnabled) { "true" } else { "false" }))
    [void]$sb.AppendLine("global_chatter: $gMs")
    [void]$sb.AppendLine("hide_in_system_tray: true")
    [void]$sb.AppendLine("measure_from: $meas")
    [void]$sb.AppendLine("minimum_chatter_time: $mMs")
    [void]$sb.AppendLine("")
    foreach ($item in $script:CBState.PerKeys) {
        [void]$sb.AppendLine("key.$($item.Key): $($item.ThresholdMs)")
    }
    [void]$sb.AppendLine("auto_disable_programs: $($ui.TxtCBAutoProgs.Text.Trim())")
    [void]$sb.AppendLine("auto_disable_on_fullscreen: " + $(if ($ui.ChkCBFullscreen.IsChecked) { "true" } else { "false" }))
    [void]$sb.AppendLine("other_key_resets_timeout: " + $(if ($ui.ChkCBOtherResets.IsChecked) { "true" } else { "false" }))
    [void]$sb.AppendLine("exclude_injected: " + $(if ($ui.ChkCBExcludeInj.IsChecked) { "true" } else { "false" }))

    [System.IO.File]::WriteAllText($script:CBState.CfgPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
}

function Refresh-ChatterLiveStatus {
    param([switch]$NonBlocking)
    $ui = $script:CBState.Ui
    $proc = Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue | Select-Object -First 1
    $script:CBState.BlockedMap = @{}
    $statRows = [System.Collections.Generic.List[object]]::new()
    $logRows  = [System.Collections.Generic.List[object]]::new()

    if ($proc) {
        $wsMB   = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        $privMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
        $blockedTotal = 0
        $pressTotal = 0
        $liveEnabled = $script:CBState.IsEnabled
        $autoDis = $false

        $ipcOk = Send-ChatterIpc 0x8002
        if ($ipcOk -and -not $NonBlocking) { Start-Sleep -Milliseconds 90 }
        if (Test-Path $script:CBState.StatsPath) {
            foreach ($line in (Get-Content $script:CBState.StatsPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                    if ($line -match '^enabled=(.+)$') { $liveEnabled = ($Matches[1] -ieq 'true') }
                    elseif ($line -match '^auto_disabled=(.+)$') { $autoDis = ($Matches[1] -ieq 'true') }
                    elseif ($line -match '^press_total=(\d+)$') { $pressTotal = [int]$Matches[1] }
                    elseif ($line -match '^blocked_total=(\d+)$') { $blockedTotal = [int]$Matches[1] }
                    elseif ($line -match '^kstat=([^|]+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)$') {
                        $kn   = $Matches[1]
                        $pr   = [int]$Matches[2]
                        $bl   = [int]$Matches[3]
                        $minG = [int]$Matches[4]
                        $maxB = [int]$Matches[5]
                        $lim  = [int]$Matches[6]
                        $script:CBState.BlockedMap[$kn] = $bl
                        $pct  = if ($pr -gt 0) { [math]::Round(($bl / [double]$pr) * 100.0, 1) } else { 0.0 }
                        $timingTxt = if ($bl -gt 0) {
                            "Min $minG ms / Max $maxB ms"
                        } elseif ($minG -gt 0) {
                            "Ταχύτερο: $minG ms"
                        } else {
                            "—"
                        }
                        $statusTxt = if ($bl -gt 0) {
                            "Chatter! ($bl)"
                        } elseif ($minG -gt 0 -and $minG -lt 180) {
                            "Ύποπτο ($minG ms)"
                        } else {
                            "OK"
                        }
                        $sortKey = if ($bl -gt 0) { 2 } elseif ($minG -gt 0 -and $minG -lt 180) { 1 } else { 0 }
                        [void]$statRows.Add([PSCustomObject]@{
                            Key         = $kn
                            Presses     = $pr
                            Blocked     = $bl
                            PctText     = ("{0:N1}%" -f $pct)
                            Timing      = $timingTxt
                            LimitText   = "$lim ms"
                            StatusText  = $statusTxt
                            SortPrio    = $sortKey
                            MinGap      = $minG
                            MaxBlocked  = $maxB
                            RawLimit    = $lim
                        })
                    }
                    elseif ($line -match '^evt=([^|]+)\|([^|]+)\|([^|]+)\|(.+)$') {
                        [void]$logRows.Add([PSCustomObject]@{
                            Time     = $Matches[1]
                            Key      = $Matches[2]
                            BounceMs = "$($Matches[3]) ms"
                            LimitMs  = "$($Matches[4]) ms"
                        })
                    }
            }
        }
        $script:CBState.IsEnabled = $liveEnabled
        $stWord = if (-not $liveEnabled) { "ΣΕ ΠΑΥΣΗ" } elseif ($autoDis) { "AUTO-PAUSED (Fullscreen)" } else { "ΕΝΕΡΓΟ" }
        $totPct = if ($pressTotal -gt 0) { [math]::Round(($blockedTotal / [double]$pressTotal) * 100.0, 1) } else { 0.0 }
        $ui.TxtCBStatusBadge.Text = "$stWord  •  RAM: $wsMB MB WS ($privMB MB Priv)  •  Πατήματα: $pressTotal  •  Μπλοκαρίστηκαν: $blockedTotal ($totPct%)"
        $ui.BtnCBToggleRun.Content = "Τερματισμός"
        $ui.BtnCBPause.IsEnabled = $true
        $ui.BtnCBPause.Content = if ($liveEnabled) { "Παύση (Live)" } else { "Ενεργοποίηση" }
    } else {
        $ui.TxtCBStatusBadge.Text = "ΚΛΕΙΣΤΟ (0 MB RAM) — πάτα 'Εκκίνηση' για μόνιμη προστασία στο Tray"
        $ui.BtnCBToggleRun.Content = "Εκκίνηση"
        $ui.BtnCBPause.IsEnabled = $false
        $ui.BtnCBPause.Content = "Παύση (Live)"
    }

    Bind-ChatterKeyGrid
    $sortedStats = @($statRows | Sort-Object @{Expression='SortPrio';Descending=$true}, @{Expression='Blocked';Descending=$true}, @{Expression='Presses';Descending=$true})
    $ui.ListCBStats.ItemsSource = $sortedStats
    $ui.ListCBLog.ItemsSource   = @($logRows)
}

function Start-NillyChatterTimer {
    if (-not $script:CBState.LiveTimer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds(2000)
        $t.Add_Tick({
            if ($script:CBState.Ui.ChkCBLiveRefresh.IsChecked) {
                Refresh-ChatterLiveStatus -NonBlocking
            }
        })
        $script:CBState.LiveTimer = $t
    }
    if (-not $script:CBState.LiveTimer.IsEnabled) {
        $script:CBState.LiveTimer.Start()
    }
}

function Stop-NillyChatterTimer {
    if ($script:CBState.LiveTimer -and $script:CBState.LiveTimer.IsEnabled) {
        $script:CBState.LiveTimer.Stop()
    }
}

function Invoke-ChatterStableCursorChanged {
    if ($script:CBState.UpdatingUi) { return }
    $stable = [bool]$script:CBState.Ui.ChkCBStableCursor.IsChecked
    [NillyChatterIpc]::SetMouseVanish((-not $stable))
    $script:CBState.Ui.TxtCBFooterStatus.Text = if ($stable) {
        "Σταθερός δείκτης ποντικιού ΕΝΕΡΓΟΣ (το ποντίκι δεν αναβοσβήνει/εξαφανίζεται όταν γράφεις)!"
    } else {
        "Επαναφέρθηκε η προεπιλογή Windows (απόκρυψη δείκτη κατά την πληκτρολόγηση)."
    }
}

function Invoke-ChatterAddOrUpdateKey {
    $ui = $script:CBState.Ui
    $kName = $ui.TxtCBNewKey.Text.Trim()
    $msVal = 0
    if (-not $kName -or -not [int]::TryParse($ui.TxtCBNewKeyMs.Text.Trim(), [ref]$msVal) -or $msVal -lt 0 -or $msVal -gt 2000) {
        $ui.TxtCBFooterStatus.Text = "Δώσε έγκυρο πλήκτρο (π.χ. I, E, M, Back, Space) & όριο 0–2000 ms."
        return
    }
    $existing = $null
    foreach ($it in $script:CBState.PerKeys) {
        if ($it.Key -ieq $kName) { $existing = $it; break }
    }
    if ($existing) {
        $existing.ThresholdMs = $msVal
    } else {
        [void]$script:CBState.PerKeys.Add([PSCustomObject]@{ Key=$kName; ThresholdMs=$msVal; BlockedCount=0 })
    }
    Save-ChatterConfigFromUi
    $reloaded = Send-ChatterIpc 0x8001
    Bind-ChatterKeyGrid
    $ui.TxtCBFooterStatus.Text = "Αποθηκεύτηκε: $kName = $msVal ms" + $(if ($reloaded) { " & εφαρμόστηκε live!" } else { "." })
}

function Invoke-ChatterDeleteKey {
    $ui = $script:CBState.Ui
    $sel = $ui.ListCBKeys.SelectedItem
    if (-not $sel) { $ui.TxtCBFooterStatus.Text = "Επίλεξε πρώτα ένα πλήκτρο από τη λίστα ορίων."; return }
    for ($i = $script:CBState.PerKeys.Count - 1; $i -ge 0; $i--) {
        if ($script:CBState.PerKeys[$i].Key -ieq $sel.Key) { $script:CBState.PerKeys.RemoveAt($i) }
    }
    Save-ChatterConfigFromUi
    $reloaded = Send-ChatterIpc 0x8001
    Bind-ChatterKeyGrid
    $ui.TxtCBFooterStatus.Text = "Αφαιρέθηκε το ειδικό όριο για το πλήκτρο $($sel.Key)" + $(if ($reloaded) { " (ενημερώθηκε live)." } else { "." })
}

function Invoke-ChatterPickStatRow {
    $sel = $script:CBState.Ui.ListCBStats.SelectedItem
    if (-not $sel) { return }
    $script:CBState.Ui.TxtCBNewKey.Text = $sel.Key
    $suggest = if ($sel.MaxBlocked -gt 0) { [math]::Max($sel.RawLimit, $sel.MaxBlocked + 15) } elseif ($sel.MinGap -gt 0 -and $sel.MinGap -lt 180) { $sel.MinGap + 25 } else { [math]::Max(100, $sel.RawLimit) }
    $script:CBState.Ui.TxtCBNewKeyMs.Text = "$suggest"
    $script:CBState.Ui.TxtCBFooterStatus.Text = "Επιλέχθηκε το πλήκτρο $($sel.Key) (προτεινόμενο όριο: $suggest ms) — πάτα '+ Ορισμός' για live εφαρμογή!"
}

function Invoke-ChatterSaveApply {
    Save-ChatterConfigFromUi
    $reloaded = Send-ChatterIpc 0x8001
    if ($reloaded) {
        $script:CBState.Ui.TxtCBFooterStatus.Text = "Αποθηκεύτηκαν όλες οι ρυθμίσεις & εφαρμόστηκαν LIVE (χωρίς επανεκκίνηση)!"
    } else {
        $script:CBState.Ui.TxtCBFooterStatus.Text = "Αποθηκεύτηκαν οι ρυθμίσεις στο chatter_config.txt (πάτα 'Εκκίνηση' για ενεργοποίηση)."
    }
    Refresh-ChatterLiveStatus
}

function Invoke-ChatterToggleRun {
    $proc = Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-ChatterDaemon
        $script:CBState.Ui.TxtCBFooterStatus.Text = "Τερματίστηκε το Nilly Chatter Blocker."
    } else {
        if (Start-ChatterDaemon) {
            $script:CBState.Ui.TxtCBFooterStatus.Text = "Ξεκίνησε το Nilly Chatter Blocker στο System Tray (< 1 MB RAM)!"
        }
    }
    Refresh-ChatterLiveStatus
}

function Invoke-ChatterTogglePause {
    if (Send-ChatterIpc 0x8003) {
        Start-Sleep -Milliseconds 180
        Refresh-ChatterLiveStatus
        Save-ChatterConfigFromUi
        $script:CBState.Ui.TxtCBFooterStatus.Text = if ($script:CBState.IsEnabled) { "Το Chatter Blocker ενεργοποιήθηκε!" } else { "Το Chatter Blocker μπήκε σε παύση." }
    }
}

function Invoke-ChatterResetStats {
    if (Send-ChatterIpc 0x8005) {
        Start-Sleep -Milliseconds 180
        Refresh-ChatterLiveStatus
        $script:CBState.Ui.TxtCBFooterStatus.Text = "Μηδενίστηκαν τα στατιστικά & το log — ξεκίνησε καθαρή καταγραφή!"
    }
}

function Invoke-ChatterStartupChanged {
    if ($script:CBState.UpdatingUi) { return }
    $on = [bool]$script:CBState.Ui.ChkCBStartup.IsChecked
    Set-ChatterStartupShortcut -Enable $on
    $script:CBState.Ui.TxtCBFooterStatus.Text = if ($on) { "Ενεργοποιήθηκε η αυτόματη εκκίνηση με τα Windows (Startup)." } else { "Απενεργοποιήθηκε η αυτόματη εκκίνηση με τα Windows." }
}

function Initialize-ChatterBlockerTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap, [string]$RootDir)
    if ($script:CBState.Initialized) {
        Refresh-ChatterLiveStatus
        Start-NillyChatterTimer
        return
    }
    $script:CBState.Initialized = $true
    $script:CBState.Ui          = $UiMap
    $script:CBState.RootDir     = $RootDir
    $script:CBState.ExePath     = Join-Path $RootDir "NillyChatterBlocker.exe"
    $script:CBState.SrcPath     = Join-Path (Join-Path $RootDir "tools") "NillyChatterBlocker.cs"
    $script:CBState.CfgPath     = Join-Path $RootDir "chatter_config.txt"
    $script:CBState.StatsPath   = Join-Path $RootDir "chatter_stats.txt"

    $UiMap.BtnCBToggleRun.Add_Click({ Invoke-ChatterToggleRun })
    $UiMap.BtnCBPause.Add_Click({ Invoke-ChatterTogglePause })
    $UiMap.BtnCBRefresh.Add_Click({ Refresh-ChatterLiveStatus })
    $UiMap.BtnCBResetStats.Add_Click({ Invoke-ChatterResetStats })
    $UiMap.BtnCBSaveApply.Add_Click({ Invoke-ChatterSaveApply })
    $UiMap.BtnCBAddKey.Add_Click({ Invoke-ChatterAddOrUpdateKey })
    $UiMap.BtnCBDelKey.Add_Click({ Invoke-ChatterDeleteKey })
    $UiMap.ListCBStats.Add_MouseDoubleClick({ Invoke-ChatterPickStatRow })
    $UiMap.ChkCBStartup.Add_Checked({ Invoke-ChatterStartupChanged })
    $UiMap.ChkCBStartup.Add_Unchecked({ Invoke-ChatterStartupChanged })
    $UiMap.ChkCBStableCursor.Add_Checked({ Invoke-ChatterStableCursorChanged })
    $UiMap.ChkCBStableCursor.Add_Unchecked({ Invoke-ChatterStableCursorChanged })

    Load-ChatterConfigToUi
    Refresh-ChatterLiveStatus
    Start-NillyChatterTimer
}

Export-ModuleMember -Function Initialize-ChatterBlockerTool, Refresh-ChatterLiveStatus, Start-NillyChatterTimer, Stop-NillyChatterTimer, Ensure-ChatterDaemonCompiled, Start-ChatterDaemon, Stop-ChatterDaemon, Set-ChatterStartupShortcut
