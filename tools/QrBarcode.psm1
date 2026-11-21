<#
.SYNOPSIS
    Nilly QuickTools — Tool #2: QR Code & Barcode Pro
    ISO/IEC 18004 QR (V1-V20) + 9 Retail & Packaging Barcodes:
      EAN-13, EAN-8, ITF-14 (Bearer Bar), UPC-A, UPC-E, ISBN-13, ISSN, Code 128 (Auto B/C), Code 39
    100% Offline | Static codes NEVER expire | iPhone & Android Native | Vector SVG & 300-DPI PNG

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ([System.Management.Automation.PSTypeName]'NillyQrBarcodeEngineV2').Type) {
    Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.Text;

public static class NillyQrBarcodeEngineV2 {
    // =========================================================================
    // 1. ISO/IEC 18004 QR CODE ENCODER (Versions 1-20, Byte Mode UTF-8, L/M/Q/H)
    // =========================================================================
    private static readonly int[] EccFormatBits = { 1, 0, 3, 2 }; // L=01, M=00, Q=11, H=10

    private static readonly int[,] EcPerBlock = {
        { 0,  7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28 },
        { 0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26 },
        { 0, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30 },
        { 0, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28 }
    };

    private static readonly int[,] NumBlocks = {
        { 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4,  4,  4,  4,  4,  6,  6,  6,  6,  7,  8 },
        { 0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5,  5,  8,  9,  9, 10, 10, 11, 13, 14, 16 },
        { 0, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8,  8, 10, 12, 16, 12, 17, 17, 18, 21, 20 },
        { 0, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25 }
    };

    private static readonly int[][] AlignCoords = {
        new int[0], new int[0],
        new[] { 6, 18 }, new[] { 6, 22 }, new[] { 6, 26 }, new[] { 6, 30 }, new[] { 6, 34 },
        new[] { 6, 22, 38 }, new[] { 6, 24, 42 }, new[] { 6, 26, 46 }, new[] { 6, 28, 50 },
        new[] { 6, 30, 54 }, new[] { 6, 32, 58 }, new[] { 6, 34, 62 },
        new[] { 6, 26, 46, 66 }, new[] { 6, 26, 48, 70 }, new[] { 6, 26, 50, 74 },
        new[] { 6, 30, 54, 78 }, new[] { 6, 30, 56, 82 }, new[] { 6, 30, 58, 86 }, new[] { 6, 34, 62, 90 }
    };

    private static readonly int[] RawCodewords = {
        0, 26, 44, 70, 100, 134, 172, 196, 242, 292, 346, 404, 466, 532, 581, 655, 733, 815, 901, 991, 1085
    };

    public class QrResult {
        public bool[,] Modules;
        public int Size;
        public int Version;
        public int Mask;
        public int EccLevel;
        public int ByteCount;
    }

    public static QrResult EncodeQr(string text, int eccLevel) {
        if (text == null) text = "";
        if (eccLevel < 0 || eccLevel > 3) eccLevel = 1;
        byte[] dataBytes = Encoding.UTF8.GetBytes(text);

        int version = -1;
        for (int v = 1; v <= 20; v++) {
            int dataCapBytes = RawCodewords[v] - EcPerBlock[eccLevel, v] * NumBlocks[eccLevel, v];
            int headerBits = 4 + (v >= 10 ? 16 : 8);
            if (headerBits + dataBytes.Length * 8 <= dataCapBytes * 8) { version = v; break; }
        }
        if (version == -1)
            throw new InvalidOperationException("Το κείμενο είναι πολύ μεγάλο για QR (δοκίμασε χαμηλότερο ECC M/L ή πιο σύντομο URL).");

        int totalCw = RawCodewords[version];
        int ecLen   = EcPerBlock[eccLevel, version];
        int blocks  = NumBlocks[eccLevel, version];
        int dataCw  = totalCw - ecLen * blocks;

        List<bool> bits = new List<bool>(dataCw * 8);
        AppendBits(bits, 0x4, 4);
        AppendBits(bits, dataBytes.Length, version >= 10 ? 16 : 8);
        foreach (byte b in dataBytes) AppendBits(bits, b, 8);
        AppendBits(bits, 0, Math.Min(4, dataCw * 8 - bits.Count));
        while (bits.Count % 8 != 0) bits.Add(false);

        byte[] dataCodewords = new byte[dataCw];
        int byteIdx = 0;
        for (int i = 0; i < bits.Count; i += 8) {
            byte val = 0;
            for (int j = 0; j < 8; j++) val = (byte)((val << 1) | (bits[i + j] ? 1 : 0));
            dataCodewords[byteIdx++] = val;
        }
        byte padByte = 0xEC;
        while (byteIdx < dataCw) {
            dataCodewords[byteIdx++] = padByte;
            padByte = (padByte == 0xEC) ? (byte)0x11 : (byte)0xEC;
        }

        byte[] allCodewords = AddEccAndInterleave(dataCodewords, totalCw, ecLen, blocks);

        int size = version * 4 + 17;
        bool[,] isFunc = new bool[size, size];
        bool[,] baseMod = new bool[size, size];
        DrawFunctionPatterns(baseMod, isFunc, version, size);
        DrawCodewords(baseMod, isFunc, allCodewords, size);

        int bestMask = 0;
        int bestPenalty = int.MaxValue;
        bool[,] bestMat = null;
        for (int mask = 0; mask < 8; mask++) {
            bool[,] candidate = (bool[,])baseMod.Clone();
            ApplyMask(candidate, isFunc, mask, size);
            DrawFormatBits(candidate, eccLevel, mask, size);
            int pen = ComputePenalty(candidate, size);
            if (pen < bestPenalty) { bestPenalty = pen; bestMask = mask; bestMat = candidate; }
        }

        return new QrResult { Modules = bestMat, Size = size, Version = version, Mask = bestMask, EccLevel = eccLevel, ByteCount = dataBytes.Length };
    }

    private static void AppendBits(List<bool> bits, int val, int len) {
        for (int i = len - 1; i >= 0; i--) bits.Add(((val >> i) & 1) != 0);
    }

    private static byte GfMul(int x, int y) {
        int z = 0;
        for (int i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >> 7) * 0x11D); z ^= ((y >> i) & 1) * x; }
        return (byte)z;
    }

    private static byte[] ComputeRsDivisor(int degree) {
        byte[] res = new byte[degree];
        res[degree - 1] = 1;
        int root = 1;
        for (int i = 0; i < degree; i++) {
            for (int j = 0; j < degree; j++) {
                res[j] = GfMul(res[j], root);
                if (j + 1 < degree) res[j] ^= res[j + 1];
            }
            root = GfMul(root, 2);
        }
        return res;
    }

    private static byte[] ComputeRsRemainder(byte[] data, byte[] divisor) {
        byte[] rem = new byte[divisor.Length];
        foreach (byte b in data) {
            byte factor = (byte)(b ^ rem[0]);
            Array.Copy(rem, 1, rem, 0, rem.Length - 1);
            rem[rem.Length - 1] = 0;
            for (int i = 0; i < divisor.Length; i++) rem[i] ^= GfMul(divisor[i], factor);
        }
        return rem;
    }

    private static byte[] AddEccAndInterleave(byte[] data, int totalCw, int ecLen, int numBlocks) {
        int numShortBlocks = numBlocks - (totalCw % numBlocks);
        int shortDataLen   = (totalCw / numBlocks) - ecLen;
        byte[] rsDiv       = ComputeRsDivisor(ecLen);

        byte[][] dataBlocks = new byte[numBlocks][];
        byte[][] eccBlocks  = new byte[numBlocks][];
        int pos = 0;
        for (int i = 0; i < numBlocks; i++) {
            int dLen = shortDataLen + (i < numShortBlocks ? 0 : 1);
            byte[] blk = new byte[dLen];
            Array.Copy(data, pos, blk, 0, dLen);
            pos += dLen;
            dataBlocks[i] = blk;
            eccBlocks[i]  = ComputeRsRemainder(blk, rsDiv);
        }

        byte[] result = new byte[totalCw];
        int outIdx = 0;
        int maxDataLen = shortDataLen + (numShortBlocks < numBlocks ? 1 : 0);
        for (int i = 0; i < maxDataLen; i++)
            for (int b = 0; b < numBlocks; b++)
                if (i < dataBlocks[b].Length) result[outIdx++] = dataBlocks[b][i];
        for (int i = 0; i < ecLen; i++)
            for (int b = 0; b < numBlocks; b++)
                result[outIdx++] = eccBlocks[b][i];
        return result;
    }

    private static void SetFunc(bool[,] mod, bool[,] isFunc, int x, int y, bool dark) { mod[y, x] = dark; isFunc[y, x] = true; }

    private static void DrawFinder(bool[,] mod, bool[,] isFunc, int cx, int cy, int size) {
        for (int dy = -4; dy <= 4; dy++)
            for (int dx = -4; dx <= 4; dx++) {
                int xx = cx + dx, yy = cy + dy;
                if (xx >= 0 && xx < size && yy >= 0 && yy < size)
                    SetFunc(mod, isFunc, xx, yy, Math.Max(Math.Abs(dx), Math.Abs(dy)) != 2 && Math.Max(Math.Abs(dx), Math.Abs(dy)) != 4);
            }
    }

    private static void DrawAlignment(bool[,] mod, bool[,] isFunc, int cx, int cy) {
        for (int dy = -2; dy <= 2; dy++)
            for (int dx = -2; dx <= 2; dx++)
                SetFunc(mod, isFunc, cx + dx, cy + dy, Math.Max(Math.Abs(dx), Math.Abs(dy)) != 1);
    }

    private static void DrawFunctionPatterns(bool[,] mod, bool[,] isFunc, int version, int size) {
        for (int i = 0; i < size; i++) { SetFunc(mod, isFunc, 6, i, i % 2 == 0); SetFunc(mod, isFunc, i, 6, i % 2 == 0); }
        DrawFinder(mod, isFunc, 3, 3, size);
        DrawFinder(mod, isFunc, size - 4, 3, size);
        DrawFinder(mod, isFunc, 3, size - 4, size);
        int[] coords = AlignCoords[version];
        for (int i = 0; i < coords.Length; i++)
            for (int j = 0; j < coords.Length; j++)
                if (!((i == 0 && j == 0) || (i == 0 && j == coords.Length - 1) || (i == coords.Length - 1 && j == 0)))
                    DrawAlignment(mod, isFunc, coords[i], coords[j]);

        for (int i = 0; i <= 5; i++) SetFunc(mod, isFunc, 8, i, false);
        SetFunc(mod, isFunc, 8, 7, false); SetFunc(mod, isFunc, 8, 8, false); SetFunc(mod, isFunc, 7, 8, false);
        for (int i = 9; i < 15; i++) SetFunc(mod, isFunc, 14 - i, 8, false);
        for (int i = 0; i < 8; i++) SetFunc(mod, isFunc, size - 1 - i, 8, false);
        for (int i = 8; i < 15; i++) SetFunc(mod, isFunc, 8, size - 15 + i, false);
        SetFunc(mod, isFunc, 8, size - 8, true);

        if (version >= 7) {
            int rem = version;
            for (int i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
            int vBits = (version << 12) | rem;
            for (int i = 0; i < 18; i++) {
                bool bit = ((vBits >> i) & 1) != 0;
                int a = size - 11 + (i % 3), b = i / 3;
                SetFunc(mod, isFunc, a, b, bit);
                SetFunc(mod, isFunc, b, a, bit);
            }
        }
    }

    private static void DrawFormatBits(bool[,] mod, int eccLevel, int mask, int size) {
        int data = (EccFormatBits[eccLevel] << 3) | mask;
        int rem = data;
        for (int i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
        int bits = ((data << 10) | rem) ^ 0x5412;

        for (int i = 0; i <= 5; i++) mod[i, 8] = ((bits >> i) & 1) != 0;
        mod[7, 8] = ((bits >> 6) & 1) != 0; mod[8, 8] = ((bits >> 7) & 1) != 0; mod[8, 7] = ((bits >> 8) & 1) != 0;
        for (int i = 9; i < 15; i++) mod[8, 14 - i] = ((bits >> i) & 1) != 0;
        for (int i = 0; i < 8; i++) mod[8, size - 1 - i] = ((bits >> i) & 1) != 0;
        for (int i = 8; i < 15; i++) mod[size - 15 + i, 8] = ((bits >> i) & 1) != 0;
        mod[size - 8, 8] = true;
    }

    private static void DrawCodewords(bool[,] mod, bool[,] isFunc, byte[] data, int size) {
        int bitIdx = 0, totalBits = data.Length * 8;
        for (int right = size - 1; right >= 1; right -= 2) {
            if (right == 6) right = 5;
            for (int vert = 0; vert < size; vert++)
                for (int j = 0; j < 2; j++) {
                    int x = right - j;
                    int y = (((right + 1) & 2) == 0) ? (size - 1 - vert) : vert;
                    if (!isFunc[y, x] && bitIdx < totalBits) {
                        mod[y, x] = ((data[bitIdx >> 3] >> (7 - (bitIdx & 7))) & 1) != 0;
                        bitIdx++;
                    }
                }
        }
    }

    private static void ApplyMask(bool[,] mod, bool[,] isFunc, int mask, int size) {
        for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++) {
                if (isFunc[y, x]) continue;
                bool inv = false;
                switch (mask) {
                    case 0: inv = (x + y) % 2 == 0; break;
                    case 1: inv = y % 2 == 0; break;
                    case 2: inv = x % 3 == 0; break;
                    case 3: inv = (x + y) % 3 == 0; break;
                    case 4: inv = ((x / 3) + (y / 2)) % 2 == 0; break;
                    case 5: inv = (x * y) % 2 + (x * y) % 3 == 0; break;
                    case 6: inv = ((x * y) % 2 + (x * y) % 3) % 2 == 0; break;
                    case 7: inv = ((x + y) % 2 + (x * y) % 3) % 2 == 0; break;
                }
                if (inv) mod[y, x] = !mod[y, x];
            }
    }

    private static int ComputePenalty(bool[,] mod, int size) {
        int pen = 0;
        for (int y = 0; y < size; y++) {
            int run = 1;
            for (int x = 1; x < size; x++) {
                if (mod[y, x] == mod[y, x - 1]) { run++; if (run == 5) pen += 3; else if (run > 5) pen += 1; } else run = 1;
            }
        }
        for (int x = 0; x < size; x++) {
            int run = 1;
            for (int y = 1; y < size; y++) {
                if (mod[y, x] == mod[y - 1, x]) { run++; if (run == 5) pen += 3; else if (run > 5) pen += 1; } else run = 1;
            }
        }
        for (int y = 0; y < size - 1; y++)
            for (int x = 0; x < size - 1; x++) {
                bool c = mod[y, x];
                if (c == mod[y, x + 1] && c == mod[y + 1, x] && c == mod[y + 1, x + 1]) pen += 3;
            }
        int dark = 0;
        for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) if (mod[y, x]) dark++;
        int total = size * size;
        pen += (Math.Abs(dark * 20 - total * 10) / total) * 10;
        return pen;
    }

    private static bool IsInFinderZone(int x, int y, int size) {
        return (x < 7 && y < 7) || (x >= size - 7 && y < 7) || (x < 7 && y >= size - 7);
    }

    public static Bitmap RenderQrBitmap(QrResult qr, int pxSize, Color fg, Color bg, bool roundedDots, string caption) {
        const int quiet = 4;
        int totalMod = qr.Size + quiet * 2;
        int extraH = string.IsNullOrWhiteSpace(caption) ? 0 : Math.Max(34, pxSize / 12);
        Bitmap bmp = new Bitmap(pxSize, pxSize + extraH, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = roundedDots ? SmoothingMode.AntiAlias : SmoothingMode.None;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.Clear(bg);
            float modPx = (float)pxSize / totalMod;
            using (SolidBrush fgBrush = new SolidBrush(fg)) {
                for (int y = 0; y < qr.Size; y++)
                    for (int x = 0; x < qr.Size; x++) {
                        if (!qr.Modules[y, x]) continue;
                        float rx = (x + quiet) * modPx, ry = (y + quiet) * modPx;
                        if (roundedDots && !IsInFinderZone(x, y, qr.Size)) {
                            float pad = modPx * 0.08f;
                            g.FillEllipse(fgBrush, rx + pad, ry + pad, modPx - pad * 2, modPx - pad * 2);
                        } else g.FillRectangle(fgBrush, rx, ry, modPx + 0.35f, modPx + 0.35f);
                    }
                if (extraH > 0) {
                    using (Font f = new Font("Segoe UI", Math.Max(11f, extraH * 0.42f), FontStyle.Bold))
                    using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        g.DrawString(caption.Trim(), f, fgBrush, new RectangleF(8, pxSize - 4, pxSize - 16, extraH), sf);
                }
            }
        }
        return bmp;
    }

    public static string RenderQrSvg(QrResult qr, string fgHex, string bgHex, bool roundedDots, string caption) {
        const int quiet = 4, unit = 10;
        int totalW = (qr.Size + quiet * 2) * unit;
        bool hasCap = !string.IsNullOrWhiteSpace(caption);
        int totalH = totalW + (hasCap ? 34 : 0);
        StringBuilder sb = new StringBuilder(8192);
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine("<!-- Generated by PC Manager & Tools | created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/ -->");
        sb.AppendFormat(CultureInfo.InvariantCulture,
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {0} {1}\" width=\"{0}\" height=\"{1}\" shape-rendering=\"{2}\">\n",
            totalW, totalH, roundedDots ? "geometricPrecision" : "crispEdges");
        sb.AppendFormat("  <rect width=\"100%\" height=\"100%\" fill=\"{0}\"/>\n", bgHex);
        sb.AppendFormat("  <g fill=\"{0}\">\n", fgHex);
        for (int y = 0; y < qr.Size; y++)
            for (int x = 0; x < qr.Size; x++) {
                if (!qr.Modules[y, x]) continue;
                int px = (x + quiet) * unit, py = (y + quiet) * unit;
                if (roundedDots && !IsInFinderZone(x, y, qr.Size))
                    sb.AppendFormat(CultureInfo.InvariantCulture, "    <circle cx=\"{0}\" cy=\"{1}\" r=\"4.3\"/>\n", px + 5, py + 5);
                else
                    sb.AppendFormat(CultureInfo.InvariantCulture, "    <rect x=\"{0}\" y=\"{1}\" width=\"{2}\" height=\"{2}\"/>\n", px, py, unit);
            }
        sb.AppendLine("  </g>");
        if (hasCap) {
            string esc = System.Security.SecurityElement.Escape(caption.Trim());
            sb.AppendFormat(CultureInfo.InvariantCulture,
                "  <text x=\"{0}\" y=\"{1}\" text-anchor=\"middle\" font-family=\"Segoe UI, Arial, sans-serif\" font-size=\"18\" font-weight=\"700\" fill=\"{2}\">{3}</text>\n",
                totalW / 2, totalW + 20, fgHex, esc);
        }
        sb.AppendLine("</svg>");
        return sb.ToString();
    }

    // =========================================================================
    // 2. 9 ISO/GS1 RETAIL & PACKAGING BARCODES:
    //    EAN-13, EAN-8, ITF-14, UPC-A, UPC-E, ISBN-13, ISSN, CODE128 (B/C), CODE39
    // =========================================================================
    private static readonly string[] EanL = { "0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011" };
    private static readonly string[] EanG = { "0100111","0110011","0011011","0100001","0111101","0111001","0000101","0010001","0001001","0010111" }; // fixed index 4 below!
    private static readonly string[] EanGFixed = { "0100111","0110011","0011011","0100001","0011101","0111001","0000101","0010001","0001001","0010111" };
    private static readonly string[] EanR = { "1110010","1100110","1101100","1000010","1011100","1001110","1010000","1000100","1001000","1110100" };
    private static readonly string[] EanParity = { "LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG","LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL" };
    private static readonly string[] UpcEParity0 = { "EEEOOO","EEOEOO","EEOOEO","EEOOOE","EOEEOO","EOOEEO","EOOOEE","EOEOEO","EOEOOE","EOOEOE" };
    private static readonly string[] ItfDigits = { "NNWWN","WNNNW","NWNNW","WWNNN","NNWNW","WNWNN","NWWNN","NNNWW","WNNWN","NWNWN" };

    private static readonly string[] Code128Patterns = {
        "11011001100","11001101100","11001100110","10010011000","10010001100","10001001100","10011001000","10011000100","10001100100","11001001000",
        "11001000100","11000100100","10110011100","10011011100","10011001110","10111001100","10011101100","10011100110","11001110010","11001011100",
        "11001001110","11011100100","11001110100","11101101110","11101001100","11100101100","11100100110","11101100100","11100110100","11100110010",
        "11011011000","11011000110","11000110110","10100011000","10001011000","10001000110","10110001000","10001101000","10001100010","11010001000",
        "11000101000","11000100010","10110111000","10110001110","10001101110","10111011000","10111000110","10001110110","11101110110","11010001110",
        "11000101110","11011101000","11011100010","11011101110","11101011000","11101000110","11100010110","11101101000","11101100010","11100011010",
        "11101111010","11001000010","11110001010","10100110000","10100001100","10010110000","10010000110","10000101100","10000100110","10110010000",
        "10110000100","10011010000","10011000010","10000110100","10000110010","11000010010","11001010000","11110111010","11000010100","10001111010",
        "10100111100","10010111100","10010011110","10111100100","10011110100","10011110010","11110100100","11110010100","11110010010","11011011110",
        "11011110110","11110110110","10101111000","10100011110","10001011110","10111101000","10111100010","11110101000","11110100010","10111011110",
        "10111101110","11101011110","11110101110","11010000100","11010010000","11010011100","1100011101011"
    };

    private static readonly Dictionary<char, string> Code39Map = new Dictionary<char, string> {
        {'0',"nnnwwnwnn"},{'1',"wnnwnnnnw"},{'2',"nnwwnnnnw"},{'3',"wnwwnnnnn"},{'4',"nnnwwnnnw"},
        {'5',"wnnwwnnnn"},{'6',"nnwwwnnnn"},{'7',"nnnwnnwnw"},{'8',"wnnwnnwnn"},{'9',"nnwwnnwnn"},
        {'A',"wnnnnwnnw"},{'B',"nnwnnwnnw"},{'C',"wnwnnwnnn"},{'D',"nnnnwwnnw"},{'E',"wnnnwwnnn"},
        {'F',"nnwnwwnnn"},{'G',"nnnnnwwnw"},{'H',"wnnnnwwnn"},{'I',"nnwnnwwnn"},{'J',"nnnnwwwnn"},
        {'K',"wnnnnnnww"},{'L',"nnwnnnnww"},{'M',"wnwnnnnwn"},{'N',"nnnnwnnww"},{'O',"wnnnwnnwn"},
        {'P',"nnwnwnnwn"},{'Q',"nnnnnnwww"},{'R',"wnnnnnwwn"},{'S',"nnwnnnwwn"},{'T',"nnnnwnwwn"},
        {'U',"wwnnnnnnw"},{'V',"nwwnnnnnw"},{'W',"wwwnnnnnn"},{'X',"nwnnwnnnw"},{'Y',"wwnnwnnnn"},
        {'Z',"nwwnwnnnn"},{'-',"nwnnnnwnw"},{'.',"wwnnnnwnn"},{' ',"nwwnnnwnn"},{'$',"nwnwnwnnn"},
        {'/',"nwnwnnnwn"},{'+',"nwnnnwnwn"},{'%',"nnnwnwnwn"},{'*',"nwnnwnwnn"}
    };

    public class BarcodeResult {
        public string Format;
        public string Bits;
        public string NormalizedText;
        public string HumanText;
        public string TopHeader;   // e.g. "ISBN 978-..." or "ISSN 1234-5679"
        public bool[] GuardMask;
        public int QuietLeft;
        public int QuietRight;
        public bool BearerBox;     // GS1 carton frame for ITF-14
    }

    public static BarcodeResult EncodeBarcode(string input, string format) {
        if (input == null) input = "";
        input = input.Trim();
        format = (format ?? "EAN13").ToUpperInvariant();

        if (format == "EAN13" || format == "ISBN13" || format == "ISSN") {
            string topHeader = null;
            string digits;
            if (format == "ISBN13") {
                digits = ExtractDigits(input);
                if (digits.Length < 12 || digits.Length > 13 || (!digits.StartsWith("978") && !digits.StartsWith("979")))
                    throw new InvalidOperationException("Το ISBN-13 ξεκινά με 978 ή 979 και θέλει 12 ψηφία (ή 13 με check digit). Π.χ. 978-960-123-456");
                int chk = CalcGs1Check(digits.Substring(0, 12));
                if (digits.Length == 13 && (digits[12] - '0') != chk)
                    throw new InvalidOperationException("Λάθος 13ο ψηφίο ISBN-13! Το σωστό είναι: " + chk);
                string full = digits.Substring(0, 12) + chk;
                topHeader = "ISBN " + full.Substring(0,3) + "-" + full.Substring(3,3) + "-" + full.Substring(6,3) + "-" + full.Substring(9,3) + "-" + full[12];
                digits = full;
            }
            else if (format == "ISSN") {
                string cleaned = input.ToUpperInvariant().Replace("-", "").Replace(" ", "");
                if (cleaned.StartsWith("977") && cleaned.Length >= 12) {
                    digits = ExtractDigits(cleaned);
                    int chk = CalcGs1Check(digits.Substring(0, 12));
                    digits = digits.Substring(0, 12) + chk;
                    string issn7 = digits.Substring(3, 7);
                    topHeader = "ISSN " + issn7.Substring(0,4) + "-" + issn7.Substring(4,3) + CalcIssnCheckChar(issn7);
                } else {
                    if (cleaned.Length < 7 || cleaned.Length > 8)
                        throw new InvalidOperationException("Το ISSN θέλει 7 ή 8 χαρακτήρες (π.χ. 1234-5679 ή 977...).");
                    string issn7 = cleaned.Substring(0, 7);
                    foreach (char ch in issn7) if (ch < '0' || ch > '9') throw new InvalidOperationException("Τα πρώτα 7 ψηφία του ISSN πρέπει να είναι αριθμοί.");
                    char issnChk = CalcIssnCheckChar(issn7);
                    if (cleaned.Length == 8 && cleaned[7] != issnChk)
                        throw new InvalidOperationException("Λάθος 8ος χαρακτήρας ISSN! Ο σωστός είναι: " + issnChk);
                    string ean12 = "977" + issn7 + "00";
                    digits = ean12 + CalcGs1Check(ean12);
                    topHeader = "ISSN " + issn7.Substring(0,4) + "-" + issn7.Substring(4,3) + issnChk;
                }
            }
            else {
                digits = ExtractDigits(input);
                if (digits.Length < 12 || digits.Length > 13)
                    throw new InvalidOperationException("Το EAN-13 θέλει 12 ψηφία (υπολογίζει αυτόματα το 13ο) ή 13 ψηφία. Π.χ. 520123456789");
                int chk = CalcGs1Check(digits.Substring(0, 12));
                if (digits.Length == 13 && (digits[12] - '0') != chk)
                    throw new InvalidOperationException("Λάθος 13ο ψηφίο ελέγχου! Για αυτά τα 12 ψηφία το σωστό είναι: " + chk);
                digits = digits.Substring(0, 12) + chk;
            }

            StringBuilder bits = new StringBuilder(95);
            List<bool> guard = new List<bool>(95);
            AppendSeg(bits, guard, "101", true);
            string par = EanParity[digits[0] - '0'];
            for (int i = 1; i <= 6; i++) {
                int d = digits[i] - '0';
                AppendSeg(bits, guard, par[i - 1] == 'L' ? EanL[d] : EanGFixed[d], false);
            }
            AppendSeg(bits, guard, "01010", true);
            for (int i = 7; i <= 12; i++) AppendSeg(bits, guard, EanR[digits[i] - '0'], false);
            AppendSeg(bits, guard, "101", true);

            return new BarcodeResult {
                Format = format, Bits = bits.ToString(), NormalizedText = digits,
                HumanText = digits[0] + "   " + digits.Substring(1,6) + "   " + digits.Substring(7,6),
                TopHeader = topHeader, GuardMask = guard.ToArray(), QuietLeft = 11, QuietRight = 7, BearerBox = false
            };
        }
        else if (format == "EAN8") {
            string digits = ExtractDigits(input);
            if (digits.Length < 7 || digits.Length > 8)
                throw new InvalidOperationException("Το EAN-8 θέλει 7 ψηφία (υπολογίζει αυτόματα το 8ο) ή 8 ψηφία. Π.χ. 5201234");
            int chk = CalcGs1Check(digits.Substring(0, 7));
            if (digits.Length == 8 && (digits[7] - '0') != chk)
                throw new InvalidOperationException("Λάθος 8ο ψηφίο EAN-8! Το σωστό είναι: " + chk);
            string full = digits.Substring(0, 7) + chk;

            StringBuilder bits = new StringBuilder(67);
            List<bool> guard = new List<bool>(67);
            AppendSeg(bits, guard, "101", true);
            for (int i = 0; i < 4; i++) AppendSeg(bits, guard, EanL[full[i] - '0'], false);
            AppendSeg(bits, guard, "01010", true);
            for (int i = 4; i < 8; i++) AppendSeg(bits, guard, EanR[full[i] - '0'], false);
            AppendSeg(bits, guard, "101", true);

            return new BarcodeResult {
                Format = "EAN8", Bits = bits.ToString(), NormalizedText = full,
                HumanText = full.Substring(0,4) + "   " + full.Substring(4,4),
                GuardMask = guard.ToArray(), QuietLeft = 7, QuietRight = 7, BearerBox = false
            };
        }
        else if (format == "UPCA") {
            string digits = ExtractDigits(input);
            if (digits.Length < 11 || digits.Length > 12)
                throw new InvalidOperationException("Το UPC-A θέλει 11 ψηφία (υπολογίζει αυτόματα το 12ο) ή 12 ψηφία. Π.χ. 03600029145");
            int chk = CalcGs1Check(digits.Substring(0, 11));
            if (digits.Length == 12 && (digits[11] - '0') != chk)
                throw new InvalidOperationException("Λάθος 12ο ψηφίο UPC-A! Το σωστό είναι: " + chk);
            string full = digits.Substring(0, 11) + chk;

            StringBuilder bits = new StringBuilder(95);
            List<bool> guard = new List<bool>(95);
            AppendSeg(bits, guard, "101", true);
            for (int i = 0; i < 6; i++) AppendSeg(bits, guard, EanL[full[i] - '0'], i == 0);
            AppendSeg(bits, guard, "01010", true);
            for (int i = 6; i < 12; i++) AppendSeg(bits, guard, EanR[full[i] - '0'], i == 11);
            AppendSeg(bits, guard, "101", true);

            return new BarcodeResult {
                Format = "UPCA", Bits = bits.ToString(), NormalizedText = full,
                HumanText = full[0] + "  " + full.Substring(1,5) + "   " + full.Substring(6,5) + "  " + full[11],
                GuardMask = guard.ToArray(), QuietLeft = 9, QuietRight = 9, BearerBox = false
            };
        }
        else if (format == "UPCE") {
            string digits = ExtractDigits(input);
            char ns; string core6; int givenChk = -1;
            if (digits.Length == 6) { ns = '0'; core6 = digits; }
            else if (digits.Length == 7) { ns = digits[0]; core6 = digits.Substring(1, 6); }
            else if (digits.Length == 8) { ns = digits[0]; core6 = digits.Substring(1, 6); givenChk = digits[7] - '0'; }
            else throw new InvalidOperationException("Το UPC-E θέλει 6 ψηφία (π.χ. 425261) ή 7/8 ψηφία ξεκινώντας με 0 ή 1 (π.χ. 04252614).");

            if (ns != '0' && ns != '1') throw new InvalidOperationException("Το πρώτο ψηφίο του UPC-E πρέπει να είναι 0 ή 1.");
            string upca11 = ExpandUpcETo11(ns, core6);
            int chk = CalcGs1Check(upca11);
            if (givenChk != -1 && givenChk != chk)
                throw new InvalidOperationException("Λάθος ψηφίο ελέγχου UPC-E! Το σωστό 8ο ψηφίο είναι: " + chk);
            string full = ns + core6 + chk;

            StringBuilder bits = new StringBuilder(51);
            List<bool> guard = new List<bool>(51);
            AppendSeg(bits, guard, "101", true);
            string par = UpcEParity0[chk];
            for (int i = 0; i < 6; i++) {
                bool useEven = (par[i] == 'E') ^ (ns == '1');
                AppendSeg(bits, guard, useEven ? EanGFixed[core6[i] - '0'] : EanL[core6[i] - '0'], false);
            }
            AppendSeg(bits, guard, "010101", true);

            return new BarcodeResult {
                Format = "UPCE", Bits = bits.ToString(), NormalizedText = full,
                HumanText = ns + "  " + core6 + "  " + chk,
                GuardMask = guard.ToArray(), QuietLeft = 9, QuietRight = 7, BearerBox = false
            };
        }
        else if (format == "ITF14") {
            string digits = ExtractDigits(input);
            if (digits.Length < 13 || digits.Length > 14)
                throw new InvalidOperationException("Το ITF-14 (χαρτοκιβώτια) θέλει 13 ψηφία (υπολογίζει το 14ο) ή 14 ψηφία. Π.χ. 1520123456789");
            int chk = CalcGs1Check(digits.Substring(0, 13));
            if (digits.Length == 14 && (digits[13] - '0') != chk)
                throw new InvalidOperationException("Λάθος 14ο ψηφίο ITF-14! Το σωστό είναι: " + chk);
            string full = digits.Substring(0, 13) + chk;

            StringBuilder bits = new StringBuilder(140);
            bits.Append("1010"); // Start
            for (int i = 0; i < 14; i += 2) {
                string p1 = ItfDigits[full[i] - '0'];
                string p2 = ItfDigits[full[i + 1] - '0'];
                for (int k = 0; k < 5; k++) {
                    bits.Append(p1[k] == 'W' ? "111" : "1");
                    bits.Append(p2[k] == 'W' ? "000" : "0");
                }
            }
            bits.Append("11101"); // Stop
            string hText = full[0] + " " + full.Substring(1,2) + " " + full.Substring(3,5) + " " + full.Substring(8,5) + " " + full[13];
            return new BarcodeResult {
                Format = "ITF14", Bits = bits.ToString(), NormalizedText = full, HumanText = hText,
                GuardMask = new bool[bits.Length], QuietLeft = 10, QuietRight = 10, BearerBox = true
            };
        }
        else if (format == "CODE39") {
            string up = input.ToUpperInvariant().Trim('*');
            if (up.Length == 0) throw new InvalidOperationException("Γράψε κωδικό Code 39 (A-Z, 0-9, -, ., $, /, +, %). Π.χ. NG-2026");
            foreach (char ch in up)
                if (!Code39Map.ContainsKey(ch) || ch == '*')
                    throw new InvalidOperationException("Μη επιτρεπτός χαρακτήρας για Code 39: '" + ch + "'. Δέχεται A-Z, 0-9, - . $ / + % και κενό.");

            string wrapped = "*" + up + "*";
            StringBuilder bits = new StringBuilder();
            for (int c = 0; c < wrapped.Length; c++) {
                string pat = Code39Map[wrapped[c]];
                for (int i = 0; i < 9; i++) {
                    bool isBar = (i % 2 == 0);
                    int w = (pat[i] == 'w') ? 3 : 1;
                    bits.Append(isBar ? '1' : '0', w);
                }
                if (c < wrapped.Length - 1) bits.Append('0'); // inter-char narrow space
            }
            return new BarcodeResult {
                Format = "CODE39", Bits = bits.ToString(), NormalizedText = up, HumanText = "*" + up + "*",
                GuardMask = new bool[bits.Length], QuietLeft = 10, QuietRight = 10, BearerBox = false
            };
        }
        else { // CODE128 (Auto B / C — uses high-density Code 128C when pure even digits >= 4!)
            if (input.Length == 0) throw new InvalidOperationException("Γράψε κωδικό SKU/προϊόντος για Code 128 (π.χ. NG-2026-001 ή 52012345678900).");
            bool pureDigits = true;
            foreach (char ch in input) if (ch < '0' || ch > '9') { pureDigits = false; break; }

            StringBuilder bits = new StringBuilder();
            int checksum;
            string subType;
            if (pureDigits && input.Length >= 4 && input.Length % 2 == 0) {
                // Code 128C (2 digits per symbol — super compact!)
                subType = "CODE128C";
                checksum = 105;
                bits.Append(Code128Patterns[105]);
                for (int i = 0; i < input.Length; i += 2) {
                    int val = int.Parse(input.Substring(i, 2));
                    bits.Append(Code128Patterns[val]);
                    checksum += val * ((i / 2) + 1);
                }
            } else {
                subType = "CODE128B";
                checksum = 104;
                bits.Append(Code128Patterns[104]);
                for (int i = 0; i < input.Length; i++) {
                    int code = (int)input[i] - 32;
                    if (code < 0 || code > 94)
                        throw new InvalidOperationException("Το Code 128 δέχεται λατινικούς χαρακτήρες, αριθμούς & σύμβολα (ASCII 32-126).");
                    bits.Append(Code128Patterns[code]);
                    checksum += code * (i + 1);
                }
            }
            bits.Append(Code128Patterns[checksum % 103]);
            bits.Append(Code128Patterns[106]);
            return new BarcodeResult {
                Format = subType, Bits = bits.ToString(), NormalizedText = input, HumanText = input,
                GuardMask = new bool[bits.Length], QuietLeft = 10, QuietRight = 10, BearerBox = false
            };
        }
    }

    private static string ExtractDigits(string s) {
        StringBuilder sb = new StringBuilder();
        foreach (char c in s) if (c >= '0' && c <= '9') sb.Append(c);
        return sb.ToString();
    }

    // Universal GS1 Mod-10 check digit (works for EAN-13 [12], EAN-8 [7], UPC-A [11], ITF-14 [13]!)
    private static int CalcGs1Check(string digits) {
        int sum = 0;
        int len = digits.Length;
        for (int i = 0; i < len; i++) {
            int posFromRight = len - i; // 1 = rightmost data digit (weight 3)
            int w = (posFromRight % 2 == 1) ? 3 : 1;
            sum += (digits[i] - '0') * w;
        }
        return (10 - (sum % 10)) % 10;
    }

    private static char CalcIssnCheckChar(string d7) {
        int sum = 0;
        for (int i = 0; i < 7; i++) sum += (d7[i] - '0') * (8 - i);
        int rem = sum % 11;
        if (rem == 0) return '0';
        int chk = 11 - rem;
        return (chk == 10) ? 'X' : (char)('0' + chk);
    }

    private static string ExpandUpcETo11(char ns, string c) {
        char d5 = c[5];
        if (d5 == '0' || d5 == '1' || d5 == '2') return "" + ns + c[0] + c[1] + d5 + "0000" + c[2] + c[3] + c[4];
        if (d5 == '3') return "" + ns + c[0] + c[1] + c[2] + "00000" + c[3] + c[4];
        if (d5 == '4') return "" + ns + c[0] + c[1] + c[2] + c[3] + "00000" + c[4];
        return "" + ns + c[0] + c[1] + c[2] + c[3] + c[4] + "0000" + d5;
    }

    private static void AppendSeg(StringBuilder sb, List<bool> guard, string seg, bool isGuard) {
        sb.Append(seg);
        for (int i = 0; i < seg.Length; i++) guard.Add(isGuard);
    }

    public static Bitmap RenderBarcodeBitmap(BarcodeResult bc, int scale, Color fg, Color bg, string caption) {
        if (scale < 2) scale = 2;
        int bearer = bc.BearerBox ? scale * 4 : 0;
        int totalMods = bc.QuietLeft + bc.Bits.Length + bc.QuietRight;
        int w = totalMods * scale + bearer * 2;
        int topHeaderH = string.IsNullOrWhiteSpace(bc.TopHeader) ? 0 : scale * 12;
        int barH = scale * 46;
        int guardExtra = scale * 7;
        int topPad = scale * 5 + topHeaderH + bearer;
        int textH = scale * 16;
        int capH = string.IsNullOrWhiteSpace(caption) ? 0 : scale * 12;
        int h = topPad + barH + bearer + textH + capH + scale * 4;

        Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.None;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            g.Clear(bg);

            using (SolidBrush fgBrush = new SolidBrush(fg)) {
                if (topHeaderH > 0) {
                    using (Font fh = new Font("Consolas", Math.Max(9f, scale * 5.2f), FontStyle.Bold))
                    using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        g.DrawString(bc.TopHeader, fh, fgBrush, new RectangleF(0, scale * 2, w, topHeaderH), sf);
                }

                // GS1 ITF-14 Bearer Box
                if (bc.BearerBox) {
                    int bx = scale * 2, by = topPad - bearer;
                    int bw = w - scale * 4, bh = barH + bearer * 2;
                    using (Pen bp = new Pen(fg, bearer)) {
                        g.DrawRectangle(bp, bx + bearer / 2f, by + bearer / 2f, bw - bearer, bh - bearer);
                    }
                }

                for (int i = 0; i < bc.Bits.Length; i++) {
                    if (bc.Bits[i] == '1') {
                        int x = bearer + (bc.QuietLeft + i) * scale;
                        int bh = bc.GuardMask[i] ? (barH + guardExtra) : barH;
                        g.FillRectangle(fgBrush, x, topPad, scale, bh);
                    }
                }

                using (Font f = new Font("Consolas", Math.Max(10f, scale * 6.0f), FontStyle.Bold))
                using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Near })
                    g.DrawString(bc.HumanText, f, fgBrush, new RectangleF(0, topPad + barH + bearer + scale * 2, w, textH), sf);

                if (capH > 0) {
                    using (Font fc = new Font("Segoe UI", Math.Max(9f, scale * 4.4f), FontStyle.Regular))
                    using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Near })
                        g.DrawString(caption.Trim(), fc, fgBrush, new RectangleF(0, topPad + barH + bearer + textH, w, capH), sf);
                }
            }
        }
        return bmp;
    }

    public static string RenderBarcodeSvg(BarcodeResult bc, string fgHex, string bgHex, string caption) {
        const int unit = 3;
        int bearer = bc.BearerBox ? 10 : 0;
        int totalW = (bc.QuietLeft + bc.Bits.Length + bc.QuietRight) * unit + bearer * 2;
        bool hasTop = !string.IsNullOrWhiteSpace(bc.TopHeader);
        int topHeaderH = hasTop ? 28 : 0;
        int barH = 120;
        int guardExtra = 18;
        int topPad = 14 + topHeaderH + bearer;
        bool hasCap = !string.IsNullOrWhiteSpace(caption);
        int totalH = topPad + barH + bearer + 42 + (hasCap ? 26 : 0);

        StringBuilder sb = new StringBuilder(6144);
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine("<!-- Generated by PC Manager & Tools | created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/ -->");
        sb.AppendFormat("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {0} {1}\" width=\"{0}\" height=\"{1}\" shape-rendering=\"crispEdges\">\n", totalW, totalH);
        sb.AppendFormat("  <rect width=\"100%\" height=\"100%\" fill=\"{0}\"/>\n", bgHex);

        if (hasTop) {
            string escTop = System.Security.SecurityElement.Escape(bc.TopHeader);
            sb.AppendFormat("  <text x=\"{0}\" y=\"{1}\" text-anchor=\"middle\" font-family=\"Consolas, Courier New, monospace\" font-size=\"17\" font-weight=\"700\" fill=\"{2}\">{3}</text>\n",
                totalW / 2, 26, fgHex, escTop);
        }

        if (bc.BearerBox) {
            sb.AppendFormat("  <rect x=\"{0}\" y=\"{1}\" width=\"{2}\" height=\"{3}\" fill=\"none\" stroke=\"{4}\" stroke-width=\"{5}\"/>\n",
                bearer / 2 + 4, topPad - bearer / 2, totalW - bearer - 8, barH + bearer, fgHex, bearer);
        }

        sb.AppendFormat("  <g fill=\"{0}\">\n", fgHex);
        for (int i = 0; i < bc.Bits.Length; i++) {
            if (bc.Bits[i] == '1') {
                int x = bearer + (bc.QuietLeft + i) * unit;
                int bh = bc.GuardMask[i] ? (barH + guardExtra) : barH;
                sb.AppendFormat("    <rect x=\"{0}\" y=\"{1}\" width=\"{2}\" height=\"{3}\"/>\n", x, topPad, unit, bh);
            }
        }
        sb.AppendLine("  </g>");

        string escHuman = System.Security.SecurityElement.Escape(bc.HumanText);
        sb.AppendFormat("  <text x=\"{0}\" y=\"{1}\" text-anchor=\"middle\" font-family=\"Consolas, Courier New, monospace\" font-size=\"21\" font-weight=\"700\" fill=\"{2}\">{3}</text>\n",
            totalW / 2, topPad + barH + bearer + 28, fgHex, escHuman);

        if (hasCap) {
            string escCap = System.Security.SecurityElement.Escape(caption.Trim());
            sb.AppendFormat("  <text x=\"{0}\" y=\"{1}\" text-anchor=\"middle\" font-family=\"Segoe UI, Arial, sans-serif\" font-size=\"14\" fill=\"{2}\">{3}</text>\n",
                totalW / 2, topPad + barH + bearer + 54, fgHex, escCap);
        }
        sb.AppendLine("</svg>");
        return sb.ToString();
    }
}
"@ -ErrorAction SilentlyContinue
}

$script:QRState = @{
    Initialized = $false
    Ui          = $null
    RootDir     = $null
    LastQr      = $null
    LastBc      = $null
    LastMode    = "QR"
    LastPayload = ""
    LastFgHex   = "#000000"
    LastBgHex   = "#FFFFFF"
    LastRounded = $false
    LastCaption = ""
}

$script:BarcodeSamples = @{
    EAN13   = @{ Sample="520123456789";     Hint="EAN-13 (12 ψηφία → αυτόματο 13ο check digit | Σούπερ μάρκετ Ελλάδας 520... & ΕΕ):" }
    EAN8    = @{ Sample="5201234";          Hint="EAN-8 (7 ψηφία → αυτόματο 8ο check digit | Μικρές συσκευασίες, καλλυντικά):" }
    ITF14   = @{ Sample="1520123456789";    Hint="ITF-14 (13 ψηφία → αυτόματο 14ο | Κούτες / Χαρτοκιβώτια χονδρικής με Bearer Bar):" }
    UPCA    = @{ Sample="03600029145";      Hint="UPC-A (11 ψηφία → αυτόματο 12ο | Εξαγωγές ΗΠΑ / Καναδά / Amazon):" }
    UPCE    = @{ Sample="0425261";          Hint="UPC-E (6 ή 7 ψηφία ξεκινώντας με 0/1 | Μικρές συσκευασίες ΗΠΑ):" }
    ISBN13  = @{ Sample="978-960-123-456";  Hint="ISBN-13 (Βιβλία & Εξώφυλλα — ξεκινά με 978/979, αυτόματο 13ο ψηφίο):" }
    ISSN    = @{ Sample="1234-5679";        Hint="ISSN (Περιοδικά / Έντυπα — 7 ή 8 ψηφία, μετατρέπεται σε GS1 977):" }
    CODE128 = @{ Sample="NG-2026-001";      Hint="Code 128 Auto B/C (SKU, Αποθήκη, Courier — αυτόματη συμπίεση 128C για ζυγούς αριθμούς):" }
    CODE39  = @{ Sample="NG-2026";          Hint="Code 39 (Βιομηχανικά / Εξοπλισμός — A-Z, 0-9, -, ., $, /, +, %):" }
}

function Convert-BitmapToWpfImage {
    param([System.Drawing.Bitmap]$Bmp)
    $ms = New-Object System.IO.MemoryStream
    $Bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $ms.Position = 0
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bi.StreamSource = $ms
    $bi.EndInit()
    $bi.Freeze()
    $ms.Dispose()
    return $bi
}

function Parse-HexColorSafe {
    param([string]$Hex, [System.Drawing.Color]$Fallback)
    if (-not $Hex) { return $Fallback }
    $h = $Hex.Trim().TrimStart('#')
    if ($h -match '^[0-9A-Fa-f]{6}$') {
        return [System.Drawing.Color]::FromArgb(
            255,
            [Convert]::ToInt32($h.Substring(0,2), 16),
            [Convert]::ToInt32($h.Substring(2,2), 16),
            [Convert]::ToInt32($h.Substring(4,2), 16)
        )
    }
    return $Fallback
}

function Build-QrPayloadFromUi {
    $ui = $script:QRState.Ui
    $tpl = $ui.CmbQRTpl.SelectedItem.Tag
    switch ($tpl) {
        "URL" { return $ui.TxtQRMain.Text.Trim() }
        "VCARD" {
            $name  = $ui.TxtQRMain.Text.Trim()
            $phone = $ui.TxtQRExtra1.Text.Trim()
            $email = $ui.TxtQRExtra2.Text.Trim()
            $site  = $ui.TxtQRExtra3.Text.Trim()
            $lines = @("BEGIN:VCARD","VERSION:3.0","FN:$name","N:;$name;;;")
            if ($phone) { $lines += "TEL;TYPE=CELL,VOICE:$phone" }
            if ($email) { $lines += "EMAIL;TYPE=INTERNET:$email" }
            if ($site)  { $lines += "URL:$site" }
            $lines += "END:VCARD"
            return ($lines -join "`r`n")
        }
        "WIFI" {
            $ssid = ($ui.TxtQRMain.Text.Trim() -replace '([\\;,":])','\$1')
            $pass = ($ui.TxtQRExtra1.Text.Trim() -replace '([\\;,":])','\$1')
            $enc  = if ($pass) { "WPA" } else { "nopass" }
            return "WIFI:T:$enc;S:$ssid;P:$pass;;"
        }
        "PHONE" { return "tel:$(($ui.TxtQRMain.Text.Trim() -replace '[^0-9+]',''))" }
        "WHATSAPP" {
            $num = ($ui.TxtQRMain.Text.Trim() -replace '[^0-9]','')
            $msg = [Uri]::EscapeDataString($ui.TxtQRExtra1.Text.Trim())
            if ($msg) { return "https://wa.me/$num?text=$msg" }
            return "https://wa.me/$num"
        }
        default { return $ui.TxtQRMain.Text.Trim() }
    }
}

function Update-QrTemplateFields {
    param([bool]$FillSampleIfSwitching = $false)
    $ui = $script:QRState.Ui
    $mode = $ui.CmbQRMode.SelectedItem.Tag
    if ($mode -eq "QR") {
        $ui.PanelQROptions.Visibility = 'Visible'
        $ui.PanelBCOptions.Visibility = 'Collapsed'
        $ui.BtnQRSample.Visibility    = 'Collapsed'
        $tpl = $ui.CmbQRTpl.SelectedItem.Tag
        $ui.RowQRExtra1.Visibility = 'Collapsed'
        $ui.RowQRExtra2.Visibility = 'Collapsed'
        $ui.RowQRExtra3.Visibility = 'Collapsed'
        switch ($tpl) {
            "URL"      { $ui.LblQRMain.Text = "URL / Website (Δεν λήγει ποτέ — ανοίγει άμεσα σε iPhone & Android):"; if ($FillSampleIfSwitching -and $ui.TxtQRMain.Text -notmatch '^https?://') { $ui.TxtQRMain.Text = "https://nillygraphics.com/" } }
            "VCARD"    { $ui.LblQRMain.Text = "Ονοματεπώνυμο / Brand (vCard 3.0 — native iPhone & Android Επαφή):"; $ui.LblQRExtra1.Text = "Τηλέφωνο (+30...):"; $ui.LblQRExtra2.Text = "Email:"; $ui.LblQRExtra3.Text = "Website:"; $ui.RowQRExtra1.Visibility='Visible'; $ui.RowQRExtra2.Visibility='Visible'; $ui.RowQRExtra3.Visibility='Visible' }
            "WIFI"     { $ui.LblQRMain.Text = "Όνομα Wi-Fi (SSID — 1-tap σύνδεση σε iPhone Camera):"; $ui.LblQRExtra1.Text = "Κωδικός Wi-Fi (κενό για ανοιχτό):"; $ui.RowQRExtra1.Visibility='Visible' }
            "PHONE"    { $ui.LblQRMain.Text = "Αριθμός Τηλεφώνου (π.χ. +302101234567):" }
            "WHATSAPP" { $ui.LblQRMain.Text = "Αριθμός WhatsApp χωρίς + (π.χ. 306912345678):"; $ui.LblQRExtra1.Text = "Προσυμπληρωμένο μήνυμα (προαιρετικό):"; $ui.RowQRExtra1.Visibility='Visible' }
            default    { $ui.LblQRMain.Text = "Ελεύθερο Κείμενο / Payload:" }
        }
    } else {
        $ui.PanelQROptions.Visibility = 'Collapsed'
        $ui.PanelBCOptions.Visibility = 'Visible'
        $ui.BtnQRSample.Visibility    = 'Visible'
        $ui.RowQRExtra1.Visibility = 'Collapsed'
        $ui.RowQRExtra2.Visibility = 'Collapsed'
        $ui.RowQRExtra3.Visibility = 'Collapsed'
        $bfmt = $ui.CmbBCFormat.SelectedItem.Tag
        $meta = $script:BarcodeSamples[$bfmt]
        if ($meta) {
            $ui.LblQRMain.Text = $meta.Hint
            if ($FillSampleIfSwitching) {
                $ui.TxtQRMain.Text = $meta.Sample
            }
        }
    }
}

function Invoke-NillyGenerateCode {
    $ui = $script:QRState.Ui
    $mode = $ui.CmbQRMode.SelectedItem.Tag
    $fgHex = $ui.TxtQRFg.Text.Trim(); if ($fgHex -notmatch '^#[0-9A-Fa-f]{6}$') { $fgHex = "#000000" }
    $bgHex = $ui.TxtQRBg.Text.Trim(); if ($bgHex -notmatch '^#[0-9A-Fa-f]{6}$') { $bgHex = "#FFFFFF" }
    $fgCol = Parse-HexColorSafe $fgHex ([System.Drawing.Color]::Black)
    $bgCol = Parse-HexColorSafe $bgHex ([System.Drawing.Color]::White)
    $caption = $ui.TxtQRCaption.Text.Trim()
    $rounded = [bool]$ui.ChkQRRounded.IsChecked

    $script:QRState.LastMode    = $mode
    $script:QRState.LastFgHex   = $fgHex
    $script:QRState.LastBgHex   = $bgHex
    $script:QRState.LastRounded = $rounded
    $script:QRState.LastCaption = $caption

    $lumFg = 0.2126 * $fgCol.R + 0.7152 * $fgCol.G + 0.0722 * $fgCol.B
    $lumBg = 0.2126 * $bgCol.R + 0.7152 * $bgCol.G + 0.0722 * $bgCol.B
    $warn = if ([math]::Abs($lumBg - $lumFg) -lt 90) { " ⚠ Χαμηλή αντίθεση — για scanner/iPhone προτίμησε σκούρο σε λευκό!" } else { "" }

    try {
        if ($mode -eq "QR") {
            $payload = Build-QrPayloadFromUi
            if ([string]::IsNullOrWhiteSpace($payload)) { $ui.TxtQRStatus.Text = "Γράψε πρώτα URL ή δεδομένα."; return }
            $ecc = [int]$ui.CmbQREcc.SelectedItem.Tag
            $qr = [NillyQrBarcodeEngineV2]::EncodeQr($payload, $ecc)
            $bmp = [NillyQrBarcodeEngineV2]::RenderQrBitmap($qr, 560, $fgCol, $bgCol, $rounded, $caption)
            $ui.ImgQRPreview.Source = Convert-BitmapToWpfImage $bmp
            $bmp.Dispose()

            $script:QRState.LastQr = $qr; $script:QRState.LastBc = $null; $script:QRState.LastPayload = $payload
            $eccLbl = @('L (7%)','M (15%)','Q (25%)','H (30%)')[$ecc]
            $ui.TxtQRMeta.Text = "QR ISO/IEC 18004  •  Version $($qr.Version) ($($qr.Size)×$($qr.Size))  •  ECC $eccLbl  •  $($qr.ByteCount)B  •  100% Static"
            $ui.TxtQRStatus.Text = "Έτοιμο για iPhone & Android! Εξαγωγή σε Vector SVG (εκτύπωση) ή 300-DPI PNG.$warn"
        } else {
            $bfmt = $ui.CmbBCFormat.SelectedItem.Tag
            $raw  = $ui.TxtQRMain.Text.Trim()
            $bc   = [NillyQrBarcodeEngineV2]::EncodeBarcode($raw, $bfmt)
            $bmp  = [NillyQrBarcodeEngineV2]::RenderBarcodeBitmap($bc, 4, $fgCol, $bgCol, $caption)
            $ui.ImgQRPreview.Source = Convert-BitmapToWpfImage $bmp
            $bmp.Dispose()

            $script:QRState.LastBc = $bc; $script:QRState.LastQr = $null; $script:QRState.LastPayload = $bc.NormalizedText
            $extra = if ($bc.TopHeader) { "  •  $($bc.TopHeader)" } elseif ($bc.BearerBox) { "  •  GS1 Bearer Box" } else { "" }
            $ui.TxtQRMeta.Text = "Barcode $($bc.Format)  •  $($bc.NormalizedText)$extra  •  $($bc.Bits.Length) mod  •  ISO Verified"
            $ui.TxtQRStatus.Text = "Έγκυρο $($bc.Format) ($($bc.NormalizedText))! Έτοιμο για Vector SVG ή 300-DPI PNG.$warn"
        }
    } catch {
        $ui.TxtQRStatus.Text = "Προσοχή: $($_.Exception.Message)"
    }
}

function Load-SavedClientCodes {
    $ui = $script:QRState.Ui
    $dbPath = Join-Path $script:QRState.RootDir "saved_codes.json"
    if (-not (Test-Path $dbPath)) { $ui.ListQRSaved.ItemsSource = @(); return }
    try {
        $raw = Get-Content -Path $dbPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { $ui.ListQRSaved.ItemsSource = @(); return }
        $ui.ListQRSaved.ItemsSource = @($raw | ConvertFrom-Json)
    } catch { $ui.ListQRSaved.ItemsSource = @() }
}

function Save-CurrentClientCode {
    $ui = $script:QRState.Ui
    if (-not $script:QRState.LastPayload) { $ui.TxtQRStatus.Text = "Δημιούργησε πρώτα ένα QR ή Barcode."; return }
    $label = $ui.TxtQRClientName.Text.Trim()
    if (-not $label) {
        $label = if ($script:QRState.LastCaption) { $script:QRState.LastCaption } else { $script:QRState.LastPayload.Substring(0, [math]::Min(32, $script:QRState.LastPayload.Length)) }
    }
    $dbPath = Join-Path $script:QRState.RootDir "saved_codes.json"
    $list = [System.Collections.Generic.List[object]]::new()
    if (Test-Path $dbPath) {
        try {
            $existing = @(Get-Content -Path $dbPath -Raw -Encoding UTF8 | ConvertFrom-Json)
            foreach ($x in $existing) { if ($x) { [void]$list.Add($x) } }
        } catch {}
    }
    $typeTag = if ($script:QRState.LastMode -eq "QR") { "QR" } else { $ui.CmbBCFormat.SelectedItem.Tag }
    $list.Insert(0, [PSCustomObject]@{
        Client  = $label
        Type    = $typeTag
        Payload = $script:QRState.LastPayload
        Caption = $script:QRState.LastCaption
        Fg      = $script:QRState.LastFgHex
        Bg      = $script:QRState.LastBgHex
        Date    = (Get-Date -Format "yyyy-MM-dd HH:mm")
    })
    [System.IO.File]::WriteAllText($dbPath, (ConvertTo-Json -InputObject @($list) -Depth 4), [System.Text.UTF8Encoding]::new($false))
    Load-SavedClientCodes
    $ui.TxtQRStatus.Text = "Αποθηκεύτηκε στο αρχείο πελατών (saved_codes.json): $label"
}

function Initialize-QrBarcodeTool {
    param(
        [System.Windows.Window]$MainWindow,
        [hashtable]$UiMap,
        [string]$RootDir
    )

    if ($script:QRState.Initialized) { return }
    $script:QRState.Initialized = $true
    $script:QRState.Ui          = $UiMap
    $script:QRState.RootDir     = $RootDir

    $UiMap.CmbQRMode.Add_SelectionChanged({ Update-QrTemplateFields -FillSampleIfSwitching $true; Invoke-NillyGenerateCode })
    $UiMap.CmbQRTpl.Add_SelectionChanged({ Update-QrTemplateFields -FillSampleIfSwitching $false })
    $UiMap.CmbBCFormat.Add_SelectionChanged({ Update-QrTemplateFields -FillSampleIfSwitching $true; Invoke-NillyGenerateCode })
    $UiMap.BtnQRGenerate.Add_Click({ Invoke-NillyGenerateCode })
    $UiMap.BtnQRSample.Add_Click({
        $bfmt = $script:QRState.Ui.CmbBCFormat.SelectedItem.Tag
        if ($script:BarcodeSamples[$bfmt]) {
            $script:QRState.Ui.TxtQRMain.Text = $script:BarcodeSamples[$bfmt].Sample
            Invoke-NillyGenerateCode
        }
    })

    $UiMap.BtnQRSaveSvg.Add_Click({
        if (-not $script:QRState.LastQr -and -not $script:QRState.LastBc) { Invoke-NillyGenerateCode }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "Vector SVG (*.svg)|*.svg"
        $dlg.FileName = if ($script:QRState.LastMode -eq "QR") { "nilly-qrcode.svg" } else { "nilly-barcode-$($script:QRState.LastBc.Format)-$($script:QRState.LastBc.NormalizedText).svg" }
        if ($dlg.ShowDialog() -eq $true) {
            $svg = if ($script:QRState.LastMode -eq "QR") {
                [NillyQrBarcodeEngineV2]::RenderQrSvg($script:QRState.LastQr, $script:QRState.LastFgHex, $script:QRState.LastBgHex, $script:QRState.LastRounded, $script:QRState.LastCaption)
            } else {
                [NillyQrBarcodeEngineV2]::RenderBarcodeSvg($script:QRState.LastBc, $script:QRState.LastFgHex, $script:QRState.LastBgHex, $script:QRState.LastCaption)
            }
            [System.IO.File]::WriteAllText($dlg.FileName, $svg, [System.Text.UTF8Encoding]::new($false))
            $script:QRState.Ui.TxtQRStatus.Text = "Αποθηκεύτηκε Vector SVG: $($dlg.FileName)"
        }
    })

    $UiMap.BtnQRSavePng.Add_Click({
        if (-not $script:QRState.LastQr -and -not $script:QRState.LastBc) { Invoke-NillyGenerateCode }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "High-Res PNG (*.png)|*.png"
        $dlg.FileName = if ($script:QRState.LastMode -eq "QR") { "nilly-qrcode-2048px.png" } else { "nilly-barcode-$($script:QRState.LastBc.Format)-$($script:QRState.LastBc.NormalizedText).png" }
        if ($dlg.ShowDialog() -eq $true) {
            $fgCol = Parse-HexColorSafe $script:QRState.LastFgHex ([System.Drawing.Color]::Black)
            $bgCol = Parse-HexColorSafe $script:QRState.LastBgHex ([System.Drawing.Color]::White)
            $bmp = if ($script:QRState.LastMode -eq "QR") {
                [NillyQrBarcodeEngineV2]::RenderQrBitmap($script:QRState.LastQr, 2048, $fgCol, $bgCol, $script:QRState.LastRounded, $script:QRState.LastCaption)
            } else {
                [NillyQrBarcodeEngineV2]::RenderBarcodeBitmap($script:QRState.LastBc, 8, $fgCol, $bgCol, $script:QRState.LastCaption)
            }
            $bmp.SetResolution(300, 300)
            $bmp.Save($dlg.FileName, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            $script:QRState.Ui.TxtQRStatus.Text = "Αποθηκεύτηκε High-Res PNG (300 DPI): $($dlg.FileName)"
        }
    })

    $UiMap.BtnQRCopyImg.Add_Click({
        if (-not $script:QRState.LastQr -and -not $script:QRState.LastBc) { Invoke-NillyGenerateCode }
        try {
            $fgCol = Parse-HexColorSafe $script:QRState.LastFgHex ([System.Drawing.Color]::Black)
            $bgCol = Parse-HexColorSafe $script:QRState.LastBgHex ([System.Drawing.Color]::White)
            $bmp = if ($script:QRState.LastMode -eq "QR") {
                [NillyQrBarcodeEngineV2]::RenderQrBitmap($script:QRState.LastQr, 1024, $fgCol, $bgCol, $script:QRState.LastRounded, $script:QRState.LastCaption)
            } else {
                [NillyQrBarcodeEngineV2]::RenderBarcodeBitmap($script:QRState.LastBc, 6, $fgCol, $bgCol, $script:QRState.LastCaption)
            }
            $img = Convert-BitmapToWpfImage $bmp
            $bmp.Dispose()
            [System.Windows.Clipboard]::SetImage($img)
            $script:QRState.Ui.TxtQRStatus.Text = "Η εικόνα αντιγράφηκε στο Clipboard (Ctrl+V σε Affinity, Email, WhatsApp)!"
        } catch {
            $script:QRState.Ui.TxtQRStatus.Text = "Σφάλμα αντιγραφής εικόνας: $($_.Exception.Message)"
        }
    })

    $UiMap.BtnQRSaveClient.Add_Click({ Save-CurrentClientCode })
    $UiMap.ListQRSaved.Add_MouseDoubleClick({
        $sel = $script:QRState.Ui.ListQRSaved.SelectedItem
        if (-not $sel) { return }
        if ($sel.Type -eq "QR") {
            $script:QRState.Ui.CmbQRMode.SelectedIndex = 0
            $script:QRState.Ui.CmbQRTpl.SelectedIndex = 5
        } else {
            $script:QRState.Ui.CmbQRMode.SelectedIndex = 1
            $idx = 0
            for ($i = 0; $i -lt $script:QRState.Ui.CmbBCFormat.Items.Count; $i++) {
                if ($script:QRState.Ui.CmbBCFormat.Items[$i].Tag -eq $sel.Type) { $idx = $i; break }
            }
            $script:QRState.Ui.CmbBCFormat.SelectedIndex = $idx
        }
        Update-QrTemplateFields -FillSampleIfSwitching $false
        $script:QRState.Ui.TxtQRMain.Text = $sel.Payload
        $script:QRState.Ui.TxtQRCaption.Text = $sel.Caption
        if ($sel.Fg) { $script:QRState.Ui.TxtQRFg.Text = $sel.Fg }
        if ($sel.Bg) { $script:QRState.Ui.TxtQRBg.Text = $sel.Bg }
        Invoke-NillyGenerateCode
    })

    Update-QrTemplateFields -FillSampleIfSwitching $false
    $UiMap.TxtQRMain.Text = "https://nillygraphics.com/"
    $UiMap.TxtQRCaption.Text = "nillygraphics.com"
    Load-SavedClientCodes
    Invoke-NillyGenerateCode
}

Export-ModuleMember -Function Initialize-QrBarcodeTool, Invoke-NillyGenerateCode
