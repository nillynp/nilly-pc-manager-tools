# Nilly PC Manager & Tools v4.2

**Ultra-lightweight (< 520 KB, ~140 KB ZIP), zero-background-RAM Windows 10/11 System Manager, Graphic Design & SEO Suite + Ultra-Light Win32 Keyboard Chatter Blocker + QuickSnap + 1-Click NillyDoc Pro Launcher.**

Built to replace heavy background bloatware & 13+ separate apps (Microsoft PC Manager, PowerToys 1.3+ GB, 47 MB KeyboardChatterBlocker, CPU-Z, GPU-Z, Sticky Notes, online expiring QR/barcode sites, DPI calculators, SEO/Base64 web tools, RAM/cache scripts) with **one** sleek, dark-themed, native, 100% portable desktop suite.

> **created by Nilly graphics (Sotiris Christos)**
> Official app pages: **[Ελληνικά](https://nillygraphics.com/nilly-pc-manager-tools/el/)** · **[English](https://nillygraphics.com/nilly-pc-manager-tools/en/)**
> Direct Portable Download: **[Latest GitHub Release (ZIP + SHA-256)](https://github.com/nillynp/nilly-pc-manager-tools/releases/latest)**
> Companion PDF Studio (~2 MB): **[NillyDoc Pro — Ultra-Light Acrobat-Style PDF Editor](https://github.com/nillynp/nillydoc-pro)**

---

## Why Nilly PC Manager & Tools?

- **0 MB Background RAM:** The main suite never registers in Startup, installs zero Windows services, leaves zero lingering processes when closed, and enforces single-instance focus.
- **< 500 KB Unpacked (~180 KB Portable ZIP):** 100% pure Windows-native WPF + Win32 / C# (zero Electron, zero WebView2, zero Node/Python runtime dependencies).
- **16 Lazy-Loaded Modules:** Every QuickTool lives in its own `.psm1` module under `tools/` and loads only when clicked (`0 KB` RAM until used).
- **Full Native Dark Theme:** Custom dark Win11 titlebar, dark ComboBox dropdowns, sleek scrollbars, responsive layout, and high-DPI awareness.
- **100% Safe & Open-Source:** Zero telemetry, zero background network calls (optional 1-click GitHub Update Check only when clicked), never touches Docker, Documents, Xbox, Phone Link, WebView2, browser cookies, passwords, or personal files.

---

## Included Modules (16 Modular Tools)

### System Management
- **PC Boost & Overview:** Instant Win32 RAM working-set trim (`EmptyWorkingSet`), User Temp cleanup, live uptime, and multi-drive health bars.
- **My Hub (`tools/MyHub.psm1`):** 1-click **Clean RAM Purge**, **Firefox Cache Clean & Restart** (tabs, cookies & passwords stay intact), plus automatic detection of local workflow tools.
- **Keyboard Chatter Blocker (`tools/ChatterBlocker.psm1` + `tools/NillyChatterBlocker.cs`):** Ultra-light pure-Win32 `WH_KEYBOARD_LL` tray daemon (`~33 KB`, **`~0.5 MB` WS RAM** vs 47 MB original!), compiled natively via Windows' built-in `csc.exe`, with full per-key analytics (`Presses`, `Blocked`, `% Chatter`, `Min/Max ms`, fault detection), per-key `ms` overrides, D3D Fullscreen game auto-pause, non-blocking live refresh, stable cursor toggle, optional Startup, and global **`Ctrl+Alt+S`** QuickSnap trigger.
- **On-Demand Apps Control:** Auto-detects heavy background suites (**Dropbox**, **Razer Synapse**, **Logi Options+**, **Logitech G HUB**) for 1-click Close/Launch + **Focus / Game Mode** & **Restore**.
- **Startup Manager (`tools/StartupManager.psm1`):** Clean Windows Startup manager (`HKCU\Run`, `HKLM\Run`, `HKLM32\Run`, `Startup` folder) with exact `StartupApproved` status, live RAM usage, and reversible 1-click Enable/Disable toggles.
- **Deep Safe Cleaner:** Fast native C# directory scanner for User Temp, Firefox/Brave/Chrome/Edge caches, Chrome On-Device AI model cache, Spotify caches, npm/pip/CrashDumps, Recycle Bin & Admin Windows Update/DISM cleanup.
- **RAM Process Manager:** Top 35 grouped memory consumers with live search filter and critical process protection.
- **Hardware & Specs (`tools/HardwareSpecs.psm1`):** Full **CPU-Z + GPU-Z replacement** — CPU cores/clocks/L2+L3 cache/stepping/virtualization, Motherboard/BIOS, RAM SPD slot-by-slot (channels/DDR gen/MHz/voltage/part number), GPU 64-bit VRAM/VBIOS/subvendor/PCIe ID/driver date/refresh rate, monitors, SSD SMART health & Local IP + 1-click Copy Report.
- **Protection, About & Update Check:** Windows Defender Quick Scan, DNS Flush + latency test (`1.1.1.1`), Taskbar Explorer repair, Windows Settings shortcuts, and 1-click on-demand GitHub Update Check.

### Graphic Design, Print & SEO Tools
1. **Color Picker Pro (`tools/ColorPicker.psm1`):** 120 FPS Screen Zoom Loupe (`11×11` pixel grid, `10×–24×` wheel zoom, `±1px` arrow nudge) + **Live Spy (`Click/F2`)** + HEX, RGB, HSL, CMYK, CSS Variable, WCAG 2.1 Contrast (AA/AAA), Tints/Shades & History.
2. **QR Code & Barcode Pro (`tools/QrBarcode.psm1`):** 100% offline static ISO/IEC 18004 QR Codes (Versions 1–20, iPhone/Android native URL/vCard 3.0/Wi-Fi/Phone/WhatsApp, rounded dots, contrast warning) + **9 ISO/GS1 Barcodes** (`EAN-13`, `EAN-8`, `ITF-14` with GS1 Bearer Box, `UPC-A`, `UPC-E`, `ISBN-13`, `ISSN`, `Code 128 Auto B/C`, `Code 39`) → True Vector `.SVG`, 300-DPI `.PNG`, Clipboard & local client archive.
3. **Print, DPI & Social Sizes Calculator (`tools/PrintDpi.psm1`):** `mm/cm ↔ px` (`72/150/300/600 DPI`), automatic **+3mm / +5mm Bleed**, 15 Print & Social presets, Aspect Ratio, Megapixels & proportional scale.
4. **Nilly QuickSnap & Pixel Ruler (`tools/PixelRuler.psm1` + `tools/NillySnap.cs`):** Ultra-fast `0 MB` background RAM screen capture (`Ctrl+Alt+S`, side-by-side backup to Windows Snipping Tool without touching `Win+Shift+S`!) with live `W × H px` Pixel Ruler, Fullscreen (`F`), 3s Delay, Arrow (`A`), Box (`R`), Pen (`P`), Highlighter (`H`), **Blur/Pixelate (`B`)**, Undo (`Ctrl+Z`), Auto-Copy PNG (`Enter`) & Save PNG (`Ctrl+S`).
5. **Image Resizer & Converter (`tools/ImageResizer.psm1`):** Drag & Drop batch resize with EXIF orientation support, presets, JPG quality slider & PNG conversion (saves safely into `_resized/`).
6. **NillyDoc Pro (1-Click PDF Studio Launcher):** Instant auto-detecting launcher for **[NillyDoc Pro](https://github.com/nillynp/nillydoc-pro)** (~2 MB Acrobat-style PDF editor with Greek editing, comments, signatures & Multi-Image→PDF resize) — opens locally if installed or links to the free GitHub release on new PCs.
7. **Images → PDF Creator (`tools/ImagesToPdf.psm1`):** Pure zero-dependency C# PDF 1.4 writer — Drag & Drop images, reorder pages, A4 Portrait/Landscape/Full-Bleed & quality presets.
8. **Batch Renamer & SEO Slug (`tools/BatchRenamer.psm1`):** Drag & Drop batch renaming with **Greek → Latin SEO URL Slug** conversion, Find/Replace, numbering, Live Preview & 1-Click Undo.
9. **SEO, Text & Password Toolkit (`tools/SeoText.psm1`):** Google SERP Title (60c) & Meta Desc (155c) live checker/preview + Greek→SEO Slug + HTML Meta tags, Plain Text Cleaner & Case Converter, and Crypto Password Generator.
10. **SVG / Image → Base64 & File Hash (`tools/Base64Hash.psm1`):** Drag & Drop SVG/PNG/JPG/WebP/ICO → Data URI, HTML `<img>` & CSS `url()` + native SHA-256 & MD5 hashes.

### Utilities
10. **Quick Notes & Client Snippets (`tools/QuickNotes.psm1`):** Lightweight **Sticky Notes replacement** — local scratchpad + 1-click Copy snippets stored privately in `notes.json` (gitignored).
11. **File Locksmith (`tools/FileLocksmith.psm1`):** Native Windows Restart Manager API (`rstrtmgr.dll`) to detect and safely unlock files held by running processes.
12. **Always On Top (`tools/AlwaysOnTop.psm1`):** Win32 window manager to Pin/Unpin any open desktop window above all others with 1 click.

### Bonus: Self-Hosted Dynamic QR (`hostinger-qr/`)
- Optional ~7 KB PHP 8 + JSON redirector for Hostinger so you can host editable client QR codes under your own domain with zero monthly subscriptions.

---

## Quick Start on ANY Windows 10 / 11 PC (100% Portable!)

1. Download the `Nilly-PC-Manager-Tools-*-Portable.zip` asset from the **[latest GitHub release](https://github.com/nillynp/nilly-pc-manager-tools/releases/latest)** and extract it anywhere (e.g. `C:\Tools\NillyPCManager`).
2. Double-click **`Install_Desktop_Shortcut.bat`** *(clears Windows download block & creates Desktop + Start Menu shortcuts — zero admin rights, zero Startup entries, 0 MB background RAM!)*.
   - Or just double-click **`Launch_PCManagerLite.vbs`** directly!
3. To remove cleanly anytime, double-click **`Uninstall_Shortcuts.bat`** and delete the folder.

---

**Author:** created by **Nilly graphics (Sotiris Christos)**
**App setup and download guide:** [Ελληνικά](https://nillygraphics.com/nilly-pc-manager-tools/el/) · [English](https://nillygraphics.com/nilly-pc-manager-tools/en/)
**License:** MIT
