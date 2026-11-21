<#
.SYNOPSIS
    Nilly QuickTools — Print, DPI & Social Sizes Calculator
    Instant mm/cm <-> px converter (72/150/300/600 DPI) + Auto Bleed (+3mm/+5mm) + Print/Social Presets + Aspect Ratio
    Lazy-loaded PowerShell Module (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:PDState = @{
    Initialized = $false
    Ui          = $null
    Updating    = $false
}

$script:PDPresets = @(
    @{ Name="A4 (210 × 297 mm @ 300 DPI)";             W=210.0;  H=297.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="A3 (297 × 420 mm @ 300 DPI)";             W=297.0;  H=420.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="A5 (148 × 210 mm @ 300 DPI)";             W=148.0;  H=210.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="A6 (105 × 148 mm @ 300 DPI)";             W=105.0;  H=148.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="Επαγγελματική Κάρτα (85 × 55 mm)";        W=85.0;   H=55.0;   Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="Flyer DL (99 × 210 mm @ 300 DPI)";        W=99.0;   H=210.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="Αφίσα B2 (500 × 700 mm @ 300 DPI)";       W=500.0;  H=700.0;  Unit="mm"; Dpi=300; Bleed=3 }
    @{ Name="Roll-Up Banner (850 × 2000 mm @ 150 DPI)";W=850.0;  H=2000.0; Unit="mm"; Dpi=150; Bleed=5 }
    @{ Name="Instagram Post Square (1080 × 1080 px)";  W=1080.0; H=1080.0; Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="Instagram Portrait 4:5 (1080 × 1350 px)"; W=1080.0; H=1350.0; Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="Story / Reels / TikTok (1080 × 1920 px)"; W=1080.0; H=1920.0; Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="YouTube Thumbnail (1280 × 720 px)";       W=1280.0; H=720.0;  Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="Web OG / Share Image (1200 × 630 px)";    W=1200.0; H=630.0;  Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="Facebook Cover (820 × 312 px)";           W=820.0;  H=312.0;  Unit="px"; Dpi=72;  Bleed=0 }
    @{ Name="Full HD / 16:9 Screen (1920 × 1080 px)";  W=1920.0; H=1080.0; Unit="px"; Dpi=72;  Bleed=0 }
)

function Get-Gcd([int]$a, [int]$b) {
    $a = [math]::Abs($a); $b = [math]::Abs($b)
    while ($b -ne 0) { $t = $b; $b = $a % $b; $a = $t }
    return [math]::Max(1, $a)
}

function Recalc-PrintDpi {
    if ($script:PDState.Updating) { return }
    $ui = $script:PDState.Ui
    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    $wVal = 0.0; $hVal = 0.0; $dpi = 300; $bleedMm = 0.0
    if (-not [double]::TryParse(($ui.TxtPDWidth.Text -replace ',','.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$wVal)) { return }
    if (-not [double]::TryParse(($ui.TxtPDHeight.Text -replace ',','.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$hVal)) { return }
    if ($wVal -le 0 -or $hVal -le 0) { return }

    if (-not $ui.CmbPDUnit.SelectedItem -or -not $ui.CmbPDDpi.SelectedItem -or -not $ui.CmbPDBleed.SelectedItem) { return }
    [void][int]::TryParse("$($ui.CmbPDDpi.SelectedItem.Tag)", [ref]$dpi)
    if ($dpi -le 0) { $dpi = 300 }
    [void][double]::TryParse("$($ui.CmbPDBleed.SelectedItem.Tag)", [System.Globalization.NumberStyles]::Float, $inv, [ref]$bleedMm)

    $unit = "$($ui.CmbPDUnit.SelectedItem.Tag)"
    $wMm = 0.0; $hMm = 0.0
    switch ($unit) {
        "mm" { $wMm = $wVal; $hMm = $hVal }
        "cm" { $wMm = $wVal * 10.0; $hMm = $hVal * 10.0 }
        "px" { $wMm = ($wVal / $dpi) * 25.4; $hMm = ($hVal / $dpi) * 25.4 }
    }

    $wPx = [int][math]::Round(($wMm / 25.4) * $dpi)
    $hPx = [int][math]::Round(($hMm / 25.4) * $dpi)

    $wBleedMm = $wMm + ($bleedMm * 2.0)
    $hBleedMm = $hMm + ($bleedMm * 2.0)
    $wBleedPx = [int][math]::Round(($wBleedMm / 25.4) * $dpi)
    $hBleedPx = [int][math]::Round(($hBleedMm / 25.4) * $dpi)

    $gcd = Get-Gcd $wPx $hPx
    $rw = [int]($wPx / $gcd); $rh = [int]($hPx / $gcd)
    $ratioDec = [math]::Round($wMm / $hMm, 3)
    $ratioTxt = if ($rw -le 32 -and $rh -le 32) { "${rw}:${rh} ($ratioDec)" } else { "$ratioDec : 1" }

    $ui.ValPDPixels.Text = "$wPx × $hPx px  (@ $dpi DPI)"
    $ui.ValPDMm.Text     = ("{0:N1} × {1:N1} mm  ({2:N2} × {3:N2} cm)" -f $wMm, $hMm, ($wMm/10), ($hMm/10))
    $ui.ValPDBleed.Text  = if ($bleedMm -gt 0) {
        ("{0:N1} × {1:N1} mm  |  {2} × {3} px  (+{4}mm bleed/πλευρά)" -f $wBleedMm, $hBleedMm, $wBleedPx, $hBleedPx, $bleedMm)
    } else {
        "Χωρίς Bleed (0 mm)"
    }
    $ui.ValPDRatio.Text  = "$ratioTxt  •  $([math]::Round(($wPx * $hPx) / 1000000.0, 2)) MP"

    # Proportional Scale helper
    $newW = 0.0
    if ([double]::TryParse(($ui.TxtPDScaleW.Text -replace ',','.'), [System.Globalization.NumberStyles]::Float, $inv, [ref]$newW) -and $newW -gt 0) {
        $propH = [math]::Round($newW * ($hMm / $wMm), 1)
        $ui.TxtPDScaleRes.Text = "Αναλογικό ύψος: $propH"
    } else {
        $ui.TxtPDScaleRes.Text = "—"
    }
}

function Initialize-PrintDpiTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:PDState.Initialized) { return }
    $script:PDState.Initialized = $true
    $script:PDState.Ui          = $UiMap

    $UiMap.CmbPDPreset.Items.Clear()
    foreach ($p in $script:PDPresets) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $p.Name
        $item.Tag = $p
        [void]$UiMap.CmbPDPreset.Items.Add($item)
    }

    $UiMap.CmbPDPreset.Add_SelectionChanged({
        $sel = $script:PDState.Ui.CmbPDPreset.SelectedItem
        if (-not $sel -or -not $sel.Tag) { return }
        $p = $sel.Tag
        $script:PDState.Updating = $true
        $script:PDState.Ui.TxtPDWidth.Text  = "$($p.W)"
        $script:PDState.Ui.TxtPDHeight.Text = "$($p.H)"
        $script:PDState.Ui.CmbPDUnit.SelectedIndex = if ($p.Unit -eq "mm") { 0 } elseif ($p.Unit -eq "cm") { 1 } else { 2 }
        $script:PDState.Ui.CmbPDDpi.SelectedIndex  = if ($p.Dpi -eq 72) { 0 } elseif ($p.Dpi -eq 150) { 1 } elseif ($p.Dpi -eq 300) { 2 } else { 3 }
        $script:PDState.Ui.CmbPDBleed.SelectedIndex = if ($p.Bleed -eq 0) { 0 } elseif ($p.Bleed -eq 3) { 1 } else { 2 }
        $script:PDState.Updating = $false
        Recalc-PrintDpi
    })

    foreach ($tb in @($UiMap.TxtPDWidth,$UiMap.TxtPDHeight,$UiMap.TxtPDScaleW)) { $tb.Add_TextChanged({ Recalc-PrintDpi }) }
    foreach ($cb in @($UiMap.CmbPDUnit,$UiMap.CmbPDDpi,$UiMap.CmbPDBleed)) { $cb.Add_SelectionChanged({ Recalc-PrintDpi }) }

    $UiMap.BtnPDSwap.Add_Click({
        $script:PDState.Updating = $true
        $tmp = $script:PDState.Ui.TxtPDWidth.Text
        $script:PDState.Ui.TxtPDWidth.Text = $script:PDState.Ui.TxtPDHeight.Text
        $script:PDState.Ui.TxtPDHeight.Text = $tmp
        $script:PDState.Updating = $false
        Recalc-PrintDpi
    })

    $UiMap.BtnPDCopy.Add_Click({
        $ui = $script:PDState.Ui
        $summary = "Pixels: $($ui.ValPDPixels.Text) | Print: $($ui.ValPDMm.Text) | Bleed: $($ui.ValPDBleed.Text) | Ratio: $($ui.ValPDRatio.Text)"
        try {
            [System.Windows.Clipboard]::SetDataObject($summary, $true)
            $ui.TxtPDStatus.Text = "Αντιγράφηκαν οι διαστάσεις στο Clipboard!"
        } catch {}
    })

    $UiMap.CmbPDPreset.SelectedIndex = 0
}

Export-ModuleMember -Function Initialize-PrintDpiTool, Recalc-PrintDpi
