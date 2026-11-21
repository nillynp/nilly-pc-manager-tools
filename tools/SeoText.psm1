<#
.SYNOPSIS
    Nilly QuickTools — SEO, Text & Password Toolkit
    Google SERP Title/Meta Length Checker + Greek->SEO URL Slug + Plain Text Cleaner + Case Converter + Crypto Password Generator
    Lazy-loaded PowerShell Module (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:SEOState = @{
    Initialized = $false
    Ui          = $null
    BrushConv   = [Windows.Media.BrushConverter]::new()
}

function Convert-TextToSeoSlugLocal {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $s = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $clean = $sb.ToString().ToLowerInvariant()
    $clean = $clean -replace 'ου','ou' -replace 'αι','ai' -replace 'ει','ei' -replace 'οι','oi' -replace 'μπ','mp' -replace 'ντ','nt' -replace 'γκ','gk' -replace 'γγ','ng' -replace 'τσ','ts' -replace 'τζ','tz' -replace 'αυ','av' -replace 'ευ','ev'
    $map = [System.Collections.Generic.Dictionary[char,string]]::new()
    @(
        @('α','a'),@('β','v'),@('γ','g'),@('δ','d'),@('ε','e'),@('ζ','z'),@('η','i'),@('θ','th'),@('ι','i'),@('κ','k'),@('λ','l'),@('μ','m'),
        @('ν','n'),@('ξ','x'),@('ο','o'),@('π','p'),@('ρ','r'),@('σ','s'),@('ς','s'),@('τ','t'),@('υ','y'),@('φ','f'),@('χ','ch'),@('ψ','ps'),@('ω','o')
    ) | ForEach-Object { $map[[char]$_[0]] = $_[1] }

    $out = New-Object System.Text.StringBuilder
    foreach ($c in $clean.ToCharArray()) {
        if ($map.ContainsKey($c)) { [void]$out.Append($map[$c]) }
        elseif ($c -match '[a-z0-9]') { [void]$out.Append($c) }
        else { [void]$out.Append('-') }
    }
    return (($out.ToString() -replace '-{2,}', '-').Trim('-'))
}

function New-CryptoPassword {
    param([int]$Length = 16, [bool]$IncludeSymbols = $true)
    $chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    if ($IncludeSymbols) { $chars += "!@#$%^&*-_=+" }
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] ($Length * 2)
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) {
        $idx = ([BitConverter]::ToUInt16($bytes, $i * 2)) % $chars.Length
        [void]$sb.Append($chars[$idx])
    }
    return $sb.ToString()
}

function Update-SeoPreview {
    $ui = $script:SEOState.Ui
    $conv = $script:SEOState.BrushConv

    $title = $ui.TxtSEOTitle.Text
    $desc  = $ui.TxtSEODesc.Text
    $tLen  = $title.Length
    $dLen  = $desc.Length

    $ui.LblSEOTitleCount.Text = "$tLen / 60 chars"
    $ui.LblSEOTitleCount.Foreground = $conv.ConvertFromString($(if ($tLen -eq 0) { "#64748B" } elseif ($tLen -le 60) { "#22C55E" } elseif ($tLen -le 68) { "#F59E0B" } else { "#F43F5E" }))
    $ui.BarSEOTitle.Value = [math]::Min(80, $tLen)

    $ui.LblSEODescCount.Text = "$dLen / 155 chars"
    $ui.LblSEODescCount.Foreground = $conv.ConvertFromString($(if ($dLen -eq 0) { "#64748B" } elseif ($dLen -le 155) { "#22C55E" } elseif ($dLen -le 168) { "#F59E0B" } else { "#F43F5E" }))
    $ui.BarSEODesc.Value = [math]::Min(200, $dLen)

    $slug = Convert-TextToSeoSlugLocal -Text $title
    $ui.TxtSEOSlugOut.Text = if ($slug) { "https://nillygraphics.com/$slug/" } else { "https://nillygraphics.com/" }

    $ui.PrevSEOTitle.Text = if ($title) { $title } else { "Nilly Graphics — Σχεδιασμός Λογοτύπου, Συσκευασίας & Web" }
    $ui.PrevSEODesc.Text  = if ($desc) { $desc } else { "created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/" }
}

function Update-TextStats {
    $t = $script:SEOState.Ui.TxtSEOCleaner.Text
    $chars = $t.Length
    $words = if ([string]::IsNullOrWhiteSpace($t)) { 0 } else { ($t.Trim() -split '\s+').Count }
    $lines = if ([string]::IsNullOrEmpty($t)) { 0 } else { ($t -split "`r?`n").Count }
    $script:SEOState.Ui.LblSEOTextStats.Text = "$words λέξεις  •  $chars χαρακτήρες  •  $lines γραμμές"
}

function Initialize-SeoTextTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:SEOState.Initialized) { return }
    $script:SEOState.Initialized = $true
    $script:SEOState.Ui          = $UiMap

    $UiMap.TxtSEOTitle.Add_TextChanged({ Update-SeoPreview })
    $UiMap.TxtSEODesc.Add_TextChanged({ Update-SeoPreview })
    $UiMap.TxtSEOCleaner.Add_TextChanged({ Update-TextStats })

    $UiMap.BtnSEOCopySlug.Add_Click({
        $slugOnly = Convert-TextToSeoSlugLocal -Text $script:SEOState.Ui.TxtSEOTitle.Text
        if ($slugOnly) {
            try { [System.Windows.Clipboard]::SetDataObject($slugOnly, $true) } catch {}
            $script:SEOState.Ui.TxtSEOStatus.Text = "Αντιγράφηκε το SEO Slug: $slugOnly"
        }
    })

    $UiMap.BtnSEOCopyMeta.Add_Click({
        $t = [System.Security.SecurityElement]::Escape($script:SEOState.Ui.TxtSEOTitle.Text)
        $d = [System.Security.SecurityElement]::Escape($script:SEOState.Ui.TxtSEODesc.Text)
        $html = "<title>$t</title>`r`n<meta name=`"description`" content=`"$d`">`r`n<meta name=`"author`" content=`"Nilly graphics (Sotiris Christos) - https://nillygraphics.com/`">"
        try { [System.Windows.Clipboard]::SetDataObject($html, $true) } catch {}
        $script:SEOState.Ui.TxtSEOStatus.Text = "Αντιγράφηκαν τα έτοιμα HTML SEO Meta Tags!"
    })

    $UiMap.BtnSEOCleanSpaces.Add_Click({
        $t = $script:SEOState.Ui.TxtSEOCleaner.Text
        $t = $t -replace "[\u200B\uFEFF]", "" -replace "\u00A0", " "
        $t = ($t -replace '[ \t]+', ' ') -replace '(\r?\n){3,}', "`r`n`r`n"
        $script:SEOState.Ui.TxtSEOCleaner.Text = $t.Trim()
        $script:SEOState.Ui.TxtSEOStatus.Text = "Καθαρίστηκαν περιττά κενά, αόρατοι χαρακτήρες & κενές γραμμές!"
    })

    $UiMap.BtnSEOUpper.Add_Click({ $script:SEOState.Ui.TxtSEOCleaner.Text = $script:SEOState.Ui.TxtSEOCleaner.Text.ToUpper() })
    $UiMap.BtnSEOLower.Add_Click({ $script:SEOState.Ui.TxtSEOCleaner.Text = $script:SEOState.Ui.TxtSEOCleaner.Text.ToLower() })
    $UiMap.BtnSEOTitleCase.Add_Click({
        $ti = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
        $script:SEOState.Ui.TxtSEOCleaner.Text = $ti.ToTitleCase($script:SEOState.Ui.TxtSEOCleaner.Text.ToLower())
    })
    $UiMap.BtnSEOCopyPlain.Add_Click({
        $txt = $script:SEOState.Ui.TxtSEOCleaner.Text
        if ($txt) {
            try { [System.Windows.Clipboard]::SetDataObject($txt, $true) } catch {}
            $script:SEOState.Ui.TxtSEOStatus.Text = "Αντιγράφηκε καθαρό κείμενο (Plain Text)!"
        }
    })

    $UiMap.BtnSEOGenPass.Add_Click({
        $len = 16
        if ($script:SEOState.Ui.CmbSEOPassLen.SelectedItem) {
            [void][int]::TryParse("$($script:SEOState.Ui.CmbSEOPassLen.SelectedItem.Tag)", [ref]$len)
        }
        $sym = [bool]$script:SEOState.Ui.ChkSEOPassSym.IsChecked
        $pw = New-CryptoPassword -Length $len -IncludeSymbols $sym
        $script:SEOState.Ui.TxtSEOPassOut.Text = $pw
        try { [System.Windows.Clipboard]::SetDataObject($pw, $true) } catch {}
        $script:SEOState.Ui.TxtSEOStatus.Text = "Δημιουργήθηκε & αντιγράφηκε ασφαλής κωδικός ($len χαρακτήρες)!"
    })

    $UiMap.TxtSEOTitle.Text = "Nilly Graphics — Σχεδιασμός Λογοτύπου & Συσκευασίας"
    $UiMap.TxtSEODesc.Text  = "Επαγγελματική γραφιστική, branding, συσκευασία & ιστοσελίδες από τη Nilly Graphics (Sotiris Christos)."
    $UiMap.TxtSEOPassOut.Text = New-CryptoPassword -Length 16 -IncludeSymbols $true
    Update-SeoPreview
    Update-TextStats
}

Export-ModuleMember -Function Initialize-SeoTextTool, Convert-TextToSeoSlugLocal, New-CryptoPassword
