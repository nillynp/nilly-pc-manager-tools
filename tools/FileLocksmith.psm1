<#
.SYNOPSIS
    Nilly QuickTools — Tool #5: File Locksmith (Windows Restart Manager API)
    Finds which process is locking any file and safely unlocks it (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

if (-not ([System.Management.Automation.PSTypeName]'NillyLocksmithApi').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class NillyLocksmithApi {
    private const int CCH_RM_MAX_APP_NAME = 255;
    private const int CCH_RM_MAX_SVC_NAME = 63;

    [StructLayout(LayoutKind.Sequential)]
    struct RM_UNIQUE_PROCESS {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)]
        public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)]
        public string strServiceShortName;
        public int ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bRestartable;
    }

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames,
        uint nApplications, [In] RM_UNIQUE_PROCESS[] rgApplications, uint nServices, string[] rgsServiceNames);

    [DllImport("rstrtmgr.dll")]
    static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
        [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

    [DllImport("rstrtmgr.dll")]
    static extern int RmEndSession(uint pSessionHandle);

    public class LockInfo {
        public int PID;
        public string ProcessName;
        public string AppName;
    }

    public static List<LockInfo> WhoIsLocking(string filePath) {
        var result = new List<LockInfo>();
        uint handle;
        string key = Guid.NewGuid().ToString();
        if (RmStartSession(out handle, 0, key) != 0) return result;
        try {
            string[] resources = new string[] { filePath };
            if (RmRegisterResources(handle, (uint)resources.Length, resources, 0, null, 0, null) != 0) return result;
            uint needed = 0, count = 0, reasons = 0;
            int res = RmGetList(handle, out needed, ref count, null, ref reasons);
            if (res == 234 && needed > 0) { // ERROR_MORE_DATA
                var infos = new RM_PROCESS_INFO[needed];
                count = needed;
                if (RmGetList(handle, out needed, ref count, infos, ref reasons) == 0) {
                    for (int i = 0; i < count; i++) {
                        int pid = infos[i].Process.dwProcessId;
                        string pname = "";
                        try { pname = Process.GetProcessById(pid).ProcessName; } catch { pname = infos[i].strAppName; }
                        result.Add(new LockInfo { PID = pid, ProcessName = pname, AppName = infos[i].strAppName });
                    }
                }
            }
        } finally {
            RmEndSession(handle);
        }
        return result;
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:FLState = @{
    Initialized = $false
    Ui          = $null
    CurrentFile = $null
}

$script:FLProtected = @('System','Idle','csrss','wininit','services','lsass','winlogon','svchost','dwm','MsMpEng','Docker Desktop')

function Scan-LockedFile {
    param([string]$FilePath)
    $ui = $script:FLState.Ui
    if (-not $FilePath -or -not (Test-Path $FilePath -PathType Leaf)) {
        $ui.TxtFLStatus.Text = "Επίλεξε ή ρίξε ένα έγκυρο αρχείο (όχι φάκελο)."
        return
    }
    $script:FLState.CurrentFile = $FilePath
    $ui.TxtFLPath.Text = $FilePath
    $locks = [NillyLocksmithApi]::WhoIsLocking($FilePath)
    $rows = @()
    foreach ($l in $locks) {
        $rows += [PSCustomObject]@{
            PID         = $l.PID
            ProcessName = $l.ProcessName
            AppName     = $l.AppName
            Protected   = if ($script:FLProtected -contains $l.ProcessName) { "Σύστημα" } else { "Εφαρμογή" }
        }
    }
    $ui.ListFLLocks.ItemsSource = $rows
    if ($rows.Count -eq 0) {
        $ui.TxtFLStatus.Text = "Κανένα πρόγραμμα δεν κλειδώνει αυτό το αρχείο αυτή τη στιγμή!"
    } else {
        $ui.TxtFLStatus.Text = "Βρέθηκαν $($rows.Count) διεργασίες που κρατάνε ανοιχτό το αρχείο."
    }
}

function Initialize-FileLocksmithTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:FLState.Initialized) { return }
    $script:FLState.Initialized = $true
    $script:FLState.Ui          = $UiMap

    $dropHandler = {
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $arr = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            if ($arr.Length -gt 0) { Scan-LockedFile -FilePath $arr[0] }
        }
    }
    $UiMap.ZoneFLDrop.Add_Drop($dropHandler)
    $UiMap.ListFLLocks.Add_Drop($dropHandler)

    $UiMap.BtnFLBrowse.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) { Scan-LockedFile -FilePath $dlg.FileName }
    })

    $UiMap.BtnFLScan.Add_Click({
        Scan-LockedFile -FilePath $script:FLState.Ui.TxtFLPath.Text.Trim()
    })

    $UiMap.BtnFLKill.Add_Click({
        $sel = $script:FLState.Ui.ListFLLocks.SelectedItem
        if (-not $sel) { $script:FLState.Ui.TxtFLStatus.Text = "Επίλεξε πρώτα μια διεργασία από τη λίστα."; return }
        if ($script:FLProtected -contains $sel.ProcessName) {
            $script:FLState.Ui.TxtFLStatus.Text = "Η διεργασία '$($sel.ProcessName)' είναι κρίσιμη για το σύστημα και προστατεύεται."
            return
        }
        try {
            Stop-Process -Id $sel.PID -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 300
            Scan-LockedFile -FilePath $script:FLState.CurrentFile
            $script:FLState.Ui.TxtFLStatus.Text = "Τερματίστηκε το $($sel.ProcessName) (PID $($sel.PID)) — το αρχείο ξεκλειδώθηκε!"
        } catch {
            $script:FLState.Ui.TxtFLStatus.Text = "Δεν μπόρεσε να τερματιστεί: $($_.Exception.Message)"
        }
    })
}

Export-ModuleMember -Function Initialize-FileLocksmithTool, Scan-LockedFile
