<#
.SYNOPSIS
    Nilly QuickTools — Screen Pixel Ruler & Quick Region Screenshot
    Drag anywhere on screen to measure exact W x H px + Aspect Ratio and copy/save crisp PNG capture!
    Double-buffered 120 FPS Win32 overlay (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ([System.Management.Automation.PSTypeName]'NillyRulerCaptureForm').Type) {
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class NillyRulerCaptureForm : Form {
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
    [DllImport("gdi32.dll")]  static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, int rop);

    private Bitmap _screenBmp;
    private Rectangle _vScreen;
    private bool _dragging = false;
    private Point _startPt;
    private Point _currPt;
    public Rectangle Selection { get; private set; }
    public Bitmap CapturedCrop { get; private set; }
    public bool HasSelection { get; private set; }
    public bool CaptureOk { get; private set; }
    public string ErrorMessage { get; private set; }

    public NillyRulerCaptureForm() {
        HasSelection = false;
        _vScreen = SystemInformation.VirtualScreen;
        string err;
        _screenBmp = CaptureDesktop(_vScreen, out err);
        if (_screenBmp == null) {
            CaptureOk = false;
            ErrorMessage = err ?? "Screen capture failed.";
            return;
        }
        CaptureOk = true;

        this.FormBorderStyle = FormBorderStyle.None;
        this.StartPosition = FormStartPosition.Manual;
        this.Bounds = _vScreen;
        this.TopMost = true;
        this.ShowInTaskbar = false;
        this.DoubleBuffered = true;
        this.Cursor = Cursors.Cross;
        this.KeyPreview = true;
    }

    private static Bitmap CaptureDesktop(Rectangle bounds, out string error) {
        error = null;
        if (bounds.Width <= 0 || bounds.Height <= 0) { error = "Invalid bounds"; return null; }
        Bitmap bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
        try {
            IntPtr srcDc = GetDC(IntPtr.Zero);
            if (srcDc != IntPtr.Zero) {
                try {
                    using (Graphics g = Graphics.FromImage(bmp)) {
                        IntPtr dstDc = g.GetHdc();
                        try {
                            if (BitBlt(dstDc, 0, 0, bounds.Width, bounds.Height, srcDc, bounds.Left, bounds.Top, 0x00CC0020 | 0x40000000))
                                return bmp;
                        } finally { g.ReleaseHdc(dstDc); }
                    }
                } finally { ReleaseDC(IntPtr.Zero, srcDc); }
            }
        } catch {}
        try {
            using (Graphics g = Graphics.FromImage(bmp)) g.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, bounds.Size);
            return bmp;
        } catch (Exception ex) { bmp.Dispose(); error = ex.Message; return null; }
    }

    private Rectangle GetRect() {
        int x = Math.Min(_startPt.X, _currPt.X);
        int y = Math.Min(_startPt.Y, _currPt.Y);
        int w = Math.Abs(_currPt.X - _startPt.X);
        int h = Math.Abs(_currPt.Y - _startPt.Y);
        return new Rectangle(x, y, w, h);
    }

    protected override void OnShown(EventArgs e) { base.OnShown(e); this.Activate(); this.Focus(); }
    protected override void OnKeyDown(KeyEventArgs e) { if (e.KeyCode == Keys.Escape) { HasSelection = false; this.Close(); } base.OnKeyDown(e); }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button == MouseButtons.Right) { HasSelection = false; this.Close(); return; }
        if (e.Button == MouseButtons.Left) { _dragging = true; _startPt = e.Location; _currPt = e.Location; this.Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        _currPt = e.Location;
        if (_dragging) this.Invalidate();
        base.OnMouseMove(e);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        if (_dragging && e.Button == MouseButtons.Left) {
            _dragging = false;
            Rectangle r = Rectangle.Intersect(GetRect(), new Rectangle(0, 0, _screenBmp.Width, _screenBmp.Height));
            if (r.Width >= 2 && r.Height >= 2) {
                Selection = r;
                CapturedCrop = _screenBmp.Clone(r, PixelFormat.Format32bppArgb);
                HasSelection = true;
            }
            this.Close();
        }
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        if (_screenBmp == null) return;
        Graphics g = e.Graphics;
        g.DrawImageUnscaled(_screenBmp, 0, 0);

        // Subtle dark dim outside selection
        using (SolidBrush dim = new SolidBrush(Color.FromArgb(95, 7, 11, 18))) {
            g.FillRectangle(dim, 0, 0, _screenBmp.Width, _screenBmp.Height);
        }

        if (_dragging) {
            Rectangle r = GetRect();
            if (r.Width > 0 && r.Height > 0) {
                g.DrawImage(_screenBmp, r, r, GraphicsUnit.Pixel);
                using (Pen p = new Pen(Color.FromArgb(255, 56, 189, 248), 2)) g.DrawRectangle(p, r);
            }
            string ratio = r.Height > 0 ? string.Format("{0:F2}:1", (double)r.Width / r.Height) : "-";
            string badge = string.Format("{0} × {1} px  ({2})  |  Release = Capture  |  Esc = Cancel", r.Width, r.Height, ratio);
            using (Font f = new Font("Consolas", 10.5f, FontStyle.Bold)) {
                SizeF sz = g.MeasureString(badge, f);
                int bx = Math.Max(8, Math.Min(_screenBmp.Width - (int)sz.Width - 20, r.Left));
                int by = (r.Top - 32 > 8) ? (r.Top - 32) : (r.Bottom + 8);
                using (SolidBrush bg = new SolidBrush(Color.FromArgb(240, 11, 15, 23)))
                using (Pen bp = new Pen(Color.FromArgb(255, 56, 189, 248), 1))
                using (SolidBrush fg = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.FillRectangle(bg, bx, by, sz.Width + 14, 26);
                    g.DrawRectangle(bp, bx, by, sz.Width + 14, 26);
                    g.DrawString(badge, f, fg, bx + 7, by + 5);
                }
            }
        } else {
            string hint = "Σύρε με το ποντίκι για Μέτρηση Pixels & Screenshot  |  Esc ή Δεξί κλικ για ακύρωση";
            using (Font f = new Font("Segoe UI", 11f, FontStyle.Bold)) {
                SizeF sz = g.MeasureString(hint, f);
                int bx = (_screenBmp.Width - (int)sz.Width) / 2 - 12;
                using (SolidBrush bg = new SolidBrush(Color.FromArgb(235, 11, 15, 23)))
                using (Pen bp = new Pen(Color.FromArgb(255, 56, 189, 248), 1))
                using (SolidBrush fg = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.FillRectangle(bg, bx, 24, sz.Width + 24, 34);
                    g.DrawRectangle(bp, bx, 24, sz.Width + 24, 34);
                    g.DrawString(hint, f, fg, bx + 12, 31);
                }
            }
        }
    }

    protected override void Dispose(bool disposing) {
        if (disposing && _screenBmp != null) { _screenBmp.Dispose(); _screenBmp = null; }
        base.Dispose(disposing);
    }
}
"@
}

$script:PRState = @{
    Initialized = $false
    MainWindow  = $null
    Ui          = $null
    RootDir     = $null
    SnapExe     = $null
    SnapSrc     = $null
    LastCrop    = $null
    LastDims    = ""
}

function Ensure-NillySnapCompiled {
    param([switch]$ForceRebuild)
    $exe = $script:PRState.SnapExe
    $src = $script:PRState.SnapSrc
    if (-not $src -or -not (Test-Path $src)) { return $false }

    $needBuild = $ForceRebuild -or (-not (Test-Path $exe))
    if (-not $needBuild) {
        if ((Get-Item $src).LastWriteTimeUtc -gt (Get-Item $exe).LastWriteTimeUtc) { $needBuild = $true }
    }
    if (-not $needBuild) { return $true }

    $csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) { $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
    if (-not (Test-Path $csc)) { return $false }

    $ico = Join-Path $script:PRState.RootDir "PCManagerLite.ico"
    $args = @('/nologo','/target:winexe','/optimize+','/platform:x64','/r:System.Drawing.dll','/r:System.Windows.Forms.dll')
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

function Invoke-NillyQuickSnap {
    param([int]$DelaySec = 0, [switch]$EditMode)
    if (-not (Ensure-NillySnapCompiled)) {
        $script:PRState.Ui.TxtPRStatus.Text = "Αποτυχία compile του NillySnap.exe."
        return
    }
    $mw = $script:PRState.MainWindow
    $prevState = $mw.WindowState
    $outPng = Join-Path $script:PRState.RootDir "last_snap.png"
    $outMeta = "$outPng.meta"
    Remove-Item $outPng, $outMeta -Force -ErrorAction SilentlyContinue

    $mw.Hide()
    Start-Sleep -Milliseconds 160
    try {
        $argParts = @("-out `"$outPng`"")
        if ($DelaySec -gt 0) { $argParts += "-delay $DelaySec" }
        if ($EditMode) { $argParts += "-edit" }
        $p = Start-Process -FilePath $script:PRState.SnapExe -ArgumentList ($argParts -join ' ') -PassThru
        $p.WaitForExit()
    } finally {
        $mw.Show()
        $mw.WindowState = $prevState
        $mw.Activate() | Out-Null
    }

    if (Test-Path $outPng) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($outPng)
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            $bmp = New-Object System.Drawing.Bitmap($ms)
            $clone = New-Object System.Drawing.Bitmap($bmp)
            $bmp.Dispose(); $ms.Dispose()
            if ($script:PRState.LastCrop) { $script:PRState.LastCrop.Dispose() }
            $script:PRState.LastCrop = $clone
            $script:PRState.Ui.ImgPRPreview.Source = Convert-RulerBmpToWpf $clone
            $dims = "$($clone.Width) × $($clone.Height) px"
            $ratio = if ($clone.Height -gt 0) { [math]::Round($clone.Width / $clone.Height, 2) } else { 0 }
            $script:PRState.LastDims = $dims
            $script:PRState.Ui.TxtPRDims.Text = "$dims  •  Ratio ${ratio}:1  •  Nilly QuickSnap (έτοιμο στο Clipboard!)"
            $script:PRState.Ui.TxtPRStatus.Text = "Έτοιμο Screenshot ($dims) με QuickSnap — αντιγράφηκε ήδη στο Clipboard (Ctrl+V)!"
        } catch {
            $script:PRState.Ui.TxtPRStatus.Text = "Η λήψη ολοκληρώθηκε."
        }
    } else {
        $script:PRState.Ui.TxtPRStatus.Text = "Ακυρώθηκε η λήψη QuickSnap (0 MB background RAM)."
    }
}

function Convert-RulerBmpToWpf([System.Drawing.Bitmap]$Bmp) {
    $ms = New-Object System.IO.MemoryStream
    $Bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $ms.Position = 0
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bi.StreamSource = $ms; $bi.EndInit(); $bi.Freeze(); $ms.Dispose()
    return $bi
}

function Initialize-PixelRulerTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap, [string]$RootDir = "")
    if ($script:PRState.Initialized) { return }
    $script:PRState.Initialized = $true
    $script:PRState.MainWindow  = $MainWindow
    $script:PRState.Ui          = $UiMap
    if ($RootDir) {
        $script:PRState.RootDir = $RootDir
        $script:PRState.SnapExe = Join-Path $RootDir "NillySnap.exe"
        $script:PRState.SnapSrc = Join-Path (Join-Path $RootDir "tools") "NillySnap.cs"
    }

    if ($UiMap.BtnPRQuickSnap) {
        $UiMap.BtnPRQuickSnap.Add_Click({ Invoke-NillyQuickSnap -DelaySec 0 -EditMode })
    }
    if ($UiMap.BtnPRDelay3) {
        $UiMap.BtnPRDelay3.Add_Click({ Invoke-NillyQuickSnap -DelaySec 3 -EditMode })
    }

    $UiMap.BtnPRStart.Add_Click({
        $mw = $script:PRState.MainWindow
        $prevState = $mw.WindowState
        $mw.Hide()
        Start-Sleep -Milliseconds 180
        $crop = $null; $rect = $null; $errMsg = $null
        try {
            $frm = New-Object NillyRulerCaptureForm
            if (-not $frm.CaptureOk) { $errMsg = $frm.ErrorMessage }
            else {
                [void]$frm.ShowDialog()
                if ($frm.HasSelection) {
                    $crop = $frm.CapturedCrop
                    $rect = $frm.Selection
                }
            }
            $frm.Dispose()
        } catch { $errMsg = $_.Exception.Message }
        finally {
            $mw.Show()
            $mw.WindowState = $prevState
            $mw.Activate() | Out-Null
        }

        if ($errMsg) {
            $script:PRState.Ui.TxtPRStatus.Text = "Σφάλμα capture: $errMsg"
        } elseif ($crop) {
            if ($script:PRState.LastCrop) { $script:PRState.LastCrop.Dispose() }
            $script:PRState.LastCrop = $crop
            $wpfImg = Convert-RulerBmpToWpf $crop
            $script:PRState.Ui.ImgPRPreview.Source = $wpfImg
            $ratio = if ($rect.Height -gt 0) { [math]::Round($rect.Width / $rect.Height, 2) } else { 0 }
            $dims = "$($rect.Width) × $($rect.Height) px"
            $script:PRState.LastDims = $dims
            $script:PRState.Ui.TxtPRDims.Text = "$dims  •  Ratio ${ratio}:1  •  Θέση ($($rect.X), $($rect.Y))"
            if ($script:PRState.Ui.ChkPRAutoCopy.IsChecked) {
                try { [System.Windows.Clipboard]::SetImage($wpfImg) } catch {}
                $script:PRState.Ui.TxtPRStatus.Text = "Μετρήθηκε $dims & αντιγράφηκε το Screenshot στο Clipboard (Ctrl+V)!"
            } else {
                $script:PRState.Ui.TxtPRStatus.Text = "Μετρήθηκε $dims — έτοιμο για Copy ή Αποθήκευση PNG."
            }
        } else {
            $script:PRState.Ui.TxtPRStatus.Text = "Ακυρώθηκε η μέτρηση / λήψη."
        }
    })

    $UiMap.BtnPRCopyImg.Add_Click({
        if (-not $script:PRState.LastCrop) { $script:PRState.Ui.TxtPRStatus.Text = "Κάνε πρώτα μια λήψη."; return }
        try {
            [System.Windows.Clipboard]::SetImage((Convert-RulerBmpToWpf $script:PRState.LastCrop))
            $script:PRState.Ui.TxtPRStatus.Text = "Αντιγράφηκε το Screenshot στο Clipboard!"
        } catch {}
    })

    $UiMap.BtnPRCopyDims.Add_Click({
        if ($script:PRState.LastDims) {
            try { [System.Windows.Clipboard]::SetDataObject($script:PRState.LastDims, $true) } catch {}
            $script:PRState.Ui.TxtPRStatus.Text = "Αντιγράφηκαν οι διαστάσεις: $($script:PRState.LastDims)"
        }
    })

    $UiMap.BtnPRSavePng.Add_Click({
        if (-not $script:PRState.LastCrop) { $script:PRState.Ui.TxtPRStatus.Text = "Κάνε πρώτα μια λήψη."; return }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "PNG Image (*.png)|*.png"
        $dlg.FileName = "nilly-capture-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
        if ($dlg.ShowDialog() -eq $true) {
            $script:PRState.LastCrop.Save($dlg.FileName, [System.Drawing.Imaging.ImageFormat]::Png)
            $script:PRState.Ui.TxtPRStatus.Text = "Αποθηκεύτηκε: $($dlg.FileName)"
        }
    })
}

Export-ModuleMember -Function Initialize-PixelRulerTool, Ensure-NillySnapCompiled
