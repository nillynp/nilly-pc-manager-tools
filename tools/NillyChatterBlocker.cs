// Nilly Keyboard Chatter Blocker — Ultra-Light Pure Win32 Daemon (0 WinForms, 0 WPF, ~2 MB RAM!)
// created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/
// Compiles natively on any Windows 10/11 PC with built-in .NET 4.8 csc.exe (mscorlib.dll ONLY!)

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace NillyChatterBlocker {
    internal static class Program {
        // =====================================================================
        // Win32 Constants & Custom IPC Messages
        // =====================================================================
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN     = 0x0100;
        private const int WM_KEYUP       = 0x0101;
        private const int WM_SYSKEYDOWN  = 0x0104;
        private const int WM_SYSKEYUP    = 0x0105;
        private const int WM_DESTROY     = 0x0002;
        private const int WM_COMMAND     = 0x0111;
        private const int WM_TIMER       = 0x0113;
        private const int WM_RBUTTONUP   = 0x0205;
        private const int WM_LBUTTONDBLCLK = 0x0203;
        private const uint LLKHF_INJECTED = 0x10;

        private const uint WM_TRAY       = 0x8000;
        private const uint WM_RELOAD_CFG = 0x8001;
        private const uint WM_DUMP_STATS = 0x8002;
        private const uint WM_TOGGLE_EN  = 0x8003;
        private const uint WM_EXIT_APP   = 0x8004;

        private const uint NIM_ADD    = 0x00000000;
        private const uint NIM_MODIFY = 0x00000001;
        private const uint NIM_DELETE = 0x00000002;
        private const uint NIF_MESSAGE = 0x00000001;
        private const uint NIF_ICON    = 0x00000002;
        private const uint NIF_TIP     = 0x00000004;

        private const uint MF_STRING    = 0x00000000;
        private const uint MF_SEPARATOR = 0x00000800;
        private const uint MF_CHECKED   = 0x00000008;
        private const uint MF_GRAYED    = 0x00000001;
        private const uint TPM_RIGHTBUTTON = 0x0002;
        private const uint TPM_RETURNCMD   = 0x0100;

        private const uint IDM_TOGGLE   = 1001;
        private const uint IDM_SETTINGS = 1002;
        private const uint IDM_RELOAD   = 1003;
        private const uint IDM_EXIT     = 1004;

        private const uint IMAGE_ICON       = 1;
        private const uint LR_LOADFROMFILE  = 0x0010;
        private const uint LR_DEFAULTSIZE   = 0x0040;
        private const uint MONITOR_DEFAULTTONEAREST = 2;
        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        // =====================================================================
        // Win32 Structs & Delegates
        // =====================================================================
        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
        private delegate IntPtr WndProcDelegate(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT {
            public uint vkCode;
            public uint scanCode;
            public uint flags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSG {
            public IntPtr hwnd;
            public uint message;
            public IntPtr wParam;
            public IntPtr lParam;
            public uint time;
            public POINT pt;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct WNDCLASSEXW {
            public uint cbSize;
            public uint style;
            public IntPtr lpfnWndProc;
            public int cbClsExtra;
            public int cbWndExtra;
            public IntPtr hInstance;
            public IntPtr hIcon;
            public IntPtr hCursor;
            public IntPtr hbrBackground;
            public string lpszMenuName;
            public string lpszClassName;
            public IntPtr hIconSm;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct NOTIFYICONDATAW {
            public int cbSize;
            public IntPtr hWnd;
            public uint uID;
            public uint uFlags;
            public uint uCallbackMessage;
            public IntPtr hIcon;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szTip;
            public uint dwState;
            public uint dwStateMask;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string szInfo;
            public uint uTimeoutOrVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            public string szInfoTitle;
            public uint dwInfoFlags;
            public Guid guidItem;
            public IntPtr hBalloonIcon;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MONITORINFO {
            public int cbSize;
            public RECT rcMonitor;
            public RECT rcWork;
            public uint dwFlags;
        }

        // =====================================================================
        // Win32 P/Invoke
        // =====================================================================
        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookExW(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr GetModuleHandleW(string lpModuleName);

        [DllImport("kernel32.dll")]
        private static extern bool QueryPerformanceCounter(out long lpPerformanceCount);

        [DllImport("kernel32.dll")]
        private static extern bool QueryPerformanceFrequency(out long lpFrequency);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll")]
        private static extern bool SetProcessWorkingSetSize(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);

        [DllImport("psapi.dll")]
        private static extern bool EmptyWorkingSet(IntPtr hProcess);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern ushort RegisterClassExW(ref WNDCLASSEXW lpwcx);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr CreateWindowExW(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle,
            int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

        [DllImport("user32.dll")]
        private static extern bool DestroyWindow(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr DefWindowProcW(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetMessageW(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

        [DllImport("user32.dll")]
        private static extern bool TranslateMessage(ref MSG lpMsg);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr DispatchMessageW(ref MSG lpMsg);

        [DllImport("user32.dll")]
        private static extern void PostQuitMessage(int nExitCode);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern uint RegisterWindowMessageW(string lpString);

        [DllImport("user32.dll")]
        private static extern UIntPtr SetTimer(IntPtr hWnd, UIntPtr nIDEvent, uint uElapse, IntPtr lpTimerFunc);

        [DllImport("user32.dll")]
        private static extern bool KillTimer(IntPtr hWnd, UIntPtr uIDEvent);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern bool Shell_NotifyIconW(uint dwMessage, ref NOTIFYICONDATAW lpData);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadImageW(IntPtr hInst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        [DllImport("user32.dll")]
        private static extern IntPtr LoadIconW(IntPtr hInstance, IntPtr lpIconName);

        [DllImport("user32.dll")]
        private static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("user32.dll")]
        private static extern IntPtr CreatePopupMenu();

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool AppendMenuW(IntPtr hMenu, uint uFlags, UIntPtr uIDNewItem, string lpNewItem);

        [DllImport("user32.dll")]
        private static extern uint TrackPopupMenu(IntPtr hMenu, uint uFlags, int x, int y, int nReserved, IntPtr hWnd, IntPtr prcRect);

        [DllImport("user32.dll")]
        private static extern bool DestroyMenu(IntPtr hMenu);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

        [DllImport("user32.dll")]
        private static extern bool GetMonitorInfoW(IntPtr hMonitor, ref MONITORINFO lpmi);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassNameW(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool QueryFullProcessImageNameW(IntPtr hProcess, uint dwFlags, StringBuilder lpExeName, ref int lpdwSize);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr hObject);

        // =====================================================================
        // Daemon State (zero allocations on hot keyboard hook path!)
        // =====================================================================
        private static string _baseDir;
        private static string _cfgPath;
        private static string _statsPath;
        private static IntPtr _hWnd;
        private static IntPtr _hHook;
        private static IntPtr _hIcon;
        private static uint _wmTaskbarCreated;
        private static LowLevelKeyboardProc _hookDelegate;
        private static WndProcDelegate _wndProcDelegate;

        private static long _qpcFreq;
        private static bool _isEnabled = true;
        private static double _globalChatterMs = 50.0;
        private static double _minChatterMs = 0.0;
        private static bool _measureFromRelease = false;
        private static bool _autoDisableFullscreen = true;
        private static bool _otherKeyResets = false;
        private static bool _excludeInjected = false;
        private static string[] _autoDisableProgs = new string[0];
        private static readonly double[] _perKeyMs = new double[256];

        private static readonly bool[] _isDown = new bool[256];
        private static readonly bool[] _blockedDown = new bool[256];
        private static readonly long[] _lastTime = new long[256];

        // Lightweight in-memory diagnostics (zero disk writes unless requested!)
        private static long _blockedTotal = 0;
        private static readonly int[] _blockedByVk = new int[256];
        private static readonly string[] _recentEvents = new string[24];
        private static int _recentIdx = 0;
        private static DateTime _startedAt = DateTime.Now;

        // Cached foreground window auto-disable check (0.002 ms hot path!)
        private static IntPtr _lastFgHwnd = IntPtr.Zero;
        private static long _lastFgCheckTicks = 0;
        private static bool _lastFgDisabled = false;
        private static readonly StringBuilder _clsBuf = new StringBuilder(64);
        private static readonly StringBuilder _exeBuf = new StringBuilder(512);

        private static readonly Dictionary<string, int> _nameToVk = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        private static readonly string[] _vkToName = new string[256];

        private static void InitKeyMaps() {
            for (int c = 'A'; c <= 'Z'; c++) RegKey(((char)c).ToString(), c);
            for (int d = 0; d <= 9; d++) {
                RegKey("D" + d, 0x30 + d);
                _nameToVk[d.ToString()] = 0x30 + d;
                RegKey("NumPad" + d, 0x60 + d);
            }
            for (int f = 1; f <= 24; f++) RegKey("F" + f, 0x6F + f);

            RegKey("Back", 0x08); _nameToVk["Backspace"] = 0x08;
            RegKey("Tab", 0x09);
            RegKey("Return", 0x0D); _nameToVk["Enter"] = 0x0D;
            RegKey("Pause", 0x13);
            RegKey("Capital", 0x14); _nameToVk["CapsLock"] = 0x14;
            RegKey("Escape", 0x1B); _nameToVk["Esc"] = 0x1B;
            RegKey("Space", 0x20);
            RegKey("PageUp", 0x21); _nameToVk["Prior"] = 0x21;
            RegKey("PageDown", 0x22); _nameToVk["Next"] = 0x22;
            RegKey("End", 0x23);
            RegKey("Home", 0x24);
            RegKey("Left", 0x25);
            RegKey("Up", 0x26);
            RegKey("Right", 0x27);
            RegKey("Down", 0x28);
            RegKey("PrintScreen", 0x2C); _nameToVk["Snapshot"] = 0x2C;
            RegKey("Insert", 0x2D);
            RegKey("Delete", 0x2E); _nameToVk["Del"] = 0x2E;
            RegKey("LWin", 0x5B);
            RegKey("RWin", 0x5C);
            RegKey("Apps", 0x5D);
            RegKey("Multiply", 0x6A);
            RegKey("Add", 0x6B);
            RegKey("Subtract", 0x6D);
            RegKey("Decimal", 0x6E);
            RegKey("Divide", 0x6F);
            RegKey("NumLock", 0x90);
            RegKey("Scroll", 0x91);
            RegKey("LShiftKey", 0xA0); _nameToVk["LShift"] = 0xA0;
            RegKey("RShiftKey", 0xA1); _nameToVk["RShift"] = 0xA1;
            RegKey("LControlKey", 0xA2); _nameToVk["LCtrl"] = 0xA2;
            RegKey("RControlKey", 0xA3); _nameToVk["RCtrl"] = 0xA3;
            RegKey("LMenu", 0xA4); _nameToVk["LAlt"] = 0xA4;
            RegKey("RMenu", 0xA5); _nameToVk["RAlt"] = 0xA5;
            RegKey("VolumeMute", 0xAD);
            RegKey("VolumeDown", 0xAE);
            RegKey("VolumeUp", 0xAF);
            RegKey("MediaNextTrack", 0xB0);
            RegKey("MediaPreviousTrack", 0xB1);
            RegKey("MediaStop", 0xB2);
            RegKey("MediaPlayPause", 0xB3);
            RegKey("OemSemicolon", 0xBA); _nameToVk["Oem1"] = 0xBA;
            RegKey("Oemplus", 0xBB);
            RegKey("Oemcomma", 0xBC);
            RegKey("OemMinus", 0xBD);
            RegKey("OemPeriod", 0xBE);
            RegKey("OemQuestion", 0xBF); _nameToVk["Oem2"] = 0xBF;
            RegKey("Oemtilde", 0xC0); _nameToVk["Oem3"] = 0xC0;
            RegKey("OemOpenBrackets", 0xDB); _nameToVk["Oem4"] = 0xDB;
            RegKey("OemPipe", 0xDC); _nameToVk["Oem5"] = 0xDC;
            RegKey("OemCloseBrackets", 0xDD); _nameToVk["Oem6"] = 0xDD;
            RegKey("OemQuotes", 0xDE); _nameToVk["Oem7"] = 0xDE;
            RegKey("OemBackslash", 0xE2); _nameToVk["Oem102"] = 0xE2;
        }

        private static void RegKey(string name, int vk) {
            _nameToVk[name] = vk;
            if (vk >= 0 && vk < 256 && _vkToName[vk] == null) _vkToName[vk] = name;
        }

        private static string GetVkName(int vk) {
            if (vk >= 0 && vk < 256 && _vkToName[vk] != null) return _vkToName[vk];
            return "VK_" + vk.ToString("X2");
        }

        private static int ParseKeyName(string name) {
            int vk;
            if (_nameToVk.TryGetValue(name.Trim(), out vk)) return vk;
            if (name.StartsWith("VK_", StringComparison.OrdinalIgnoreCase)) {
                int parsed;
                if (int.TryParse(name.Substring(3), System.Globalization.NumberStyles.HexNumber, null, out parsed) && parsed >= 0 && parsed < 256)
                    return parsed;
            }
            return -1;
        }

        private static void LoadConfig() {
            // Reset defaults
            _isEnabled = true;
            _globalChatterMs = 50.0;
            _minChatterMs = 0.0;
            _measureFromRelease = false;
            _autoDisableFullscreen = true;
            _otherKeyResets = false;
            _excludeInjected = false;
            _autoDisableProgs = new string[0];
            for (int i = 0; i < 256; i++) _perKeyMs[i] = -1.0;

            if (!File.Exists(_cfgPath)) return;
            try {
                string[] lines = File.ReadAllLines(_cfgPath, Encoding.UTF8);
                List<string> progs = new List<string>();
                foreach (string raw in lines) {
                    string line = raw.Trim();
                    if (line.Length == 0 || line.StartsWith("#")) continue;
                    int colon = line.IndexOf(':');
                    if (colon <= 0) continue;
                    string key = line.Substring(0, colon).Trim();
                    string val = line.Substring(colon + 1).Trim();

                    if (key.Equals("is_enabled", StringComparison.OrdinalIgnoreCase)) {
                        _isEnabled = val.Equals("true", StringComparison.OrdinalIgnoreCase);
                    } else if (key.Equals("global_chatter", StringComparison.OrdinalIgnoreCase)) {
                        double d; if (double.TryParse(val, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out d)) _globalChatterMs = d;
                    } else if (key.Equals("minimum_chatter_time", StringComparison.OrdinalIgnoreCase)) {
                        double d; if (double.TryParse(val, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out d)) _minChatterMs = d;
                    } else if (key.Equals("measure_from", StringComparison.OrdinalIgnoreCase)) {
                        _measureFromRelease = val.Equals("Release", StringComparison.OrdinalIgnoreCase);
                    } else if (key.Equals("auto_disable_on_fullscreen", StringComparison.OrdinalIgnoreCase)) {
                        _autoDisableFullscreen = val.Equals("true", StringComparison.OrdinalIgnoreCase);
                    } else if (key.Equals("other_key_resets_timeout", StringComparison.OrdinalIgnoreCase)) {
                        _otherKeyResets = val.Equals("true", StringComparison.OrdinalIgnoreCase);
                    } else if (key.Equals("exclude_injected", StringComparison.OrdinalIgnoreCase)) {
                        _excludeInjected = val.Equals("true", StringComparison.OrdinalIgnoreCase);
                    } else if (key.Equals("auto_disable_programs", StringComparison.OrdinalIgnoreCase)) {
                        if (val.Length > 0) {
                            foreach (string p in val.Split(new char[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)) {
                                string pt = p.Trim().ToLowerInvariant();
                                if (pt.EndsWith(".exe")) pt = pt.Substring(0, pt.Length - 4);
                                if (pt.Length > 0) progs.Add(pt);
                            }
                        }
                    } else if (key.StartsWith("key.", StringComparison.OrdinalIgnoreCase)) {
                        string kName = key.Substring(4).Trim();
                        int vk = ParseKeyName(kName);
                        double d;
                        if (vk >= 0 && vk < 256 && double.TryParse(val, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out d)) {
                            _perKeyMs[vk] = d;
                        }
                    }
                }
                _autoDisableProgs = progs.ToArray();
            } catch {}
            UpdateTrayTip();
        }

        private static bool IsAutoDisabled(long nowTicks) {
            if (!_autoDisableFullscreen && _autoDisableProgs.Length == 0) return false;
            IntPtr fg = GetForegroundWindow();
            if (fg == IntPtr.Zero) return false;

            // Fast cache hit (< 2 microseconds!)
            double sinceCheckMs = (nowTicks - _lastFgCheckTicks) * 1000.0 / _qpcFreq;
            if (fg == _lastFgHwnd && sinceCheckMs < 500.0) return _lastFgDisabled;

            _lastFgHwnd = fg;
            _lastFgCheckTicks = nowTicks;
            bool disabled = false;

            // 1. Check Fullscreen (skip Desktop/Shell windows)
            if (_autoDisableFullscreen) {
                _clsBuf.Length = 0;
                GetClassNameW(fg, _clsBuf, _clsBuf.Capacity);
                string cls = _clsBuf.ToString();
                if (cls != "Progman" && cls != "WorkerW" && cls != "Shell_TrayWnd" && cls != "Shell_SecondaryTrayWnd") {
                    RECT wr;
                    if (GetWindowRect(fg, out wr)) {
                        IntPtr mon = MonitorFromWindow(fg, MONITOR_DEFAULTTONEAREST);
                        MONITORINFO mi = new MONITORINFO();
                        mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
                        if (mon != IntPtr.Zero && GetMonitorInfoW(mon, ref mi)) {
                            if (wr.Left <= mi.rcMonitor.Left && wr.Top <= mi.rcMonitor.Top &&
                                wr.Right >= mi.rcMonitor.Right && wr.Bottom >= mi.rcMonitor.Bottom) {
                                disabled = true;
                            }
                        }
                    }
                }
            }

            // 2. Check Auto-Disable Programs list
            if (!disabled && _autoDisableProgs.Length > 0) {
                uint pid;
                GetWindowThreadProcessId(fg, out pid);
                if (pid != 0) {
                    IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
                    if (hProc != IntPtr.Zero) {
                        try {
                            int sz = _exeBuf.Capacity;
                            _exeBuf.Length = 0;
                            if (QueryFullProcessImageNameW(hProc, 0, _exeBuf, ref sz)) {
                                string full = _exeBuf.ToString();
                                int slash = full.LastIndexOf('\\');
                                string fname = (slash >= 0 ? full.Substring(slash + 1) : full).ToLowerInvariant();
                                if (fname.EndsWith(".exe")) fname = fname.Substring(0, fname.Length - 4);
                                for (int i = 0; i < _autoDisableProgs.Length; i++) {
                                    if (fname == _autoDisableProgs[i]) { disabled = true; break; }
                                }
                            }
                        } finally { CloseHandle(hProc); }
                    }
                }
            }

            _lastFgDisabled = disabled;
            return disabled;
        }

        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0 && _isEnabled) {
                int msg = wParam.ToInt32();
                bool isDownEvt = (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN);
                bool isUpEvt   = (msg == WM_KEYUP   || msg == WM_SYSKEYUP);

                if (isDownEvt || isUpEvt) {
                    KBDLLHOOKSTRUCT kb = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                    int vk = (int)(kb.vkCode & 0xFF);

                    if (!_excludeInjected || (kb.flags & LLKHF_INJECTED) == 0) {
                        long nowTicks;
                        QueryPerformanceCounter(out nowTicks);

                        if (isDownEvt) {
                            // Held-key auto-repeat (no KeyUp received since KeyDown) -> ALWAYS pass through!
                            if (_isDown[vk]) {
                                return CallNextHookEx(_hHook, nCode, wParam, lParam);
                            }

                            double thresh = (_perKeyMs[vk] >= 0.0) ? _perKeyMs[vk] : _globalChatterMs;
                            if (thresh > 0.0 && _lastTime[vk] > 0) {
                                double elapsedMs = (nowTicks - _lastTime[vk]) * 1000.0 / _qpcFreq;
                                if (elapsedMs < thresh && elapsedMs >= _minChatterMs && !IsAutoDisabled(nowTicks)) {
                                    // BLOCK MECHANICAL CHATTER!
                                    _blockedDown[vk] = true;
                                    _blockedTotal++;
                                    _blockedByVk[vk]++;
                                    _recentEvents[_recentIdx] = DateTime.Now.ToString("HH:mm:ss") + "|" + GetVkName(vk) + "|" + elapsedMs.ToString("F1", System.Globalization.CultureInfo.InvariantCulture) + "|" + thresh.ToString("F0", System.Globalization.CultureInfo.InvariantCulture);
                                    _recentIdx = (_recentIdx + 1) % _recentEvents.Length;
                                    return (IntPtr)1;
                                }
                            }

                            _isDown[vk] = true;
                            _blockedDown[vk] = false;
                            if (_otherKeyResets) {
                                for (int i = 0; i < 256; i++) { if (i != vk) _lastTime[i] = 0; }
                            }
                            if (!_measureFromRelease) _lastTime[vk] = nowTicks;
                        } else {
                            // KeyUp
                            if (_blockedDown[vk]) {
                                _blockedDown[vk] = false;
                                return (IntPtr)1;
                            }
                            _isDown[vk] = false;
                            if (_measureFromRelease) _lastTime[vk] = nowTicks;
                        }
                    }
                }
            }
            return CallNextHookEx(_hHook, nCode, wParam, lParam);
        }

        private static void DumpStats() {
            try {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("enabled=" + (_isEnabled ? "true" : "false"));
                sb.AppendLine("started=" + _startedAt.ToString("yyyy-MM-dd HH:mm:ss"));
                sb.AppendLine("blocked_total=" + _blockedTotal);
                sb.AppendLine("global_ms=" + _globalChatterMs.ToString("F0", System.Globalization.CultureInfo.InvariantCulture));

                // Top per-key blocked counts
                for (int i = 0; i < 256; i++) {
                    if (_blockedByVk[i] > 0) sb.AppendLine("stat." + GetVkName(i) + "=" + _blockedByVk[i]);
                }
                // Recent events newest-first
                for (int k = 1; k <= _recentEvents.Length; k++) {
                    int pos = (_recentIdx - k + _recentEvents.Length) % _recentEvents.Length;
                    if (_recentEvents[pos] != null) sb.AppendLine("evt=" + _recentEvents[pos]);
                }
                File.WriteAllText(_statsPath, sb.ToString(), new UTF8Encoding(false));
            } catch {}
        }

        private static void AddTrayIcon() {
            NOTIFYICONDATAW nid = new NOTIFYICONDATAW();
            nid.cbSize = Marshal.SizeOf(typeof(NOTIFYICONDATAW));
            nid.hWnd = _hWnd;
            nid.uID = 1;
            nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
            nid.uCallbackMessage = WM_TRAY;
            nid.hIcon = _hIcon;
            nid.szTip = BuildTip();
            Shell_NotifyIconW(NIM_ADD, ref nid);
        }

        private static void UpdateTrayTip() {
            if (_hWnd == IntPtr.Zero) return;
            NOTIFYICONDATAW nid = new NOTIFYICONDATAW();
            nid.cbSize = Marshal.SizeOf(typeof(NOTIFYICONDATAW));
            nid.hWnd = _hWnd;
            nid.uID = 1;
            nid.uFlags = NIF_TIP;
            nid.szTip = BuildTip();
            Shell_NotifyIconW(NIM_MODIFY, ref nid);
        }

        private static void RemoveTrayIcon() {
            if (_hWnd == IntPtr.Zero) return;
            NOTIFYICONDATAW nid = new NOTIFYICONDATAW();
            nid.cbSize = Marshal.SizeOf(typeof(NOTIFYICONDATAW));
            nid.hWnd = _hWnd;
            nid.uID = 1;
            Shell_NotifyIconW(NIM_DELETE, ref nid);
        }

        private static string BuildTip() {
            string st = _isEnabled ? "ΕΝΕΡΓΟ" : "ΠΑΥΣΗ";
            return "Nilly Chatter Blocker (" + st + ") | Blocked: " + _blockedTotal + " — nillygraphics.com";
        }

        private static void ShowTrayMenu() {
            UpdateTrayTip();
            IntPtr hMenu = CreatePopupMenu();
            if (hMenu == IntPtr.Zero) return;
            try {
                AppendMenuW(hMenu, MF_STRING | MF_GRAYED, UIntPtr.Zero, "Nilly Chatter Blocker — Blocked: " + _blockedTotal);
                AppendMenuW(hMenu, MF_SEPARATOR, UIntPtr.Zero, null);
                AppendMenuW(hMenu, MF_STRING | (_isEnabled ? MF_CHECKED : 0), (UIntPtr)IDM_TOGGLE, _isEnabled ? "Ενεργό (Κλικ για Παύση)" : "Σε Παύση (Κλικ για Ενεργοποίηση)");
                AppendMenuW(hMenu, MF_STRING, (UIntPtr)IDM_SETTINGS, "Ρυθμίσεις (PC Manager & Tools)");
                AppendMenuW(hMenu, MF_STRING, (UIntPtr)IDM_RELOAD, "Επαναφόρτωση Ρυθμίσεων");
                AppendMenuW(hMenu, MF_SEPARATOR, UIntPtr.Zero, null);
                AppendMenuW(hMenu, MF_STRING, (UIntPtr)IDM_EXIT, "Έξοδος");

                POINT pt;
                GetCursorPos(out pt);
                SetForegroundWindow(_hWnd);
                uint cmd = TrackPopupMenu(hMenu, TPM_RIGHTBUTTON | TPM_RETURNCMD, pt.X, pt.Y, 0, _hWnd, IntPtr.Zero);
                if (cmd == IDM_TOGGLE) {
                    _isEnabled = !_isEnabled;
                    UpdateTrayTip();
                } else if (cmd == IDM_SETTINGS) {
                    OpenSettingsUi();
                } else if (cmd == IDM_RELOAD) {
                    LoadConfig();
                } else if (cmd == IDM_EXIT) {
                    PostQuitMessage(0);
                }
            } finally {
                DestroyMenu(hMenu);
            }
        }

        private static void OpenSettingsUi() {
            try {
                string vbs = Path.Combine(_baseDir, "Launch_PCManagerLite.vbs");
                if (File.Exists(vbs)) {
                    Process.Start("wscript.exe", "\"" + vbs + "\" ChatterBlocker");
                }
            } catch {}
        }

        private static void TrimMemory() {
            try {
                GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced);
                GC.WaitForPendingFinalizers();
                GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced);
                IntPtr p = GetCurrentProcess();
                EmptyWorkingSet(p);
                SetProcessWorkingSetSize(p, (IntPtr)(-1), (IntPtr)(-1));
            } catch {}
        }

        private static IntPtr WndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam) {
            if (msg == WM_TRAY) {
                int ev = (int)(lParam.ToInt64() & 0xFFFF);
                if (ev == WM_RBUTTONUP) ShowTrayMenu();
                else if (ev == WM_LBUTTONDBLCLK) OpenSettingsUi();
                return IntPtr.Zero;
            }
            if (msg == WM_RELOAD_CFG) { LoadConfig(); SetTimer(hWnd, (UIntPtr)1, 1500, IntPtr.Zero); return IntPtr.Zero; }
            if (msg == WM_DUMP_STATS) { DumpStats(); SetTimer(hWnd, (UIntPtr)1, 2000, IntPtr.Zero); return IntPtr.Zero; }
            if (msg == WM_TOGGLE_EN)  { _isEnabled = !_isEnabled; UpdateTrayTip(); DumpStats(); SetTimer(hWnd, (UIntPtr)1, 2000, IntPtr.Zero); return IntPtr.Zero; }
            if (msg == WM_EXIT_APP)   { PostQuitMessage(0); return IntPtr.Zero; }
            if (msg == WM_TIMER) {
                if (wParam.ToInt64() == 1) KillTimer(hWnd, (UIntPtr)1);
                TrimMemory();
                return IntPtr.Zero;
            }
            if (msg == _wmTaskbarCreated && _wmTaskbarCreated != 0) {
                AddTrayIcon();
                return IntPtr.Zero;
            }
            if (msg == WM_DESTROY) {
                PostQuitMessage(0);
                return IntPtr.Zero;
            }
            return DefWindowProcW(hWnd, msg, wParam, lParam);
        }

        [STAThread]
        public static int Main(string[] args) {
            bool createdNew;
            using (Mutex mutex = new Mutex(true, "Local\\NillyChatterBlocker_SingleInstance", out createdNew)) {
                if (!createdNew) return 0;

                _baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
                _cfgPath = Path.Combine(_baseDir, "chatter_config.txt");
                _statsPath = Path.Combine(_baseDir, "chatter_stats.txt");

                QueryPerformanceFrequency(out _qpcFreq);
                InitKeyMaps();
                LoadConfig();

                IntPtr hInst = GetModuleHandleW(null);
                string icoPath = Path.Combine(_baseDir, "PCManagerLite.ico");
                if (File.Exists(icoPath)) {
                    _hIcon = LoadImageW(IntPtr.Zero, icoPath, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
                }
                if (_hIcon == IntPtr.Zero) {
                    _hIcon = LoadIconW(IntPtr.Zero, (IntPtr)32512); // IDI_APPLICATION
                }

                _wmTaskbarCreated = RegisterWindowMessageW("TaskbarCreated");
                _wndProcDelegate = new WndProcDelegate(WndProc);

                WNDCLASSEXW wc = new WNDCLASSEXW();
                wc.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEXW));
                wc.lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_wndProcDelegate);
                wc.hInstance = hInst;
                wc.lpszClassName = "NillyChatterBlocker_MsgWnd";
                RegisterClassExW(ref wc);

                _hWnd = CreateWindowExW(0, "NillyChatterBlocker_MsgWnd", "NillyChatterBlocker", 0,
                    0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, hInst, IntPtr.Zero);

                AddTrayIcon();

                _hookDelegate = new LowLevelKeyboardProc(HookCallback);
                _hHook = SetWindowsHookExW(WH_KEYBOARD_LL, _hookDelegate, hInst, 0);

                // Trim RAM aggressively 1.5s after launch + gentle periodic trim every 10 min!
                SetTimer(_hWnd, (UIntPtr)1, 1500, IntPtr.Zero);
                SetTimer(_hWnd, (UIntPtr)2, 600000, IntPtr.Zero);
                TrimMemory();

                MSG m;
                while (GetMessageW(out m, IntPtr.Zero, 0, 0) > 0) {
                    TranslateMessage(ref m);
                    DispatchMessageW(ref m);
                }

                if (_hHook != IntPtr.Zero) UnhookWindowsHookEx(_hHook);
                RemoveTrayIcon();
                if (_hIcon != IntPtr.Zero) DestroyIcon(_hIcon);
                if (_hWnd != IntPtr.Zero) DestroyWindow(_hWnd);
                return 0;
            }
        }
    }
}
