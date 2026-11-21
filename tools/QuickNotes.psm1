<#
.SYNOPSIS
    Nilly QuickTools — Quick Notes & Client Snippets (Lightweight Sticky Notes Replacement!)
    Local scratchpad + 1-click Copy reusable snippets stored privately in notes.json (gitignored!)
    Lazy-loaded PowerShell Module (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:QNState = @{
    Initialized = $false
    Ui          = $null
    DbPath      = $null
    Snippets    = [System.Collections.Generic.List[object]]::new()
}

function Load-QuickNotesData {
    $ui = $script:QNState.Ui
    $script:QNState.Snippets.Clear()
    if (Test-Path $script:QNState.DbPath) {
        try {
            $data = Get-Content -Path $script:QNState.DbPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $data.Scratchpad) { $ui.TxtQNScratch.Text = [string]$data.Scratchpad }
            foreach ($s in @($data.Snippets)) {
                if ($s -and $s.Title) { [void]$script:QNState.Snippets.Add($s) }
            }
        } catch {}
    } else {
        # Default helpful Nilly Graphics SEO snippet on first open
        [void]$script:QNState.Snippets.Add([PSCustomObject]@{
            Title = "Nilly Graphics Signature"
            Body  = "created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/"
        })
    }
    $ui.ListQNSnippets.ItemsSource = @($script:QNState.Snippets)
}

function Save-QuickNotesData {
    $payload = [PSCustomObject]@{
        Scratchpad = $script:QNState.Ui.TxtQNScratch.Text
        Snippets   = @($script:QNState.Snippets)
        Updated    = (Get-Date -Format "yyyy-MM-dd HH:mm")
    }
    $json = ConvertTo-Json -InputObject $payload -Depth 4
    [System.IO.File]::WriteAllText($script:QNState.DbPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Initialize-QuickNotesTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap, [string]$RootDir)
    if ($script:QNState.Initialized) { return }
    $script:QNState.Initialized = $true
    $script:QNState.Ui          = $UiMap
    $script:QNState.DbPath      = Join-Path $RootDir "notes.json"

    $UiMap.BtnQNSaveScratch.Add_Click({
        Save-QuickNotesData
        $script:QNState.Ui.TxtQNStatus.Text = "Αποθηκεύτηκαν οι σημειώσεις τοπικά (notes.json — ιδιωτικό, εκτός GitHub)."
    })

    $UiMap.BtnQNAddSnip.Add_Click({
        $title = $script:QNState.Ui.TxtQNSnipTitle.Text.Trim()
        $body  = $script:QNState.Ui.TxtQNSnipBody.Text.Trim()
        if (-not $title -or -not $body) {
            $script:QNState.Ui.TxtQNStatus.Text = "Συμπλήρωσε τίτλο & κείμενο snippet (π.χ. ΑΦΜ, IBAN, Email signature)."
            return
        }
        [void]$script:QNState.Snippets.Insert(0, [PSCustomObject]@{ Title=$title; Body=$body })
        $script:QNState.Ui.ListQNSnippets.ItemsSource = @($script:QNState.Snippets)
        $script:QNState.Ui.TxtQNSnipTitle.Text = ""
        $script:QNState.Ui.TxtQNSnipBody.Text  = ""
        Save-QuickNotesData
        $script:QNState.Ui.TxtQNStatus.Text = "Αποθηκεύτηκε το snippet: $title"
    })

    $copySelected = {
        $sel = $script:QNState.Ui.ListQNSnippets.SelectedItem
        if (-not $sel) { $script:QNState.Ui.TxtQNStatus.Text = "Επίλεξε πρώτα ένα snippet."; return }
        try {
            [System.Windows.Clipboard]::SetDataObject([string]$sel.Body, $true)
            $script:QNState.Ui.TxtQNStatus.Text = "Αντιγράφηκε στο Clipboard: $($sel.Title)"
        } catch {}
    }

    $UiMap.BtnQNCopySnip.Add_Click($copySelected)
    $UiMap.ListQNSnippets.Add_MouseDoubleClick($copySelected)

    $UiMap.BtnQNDelSnip.Add_Click({
        $idx = $script:QNState.Ui.ListQNSnippets.SelectedIndex
        if ($idx -ge 0 -and $idx -lt $script:QNState.Snippets.Count) {
            $name = $script:QNState.Snippets[$idx].Title
            $script:QNState.Snippets.RemoveAt($idx)
            $script:QNState.Ui.ListQNSnippets.ItemsSource = @($script:QNState.Snippets)
            Save-QuickNotesData
            $script:QNState.Ui.TxtQNStatus.Text = "Διαγράφηκε το snippet: $name"
        }
    })

    Load-QuickNotesData
}

Export-ModuleMember -Function Initialize-QuickNotesTool
