<#
.SYNOPSIS
    Nilly QuickTools — Tool #6: Always On Top (Win32 Window Pin / Unpin)
    Pin any open window above all others with 1 click (0 MB background RAM)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

if (-not ([System.Management.Automation.PSTypeName]'NillyTopMostApi').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class NillyTopMostApi {
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TOPMOST = 0x00000008;
    private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    private static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_SHOWWINDOW = 0x0040;

    public class WinItem {
        public long Handle;
        public string Title;
        public string Process;
        public bool IsPinned;
        public string Status { get { return IsPinned ? "PINNED" : "Κανονικό"; } }
    }

    public static List<WinItem> ListWindows(long excludeHandle) {
        var list = new List<WinItem>();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd) || hWnd.ToInt64() == excludeHandle) return true;
            int len = GetWindowTextLength(hWnd);
            if (len <= 0) return true;
            var sb = new StringBuilder(len + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            string title = sb.ToString().Trim();
            if (string.IsNullOrEmpty(title) || title == "Program Manager" || title == "Windows Input Experience") return true;
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            string proc = "";
            try { proc = Process.GetProcessById((int)pid).ProcessName; } catch {}
            bool pinned = (GetWindowLong(hWnd, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
            list.Add(new WinItem { Handle = hWnd.ToInt64(), Title = title, Process = proc, IsPinned = pinned });
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static bool SetPinned(long handle, bool pin) {
        return SetWindowPos(new IntPtr(handle), pin ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:AOTState = @{
    Initialized = $false
    MainWindow  = $null
    Ui          = $null
}

function Refresh-AlwaysOnTopList {
    $ui = $script:AOTState.Ui
    $myHwnd = 0
    try { $myHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($script:AOTState.MainWindow)).Handle.ToInt64() } catch {}
    $wins = [NillyTopMostApi]::ListWindows($myHwnd)
    $ui.ListAOTWindows.ItemsSource = @($wins | Sort-Object -Property @{Expression="IsPinned";Descending=$true}, Title)
    $pinnedCnt = @($wins | Where-Object { $_.IsPinned }).Count
    $ui.TxtAOTStatus.Text = "Βρέθηκαν $($wins.Count) ανοιχτά παράθυρα ($pinnedCnt καρφιτσωμένα). Διπλό κλικ ή κουμπί για Pin/Unpin."
}

function Toggle-SelectedTopMost {
    $sel = $script:AOTState.Ui.ListAOTWindows.SelectedItem
    if (-not $sel) { $script:AOTState.Ui.TxtAOTStatus.Text = "Επίλεξε πρώτα ένα παράθυρο από τη λίστα."; return }
    $newPin = -not $sel.IsPinned
    [void][NillyTopMostApi]::SetPinned($sel.Handle, $newPin)
    Refresh-AlwaysOnTopList
    $script:AOTState.Ui.TxtAOTStatus.Text = if ($newPin) { "Καρφιτσώθηκε πάνω από όλα: $($sel.Title)" } else { "Ξεκαρφιτσώθηκε: $($sel.Title)" }
}

function Initialize-AlwaysOnTopTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:AOTState.Initialized) { Refresh-AlwaysOnTopList; return }
    $script:AOTState.Initialized = $true
    $script:AOTState.MainWindow  = $MainWindow
    $script:AOTState.Ui          = $UiMap

    $UiMap.BtnAOTRefresh.Add_Click({ Refresh-AlwaysOnTopList })
    $UiMap.BtnAOTToggle.Add_Click({ Toggle-SelectedTopMost })
    $UiMap.ListAOTWindows.Add_MouseDoubleClick({ Toggle-SelectedTopMost })

    $UiMap.BtnAOTUnpinAll.Add_Click({
        $items = @($script:AOTState.Ui.ListAOTWindows.ItemsSource)
        $cnt = 0
        foreach ($w in $items) {
            if ($w.IsPinned) { [void][NillyTopMostApi]::SetPinned($w.Handle, $false); $cnt++ }
        }
        Refresh-AlwaysOnTopList
        $script:AOTState.Ui.TxtAOTStatus.Text = "Ξεκαρφιτσώθηκαν όλα ($cnt παράθυρα)."
    })

    Refresh-AlwaysOnTopList
}

Export-ModuleMember -Function Initialize-AlwaysOnTopTool, Refresh-AlwaysOnTopList
