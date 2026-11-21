<#
.SYNOPSIS
    Nilly QuickTools — Tool #3: Image Resizer & Converter (Drag & Drop, Safe _resized Output)
    Lazy-loaded PowerShell Module for PC Manager & Tools (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'NillyImageResizerEngine').Type) {
    Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;

public static class NillyImageResizerEngine {
    public class ResizeOutcome {
        public string OutputPath;
        public long OldBytes;
        public long NewBytes;
        public int NewWidth;
        public int NewHeight;
    }

    public static ResizeOutcome ProcessImage(string srcPath, int maxEdge, int pctScale, string outFormat, long jpgQuality) {
        long oldBytes = new FileInfo(srcPath).Length;
        string dir = Path.GetDirectoryName(srcPath);
        string outDir = Path.Combine(dir, "_resized");
        Directory.CreateDirectory(outDir);

        string baseName = Path.GetFileNameWithoutExtension(srcPath);
        string srcExt = Path.GetExtension(srcPath).ToLowerInvariant();
        string targetExt = outFormat == "JPG" ? ".jpg" : (outFormat == "PNG" ? ".png" : srcExt);
        if (targetExt != ".jpg" && targetExt != ".jpeg" && targetExt != ".png" && targetExt != ".bmp") targetExt = ".jpg";

        string outPath = Path.Combine(outDir, baseName + targetExt);

        using (Image img = Image.FromFile(srcPath)) {
            // Respect EXIF Orientation tag (0x0112) so iPhone photos never rotate sideways!
            try {
                if (img.PropertyIdList.Contains(0x0112)) {
                    int orient = img.GetPropertyItem(0x0112).Value[0];
                    if (orient == 3) img.RotateFlip(RotateFlipType.Rotate180FlipNone);
                    else if (orient == 6) img.RotateFlip(RotateFlipType.Rotate90FlipNone);
                    else if (orient == 8) img.RotateFlip(RotateFlipType.Rotate270FlipNone);
                }
            } catch {}

            int w = img.Width;
            int h = img.Height;
            int nw = w, nh = h;

            if (pctScale > 0 && pctScale < 100) {
                nw = Math.Max(1, (int)Math.Round(w * (pctScale / 100.0)));
                nh = Math.Max(1, (int)Math.Round(h * (pctScale / 100.0)));
            } else if (maxEdge > 0 && (w > maxEdge || h > maxEdge)) {
                double ratio = Math.Min((double)maxEdge / w, (double)maxEdge / h);
                nw = Math.Max(1, (int)Math.Round(w * ratio));
                nh = Math.Max(1, (int)Math.Round(h * ratio));
            }

            using (Bitmap dst = new Bitmap(nw, nh, PixelFormat.Format32bppArgb)) {
                dst.SetResolution(img.HorizontalResolution > 0 ? img.HorizontalResolution : 96,
                                  img.VerticalResolution > 0 ? img.VerticalResolution : 96);
                using (Graphics g = Graphics.FromImage(dst)) {
                    g.CompositingQuality = CompositingQuality.HighQuality;
                    g.InterpolationMode  = InterpolationMode.HighQualityBicubic;
                    g.SmoothingMode      = SmoothingMode.HighQuality;
                    g.PixelOffsetMode    = PixelOffsetMode.HighQuality;
                    if (targetExt == ".jpg" || targetExt == ".jpeg") g.Clear(Color.White);
                    g.DrawImage(img, 0, 0, nw, nh);
                }

                if (targetExt == ".jpg" || targetExt == ".jpeg") {
                    ImageCodecInfo jpgCodec = ImageCodecInfo.GetImageEncoders().First(c => c.MimeType == "image/jpeg");
                    EncoderParameters ep = new EncoderParameters(1);
                    ep.Param[0] = new EncoderParameter(Encoder.Quality, Math.Max(40L, Math.Min(100L, jpgQuality)));
                    dst.Save(outPath, jpgCodec, ep);
                } else if (targetExt == ".png") {
                    dst.Save(outPath, ImageFormat.Png);
                } else {
                    dst.Save(outPath, ImageFormat.Bmp);
                }
            }

            return new ResizeOutcome {
                OutputPath = outPath,
                OldBytes = oldBytes,
                NewBytes = new FileInfo(outPath).Length,
                NewWidth = nw,
                NewHeight = nh
            };
        }
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:IRState = @{
    Initialized = $false
    Ui          = $null
    Files       = [System.Collections.Generic.List[string]]::new()
    LastOutDir  = $null
}

$script:AllowedImgExt = @('.png','.jpg','.jpeg','.bmp','.gif','.tif','.tiff')

function Add-ImageResizerFiles {
    param([string[]]$Paths)
    $added = 0
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        if (Test-Path $p -PathType Container) {
            Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($script:AllowedImgExt -contains $_.Extension.ToLowerInvariant() -and -not $script:IRState.Files.Contains($_.FullName)) {
                    [void]$script:IRState.Files.Add($_.FullName); $added++
                }
            }
        } elseif (Test-Path $p -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($p).ToLowerInvariant()
            if ($script:AllowedImgExt -contains $ext -and -not $script:IRState.Files.Contains($p)) {
                [void]$script:IRState.Files.Add($p); $added++
            }
        }
    }
    Render-ImageResizerList
    if ($added -gt 0) {
        $script:IRState.Ui.TxtIRStatus.Text = "Προστέθηκαν $added εικόνες (σύνολο: $($script:IRState.Files.Count))."
    }
}

function Render-ImageResizerList {
    $rows = @()
    foreach ($f in $script:IRState.Files) {
        $fi = Get-Item $f -ErrorAction SilentlyContinue
        if ($fi) {
            $rows += [PSCustomObject]@{
                Name = $fi.Name
                Size = if ($fi.Length -ge 1MB) { "{0:N2} MB" -f ($fi.Length/1MB) } else { "{0:N0} KB" -f ($fi.Length/1KB) }
                Path = $fi.FullName
            }
        }
    }
    $script:IRState.Ui.ListIRFiles.ItemsSource = $rows
}

function Initialize-ImageResizerTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:IRState.Initialized) { return }
    $script:IRState.Initialized = $true
    $script:IRState.Ui          = $UiMap

    # Drag & Drop on drop zone & list
    $dropHandler = {
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $dropped = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            Add-ImageResizerFiles -Paths $dropped
        }
    }
    $UiMap.ZoneIRDrop.Add_Drop($dropHandler)
    $UiMap.ListIRFiles.Add_Drop($dropHandler)

    $UiMap.BtnIRBrowse.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Multiselect = $true
        $dlg.Filter = "Images (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff"
        if ($dlg.ShowDialog() -eq $true) { Add-ImageResizerFiles -Paths $dlg.FileNames }
    })

    $UiMap.BtnIRClear.Add_Click({
        $script:IRState.Files.Clear()
        Render-ImageResizerList
        $script:IRState.Ui.TxtIRStatus.Text = "Η λίστα καθαρίστηκε."
    })

    $UiMap.CmbIRPreset.Add_SelectionChanged({
        $tag = $script:IRState.Ui.CmbIRPreset.SelectedItem.Tag
        $script:IRState.Ui.TxtIRCustomPx.IsEnabled = ($tag -eq "CUSTOM")
    })

    $UiMap.SliderIRQuality.Add_ValueChanged({
        $script:IRState.Ui.LblIRQuality.Text = "$([int]$script:IRState.Ui.SliderIRQuality.Value)%"
    })

    $UiMap.BtnIROpenOut.Add_Click({
        if ($script:IRState.LastOutDir -and (Test-Path $script:IRState.LastOutDir)) {
            Start-Process "explorer.exe" -ArgumentList "`"$($script:IRState.LastOutDir)`""
        } else {
            $script:IRState.Ui.TxtIRStatus.Text = "Δεν έχει δημιουργηθεί ακόμα φάκελος εξόδου _resized."
        }
    })

    $UiMap.BtnIRRun.Add_Click({
        $ui = $script:IRState.Ui
        if ($script:IRState.Files.Count -eq 0) {
            $ui.TxtIRStatus.Text = "Ρίξε (Drag & Drop) ή επίλεξε πρώτα εικόνες."
            return
        }
        $preset = $ui.CmbIRPreset.SelectedItem.Tag
        $maxEdge = 0; $pct = 0
        switch ($preset) {
            "1920"   { $maxEdge = 1920 }
            "1200"   { $maxEdge = 1200 }
            "1080"   { $maxEdge = 1080 }
            "600"    { $maxEdge = 600  }
            "PCT50"  { $pct = 50       }
            "CUSTOM" { [void][int]::TryParse($ui.TxtIRCustomPx.Text.Trim(), [ref]$maxEdge) }
        }
        $fmt = $ui.CmbIRFormat.SelectedItem.Tag
        $qual = [long][math]::Round($ui.SliderIRQuality.Value)

        $ui.BtnIRRun.IsEnabled = $false
        $ui.TxtIRStatus.Text = "Επεξεργασία $($script:IRState.Files.Count) εικόνων..."
        $MainWindow.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)

        [long]$totOld = 0; [long]$totNew = 0; $ok = 0; $fail = 0
        foreach ($f in $script:IRState.Files) {
            try {
                $res = [NillyImageResizerEngine]::ProcessImage($f, $maxEdge, $pct, $fmt, $qual)
                $totOld += $res.OldBytes; $totNew += $res.NewBytes; $ok++
                $script:IRState.LastOutDir = [System.IO.Path]::GetDirectoryName($res.OutputPath)
            } catch { $fail++ }
        }

        $oldMB = [math]::Round($totOld / 1MB, 2)
        $newMB = [math]::Round($totNew / 1MB, 2)
        $savedPct = if ($totOld -gt 0) { [math]::Round((($totOld - $totNew) / $totOld) * 100, 0) } else { 0 }
        $ui.TxtIRStatus.Text = "Έτοιμο! $ok εικόνες στον φάκελο '_resized' ($oldMB MB → $newMB MB, εξοικονόμηση $savedPct%)." + $(if ($fail -gt 0) { " ($fail σφάλματα)" } else { "" })
        $ui.BtnIRRun.IsEnabled = $true
    })
}

Export-ModuleMember -Function Initialize-ImageResizerTool, Add-ImageResizerFiles
