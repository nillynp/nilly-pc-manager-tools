<#
.SYNOPSIS
    Nilly QuickTools — Keyboard Chatter Blocker Pro (Ultra-Light Native Win32 Daemon Manager)
    Replaces heavy 47 MB KeyboardChatterBlocker with a ~32 KB pure Win32 daemon (~0.3-2 MB RAM!)
    Full live settings editor, per-key ms overrides, live blocked chatter log & Startup toggle.

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

    # Stop running daemon before overwriting exe
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

    # Sensible defaults (used on fresh PCs without an existing config)
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
    $ui = $script:CBState.Ui
    $proc = Get-Process -Name 'NillyChatterBlocker' -ErrorAction SilentlyContinue | Select-Object -First 1
    $script:CBState.BlockedMap = @{}
    $logRows = @()

    if ($proc) {
        $wsMB   = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        $privMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
        $blockedTotal = 0
        $liveEnabled = $script:CBState.IsEnabled

        if (Send-ChatterIpc 0x8002) {
            Start-Sleep -Milliseconds 180
            if (Test-Path $script:CBState.StatsPath) {
                foreach ($line in (Get-Content $script:CBState.StatsPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                    if ($line -match '^enabled=(.+)$') { $liveEnabled = ($Matches[1] -ieq 'true') }
                    elseif ($line -match '^blocked_total=(\d+)$') { $blockedTotal = [int]$Matches[1] }
                    elseif ($line -match '^stat\.([^=]+)=(\d+)$') { $script:CBState.BlockedMap[$Matches[1]] = [int]$Matches[2] }
                    elseif ($line -match '^evt=([^|]+)\|([^|]+)\|([^|]+)\|(.+)$') {
                        $logRows += [PSCustomObject]@{
                            Time     = $Matches[1]
                            Key      = $Matches[2]
                            BounceMs = "$($Matches[3]) ms"
                            LimitMs  = "$($Matches[4]) ms"
                        }
                    }
                }
            }
        }
        $script:CBState.IsEnabled = $liveEnabled
        $stWord = if ($liveEnabled) { "ΕΝΕΡΓΟ" } else { "ΣΕ ΠΑΥΣΗ" }
        $ui.TxtCBStatusBadge.Text = "$stWord  •  RAM: $wsMB MB WS ($privMB MB Priv)  •  Μπλοκαρίστηκαν: $blockedTotal διπλοπατήματα"
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
    $ui.ListCBLog.ItemsSource = $logRows
}

function Invoke-ChatterAddOrUpdateKey {
    $ui = $script:CBState.Ui
    $kName = $ui.CmbCBNewKey.Text.Trim()
    $msVal = 0
    if (-not $kName -or -not [int]::TryParse($ui.TxtCBNewKeyMs.Text.Trim(), [ref]$msVal) -or $msVal -lt 0 -or $msVal -gt 2000) {
        $ui.TxtCBFooterStatus.Text = "Δώσε έγκυρο πλήκτρο (π.χ. E, I, M, Back, Space) & όριο 0–2000 ms."
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
    if (-not $sel) { $ui.TxtCBFooterStatus.Text = "Επίλεξε πρώτα ένα πλήκτρο από τη λίστα."; return }
    for ($i = $script:CBState.PerKeys.Count - 1; $i -ge 0; $i--) {
        if ($script:CBState.PerKeys[$i].Key -ieq $sel.Key) { $script:CBState.PerKeys.RemoveAt($i) }
    }
    Save-ChatterConfigFromUi
    $reloaded = Send-ChatterIpc 0x8001
    Bind-ChatterKeyGrid
    $ui.TxtCBFooterStatus.Text = "Αφαιρέθηκε η ρύθμιση για το πλήκτρο $($sel.Key)" + $(if ($reloaded) { " (ενημερώθηκε live)." } else { "." })
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
            $script:CBState.Ui.TxtCBFooterStatus.Text = "Ξεκίνησε το Nilly Chatter Blocker στο System Tray (~1-2 MB RAM)!"
        }
    }
    Refresh-ChatterLiveStatus
}

function Invoke-ChatterTogglePause {
    if (Send-ChatterIpc 0x8003) {
        Start-Sleep -Milliseconds 200
        Refresh-ChatterLiveStatus
        Save-ChatterConfigFromUi
        $script:CBState.Ui.TxtCBFooterStatus.Text = if ($script:CBState.IsEnabled) { "Το Chatter Blocker ενεργοποιήθηκε!" } else { "Το Chatter Blocker μπήκε σε παύση." }
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
    if ($script:CBState.Initialized) { Refresh-ChatterLiveStatus; return }
    $script:CBState.Initialized = $true
    $script:CBState.Ui          = $UiMap
    $script:CBState.RootDir     = $RootDir
    $script:CBState.ExePath     = Join-Path $RootDir "NillyChatterBlocker.exe"
    $script:CBState.SrcPath     = Join-Path (Join-Path $RootDir "tools") "NillyChatterBlocker.cs"
    $script:CBState.CfgPath     = Join-Path $RootDir "chatter_config.txt"
    $script:CBState.StatsPath   = Join-Path $RootDir "chatter_stats.txt"

    # Populate quick key picker
    $UiMap.CmbCBNewKey.Items.Clear()
    foreach ($kn in @('I','Back','M','E','Space','Return','A','S','D','W','O','N','T','R','VolumeUp','VolumeDown','Delete','Tab','OemPeriod','Oemcomma')) {
        [void]$UiMap.CmbCBNewKey.Items.Add($kn)
    }

    $UiMap.BtnCBToggleRun.Add_Click({ Invoke-ChatterToggleRun })
    $UiMap.BtnCBPause.Add_Click({ Invoke-ChatterTogglePause })
    $UiMap.BtnCBRefresh.Add_Click({ Refresh-ChatterLiveStatus })
    $UiMap.BtnCBSaveApply.Add_Click({ Invoke-ChatterSaveApply })
    $UiMap.BtnCBAddKey.Add_Click({ Invoke-ChatterAddOrUpdateKey })
    $UiMap.BtnCBDelKey.Add_Click({ Invoke-ChatterDeleteKey })
    $UiMap.ChkCBStartup.Add_Checked({ Invoke-ChatterStartupChanged })
    $UiMap.ChkCBStartup.Add_Unchecked({ Invoke-ChatterStartupChanged })

    Load-ChatterConfigToUi
    Refresh-ChatterLiveStatus
}

Export-ModuleMember -Function Initialize-ChatterBlockerTool, Refresh-ChatterLiveStatus, Ensure-ChatterDaemonCompiled, Start-ChatterDaemon, Stop-ChatterDaemon, Set-ChatterStartupShortcut
