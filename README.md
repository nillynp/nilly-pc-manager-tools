# Nilly PC Manager & Tools v3.1

**Ultra-lightweight (~340 KB), zero-background-RAM Windows 10/11 System Manager & Graphic Designer QuickTools Suite.**
Built to replace heavy background bloatware & 10+ separate apps (Microsoft PC Manager, PowerToys 1.3+ GB, CPU-Z, GPU-Z, Sticky Notes, online expiring QR/barcode sites, RAM/cache scripts) with **one** clean, native, on-demand desktop suite.

> **created by Nilly graphics (Sotiris Christos)**
> Official Website: **[https://nillygraphics.com/](https://nillygraphics.com/)**

---

## Why Nilly PC Manager & Tools?

- **0 MB Background RAM:** Never registers in Startup, installs zero Windows services, leaves zero lingering processes when closed. Opens only when you want it.
- **~260 KB Total Footprint:** Pure Windows-native WPF + Win32 / C# (zero Electron, zero WebView2, zero Node/Python runtime dependencies).
- **Lazy-Loaded Modular Architecture:** Every QuickTool lives in its own lightweight `.psm1` module under `tools/` and loads only when clicked.
- **100% Safe by Design:** Never touches Docker, Documents, Xbox, Phone Link, WebView2, browser cookies, passwords, or personal files.

---

## Included Modules

### System Management
- **PC Boost & Overview:** Instant Win32 RAM working-set trim (`EmptyWorkingSet`), User Temp cleanup, live system uptime, and multi-drive health bars (`C:`, `H:`, `J:`, etc.).
- **On-Demand Apps Control:** 1-click Close/Launch toggles for heavy background suites (**Dropbox**, **Razer Synapse 4**, **Logi Options+**, **Logitech G HUB**) + 1-click **Focus / Game Mode** & **Restore**.
- **Deep Safe Cleaner:** Fast native C# directory scanner for User Temp, Firefox/Brave/Chrome/Edge caches, Chrome On-Device AI model cache (`OptGuideOnDeviceModel`), Spotify caches, npm/pip/CrashDumps, Recycle Bin & Admin Windows Update/DISM cleanup.
- **RAM Process Manager:** Top 35 grouped memory consumers with live search filter and critical process protection.
- **Protection & Quick Tools:** Windows Defender Quick Scan, DNS Flush + latency test (`1.1.1.1`), Taskbar Explorer repair & Windows Settings shortcuts.

### Nilly QuickTools (Lightweight PowerToys & Designer Replacement)
1. **Color Picker Pro (`tools/ColorPicker.psm1`):**
   - Double-buffered 120 FPS Screen Zoom Loupe (`11×11` pixel grid, mouse wheel zoom `10×–24×`, `±1px` arrow-key nudging).
   - **Live Spy (`Click / F2`):** Real-time pixel reader over any window/video — left-click to lock & auto-copy `#HEX`.
   - Instant conversion to **HEX**, **RGB**, **HSL**, **CMYK (Print)**, **CSS Variable**, **WCAG 2.1 Contrast (AA/AAA)**, 7-step **Tints & Shades**, and color history.
2. **QR Code & Barcode Pro (`tools/QrBarcode.psm1`):**
   - **100% Offline Static ISO/IEC 18004 QR Codes (Versions 1–20)** — never expire, native iPhone & Android Camera support (**URL**, **vCard 3.0 UTF-8**, **Wi-Fi 1-tap**, **Phone**, **WhatsApp**, **Text**), ECC L/M/Q/H, Rounded Dots style, contrast check.
   - **9 ISO/GS1 Retail & Packaging Barcodes:** **EAN-13** (`520...` Greece/EU), **EAN-8**, **ITF-14** (with GS1 Bearer Box for shipping cartons), **UPC-A**, **UPC-E**, **ISBN-13** (books), **ISSN** (magazines), **Code 128 Auto B/C** (SKUs/courier), and **Code 39** — all with automatic check-digit calculation/validation.
   - **Print-Ready Exports:** True **Vector `.SVG`** (infinite DPI for Affinity/Illustrator/Corel), **300-DPI High-Res `.PNG`**, **Clipboard Copy**, and local client archive (`saved_codes.json`, gitignored).
3. **Image Resizer & Converter (`tools/ImageResizer.psm1`):**
   - Drag & Drop batch resizing with EXIF rotation support (safe for iPhone photos), presets (Full HD 1920, Web 1200, Instagram 1080, 600px, 50%, Custom), JPG quality slider & PNG conversion. Always saves safely inside `_resized/`.
4. **Batch Renamer & SEO Slug (`tools/BatchRenamer.psm1`):**
   - Drag & Drop batch renaming with **Greek → Latin SEO URL Slug** conversion (`Φωτογραφία Προϊόντος 01.jpg` → `fotografia-proiontos-01.jpg`), Find/Replace, Prefix/Suffix, numbering, **Live Preview**, and **1-Click Undo**.
5. **File Locksmith (`tools/FileLocksmith.psm1`):**
   - Native Windows Restart Manager API (`rstrtmgr.dll`) to identify which process locks any file and safely unlock it.
6. **Always On Top (`tools/AlwaysOnTop.psm1`):**
   - Win32 window manager to Pin/Unpin any open desktop window above all others with 1 click.
7. **My Hub (`tools/MyHub.psm1`):**
   - Unified 1-click **Clean RAM Purge**, **Firefox Cache Clean & Restart** (keeps open tabs/cookies/passwords intact), **Master Backup Monitor/Trigger**, and **G-Phonor Voice-to-Text** toggle.
8. **Hardware & System Specs (`tools/HardwareSpecs.psm1`):**
   - Lightweight **CPU-Z + GPU-Z replacement**: CPU cores/clocks, Motherboard/BIOS, RAM sticks slot-by-slot (GB/MHz/manufacturer), GPU VRAM & driver version, monitors, SSD SMART health & Local IP + 1-click Copy Report.
9. **Images → PDF Creator (`tools/ImagesToPdf.psm1`):**
   - Pure zero-dependency C# PDF 1.4 writer: Drag & Drop images, reorder pages, A4 Portrait/Landscape/Full-Bleed & quality presets.
10. **Quick Notes & Client Snippets (`tools/QuickNotes.psm1`):**
    - Lightweight **Sticky Notes replacement**: local scratchpad + 1-click Copy reusable snippets stored privately in `notes.json` (gitignored).

### Bonus: Self-Hosted Hostinger Dynamic QR (`hostinger-qr/`)
- Optional ~7 KB PHP 8 + JSON redirector (`index.php`, `admin.php`, `.htaccess`) for Hostinger so you can create **editable client QR codes** under your own domain (`https://nillygraphics.com/go/client`) with scan counters and zero monthly subscriptions.

---

## Quick Start on ANY Windows 10 / 11 PC (100% Portable!)
1. Click **Code → Download ZIP** (or `git clone https://github.com/nillynp/nilly-pc-manager-tools.git`) and extract anywhere.
2. Double-click **`Install_Desktop_Shortcut.bat`** *(unblocks downloaded files & creates the `PC Manager & Tools` Desktop icon — no admin rights, zero Startup entries, 0 MB background RAM!)*.
   - Or just double-click **`Launch_PCManagerLite.vbs`** directly to run without even creating a shortcut!

---

**Author:** created by **Nilly graphics (Sotiris Christos)**
**Website:** [https://nillygraphics.com/](https://nillygraphics.com/)
**License:** MIT
