// Nilly Keyboard Chatter Blocker — Ultra-Light Pure Win32 Daemon (0 WinForms, 0 WPF, ~0.5 MB WS RAM!)
// Exact FreneticLLC KeyBlocker + QUNS_RUNNING_D3D_FULL_SCREEN algorithm with zero UI bloat.
// created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/

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
        // Win32 Constants & IPC Messages
        // =====================================================================
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN     = 0x0100;
        private const int WM_KEYUP       = 0x0101;
        private const int WM_SYSKEYDOWN  = 0x0104;
        private const int WM_SYSKEYUP    = 0x0105;
        private const int WM_DESTROY     = 0x0002;
        private const int WM_TIMER       = 0x0113;
        private const int WM_HOTKEY      = 0x0312;
        private const int WM_RBUTTONUP   = 0x0205;
        private const int WM_LBUTTONDBLCLK = 0x0203;
        private const uint MOD_ALT       = 0x0001;
        private const uint MOD_CONTROL   = 0x0002;
        private const uint MOD_NOREPEAT  = 0x4000;
        private const int  HOTKEY_SNAP   = 9001;
        private const uint LLKHF_LOWER_IL_INJECTED = 0x02;
        private const uint LLKHF_INJECTED = 0x10;

        private const uint WM_TRAY       = 0x8000;
        private const uint WM_RELOAD_CFG = 0x8001;
        private const uint WM_DUMP_STATS = 0x8002;
        private const uint WM_TOGGLE_EN  = 0x8003;
        private const uint WM_EXIT_APP   = 0x8004;
        private const uint WM_RESET_STAT = 0x8005;
        private const uint WM_DO_SNAP    = 0x8006;
        private const uint WM_CLOSE_SNAP = 0x8007;

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
        private const uint IDM_SNAP     = 1005;
        private const uint IDM_EXIT     = 1004;

        private const uint IMAGE_ICON      = 1;
        private const uint LR_LOADFROMFILE = 0x0010;
        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
        private const int  QUNS_RUNNING_D3D_FULL_SCREEN = 3;

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
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

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

        // =====================================================================
        // Win32 P/Invoke
        // =====================================================================
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll")]
        private static extern bool SetProcessWorkingSetSize(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);

        [DllImport("psapi.dll")]
        private static extern bool EmptyWorkingSet(IntPtr hProcess);

        [DllImport("shell32.dll")]
        private static extern int SHQueryUserNotificationState(out int pquns);

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

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [DllImport("user32.dll")]
        private static extern int GetSystemMetrics(int nIndex);

        [DllImport("user32.dll")]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateCompatibleDC(IntPtr hDC);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteDC(IntPtr hDC);

        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateCompatibleBitmap(IntPtr hDC, int nWidth, int nHeight);

        [DllImport("gdi32.dll")]
        private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);

        [DllImport("gdi32.dll")]
        private static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int w, int h, IntPtr hdcSrc, int xSrc, int ySrc, uint rop);

        [DllImport("msimg32.dll")]
        private static extern bool AlphaBlend(IntPtr hdcDest, int xDest, int yDest, int wDest, int hDest, IntPtr hdcSrc, int xSrc, int ySrc, int wSrc, int hSrc, uint blendFunction);

        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateSolidBrush(uint crColor);

        [DllImport("gdi32.dll")]
        private static extern IntPtr CreatePen(int iStyle, int cWidth, uint color);

        [DllImport("gdi32.dll")]
        private static extern IntPtr GetStockObject(int i);

        [DllImport("user32.dll")]
        private static extern int FillRect(IntPtr hDC, ref RECT lprc, IntPtr hbr);

        [DllImport("gdi32.dll")]
        private static extern bool RoundRect(IntPtr hdc, int left, int top, int right, int bottom, int width, int height);

        [DllImport("gdi32.dll")]
        private static extern bool Rectangle(IntPtr hdc, int left, int top, int right, int bottom);

        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr CreateFontW(int cHeight, int cWidth, int cEscapement, int cOrientation, int cWeight,
            uint bItalic, uint bUnderline, uint bStrikeOut, uint iCharSet, uint iOutPrecision, uint iClipPrecision,
            uint iQuality, uint iPitchAndFamily, string pszFaceName);

        [DllImport("gdi32.dll")]
        private static extern int SetBkMode(IntPtr hdc, int mode);

        [DllImport("gdi32.dll")]
        private static extern uint SetTextColor(IntPtr hdc, uint color);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int DrawTextW(IntPtr hdc, string lpchText, int cchText, ref RECT lprc, uint format);

        [DllImport("user32.dll")]
        private static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);

        [DllImport("user32.dll")]
        private static extern bool EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);

        [DllImport("user32.dll")]
        private static extern bool InvalidateRect(IntPtr hWnd, IntPtr lpRect, bool bErase);

        [DllImport("user32.dll")]
        private static extern bool UpdateWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        private static extern IntPtr SetCapture(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        private static extern IntPtr LoadCursorW(IntPtr hInstance, IntPtr lpCursorName);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        [DllImport("gdi32.dll")]
        private static extern int GetDIBits(IntPtr hdc, IntPtr hbm, uint start, uint cLines, IntPtr lpvBits, ref BITMAPINFOHEADER lpbmi, uint usage);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GlobalAlloc(uint uFlags, UIntPtr dwBytes);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GlobalLock(IntPtr hMem);

        [DllImport("kernel32.dll")]
        private static extern bool GlobalUnlock(IntPtr hMem);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GlobalFree(IntPtr hMem);

        [DllImport("user32.dll")]
        private static extern bool OpenClipboard(IntPtr hWndNewOwner);

        [DllImport("user32.dll")]
        private static extern bool EmptyClipboard();

        [DllImport("user32.dll")]
        private static extern IntPtr SetClipboardData(uint uFormat, IntPtr hMem);

        [DllImport("user32.dll")]
        private static extern bool CloseClipboard();

        [DllImport("user32.dll")]
        private static extern bool PostMessageW(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern IntPtr SetFocus(IntPtr hWnd);

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left, Top, Right, Bottom; }

        [StructLayout(LayoutKind.Sequential)]
        private struct PAINTSTRUCT {
            public IntPtr hdc;
            public int fErase;
            public RECT rcPaint;
            public int fRestore;
            public int fIncUpdate;
            public ulong r0, r1, r2, r3;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct BITMAPINFOHEADER {
            public uint biSize;
            public int biWidth;
            public int biHeight;
            public ushort biPlanes;
            public ushort biBitCount;
            public uint biCompression;
            public uint biSizeImage;
            public int biXPelsPerMeter;
            public int biYPelsPerMeter;
            public uint biClrUsed;
            public uint biClrImportant;
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern bool Shell_NotifyIconW(uint dwMessage, ref NOTIFYICONDATAW lpData);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadImageW(IntPtr hInst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
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
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool QueryFullProcessImageNameW(IntPtr hProcess, uint dwFlags, StringBuilder lpExeName, ref int lpdwSize);

        [DllImport("kernel32.dll")]
        private static extern bool CloseHandle(IntPtr hObject);

        // =====================================================================
        // Daemon State — 100% faithful to FreneticLLC KeyBlocker semantics
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

        private static bool _isEnabled = true;
        private static bool _isAutoDisabled = false;
        private static uint _globalChatterMs = 50;
        private static uint _minChatterMs = 0;
        private static bool _measureFromRelease = false;
        private static bool _autoDisableFullscreen = true;
        private static bool _otherKeyResets = false;
        private static bool _excludeInjected = false;
        private static string[] _autoDisableProgs = new string[0];
        private static readonly int[] _perKeyMs = new int[256]; // -1 = use global

        private static readonly bool[]  _keyIsDown = new bool[256];
        private static readonly bool[]  _downWasBlocked = new bool[256];
        private static readonly ulong[] _lastPressMs = new ulong[256];
        private static readonly ulong[] _lastReleaseMs = new ulong[256];
        private static int _lastPressedVk = -1;

        private static long _blockedTotal = 0;
        private static long _pressTotal = 0;
        private static readonly int[] _pressByVk = new int[256];
        private static readonly int[] _blockedByVk = new int[256];
        private static readonly ulong[] _minGapByVk = new ulong[256];
        private static readonly ulong[] _maxBlockedByVk = new ulong[256];
        private static readonly string[] _recentEvents = new string[50];
        private static int _recentIdx = 0;
        private static DateTime _startedAt = DateTime.Now;
        private static IntPtr _lastFgHwnd = IntPtr.Zero;
        private static bool _lastProgDisabled = false;
        private static readonly StringBuilder _exeBuf = new StringBuilder(512);

        private static readonly Dictionary<string, int> _nameToVk = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        private static readonly string[] _vkToName = new string[256];

        private static ulong GetTimeMs() {
            return (ulong)(Stopwatch.GetTimestamp() * (1000.0 / Stopwatch.Frequency));
        }

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
            _isEnabled = true;
            _globalChatterMs = 50;
            _minChatterMs = 0;
            _measureFromRelease = false;
            _autoDisableFullscreen = true;
            _otherKeyResets = false;
            _excludeInjected = false;
            _autoDisableProgs = new string[0];
            for (int i = 0; i < 256; i++) _perKeyMs[i] = -1;

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
                        uint u; if (uint.TryParse(val, out u)) _globalChatterMs = u;
                    } else if (key.Equals("minimum_chatter_time", StringComparison.OrdinalIgnoreCase)) {
                        uint u; if (uint.TryParse(val, out u)) _minChatterMs = u;
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
                            foreach (string p in val.Split(new char[] { '/', ',', ';' }, StringSplitOptions.RemoveEmptyEntries)) {
                                string pt = p.Trim().ToLowerInvariant();
                                if (pt.EndsWith(".exe")) pt = pt.Substring(0, pt.Length - 4);
                                if (pt.Length > 0) progs.Add(pt);
                            }
                        }
                    } else if (key.StartsWith("key.", StringComparison.OrdinalIgnoreCase)) {
                        string kName = key.Substring(4).Trim();
                        int vk = ParseKeyName(kName);
                        int ms;
                        if (vk >= 0 && vk < 256 && int.TryParse(val, out ms) && ms >= 0) {
                            _perKeyMs[vk] = ms;
                        }
                    }
                }
                _autoDisableProgs = progs.ToArray();
            } catch {}
            UpdateAutoDisableState();
            UpdateTrayTip();
        }

        // Exact FreneticLLC FullScreenDetectHelper + AutoDisablePrograms check (runs on 1-sec timer, ZERO hook latency!)
        private static void UpdateAutoDisableState() {
            bool disabled = false;

            // 1. Exact Direct3D Fullscreen check ONLY (never false-triggers on maximized apps like Antigravity/browsers!)
            if (_autoDisableFullscreen) {
                int state;
                if (SHQueryUserNotificationState(out state) == 0 && state == QUNS_RUNNING_D3D_FULL_SCREEN) {
                    disabled = true;
                }
            }

            // 2. Auto-disable programs check (cached per foreground HWND — zero OpenProcess while typing in same window!)
            if (!disabled && _autoDisableProgs.Length > 0) {
                IntPtr fg = GetForegroundWindow();
                if (fg != IntPtr.Zero) {
                    if (fg == _lastFgHwnd) {
                        disabled = _lastProgDisabled;
                    } else {
                        _lastFgHwnd = fg;
                        bool progMatch = false;
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
                                            if (fname == _autoDisableProgs[i]) { progMatch = true; break; }
                                        }
                                    }
                                } finally { CloseHandle(hProc); }
                            }
                        }
                        _lastProgDisabled = progMatch;
                        disabled = progMatch;
                    }
                }
            }

            _isAutoDisabled = disabled;
        }

        // Exact FreneticLLC KeyBlocker.AllowKeyDown / AllowKeyUp logic
        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0) {
                int msg = wParam.ToInt32();
                bool isDown = (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN);
                bool isUp   = (msg == WM_KEYUP   || msg == WM_SYSKEYUP);

                if (isDown || isUp) {
                    KBDLLHOOKSTRUCT kb = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                    if (_excludeInjected && (kb.flags & (LLKHF_INJECTED | LLKHF_LOWER_IL_INJECTED)) != 0) {
                        return CallNextHookEx(_hHook, nCode, wParam, lParam);
                    }
                    int vk = (int)(kb.vkCode & 0xFF);
                    ulong timeNow = GetTimeMs();

                    if (isDown) {
                        // Esc while QuickSnap overlay is open -> ALWAYS close cleanly regardless of focus!
                        if (vk == 0x1B && _snapHwnd != IntPtr.Zero) {
                            PostMessageW(_hWnd, WM_CLOSE_SNAP, IntPtr.Zero, IntPtr.Zero);
                            return (IntPtr)1;
                        }
                        // Instant Global Hotkey: Ctrl + Alt + S (detected right in WH_KEYBOARD_LL -> 100% immune to conflicts, Greek & English!)
                        if (vk == 0x53 && _snapHwnd == IntPtr.Zero) {
                            bool ctrlNow = ((GetAsyncKeyState(0x11) & 0x8000) != 0);
                            bool altNow  = ((GetAsyncKeyState(0x12) & 0x8000) != 0);
                            bool winNow  = ((GetAsyncKeyState(0x5B) & 0x8000) != 0) || ((GetAsyncKeyState(0x5C) & 0x8000) != 0);
                            if (ctrlNow && altNow && !winNow) {
                                PostMessageW(_hWnd, WM_DO_SNAP, IntPtr.Zero, IntPtr.Zero);
                                return (IntPtr)1;
                            }
                        }
                        if (!_isEnabled || _isAutoDisabled) {
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        int customMs = _perKeyMs[vk];
                        if (!_otherKeyResets && _globalChatterMs == 0 && customMs < 0) {
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        // Held key auto-repeat -> allow!
                        if (_keyIsDown[vk]) {
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        _keyIsDown[vk] = true;
                        _pressTotal++;
                        _pressByVk[vk]++;

                        ulong timeLast = _measureFromRelease ? _lastReleaseMs[vk] : _lastPressMs[vk];
                        if (_otherKeyResets) {
                            if (vk != _lastPressedVk) {
                                _lastPressedVk = vk;
                                _lastPressMs[vk] = timeNow;
                                return CallNextHookEx(_hHook, nCode, wParam, lParam);
                            }
                            _lastPressedVk = vk;
                        }
                        if (timeLast > timeNow) {
                            _lastPressMs[vk] = timeNow;
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        uint maxTime = (customMs >= 0) ? (uint)customMs : _globalChatterMs;
                        ulong timePassed = unchecked(timeNow - timeLast);
                        if (timeLast > 0 && timePassed < 5000) {
                            if (_minGapByVk[vk] == 0 || timePassed < _minGapByVk[vk]) {
                                _minGapByVk[vk] = timePassed;
                            }
                        }
                        if (timePassed >= maxTime || timePassed < _minChatterMs) {
                            _lastPressMs[vk] = timeNow;
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }

                        // BLOCK CHATTER!
                        _downWasBlocked[vk] = true;
                        _blockedTotal++;
                        _blockedByVk[vk]++;
                        if (timePassed > _maxBlockedByVk[vk]) _maxBlockedByVk[vk] = timePassed;
                        _recentEvents[_recentIdx] = DateTime.Now.ToString("HH:mm:ss") + "|" + GetVkName(vk) + "|" + timePassed + "|" + maxTime;
                        _recentIdx = (_recentIdx + 1) % _recentEvents.Length;
                        return (IntPtr)1;
                    } else {
                        // KeyUp: exact FreneticLLC AllowKeyUp
                        if (!_isEnabled || _isAutoDisabled) {
                            _lastReleaseMs[vk] = timeNow;
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        _keyIsDown[vk] = false;
                        if (!_downWasBlocked[vk]) {
                            _lastReleaseMs[vk] = timeNow;
                            return CallNextHookEx(_hHook, nCode, wParam, lParam);
                        }
                        _downWasBlocked[vk] = false;
                        // Allow duplicate KeyUp through so physical keys can NEVER stick
                        return CallNextHookEx(_hHook, nCode, wParam, lParam);
                    }
                }
            }
            return CallNextHookEx(_hHook, nCode, wParam, lParam);
        }

        private static void ResetStats() {
            _blockedTotal = 0;
            _pressTotal = 0;
            for (int i = 0; i < 256; i++) {
                _pressByVk[i] = 0;
                _blockedByVk[i] = 0;
                _minGapByVk[i] = 0;
                _maxBlockedByVk[i] = 0;
            }
            for (int i = 0; i < _recentEvents.Length; i++) _recentEvents[i] = null;
            _recentIdx = 0;
            UpdateTrayTip();
            DumpStats();
        }

        private static void DumpStats() {
            try {
                StringBuilder sb = new StringBuilder();
                sb.AppendLine("enabled=" + (_isEnabled ? "true" : "false"));
                sb.AppendLine("hook_ok=" + (_hHook != IntPtr.Zero ? "true" : "false"));
                sb.AppendLine("auto_disabled=" + (_isAutoDisabled ? "true" : "false"));
                sb.AppendLine("started=" + _startedAt.ToString("yyyy-MM-dd HH:mm:ss"));
                sb.AppendLine("press_total=" + _pressTotal);
                sb.AppendLine("blocked_total=" + _blockedTotal);
                sb.AppendLine("global_ms=" + _globalChatterMs);
                for (int i = 0; i < 256; i++) {
                    if (_perKeyMs[i] >= 0) sb.AppendLine("cfg." + GetVkName(i) + "=" + _perKeyMs[i]);
                }
                for (int i = 0; i < 256; i++) {
                    if (_pressByVk[i] > 0 || _blockedByVk[i] > 0) {
                        uint lim = (_perKeyMs[i] >= 0) ? (uint)_perKeyMs[i] : _globalChatterMs;
                        sb.AppendLine("kstat=" + GetVkName(i) + "|" + _pressByVk[i] + "|" + _blockedByVk[i] + "|" + _minGapByVk[i] + "|" + _maxBlockedByVk[i] + "|" + lim);
                    }
                }
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
            string st = _isEnabled ? (_isAutoDisabled ? "AUTO-PAUSED" : "ΕΝΕΡΓΟ") : "ΠΑΥΣΗ";
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
                AppendMenuW(hMenu, MF_STRING, (UIntPtr)IDM_SNAP, "Γρήγορο Screenshot (Ctrl+Alt+S)");
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
                } else if (cmd == IDM_SNAP) {
                    LaunchQuickSnap();
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

        // =====================================================================
        // INSTANT PURE-WIN32 QUICKSNAP OVERLAY (< 15 ms open, 144 FPS, 0 KB retained RAM!)
        // Drag & Release -> Instant Copy to Clipboard (24-bit CF_DIB) & Close
        // Shift + Release -> Opens NillySnap.exe -edit for Arrow/Box/Pen/Blur markup
        // Clear, subtle bold pixel dimensions (W x H px) right beside cursor!
        // =====================================================================
        private static bool _snapClassRegistered = false;
        private static WndProcDelegate _snapWndProcDelegate;
        private static IntPtr _snapHwnd = IntPtr.Zero;
        private static int _snapVX, _snapVY, _snapVW, _snapVH;
        private static IntPtr _snapSrcDc, _snapSrcBmp, _snapSrcOld;
        private static IntPtr _snapDimDc, _snapDimBmp, _snapDimOld;
        private static IntPtr _snapBackDc, _snapBackBmp, _snapBackOld;
        private static IntPtr _snapFontBig, _snapFontSmall;
        private static bool _snapDragging = false;
        private static int _snapX0, _snapY0, _snapX1, _snapY1;
        private static int _snapMouseX, _snapMouseY;

        private static bool CopyRegionToClipboardDib(IntPtr srcDc, int rx, int ry, int rw, int rh) {
            if (rw < 2 || rh < 2) return false;
            IntPtr scrDc = GetDC(IntPtr.Zero);
            IntPtr tmpDc = CreateCompatibleDC(scrDc);
            IntPtr tmpBmp = CreateCompatibleBitmap(scrDc, rw, rh);
            IntPtr old = SelectObject(tmpDc, tmpBmp);
            BitBlt(tmpDc, 0, 0, rw, rh, srcDc, rx, ry, 0x00CC0020);
            SelectObject(tmpDc, old);

            int stride = ((rw * 3 + 3) & ~3);
            int imgBytes = stride * rh;
            int totalBytes = 40 + imgBytes;

            BITMAPINFOHEADER bih = new BITMAPINFOHEADER();
            bih.biSize = 40;
            bih.biWidth = rw;
            bih.biHeight = rh;
            bih.biPlanes = 1;
            bih.biBitCount = 24;
            bih.biCompression = 0; // BI_RGB
            bih.biSizeImage = (uint)imgBytes;

            IntPtr hMem = GlobalAlloc(0x0002, (UIntPtr)totalBytes);
            bool copied = false;
            if (hMem != IntPtr.Zero) {
                IntPtr ptr = GlobalLock(hMem);
                if (ptr != IntPtr.Zero) {
                    Marshal.StructureToPtr(bih, ptr, false);
                    IntPtr bitsPtr = new IntPtr(ptr.ToInt64() + 40);
                    int scanLines = GetDIBits(tmpDc, tmpBmp, 0, (uint)rh, bitsPtr, ref bih, 0);
                    GlobalUnlock(hMem);
                    if (scanLines > 0) {
                        for (int attempt = 0; attempt < 5; attempt++) {
                            if (OpenClipboard(_hWnd)) {
                                EmptyClipboard();
                                if (SetClipboardData(8, hMem) != IntPtr.Zero) {
                                    copied = true;
                                }
                                CloseClipboard();
                                break;
                            }
                            Thread.Sleep(10);
                        }
                    }
                }
                if (!copied) GlobalFree(hMem);
            }
            DeleteObject(tmpBmp);
            DeleteDC(tmpDc);
            ReleaseDC(IntPtr.Zero, scrDc);
            return copied;
        }

        private static void CloseInstantSnap() {
            if (_snapHwnd != IntPtr.Zero) {
                ReleaseCapture();
                DestroyWindow(_snapHwnd);
                _snapHwnd = IntPtr.Zero;
            }
            if (_snapSrcDc != IntPtr.Zero) { SelectObject(_snapSrcDc, _snapSrcOld); DeleteObject(_snapSrcBmp); DeleteDC(_snapSrcDc); _snapSrcDc = IntPtr.Zero; _snapSrcBmp = IntPtr.Zero; }
            if (_snapDimDc != IntPtr.Zero) { SelectObject(_snapDimDc, _snapDimOld); DeleteObject(_snapDimBmp); DeleteDC(_snapDimDc); _snapDimDc = IntPtr.Zero; _snapDimBmp = IntPtr.Zero; }
            if (_snapBackDc != IntPtr.Zero) { SelectObject(_snapBackDc, _snapBackOld); DeleteObject(_snapBackBmp); DeleteDC(_snapBackDc); _snapBackDc = IntPtr.Zero; _snapBackBmp = IntPtr.Zero; }
            if (_snapFontBig != IntPtr.Zero) { DeleteObject(_snapFontBig); _snapFontBig = IntPtr.Zero; }
            if (_snapFontSmall != IntPtr.Zero) { DeleteObject(_snapFontSmall); _snapFontSmall = IntPtr.Zero; }
            _snapDragging = false;
            if (_hWnd != IntPtr.Zero) SetTimer(_hWnd, (UIntPtr)1, 1500, IntPtr.Zero);
        }

        private static void PaintInstantSnap(IntPtr hWnd) {
            PAINTSTRUCT ps;
            IntPtr hdc = BeginPaint(hWnd, out ps);
            if (_snapBackDc != IntPtr.Zero && _snapDimDc != IntPtr.Zero && _snapSrcDc != IntPtr.Zero) {
                // 1. Copy pre-dimmed background
                BitBlt(_snapBackDc, 0, 0, _snapVW, _snapVH, _snapDimDc, 0, 0, 0x00CC0020);
                SetBkMode(_snapBackDc, 1); // TRANSPARENT

                if (_snapDragging) {
                    int rx = Math.Min(_snapX0, _snapX1);
                    int ry = Math.Min(_snapY0, _snapY1);
                    int rw = Math.Abs(_snapX1 - _snapX0);
                    int rh = Math.Abs(_snapY1 - _snapY0);

                    if (rw > 0 && rh > 0) {
                        // 2. Blit crisp bright selection
                        BitBlt(_snapBackDc, rx, ry, rw, rh, _snapSrcDc, rx, ry, 0x00CC0020);

                        // 3. Crisp 2px Cyan border (#38BDF8 -> COLORREF 0x00F8BD38)
                        IntPtr pen = CreatePen(0, 2, 0x00F8BD38);
                        IntPtr oldP = SelectObject(_snapBackDc, pen);
                        IntPtr oldB = SelectObject(_snapBackDc, GetStockObject(5)); // NULL_BRUSH
                        Rectangle(_snapBackDc, rx, ry, rx + rw, ry + rh);
                        SelectObject(_snapBackDc, oldB);
                        SelectObject(_snapBackDc, oldP);
                        DeleteObject(pen);

                        // 4. Crisp readable Pixel Dimension Pill right near drag corner (subtle & clear!)
                        string ratio = (rh > 0) ? string.Format("{0:F2}:1", (double)rw / rh) : "";
                        string dimTxt = string.Format("{0} × {1} px", rw, rh);
                        string fullTxt = (rw >= 40 && rh >= 20) ? (dimTxt + "  ·  " + ratio) : dimTxt;

                        IntPtr oldF = SelectObject(_snapBackDc, _snapFontBig);
                        RECT mr = new RECT();
                        DrawTextW(_snapBackDc, fullTxt, fullTxt.Length, ref mr, 0x0420); // DT_CALCRECT | DT_SINGLELINE
                        int pw = (mr.Right - mr.Left) + 20;
                        int ph = (mr.Bottom - mr.Top) + 12;

                        int px = Math.Max(8, Math.Min(_snapVW - pw - 8, _snapX1 + 14));
                        int py = (_snapY1 + 14 + ph <= _snapVH - 8) ? (_snapY1 + 14) : Math.Max(8, _snapY1 - ph - 14);
                        // Keep pill outside selection top if dragging up-left
                        if (ry - ph - 8 >= 8 && _snapY1 <= _snapY0) { px = Math.Max(8, Math.Min(_snapVW - pw - 8, rx)); py = ry - ph - 8; }

                        IntPtr bgBr = CreateSolidBrush(0x00170F0B); // #0B0F17
                        IntPtr bdPen = CreatePen(0, 1, 0x00F8BD38); // #38BDF8
                        IntPtr oB2 = SelectObject(_snapBackDc, bgBr);
                        IntPtr oP2 = SelectObject(_snapBackDc, bdPen);
                        RoundRect(_snapBackDc, px, py, px + pw, py + ph, 10, 10);
                        SelectObject(_snapBackDc, oP2);
                        SelectObject(_snapBackDc, oB2);
                        DeleteObject(bdPen);
                        DeleteObject(bgBr);

                        RECT tr = new RECT { Left = px, Top = py, Right = px + pw, Bottom = py + ph };
                        SetTextColor(_snapBackDc, 0x00FCFAF8); // #F8FAFC crisp white
                        DrawTextW(_snapBackDc, fullTxt, fullTxt.Length, ref tr, 0x0025); // DT_CENTER | DT_VCENTER | DT_SINGLELINE
                        SelectObject(_snapBackDc, oldF);
                    }
                } else {
                    // Subtle live cursor X,Y + tiny corner hint (unobtrusive!)
                    IntPtr oldF = SelectObject(_snapBackDc, _snapFontSmall);
                    string posTxt = string.Format("{0}, {1} px  ·  Σύρε = Copy  ·  F = Όλη  ·  Esc", _snapMouseX, _snapMouseY);
                    RECT mr = new RECT();
                    DrawTextW(_snapBackDc, posTxt, posTxt.Length, ref mr, 0x0420);
                    int pw = (mr.Right - mr.Left) + 16;
                    int ph = (mr.Bottom - mr.Top) + 10;
                    int px = Math.Max(8, Math.Min(_snapVW - pw - 8, _snapMouseX + 16));
                    int py = Math.Max(8, Math.Min(_snapVH - ph - 8, _snapMouseY + 18));

                    IntPtr bgBr = CreateSolidBrush(0x00170F0B);
                    IntPtr bdPen = CreatePen(0, 1, 0x004D382C);
                    IntPtr oB2 = SelectObject(_snapBackDc, bgBr);
                    IntPtr oP2 = SelectObject(_snapBackDc, bdPen);
                    RoundRect(_snapBackDc, px, py, px + pw, py + ph, 8, 8);
                    SelectObject(_snapBackDc, oP2);
                    SelectObject(_snapBackDc, oB2);
                    DeleteObject(bdPen);
                    DeleteObject(bgBr);

                    RECT tr = new RECT { Left = px, Top = py, Right = px + pw, Bottom = py + ph };
                    SetTextColor(_snapBackDc, 0x00F8BD38);
                    DrawTextW(_snapBackDc, posTxt, posTxt.Length, ref tr, 0x0025);
                    SelectObject(_snapBackDc, oldF);
                }

                // 5. Present double-buffer atomically (144 FPS zero flicker!)
                BitBlt(hdc, 0, 0, _snapVW, _snapVH, _snapBackDc, 0, 0, 0x00CC0020);
            }
            EndPaint(hWnd, ref ps);
        }

        private static IntPtr SnapWndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam) {
            const uint WM_PAINT       = 0x000F;
            const uint WM_ERASEBKGND  = 0x0014;
            const uint WM_MOUSEMOVE   = 0x0200;
            const uint WM_LBUTTONDOWN = 0x0201;
            const uint WM_LBUTTONUP   = 0x0202;
            const uint WM_RBUTTONDOWN = 0x0204;

            if (msg == WM_ERASEBKGND) return (IntPtr)1;
            if (msg == WM_PAINT) { PaintInstantSnap(hWnd); return IntPtr.Zero; }
            if (msg == WM_KEYDOWN) {
                int vk = wParam.ToInt32();
                if (vk == 0x1B) { CloseInstantSnap(); return IntPtr.Zero; } // Esc
                if (vk == 0x46) { // F = Instant Fullscreen Copy
                    CopyRegionToClipboardDib(_snapSrcDc, 0, 0, _snapVW, _snapVH);
                    CloseInstantSnap();
                    return IntPtr.Zero;
                }
            }
            if (msg == WM_RBUTTONDOWN) { CloseInstantSnap(); return IntPtr.Zero; }
            if (msg == WM_LBUTTONDOWN) {
                int x = (short)(lParam.ToInt64() & 0xFFFF);
                int y = (short)((lParam.ToInt64() >> 16) & 0xFFFF);
                _snapDragging = true;
                _snapX0 = _snapX1 = _snapMouseX = x;
                _snapY0 = _snapY1 = _snapMouseY = y;
                SetCapture(hWnd);
                InvalidateRect(hWnd, IntPtr.Zero, false);
                return IntPtr.Zero;
            }
            if (msg == WM_MOUSEMOVE) {
                int x = (short)(lParam.ToInt64() & 0xFFFF);
                int y = (short)((lParam.ToInt64() >> 16) & 0xFFFF);
                _snapMouseX = x; _snapMouseY = y;
                if (_snapDragging) { _snapX1 = x; _snapY1 = y; }
                InvalidateRect(hWnd, IntPtr.Zero, false);
                return IntPtr.Zero;
            }
            if (msg == WM_LBUTTONUP && _snapDragging) {
                int x = (short)(lParam.ToInt64() & 0xFFFF);
                int y = (short)((lParam.ToInt64() >> 16) & 0xFFFF);
                _snapX1 = x; _snapY1 = y;
                _snapDragging = false;
                int rx = Math.Min(_snapX0, _snapX1);
                int ry = Math.Min(_snapY0, _snapY1);
                int rw = Math.Abs(_snapX1 - _snapX0);
                int rh = Math.Abs(_snapY1 - _snapY0);
                bool shiftHeld = (GetAsyncKeyState(0x10) & 0x8000) != 0;
                if (rw >= 4 && rh >= 4) {
                    CopyRegionToClipboardDib(_snapSrcDc, rx, ry, rw, rh);
                }
                CloseInstantSnap();
                if (shiftHeld) {
                    try {
                        string snapExe = Path.Combine(_baseDir, "NillySnap.exe");
                        if (File.Exists(snapExe)) Process.Start(snapExe, "-edit");
                    } catch {}
                }
                return IntPtr.Zero;
            }
            return DefWindowProcW(hWnd, msg, wParam, lParam);
        }

        private static void LaunchQuickSnap() {
            if (_snapHwnd != IntPtr.Zero) return;
            try {
                _snapVX = GetSystemMetrics(76); // SM_XVIRTUALSCREEN
                _snapVY = GetSystemMetrics(77); // SM_YVIRTUALSCREEN
                _snapVW = GetSystemMetrics(78); // SM_CXVIRTUALSCREEN
                _snapVH = GetSystemMetrics(79); // SM_CYVIRTUALSCREEN
                if (_snapVW <= 0 || _snapVH <= 0) return;

                IntPtr scrDc = GetDC(IntPtr.Zero);
                if (scrDc == IntPtr.Zero) return;

                // 1. Freeze desktop instantly via pure Win32 BitBlt (~4 ms!)
                _snapSrcDc = CreateCompatibleDC(scrDc);
                _snapSrcBmp = CreateCompatibleBitmap(scrDc, _snapVW, _snapVH);
                _snapSrcOld = SelectObject(_snapSrcDc, _snapSrcBmp);
                BitBlt(_snapSrcDc, 0, 0, _snapVW, _snapVH, scrDc, _snapVX, _snapVY, 0x00CC0020 | 0x40000000);

                // 2. Pre-dimmed background copy (~3 ms ONCE!)
                _snapDimDc = CreateCompatibleDC(scrDc);
                _snapDimBmp = CreateCompatibleBitmap(scrDc, _snapVW, _snapVH);
                _snapDimOld = SelectObject(_snapDimDc, _snapDimBmp);
                BitBlt(_snapDimDc, 0, 0, _snapVW, _snapVH, _snapSrcDc, 0, 0, 0x00CC0020);
                IntPtr darkDc = CreateCompatibleDC(scrDc);
                IntPtr darkBmp = CreateCompatibleBitmap(scrDc, 1, 1);
                IntPtr darkOld = SelectObject(darkDc, darkBmp);
                RECT onePx = new RECT { Left = 0, Top = 0, Right = 1, Bottom = 1 };
                IntPtr blk = CreateSolidBrush(0x00120B07);
                FillRect(darkDc, ref onePx, blk);
                DeleteObject(blk);
                AlphaBlend(_snapDimDc, 0, 0, _snapVW, _snapVH, darkDc, 0, 0, 1, 1, (105u << 16));
                SelectObject(darkDc, darkOld); DeleteObject(darkBmp); DeleteDC(darkDc);

                // 3. Double-buffer back surface
                _snapBackDc = CreateCompatibleDC(scrDc);
                _snapBackBmp = CreateCompatibleBitmap(scrDc, _snapVW, _snapVH);
                _snapBackOld = SelectObject(_snapBackDc, _snapBackBmp);
                ReleaseDC(IntPtr.Zero, scrDc);

                // 4. Crisp fonts (18px bold Consolas for pixel dimensions + 14px Segoe UI for subtle hint)
                _snapFontBig   = CreateFontW(-17, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 5, 0, "Consolas");
                _snapFontSmall = CreateFontW(-13, 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 5, 0, "Segoe UI");

                IntPtr hInst;
                using (Process cp = Process.GetCurrentProcess())
                using (ProcessModule cm = cp.MainModule) { hInst = GetModuleHandle(cm.ModuleName); }

                if (!_snapClassRegistered) {
                    _snapWndProcDelegate = new WndProcDelegate(SnapWndProc);
                    WNDCLASSEXW swc = new WNDCLASSEXW();
                    swc.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEXW));
                    swc.lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_snapWndProcDelegate);
                    swc.hInstance = hInst;
                    swc.hCursor = LoadCursorW(IntPtr.Zero, (IntPtr)32515); // IDC_CROSS
                    swc.lpszClassName = "NillyInstantSnap_Overlay";
                    RegisterClassExW(ref swc);
                    _snapClassRegistered = true;
                }

                POINT cur; GetCursorPos(out cur);
                _snapMouseX = cur.X - _snapVX; _snapMouseY = cur.Y - _snapVY;
                _snapDragging = false;

                // WS_EX_TOPMOST (0x8) | WS_EX_TOOLWINDOW (0x80) | WS_POPUP (0x80000000) | WS_VISIBLE (0x10000000)
                _snapHwnd = CreateWindowExW(0x00000088, "NillyInstantSnap_Overlay", "NillyQuickSnap", 0x90000000,
                    _snapVX, _snapVY, _snapVW, _snapVH, IntPtr.Zero, IntPtr.Zero, hInst, IntPtr.Zero);
                if (_snapHwnd == IntPtr.Zero) {
                    throw new Exception("CreateWindowExW returned 0, err=" + Marshal.GetLastWin32Error());
                }
                ShowWindow(_snapHwnd, 5);
                SetForegroundWindow(_snapHwnd);
                SetFocus(_snapHwnd);
                UpdateWindow(_snapHwnd);
            } catch (Exception ex) {
                try {
                    File.AppendAllText(Path.Combine(_baseDir, "error.log"),
                        "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] QuickSnap error: " + ex.Message + Environment.NewLine);
                } catch {}
                CloseInstantSnap();
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
            if (msg == WM_HOTKEY && wParam.ToInt32() == HOTKEY_SNAP) {
                LaunchQuickSnap();
                return IntPtr.Zero;
            }
            if (msg == WM_DO_SNAP)    { LaunchQuickSnap(); return IntPtr.Zero; }
            if (msg == WM_CLOSE_SNAP) { CloseInstantSnap(); return IntPtr.Zero; }
            if (msg == WM_RELOAD_CFG) { _lastFgHwnd = IntPtr.Zero; LoadConfig(); DumpStats(); return IntPtr.Zero; }
            if (msg == WM_DUMP_STATS) { DumpStats(); return IntPtr.Zero; }
            if (msg == WM_TOGGLE_EN)  { _isEnabled = !_isEnabled; UpdateTrayTip(); DumpStats(); return IntPtr.Zero; }
            if (msg == WM_RESET_STAT) { ResetStats(); return IntPtr.Zero; }
            if (msg == WM_EXIT_APP)   { PostQuitMessage(0); return IntPtr.Zero; }
            if (msg == WM_TIMER) {
                long id = wParam.ToInt64();
                if (id == 1) { KillTimer(hWnd, (UIntPtr)1); TrimMemory(); }
                else if (id == 3) { UpdateAutoDisableState(); }
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

                // Ensure 1:1 physical pixel coordinates on 100%-200% DPI screens + AboveNormal priority
                try { SetProcessDPIAware(); } catch {}
                try { Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.AboveNormal; } catch {}

                _baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
                _cfgPath = Path.Combine(_baseDir, "chatter_config.txt");
                _statsPath = Path.Combine(_baseDir, "chatter_stats.txt");

                InitKeyMaps();
                LoadConfig();

                IntPtr hInst;
                using (Process curProc = Process.GetCurrentProcess())
                using (ProcessModule curMod = curProc.MainModule) {
                    hInst = GetModuleHandle(curMod.ModuleName);
                }

                string icoPath = Path.Combine(_baseDir, "PCManagerLite.ico");
                if (File.Exists(icoPath)) {
                    _hIcon = LoadImageW(IntPtr.Zero, icoPath, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
                }
                if (_hIcon == IntPtr.Zero) {
                    _hIcon = LoadIconW(IntPtr.Zero, (IntPtr)32512);
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
                // Side-by-side backup screenshot hotkey: Ctrl+Alt+S (handled BOTH via WH_KEYBOARD_LL & RegisterHotKey!)
                RegisterHotKey(_hWnd, HOTKEY_SNAP, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 0x53);

                _hookDelegate = new LowLevelKeyboardProc(HookCallback);
                _hHook = SetWindowsHookEx(WH_KEYBOARD_LL, _hookDelegate, hInst, 0);

                // Write initial diagnostic stats immediately so health/hook/config can be verified!
                DumpStats();

                // Timer 1: one-time initial RAM trim (2s) | Timer 3: lightweight fullscreen/program poll (2.5s)
                SetTimer(_hWnd, (UIntPtr)1, 2000, IntPtr.Zero);
                SetTimer(_hWnd, (UIntPtr)3, 2500, IntPtr.Zero);

                MSG m;
                while (GetMessageW(out m, IntPtr.Zero, 0, 0) > 0) {
                    TranslateMessage(ref m);
                    DispatchMessageW(ref m);
                }

                if (_hHook != IntPtr.Zero) UnhookWindowsHookEx(_hHook);
                UnregisterHotKey(_hWnd, HOTKEY_SNAP);
                RemoveTrayIcon();
                if (_hIcon != IntPtr.Zero) DestroyIcon(_hIcon);
                if (_hWnd != IntPtr.Zero) DestroyWindow(_hWnd);
                return 0;
            }
        }
    }
}
