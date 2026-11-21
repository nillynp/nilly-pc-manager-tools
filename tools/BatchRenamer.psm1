<#
.SYNOPSIS
    Nilly QuickTools — Tool #4: Batch Renamer & Greek-to-SEO Slug Converter (with Live Preview & 1-Click Undo)
    Lazy-loaded PowerShell Module for PC Manager & Tools (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:BRState = @{
    Initialized = $false
    Ui          = $null
    Files       = [System.Collections.Generic.List[string]]::new()
    LastUndoMap = [System.Collections.Generic.List[object]]::new()
}

function Convert-GreekToSeoSlug {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $s = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $clean = $sb.ToString().ToLowerInvariant()

    # Digraphs first (Greek phonetics for clean Google SEO URLs!)
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

function Build-BatchRenamePreview {
    $ui = $script:BRState.Ui
    $find    = $ui.TxtBRFind.Text
    $replace = $ui.TxtBRReplace.Text
    $prefix  = $ui.TxtBRPrefix.Text
    $suffix  = $ui.TxtBRSuffix.Text
    $seoSlug = [bool]$ui.ChkBRSeoSlug.IsChecked
    $addNum  = [bool]$ui.ChkBRNumbering.IsChecked

    $rows = @()
    $idx = 1
    foreach ($fullPath in $script:BRState.Files) {
        if (-not (Test-Path $fullPath -PathType Leaf)) { continue }
        $dir  = [System.IO.Path]::GetDirectoryName($fullPath)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
        $ext  = [System.IO.Path]::GetExtension($fullPath)

        $newBase = $base
        if (-not [string]::IsNullOrEmpty($find)) {
            $newBase = $newBase.Replace($find, $replace)
        }
        if ($seoSlug) {
            $newBase = Convert-GreekToSeoSlug -Text $newBase
            $ext = $ext.ToLowerInvariant()
        }
        if ($prefix) { $newBase = "$prefix$newBase" }
        if ($suffix) { $newBase = "$newBase$suffix" }
        if ($addNum) { $newBase = ("{0}-{1:D3}" -f $newBase, $idx) }
        if ([string]::IsNullOrWhiteSpace($newBase)) { $newBase = "file-$idx" }

        $newName = "$newBase$ext"
        $oldName = [System.IO.Path]::GetFileName($fullPath)
        $rows += [PSCustomObject]@{
            OldName = $oldName
            NewName = $newName
            Changed = if ($oldName -cne $newName) { "Αλλαγή" } else { "Ίδιο" }
            OldFull = $fullPath
            NewFull = Join-Path $dir $newName
        }
        $idx++
    }
    $ui.ListBRPreview.ItemsSource = $rows
    return $rows
}

function Add-BatchRenamerFiles {
    param([string[]]$Paths)
    $added = 0
    foreach ($p in $Paths) {
        if (Test-Path $p -PathType Container) {
            Get-ChildItem $p -File -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $script:BRState.Files.Contains($_.FullName)) { [void]$script:BRState.Files.Add($_.FullName); $added++ }
            }
        } elseif (Test-Path $p -PathType Leaf) {
            if (-not $script:BRState.Files.Contains($p)) { [void]$script:BRState.Files.Add($p); $added++ }
        }
    }
    [void](Build-BatchRenamePreview)
    if ($added -gt 0) { $script:BRState.Ui.TxtBRStatus.Text = "Προστέθηκαν $added αρχεία (Live Preview ενημερώθηκε)." }
}

function Initialize-BatchRenamerTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:BRState.Initialized) { return }
    $script:BRState.Initialized = $true
    $script:BRState.Ui          = $UiMap

    $dropHandler = {
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            Add-BatchRenamerFiles -Paths ([string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop))
        }
    }
    $UiMap.ZoneBRDrop.Add_Drop($dropHandler)
    $UiMap.ListBRPreview.Add_Drop($dropHandler)

    $UiMap.BtnBRBrowse.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Multiselect = $true
        $dlg.Filter = "All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) { Add-BatchRenamerFiles -Paths $dlg.FileNames }
    })

    $UiMap.BtnBRClear.Add_Click({
        $script:BRState.Files.Clear()
        [void](Build-BatchRenamePreview)
        $script:BRState.Ui.TxtBRStatus.Text = "Η λίστα καθαρίστηκε."
    })

    foreach ($tb in @($UiMap.TxtBRFind,$UiMap.TxtBRReplace,$UiMap.TxtBRPrefix,$UiMap.TxtBRSuffix)) {
        $tb.Add_TextChanged({ [void](Build-BatchRenamePreview) })
    }
    foreach ($cb in @($UiMap.ChkBRSeoSlug,$UiMap.ChkBRNumbering)) {
        $cb.Add_Checked({ [void](Build-BatchRenamePreview) })
        $cb.Add_Unchecked({ [void](Build-BatchRenamePreview) })
    }

    $UiMap.BtnBRApply.Add_Click({
        $rows = @(Build-BatchRenamePreview)
        if ($rows.Count -eq 0) { $script:BRState.Ui.TxtBRStatus.Text = "Πρόσθεσε πρώτα αρχεία."; return }
        $script:BRState.LastUndoMap.Clear()
        $newList = [System.Collections.Generic.List[string]]::new()
        $done = 0; $skip = 0

        foreach ($r in $rows) {
            if ($r.OldFull -ceq $r.NewFull) { [void]$newList.Add($r.OldFull); continue }
            if ((Test-Path $r.NewFull) -and ($r.OldFull.ToLowerInvariant() -ne $r.NewFull.ToLowerInvariant())) {
                $skip++; [void]$newList.Add($r.OldFull); continue
            }
            try {
                # Handle case-only rename cleanly on NTFS via temp hop
                if ($r.OldFull.ToLowerInvariant() -eq $r.NewFull.ToLowerInvariant()) {
                    $tmp = $r.OldFull + ".nillytmp"
                    [System.IO.File]::Move($r.OldFull, $tmp)
                    [System.IO.File]::Move($tmp, $r.NewFull)
                } else {
                    [System.IO.File]::Move($r.OldFull, $r.NewFull)
                }
                [void]$script:BRState.LastUndoMap.Add([PSCustomObject]@{ From=$r.NewFull; To=$r.OldFull })
                [void]$newList.Add($r.NewFull)
                $done++
            } catch {
                $skip++; [void]$newList.Add($r.OldFull)
            }
        }
        $script:BRState.Files = $newList
        [void](Build-BatchRenamePreview)
        $script:BRState.Ui.TxtBRStatus.Text = "Μετονομάστηκαν $done αρχεία!" + $(if ($skip -gt 0) { " ($skip παραλείφθηκαν για αποφυγή σύγκρουσης)" } else { " (Μπορείς να πατήσεις Undo αν θες αναίρεση)" })
    })

    $UiMap.BtnBRUndo.Add_Click({
        if ($script:BRState.LastUndoMap.Count -eq 0) {
            $script:BRState.Ui.TxtBRStatus.Text = "Δεν υπάρχει πρόσφατη μετονομασία για αναίρεση."
            return
        }
        $restored = 0
        $newList = [System.Collections.Generic.List[string]]::new()
        for ($i = $script:BRState.LastUndoMap.Count - 1; $i -ge 0; $i--) {
            $u = $script:BRState.LastUndoMap[$i]
            try {
                if (Test-Path $u.From) {
                    [System.IO.File]::Move($u.From, $u.To)
                    [void]$newList.Add($u.To)
                    $restored++
                }
            } catch {}
        }
        $script:BRState.LastUndoMap.Clear()
        if ($newList.Count -gt 0) { $script:BRState.Files = $newList }
        [void](Build-BatchRenamePreview)
        $script:BRState.Ui.TxtBRStatus.Text = "Αναίρεση (Undo) ολοκληρώθηκε: επανήλθαν $restored αρχεία."
    })
}

Export-ModuleMember -Function Initialize-BatchRenamerTool, Convert-GreekToSeoSlug, Add-BatchRenamerFiles
