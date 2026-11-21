<#
.SYNOPSIS
    Nilly QuickTools — Images to PDF Creator (100% Native C# PDF 1.4 Writer — 0 External Libraries!)
    Creates crisp multi-page print-ready PDFs from client images/proofs/scans (replaces heavy PDF apps!)
    Lazy-loaded PowerShell Module (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'NillyPdfWriterEngine').Type) {
    Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

public static class NillyPdfWriterEngine {
    private class PdfPageData {
        public byte[] Jpeg;
        public int PxW, PxH;
        public double PageW, PageH, DrawW, DrawH, OffX, OffY;
    }

    // Pure zero-dependency ISO PDF 1.4 generator with embedded DCTDecode JPEG streams & EXIF support
    public static void CreatePdfFromImages(string[] imagePaths, string outPdfPath, string pageMode, long jpgQuality) {
        if (imagePaths == null || imagePaths.Length == 0)
            throw new InvalidOperationException("Δεν υπάρχουν εικόνες στη λίστα.");

        ImageCodecInfo jpgCodec = ImageCodecInfo.GetImageEncoders().First(c => c.MimeType == "image/jpeg");
        EncoderParameters ep = new EncoderParameters(1);
        ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, Math.Max(60L, Math.Min(100L, jpgQuality)));

        var pageData = new List<PdfPageData>();

        foreach (string path in imagePaths) {
            using (Image img = Image.FromFile(path)) {
                try {
                    if (img.PropertyIdList.Contains(0x0112)) {
                        int o = img.GetPropertyItem(0x0112).Value[0];
                        if (o == 3) img.RotateFlip(RotateFlipType.Rotate180FlipNone);
                        else if (o == 6) img.RotateFlip(RotateFlipType.Rotate90FlipNone);
                        else if (o == 8) img.RotateFlip(RotateFlipType.Rotate270FlipNone);
                    }
                } catch {}

                int pxW = img.Width, pxH = img.Height;
                byte[] jpegBytes;
                using (Bitmap rgb = new Bitmap(pxW, pxH, PixelFormat.Format24bppRgb)) {
                    using (Graphics g = Graphics.FromImage(rgb)) {
                        g.Clear(Color.White);
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.DrawImage(img, 0, 0, pxW, pxH);
                    }
                    using (MemoryStream ms = new MemoryStream()) {
                        rgb.Save(ms, jpgCodec, ep);
                        jpegBytes = ms.ToArray();
                    }
                }

                // PDF points (72 pt = 1 inch). A4 = 595.28 x 841.89 pt
                double pageW, pageH, drawW, drawH, offX, offY;
                if (pageMode == "A4P") {
                    pageW = 595.28; pageH = 841.89;
                    double margin = 20.0;
                    double scale = Math.Min((pageW - margin * 2) / pxW, (pageH - margin * 2) / pxH);
                    drawW = pxW * scale; drawH = pxH * scale;
                    offX = (pageW - drawW) / 2.0; offY = (pageH - drawH) / 2.0;
                } else if (pageMode == "A4L") {
                    pageW = 841.89; pageH = 595.28;
                    double margin = 20.0;
                    double scale = Math.Min((pageW - margin * 2) / pxW, (pageH - margin * 2) / pxH);
                    drawW = pxW * scale; drawH = pxH * scale;
                    offX = (pageW - drawW) / 2.0; offY = (pageH - drawH) / 2.0;
                } else {
                    double factor = 72.0 / 150.0;
                    pageW = Math.Max(72.0, pxW * factor);
                    pageH = Math.Max(72.0, pxH * factor);
                    drawW = pageW; drawH = pageH; offX = 0; offY = 0;
                }
                pageData.Add(new PdfPageData {
                    Jpeg = jpegBytes, PxW = pxW, PxH = pxH,
                    PageW = pageW, PageH = pageH, DrawW = drawW, DrawH = drawH, OffX = offX, OffY = offY
                });
            }
        }

        // Write clean PDF 1.4 binary structure
        using (FileStream fs = new FileStream(outPdfPath, FileMode.Create, FileAccess.Write)) {
            var offsets = new List<long>();
            WriteAscii(fs, "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n");

            int pageCount = pageData.Count;
            offsets.Add(fs.Position);
            WriteAscii(fs, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

            offsets.Add(fs.Position);
            StringBuilder kids = new StringBuilder();
            for (int i = 0; i < pageCount; i++) kids.AppendFormat("{0} 0 R ", 6 + i * 3);
            WriteAscii(fs, string.Format("2 0 obj\n<< /Type /Pages /Count {0} /Kids [ {1}] >>\nendobj\n", pageCount, kids.ToString()));

            offsets.Add(fs.Position);
            WriteAscii(fs, "3 0 obj\n<< /Producer (Nilly PC Manager & Tools - https://nillygraphics.com/) /Creator (created by Nilly graphics \\(Sotiris Christos\\)) >>\nendobj\n");

            for (int i = 0; i < pageCount; i++) {
                var p = pageData[i];
                int imgObj = 4 + i * 3;
                int cntObj = 5 + i * 3;
                int pgObj  = 6 + i * 3;

                offsets.Add(fs.Position);
                WriteAscii(fs, string.Format(CultureInfo.InvariantCulture,
                    "{0} 0 obj\n<< /Type /XObject /Subtype /Image /Width {1} /Height {2} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {3} >>\nstream\n",
                    imgObj, p.PxW, p.PxH, p.Jpeg.Length));
                fs.Write(p.Jpeg, 0, p.Jpeg.Length);
                WriteAscii(fs, "\nendstream\nendobj\n");

                string cmd = string.Format(CultureInfo.InvariantCulture, "q {0:F2} 0 0 {1:F2} {2:F2} {3:F2} cm /Im0 Do Q\n", p.DrawW, p.DrawH, p.OffX, p.OffY);
                byte[] cmdBytes = Encoding.ASCII.GetBytes(cmd);
                offsets.Add(fs.Position);
                WriteAscii(fs, string.Format("{0} 0 obj\n<< /Length {1} >>\nstream\n", cntObj, cmdBytes.Length));
                fs.Write(cmdBytes, 0, cmdBytes.Length);
                WriteAscii(fs, "endstream\nendobj\n");

                offsets.Add(fs.Position);
                WriteAscii(fs, string.Format(CultureInfo.InvariantCulture,
                    "{0} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {1:F2} {2:F2}] /Resources << /XObject << /Im0 {3} 0 R >> >> /Contents {4} 0 R >>\nendobj\n",
                    pgObj, p.PageW, p.PageH, imgObj, cntObj));
            }

            long xrefPos = fs.Position;
            WriteAscii(fs, string.Format("xref\n0 {0}\n0000000000 65535 f \n", offsets.Count + 1));
            foreach (long off in offsets) {
                WriteAscii(fs, string.Format(CultureInfo.InvariantCulture, "{0:D10} 00000 n \n", off));
            }
            WriteAscii(fs, string.Format("trailer\n<< /Size {0} /Root 1 0 R /Info 3 0 R >>\nstartxref\n{1}\n%%EOF\n", offsets.Count + 1, xrefPos));
        }
    }

    private static void WriteAscii(Stream s, string text) {
        byte[] b = Encoding.GetEncoding(28591).GetBytes(text);
        s.Write(b, 0, b.Length);
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:PdfState = @{
    Initialized = $false
    Ui          = $null
    Files       = [System.Collections.Generic.List[string]]::new()
}

$script:PdfImgExts = @('.png','.jpg','.jpeg','.bmp','.gif','.tif','.tiff')

function Render-PdfImageList {
    $rows = @()
    $idx = 1
    foreach ($f in $script:PdfState.Files) {
        $fi = Get-Item $f -ErrorAction SilentlyContinue
        if ($fi) {
            $rows += [PSCustomObject]@{
                Page = "Σελ. $idx"
                Name = $fi.Name
                Size = if ($fi.Length -ge 1MB) { "{0:N2} MB" -f ($fi.Length/1MB) } else { "{0:N0} KB" -f ($fi.Length/1KB) }
                Path = $fi.FullName
            }
            $idx++
        }
    }
    $script:PdfState.Ui.ListPdfFiles.ItemsSource = $rows
}

function Add-PdfImageFiles {
    param([string[]]$Paths)
    $added = 0
    foreach ($p in $Paths) {
        if (Test-Path $p -PathType Container) {
            Get-ChildItem $p -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
                if ($script:PdfImgExts -contains $_.Extension.ToLowerInvariant() -and -not $script:PdfState.Files.Contains($_.FullName)) {
                    [void]$script:PdfState.Files.Add($_.FullName); $added++
                }
            }
        } elseif (Test-Path $p -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($p).ToLowerInvariant()
            if ($script:PdfImgExts -contains $ext -and -not $script:PdfState.Files.Contains($p)) {
                [void]$script:PdfState.Files.Add($p); $added++
            }
        }
    }
    Render-PdfImageList
    if ($added -gt 0) { $script:PdfState.Ui.TxtPdfStatus.Text = "Προστέθηκαν $added εικόνες (σύνολο σελίδων PDF: $($script:PdfState.Files.Count))." }
}

function Initialize-ImagesToPdfTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:PdfState.Initialized) { return }
    $script:PdfState.Initialized = $true
    $script:PdfState.Ui          = $UiMap

    $dropHandler = {
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            Add-PdfImageFiles -Paths ([string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop))
        }
    }
    $UiMap.ZonePdfDrop.Add_Drop($dropHandler)
    $UiMap.ListPdfFiles.Add_Drop($dropHandler)

    $UiMap.BtnPdfBrowse.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Multiselect = $true
        $dlg.Filter = "Images (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.tif;*.tiff"
        if ($dlg.ShowDialog() -eq $true) { Add-PdfImageFiles -Paths $dlg.FileNames }
    })

    $UiMap.BtnPdfUp.Add_Click({
        $i = $script:PdfState.Ui.ListPdfFiles.SelectedIndex
        if ($i -gt 0) {
            $item = $script:PdfState.Files[$i]
            $script:PdfState.Files.RemoveAt($i)
            $script:PdfState.Files.Insert($i - 1, $item)
            Render-PdfImageList
            $script:PdfState.Ui.ListPdfFiles.SelectedIndex = $i - 1
        }
    })

    $UiMap.BtnPdfDown.Add_Click({
        $i = $script:PdfState.Ui.ListPdfFiles.SelectedIndex
        if ($i -ge 0 -and $i -lt ($script:PdfState.Files.Count - 1)) {
            $item = $script:PdfState.Files[$i]
            $script:PdfState.Files.RemoveAt($i)
            $script:PdfState.Files.Insert($i + 1, $item)
            Render-PdfImageList
            $script:PdfState.Ui.ListPdfFiles.SelectedIndex = $i + 1
        }
    })

    $UiMap.BtnPdfClear.Add_Click({
        $script:PdfState.Files.Clear()
        Render-PdfImageList
        $script:PdfState.Ui.TxtPdfStatus.Text = "Η λίστα καθαρίστηκε."
    })

    $UiMap.BtnPdfBuild.Add_Click({
        if ($script:PdfState.Files.Count -eq 0) {
            $script:PdfState.Ui.TxtPdfStatus.Text = "Ρίξε ή επίλεξε πρώτα εικόνες."
            return
        }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "PDF Document (*.pdf)|*.pdf"
        $dlg.FileName = "nilly-document.pdf"
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $mode = $script:PdfState.Ui.CmbPdfPage.SelectedItem.Tag
                $qual = [long]$script:PdfState.Ui.CmbPdfQuality.SelectedItem.Tag
                [NillyPdfWriterEngine]::CreatePdfFromImages($script:PdfState.Files.ToArray(), $dlg.FileName, $mode, $qual)
                $kb = [math]::Round((Get-Item $dlg.FileName).Length / 1KB, 1)
                $script:PdfState.Ui.TxtPdfStatus.Text = "Δημιουργήθηκε το PDF ($($script:PdfState.Files.Count) σελίδες, $kb KB): $($dlg.FileName)"
            } catch {
                $script:PdfState.Ui.TxtPdfStatus.Text = "Σφάλμα PDF: $($_.Exception.Message)"
            }
        }
    })
}

Export-ModuleMember -Function Initialize-ImagesToPdfTool, Add-PdfImageFiles
