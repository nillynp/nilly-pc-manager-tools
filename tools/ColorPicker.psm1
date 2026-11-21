<#
.SYNOPSIS
    Nilly QuickTools — Tool #1: Color Picker Pro (Rock-Solid Screen Zoom Loupe + Live Spy + HEX/RGB/HSL/CMYK/WCAG)
    Lazy-loaded PowerShell Module for PC Manager & Tools (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore

# Compiled native Win32 Pixel Spy + Double-Buffered 120 FPS Screen Zoom Loupe
if (-not ([System.Management.Automation.PSTypeName]'NillyColorLoupeForm').Type) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class NillyPixelSpy {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);

    [DllImport("gdi32.dll")]
    public static extern uint GetPixel(IntPtr hdc, int nXPos, int nYPos);

    [DllImport("gdi32.dll")]
    public static extern bool BitBlt(IntPtr hdcDest, int xDest, int yDest, int w, int h, IntPtr hdcSrc, int xSrc, int ySrc, int rop);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static Color GetColorAtCursor(out int x, out int y) {
        POINT p;
        GetCursorPos(out p);
        x = p.X; y = p.Y;
        IntPtr dc = GetDC(IntPtr.Zero);
        if (dc == IntPtr.Zero) return Color.Black;
        try {
            uint pixel = GetPixel(dc, p.X, p.Y);
            int r = (int)(pixel & 0x000000FF);
            int g = (int)((pixel & 0x0000FF00) >> 8);
            int b = (int)((pixel & 0x00FF0000) >> 16);
            return Color.FromArgb(255, r, g, b);
        } finally {
            ReleaseDC(IntPtr.Zero, dc);
        }
    }

    public static bool IsKeyPressed(int vKey) {
        return (GetAsyncKeyState(vKey) & 0x8000) != 0;
    }

    public static Bitmap CaptureVirtualScreen(out Rectangle bounds, out string error) {
        bounds = SystemInformation.VirtualScreen;
        error = null;
        if (bounds.Width <= 0 || bounds.Height <= 0) {
            error = "Invalid virtual screen bounds.";
            return null;
        }
        Bitmap bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
        // Method 1: Win32 BitBlt with SRCCOPY | CAPTUREBLT (captures layered windows cleanly)
        try {
            IntPtr srcDc = GetDC(IntPtr.Zero);
            if (srcDc != IntPtr.Zero) {
                try {
                    using (Graphics g = Graphics.FromImage(bmp)) {
                        IntPtr dstDc = g.GetHdc();
                        try {
                            const int SRCCOPY = 0x00CC0020;
                            const int CAPTUREBLT = 0x40000000;
                            if (BitBlt(dstDc, 0, 0, bounds.Width, bounds.Height, srcDc, bounds.Left, bounds.Top, SRCCOPY | CAPTUREBLT)) {
                                return bmp;
                            }
                        } finally {
                            g.ReleaseHdc(dstDc);
                        }
                    }
                } finally {
                    ReleaseDC(IntPtr.Zero, srcDc);
                }
            }
        } catch {}

        // Method 2: Fallback CopyFromScreen
        try {
            using (Graphics g = Graphics.FromImage(bmp)) {
                g.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy);
            }
            return bmp;
        } catch (Exception ex) {
            bmp.Dispose();
            error = ex.Message;
            return null;
        }
    }
}

public class NillyColorLoupeForm : Form {
    private Bitmap _screenBmp;
    private Rectangle _vScreen;
    private Point _mousePos;
    private int _cellSize = 14;
    public Color PickedColor { get; private set; }
    public bool HasPicked { get; private set; }
    public bool CaptureOk { get; private set; }
    public string ErrorMessage { get; private set; }

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int X, int Y);

    public NillyColorLoupeForm() {
        HasPicked = false;
        string err;
        _screenBmp = NillyPixelSpy.CaptureVirtualScreen(out _vScreen, out err);
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

        Point cur = Cursor.Position;
        _mousePos = new Point(
            Math.Max(0, Math.Min(_screenBmp.Width - 1, cur.X - _vScreen.Left)),
            Math.Max(0, Math.Min(_screenBmp.Height - 1, cur.Y - _vScreen.Top))
        );
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        this.Activate();
        this.Focus();
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        _mousePos = e.Location;
        this.Invalidate();
        base.OnMouseMove(e);
    }

    protected override void OnMouseWheel(MouseEventArgs e) {
        if (e.Delta > 0) _cellSize = Math.Min(24, _cellSize + 2);
        else if (e.Delta < 0) _cellSize = Math.Max(10, _cellSize - 2);
        this.Invalidate();
        base.OnMouseWheel(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left) {
            PickCurrent();
        } else if (e.Button == MouseButtons.Right) {
            HasPicked = false;
            this.Close();
        }
        base.OnMouseDown(e);
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        int dx = 0, dy = 0;
        if (e.KeyCode == Keys.Escape) { HasPicked = false; this.Close(); return; }
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) { PickCurrent(); return; }
        if (e.KeyCode == Keys.Left)  dx = -1;
        if (e.KeyCode == Keys.Right) dx = 1;
        if (e.KeyCode == Keys.Up)    dy = -1;
        if (e.KeyCode == Keys.Down)  dy = 1;
        if (dx != 0 || dy != 0) {
            int nx = Math.Max(0, Math.Min(_screenBmp.Width - 1, _mousePos.X + dx));
            int ny = Math.Max(0, Math.Min(_screenBmp.Height - 1, _mousePos.Y + dy));
            _mousePos = new Point(nx, ny);
            SetCursorPos(_vScreen.Left + nx, _vScreen.Top + ny);
            this.Invalidate();
        }
        base.OnKeyDown(e);
    }

    private void PickCurrent() {
        if (_screenBmp == null) { this.Close(); return; }
        int px = Math.Max(0, Math.Min(_screenBmp.Width - 1, _mousePos.X));
        int py = Math.Max(0, Math.Min(_screenBmp.Height - 1, _mousePos.Y));
        PickedColor = _screenBmp.GetPixel(px, py);
        HasPicked = true;
        this.Close();
    }

    protected override void OnPaint(PaintEventArgs e) {
        if (_screenBmp == null) return;
        Graphics g = e.Graphics;
        g.DrawImageUnscaled(_screenBmp, 0, 0);

        int px = Math.Max(0, Math.Min(_screenBmp.Width - 1, _mousePos.X));
        int py = Math.Max(0, Math.Min(_screenBmp.Height - 1, _mousePos.Y));
        Color c = _screenBmp.GetPixel(px, py);
        string hex = string.Format("#{0:X2}{1:X2}{2:X2}", c.R, c.G, c.B);
        string rgb = string.Format("RGB({0}, {1}, {2})", c.R, c.G, c.B);

        const int gridN = 11;
        const int half = gridN / 2;
        int cell = _cellSize;
        int loupeSize = gridN * cell;
        const int infoH = 60;
        const int pad = 9;
        int boxW = Math.Max(205, loupeSize + pad * 2);
        int boxH = loupeSize + infoH + pad * 2;

        int bx = px + 26;
        int by = py + 26;
        if (bx + boxW > _screenBmp.Width - 10)  bx = px - boxW - 26;
        if (by + boxH > _screenBmp.Height - 10) by = py - boxH - 26;
        if (bx < 8) bx = 8;
        if (by < 8) by = 8;

        using (SolidBrush cardBg = new SolidBrush(Color.FromArgb(245, 11, 15, 23)))
        using (Pen borderPen = new Pen(Color.FromArgb(255, 56, 189, 248), 2)) {
            g.FillRectangle(cardBg, bx, by, boxW, boxH);
            g.DrawRectangle(borderPen, bx, by, boxW, boxH);
        }

        int gx = bx + (boxW - loupeSize) / 2;
        int gy = by + pad;
        for (int iy = -half; iy <= half; iy++) {
            for (int ix = -half; ix <= half; ix++) {
                int sx = px + ix;
                int sy = py + iy;
                Color sc = (sx >= 0 && sx < _screenBmp.Width && sy >= 0 && sy < _screenBmp.Height)
                    ? _screenBmp.GetPixel(sx, sy)
                    : Color.Black;
                using (SolidBrush sb = new SolidBrush(sc)) {
                    g.FillRectangle(sb, gx + (ix + half) * cell, gy + (iy + half) * cell, cell, cell);
                }
            }
        }

        using (Pen gridPen = new Pen(Color.FromArgb(45, 255, 255, 255), 1)) {
            for (int i = 0; i <= gridN; i++) {
                g.DrawLine(gridPen, gx + i * cell, gy, gx + i * cell, gy + loupeSize);
                g.DrawLine(gridPen, gx, gy + i * cell, gx + loupeSize, gy + i * cell);
            }
        }

        int cx = gx + half * cell;
        int cy = gy + half * cell;
        using (Pen outerPen = new Pen(Color.Black, 2))
        using (Pen innerPen = new Pen(Color.FromArgb(255, 56, 189, 248), 2)) {
            g.DrawRectangle(outerPen, cx - 1, cy - 1, cell + 2, cell + 2);
            g.DrawRectangle(innerPen, cx, cy, cell, cell);
        }

        int fx = bx + pad;
        int fy = gy + loupeSize + 8;
        using (SolidBrush swBrush = new SolidBrush(c))
        using (Pen swPen = new Pen(Color.FromArgb(180, 255, 255, 255), 1)) {
            g.FillRectangle(swBrush, fx, fy + 2, 30, 30);
            g.DrawRectangle(swPen, fx, fy + 2, 30, 30);
        }

        using (Font fHex = new Font("Consolas", 11.5f, FontStyle.Bold))
        using (Font fSub = new Font("Segoe UI", 8f, FontStyle.Regular))
        using (SolidBrush whiteBrush = new SolidBrush(Color.FromArgb(248, 250, 252)))
        using (SolidBrush mutedBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
            g.DrawString(hex, fHex, whiteBrush, fx + 38, fy);
            g.DrawString(rgb, fSub, mutedBrush, fx + 38, fy + 18);
            g.DrawString("Click: Copy | Wheel: Zoom | Arrows: 1px | Esc", fSub, mutedBrush, fx, fy + 38);
        }
    }

    protected override void Dispose(bool disposing) {
        if (disposing && _screenBmp != null) {
            _screenBmp.Dispose();
            _screenBmp = null;
        }
        base.Dispose(disposing);
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:CPState = @{
    Initialized = $false
    MainWindow  = $null
    Ui          = $null
    History     = [System.Collections.Generic.List[string]]::new()
    Current     = $null
    BrushConv   = [Windows.Media.BrushConverter]::new()
    SpyTimer    = $null
    SpyActive   = $false
    SpyArmed    = $false
    SpyStartUtc = [DateTime]::MinValue
}

function Convert-RgbToColorInfo {
    param([int]$R, [int]$G, [int]$B)

    $R = [math]::Max(0, [math]::Min(255, $R))
    $G = [math]::Max(0, [math]::Min(255, $G))
    $B = [math]::Max(0, [math]::Min(255, $B))

    $hex = "#{0:X2}{1:X2}{2:X2}" -f $R, $G, $B
    $rgb = "rgb($R, $G, $B)"

    $rf = $R / 255.0; $gf = $G / 255.0; $bf = $B / 255.0
    $max = [math]::Max($rf, [math]::Max($gf, $bf))
    $min = [math]::Min($rf, [math]::Min($gf, $bf))
    $l = ($max + $min) / 2.0
    $h = 0.0; $s = 0.0
    if ($max -ne $min) {
        $d = $max - $min
        $s = if ($l -gt 0.5) { $d / (2.0 - $max - $min) } else { $d / ($max + $min) }
        if ($max -eq $rf) { $h = (($gf - $bf) / $d) + $(if ($gf -lt $bf) { 6.0 } else { 0.0 }) }
        elseif ($max -eq $gf) { $h = (($bf - $rf) / $d) + 2.0 }
        else { $h = (($rf - $gf) / $d) + 4.0 }
        $h *= 60.0
    }
    $hsl = "hsl($([math]::Round($h)), $([math]::Round($s * 100))%, $([math]::Round($l * 100))%)"

    $k = 1.0 - $max
    if ($k -ge 0.9999) {
        $cmyk = "cmyk(0%, 0%, 0%, 100%)"
    } else {
        $c  = [math]::Round(((1.0 - $rf - $k) / (1.0 - $k)) * 100)
        $m  = [math]::Round(((1.0 - $gf - $k) / (1.0 - $k)) * 100)
        $y  = [math]::Round(((1.0 - $bf - $k) / (1.0 - $k)) * 100)
        $kp = [math]::Round($k * 100)
        $cmyk = "cmyk($c%, $m%, $y%, $kp%)"
    }

    $linR = if ($rf -le 0.03928) { $rf / 12.92 } else { [math]::Pow(($rf + 0.055) / 1.055, 2.4) }
    $linG = if ($gf -le 0.03928) { $gf / 12.92 } else { [math]::Pow(($gf + 0.055) / 1.055, 2.4) }
    $linB = if ($bf -le 0.03928) { $bf / 12.92 } else { [math]::Pow(($bf + 0.055) / 1.055, 2.4) }
    $lum  = 0.2126 * $linR + 0.7152 * $linG + 0.0722 * $linB

    $vsWhite = [math]::Round(1.05 / ($lum + 0.05), 2)
    $vsBlack = [math]::Round(($lum + 0.05) / 0.05, 2)
    $wGrade = if ($vsWhite -ge 7) { "AAA" } elseif ($vsWhite -ge 4.5) { "AA" } elseif ($vsWhite -ge 3) { "AA Large" } else { "Fail" }
    $bGrade = if ($vsBlack -ge 7) { "AAA" } elseif ($vsBlack -ge 4.5) { "AA" } elseif ($vsBlack -ge 3) { "AA Large" } else { "Fail" }

    $swatches = @()
    foreach ($factor in @(0.60, 0.35, 0.16, 0.0, -0.18, -0.36, -0.56)) {
        if ($factor -ge 0) {
            $sr = [int][math]::Round($R + (255 - $R) * $factor)
            $sg = [int][math]::Round($G + (255 - $G) * $factor)
            $sb = [int][math]::Round($B + (255 - $B) * $factor)
        } else {
            $mF = 1.0 + $factor
            $sr = [int][math]::Round($R * $mF)
            $sg = [int][math]::Round($G * $mF)
            $sb = [int][math]::Round($B * $mF)
        }
        $swatches += ("#{0:X2}{1:X2}{2:X2}" -f $sr, $sg, $sb)
    }

    return [PSCustomObject]@{
        R        = $R
        G        = $G
        B        = $B
        Hex      = $hex
        Rgb      = $rgb
        Hsl      = $hsl
        Cmyk     = $cmyk
        CssVar   = "--brand-color: $hex;"
        Contrast = "WCAG Contrast  •  Λευκό: ${vsWhite}:1 ($wGrade)  |  Μαύρο: ${vsBlack}:1 ($bGrade)"
        BestFg   = if ($vsWhite -ge $vsBlack) { "#FFFFFF" } else { "#0B0F17" }
        Swatches = $swatches
    }
}

function Parse-HexToRgb {
    param([string]$RawHex)
    if (-not $RawHex) { return $null }
    $h = $RawHex.Trim().TrimStart('#')
    if ($h.Length -eq 3 -and $h -match '^[0-9A-Fa-f]{3}$') {
        $h = "$($h[0])$($h[0])$($h[1])$($h[1])$($h[2])$($h[2])"
    }
    if ($h -match '^[0-9A-Fa-f]{6}$') {
        return @(
            [Convert]::ToInt32($h.Substring(0,2), 16),
            [Convert]::ToInt32($h.Substring(2,2), 16),
            [Convert]::ToInt32($h.Substring(4,2), 16)
        )
    }
    return $null
}

function Copy-NillyColorValue {
    param([string]$Val, [string]$Label)
    if (-not $Val) { return }
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            [System.Windows.Clipboard]::SetDataObject($Val, $true)
            $script:CPState.Ui.TxtCPStatus.Text = "Αντιγράφηκε ($Label): $Val"
            return
        } catch {
            Start-Sleep -Milliseconds 35
        }
    }
    $script:CPState.Ui.TxtCPStatus.Text = "Δεν έγινε αντιγραφή στο clipboard — δοκίμασε ξανά."
}

function Stop-NillyColorSpy {
    if ($script:CPState.SpyTimer) {
        $script:CPState.SpyTimer.Stop()
    }
    $script:CPState.SpyActive = $false
    $script:CPState.SpyArmed  = $false
    if ($script:CPState.Ui -and $script:CPState.Ui.BtnCPLiveSpy) {
        $script:CPState.Ui.BtnCPLiveSpy.Content = "Live Spy (Click/F2)"
    }
}

function Render-NillyColorHistory {
    $ui = $script:CPState.Ui
    $conv = $script:CPState.BrushConv
    $ui.PanelCPHistory.Children.Clear()
    foreach ($hx in $script:CPState.History) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Width = 34; $btn.Height = 34
        $btn.Margin = New-Object System.Windows.Thickness(0,0,7,7)
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.ToolTip = "$hx (Κλικ για φόρτωση & αντιγραφή)"
        $btn.Background = $conv.ConvertFromString($hx)
        $btn.BorderBrush = $conv.ConvertFromString("#334155")
        $btn.BorderThickness = New-Object System.Windows.Thickness(1)
        $btn.Tag = $hx
        $btn.Add_Click({
            param($s, $e)
            $rgb = Parse-HexToRgb -RawHex $s.Tag
            if ($rgb) {
                Set-NillyPickerColor -R $rgb[0] -G $rgb[1] -B $rgb[2] -AddToHistory $false
                Copy-NillyColorValue -Val $s.Tag -Label "HEX"
            }
        })
        [void]$ui.PanelCPHistory.Children.Add($btn)
    }
}

function Set-NillyPickerColor {
    param([int]$R, [int]$G, [int]$B, [bool]$AddToHistory = $true)
    $ui = $script:CPState.Ui
    $conv = $script:CPState.BrushConv
    $info = Convert-RgbToColorInfo -R $R -G $G -B $B
    $script:CPState.Current = $info

    $ui.BoxCPPreview.Background    = $conv.ConvertFromString($info.Hex)
    $ui.TxtCPPreviewHex.Text       = $info.Hex
    $ui.TxtCPPreviewHex.Foreground = $conv.ConvertFromString($info.BestFg)
    $ui.TxtCPInputHex.Text         = $info.Hex
    $ui.TxtCPContrast.Text         = $info.Contrast

    $ui.ValCPHex.Text  = $info.Hex
    $ui.ValCPRgb.Text  = $info.Rgb
    $ui.ValCPHsl.Text  = $info.Hsl
    $ui.ValCPCmyk.Text = $info.Cmyk
    $ui.ValCPCss.Text  = $info.CssVar

    $ui.PanelCPShades.Children.Clear()
    foreach ($sw in $info.Swatches) {
        $tile = New-Object System.Windows.Controls.Button
        $tile.Height = 32
        $tile.Margin = New-Object System.Windows.Thickness(2,0,2,0)
        $tile.Cursor = [System.Windows.Input.Cursors]::Hand
        $tile.Background = $conv.ConvertFromString($sw)
        $tile.BorderBrush = $conv.ConvertFromString("#1F293B")
        $tile.BorderThickness = New-Object System.Windows.Thickness(1)
        $tile.ToolTip = "$sw (Κλικ για αντιγραφή)"
        $tile.Tag = $sw
        $tile.Add_Click({
            param($s, $e)
            $rgb = Parse-HexToRgb -RawHex $s.Tag
            if ($rgb) {
                Set-NillyPickerColor -R $rgb[0] -G $rgb[1] -B $rgb[2] -AddToHistory $true
                Copy-NillyColorValue -Val $s.Tag -Label "HEX"
            }
        })
        [void]$ui.PanelCPShades.Children.Add($tile)
    }

    if ($AddToHistory) {
        [void]$script:CPState.History.Remove($info.Hex)
        $script:CPState.History.Insert(0, $info.Hex)
        if ($script:CPState.History.Count -gt 16) { $script:CPState.History.RemoveAt(16) }
        Render-NillyColorHistory
    }
}

function Initialize-ColorPickerTool {
    param(
        [System.Windows.Window]$MainWindow,
        [hashtable]$UiMap
    )

    if ($script:CPState.Initialized) { return }
    $script:CPState.Initialized = $true
    $script:CPState.MainWindow  = $MainWindow
    $script:CPState.Ui          = $UiMap

    # Live Mouse Spy timer (runs ONLY when user explicitly activates Live Spy -> 0% CPU otherwise)
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(35)
    $timer.Add_Tick({
        if (-not $script:CPState.SpyActive) { return }
        try {
            $cx = 0; $cy = 0
            $col = [NillyPixelSpy]::GetColorAtCursor([ref]$cx, [ref]$cy)
            Set-NillyPickerColor -R $col.R -G $col.G -B $col.B -AddToHistory $false

            $lbtnDown = [NillyPixelSpy]::IsKeyPressed(0x01) # VK_LBUTTON
            $f2Down   = [NillyPixelSpy]::IsKeyPressed(0x71) # VK_F2
            $escDown  = [NillyPixelSpy]::IsKeyPressed(0x1B) # VK_ESCAPE

            # Wait until initial activation click is released + 120ms grace before arming click-to-lock
            if (-not $script:CPState.SpyArmed) {
                $elapsed = ([DateTime]::UtcNow - $script:CPState.SpyStartUtc).TotalMilliseconds
                if (-not $lbtnDown -and $elapsed -ge 120) {
                    $script:CPState.SpyArmed = $true
                }
                $script:CPState.Ui.TxtCPStatus.Text = "LIVE SPY ενεργό ($cx, $cy) — Κάνε Αριστερό Κλικ ή πάτα F2 για στοπ & αντιγραφή HEX (Esc ακύρωση)."
                return
            }

            if ($lbtnDown -or $f2Down) {
                Stop-NillyColorSpy
                Set-NillyPickerColor -R $col.R -G $col.G -B $col.B -AddToHistory $true
                Copy-NillyColorValue -Val $script:CPState.Current.Hex -Label "HEX"
                $script:CPState.Ui.TxtCPStatus.Text = "Κλειδώθηκε & αντιγράφηκε: $($script:CPState.Current.Hex)  (το Live Spy σταμάτησε)"
                $script:CPState.MainWindow.Activate() | Out-Null
            } elseif ($escDown) {
                Stop-NillyColorSpy
                $script:CPState.Ui.TxtCPStatus.Text = "Το Live Spy σταμάτησε."
            } else {
                $script:CPState.Ui.TxtCPStatus.Text = "LIVE SPY ενεργό ($cx, $cy) — Κάνε Αριστερό Κλικ ή πάτα F2 για στοπ & αντιγραφή HEX (Esc ακύρωση)."
            }
        } catch {
            Stop-NillyColorSpy
        }
    })
    $script:CPState.SpyTimer = $timer

    # 1. Screen Zoom Loupe button (rock-solid with Application.Run + Hide/Show!)
    $UiMap.BtnCPPickScreen.Add_Click({
        Stop-NillyColorSpy
        $mw = $script:CPState.MainWindow
        $prevState = $mw.WindowState
        $picked = $null
        $errMsg = $null

        $mw.Hide()
        Start-Sleep -Milliseconds 180
        try {
            $loupe = New-Object NillyColorLoupeForm
            if (-not $loupe.CaptureOk) {
                $errMsg = $loupe.ErrorMessage
            } else {
                [void]$loupe.ShowDialog()
                if ($loupe.HasPicked) { $picked = $loupe.PickedColor }
            }
            $loupe.Dispose()
        } catch {
            $errMsg = $_.Exception.Message
        } finally {
            $mw.Show()
            $mw.WindowState = $prevState
            $mw.Activate() | Out-Null
        }

        if ($errMsg) {
            $script:CPState.Ui.TxtCPStatus.Text = "Το Loupe δεν μπόρεσε να τραβήξει οθόνη ($errMsg) — δοκίμασε το κουμπί 'Live Spy (F2)'!"
        } elseif ($picked) {
            Set-NillyPickerColor -R $picked.R -G $picked.G -B $picked.B -AddToHistory $true
            Copy-NillyColorValue -Val $script:CPState.Current.Hex -Label "HEX"
        } else {
            $script:CPState.Ui.TxtCPStatus.Text = "Ακυρώθηκε η επιλογή χρώματος."
        }
    })

    # 2. Live Mouse Spy button (zero-overlay real-time pixel reader — Left-Click or F2 locks & stops!)
    $UiMap.BtnCPLiveSpy.Add_Click({
        if ($script:CPState.SpyActive) {
            Stop-NillyColorSpy
            $script:CPState.Ui.TxtCPStatus.Text = "Το Live Spy σταμάτησε."
        } else {
            $script:CPState.SpyActive   = $true
            $script:CPState.SpyArmed    = $false
            $script:CPState.SpyStartUtc = [DateTime]::UtcNow
            $script:CPState.Ui.BtnCPLiveSpy.Content = "Stop Spy (Click)"
            $script:CPState.SpyTimer.Start()
            $script:CPState.Ui.TxtCPStatus.Text = "LIVE SPY ενεργό! Πήγαινε στο χρώμα και κάνε Αριστερό Κλικ (ή F2) για στοπ & αντιγραφή HEX."
        }
    })

    # 3. Manual HEX input
    $UiMap.BtnCPApplyHex.Add_Click({
        Stop-NillyColorSpy
        $rgb = Parse-HexToRgb -RawHex $script:CPState.Ui.TxtCPInputHex.Text
        if ($rgb) {
            Set-NillyPickerColor -R $rgb[0] -G $rgb[1] -B $rgb[2] -AddToHistory $true
            $script:CPState.Ui.TxtCPStatus.Text = "Εφαρμόστηκε το χρώμα $($script:CPState.Current.Hex)."
        } else {
            $script:CPState.Ui.TxtCPStatus.Text = "Μη έγκυρο HEX (παράδειγμα: #38BDF8 ή FF5500)."
        }
    })

    $UiMap.TxtCPInputHex.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Return) {
            Stop-NillyColorSpy
            $rgb = Parse-HexToRgb -RawHex $script:CPState.Ui.TxtCPInputHex.Text
            if ($rgb) {
                Set-NillyPickerColor -R $rgb[0] -G $rgb[1] -B $rgb[2] -AddToHistory $true
                Copy-NillyColorValue -Val $script:CPState.Current.Hex -Label "HEX"
            }
        }
    })

    # 4. 1-Click Copy buttons
    $UiMap.BtnCopyHex.Add_Click({  if ($script:CPState.Current) { Copy-NillyColorValue -Val $script:CPState.Current.Hex    -Label "HEX"  } })
    $UiMap.BtnCopyRgb.Add_Click({  if ($script:CPState.Current) { Copy-NillyColorValue -Val $script:CPState.Current.Rgb    -Label "RGB"  } })
    $UiMap.BtnCopyHsl.Add_Click({  if ($script:CPState.Current) { Copy-NillyColorValue -Val $script:CPState.Current.Hsl    -Label "HSL"  } })
    $UiMap.BtnCopyCmyk.Add_Click({ if ($script:CPState.Current) { Copy-NillyColorValue -Val $script:CPState.Current.Cmyk   -Label "CMYK" } })
    $UiMap.BtnCopyCss.Add_Click({  if ($script:CPState.Current) { Copy-NillyColorValue -Val $script:CPState.Current.CssVar -Label "CSS"  } })

    $UiMap.BtnCPClearHist.Add_Click({
        $script:CPState.History.Clear()
        Render-NillyColorHistory
        $script:CPState.Ui.TxtCPStatus.Text = "Το ιστορικό χρωμάτων καθαρίστηκε."
    })

    # Initial Nilly Cyan swatch
    Set-NillyPickerColor -R 56 -G 189 -B 248 -AddToHistory $true
}

Export-ModuleMember -Function Initialize-ColorPickerTool, Convert-RgbToColorInfo, Parse-HexToRgb, Set-NillyPickerColor, Stop-NillyColorSpy
