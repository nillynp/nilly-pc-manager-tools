<#
.SYNOPSIS
    Nilly QuickTools — SVG / Image to Base64 Data URI & File Hash (SHA-256 / MD5)
    Embed logos/icons directly into HTML/CSS/Email + verify file integrity (0 MB when unused)

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/
#>

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

$script:B64State = @{
    Initialized = $false
    Ui          = $null
    DataUri     = ""
    HtmlTag     = ""
    CssUrl      = ""
    Sha256      = ""
    Md5         = ""
}

function Process-Base64AndHashFile {
    param([string]$FilePath)
    $ui = $script:B64State.Ui
    if (-not $FilePath -or -not (Test-Path $FilePath -PathType Leaf)) {
        $ui.TxtB64Status.Text = "Επίλεξε ένα έγκυρο αρχείο."
        return
    }
    $fi = Get-Item $FilePath
    $ext = $fi.Extension.ToLowerInvariant()
    $mime = switch ($ext) {
        ".svg"  { "image/svg+xml" }
        ".png"  { "image/png" }
        ".jpg"  { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".webp" { "image/webp" }
        ".gif"  { "image/gif" }
        ".ico"  { "image/x-icon" }
        default { "application/octet-stream" }
    }

    # Fast native SHA-256 & MD5
    $sha = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $md5 = (Get-FileHash -Path $FilePath -Algorithm MD5).Hash.ToLowerInvariant()
    $script:B64State.Sha256 = $sha
    $script:B64State.Md5    = $md5
    $ui.ValB64Sha.Text = $sha
    $ui.ValB64Md5.Text = $md5

    $kb = [math]::Round($fi.Length / 1KB, 1)
    $ui.TxtB64Info.Text = "$($fi.Name)  •  $kb KB  •  $mime"

    # Base64 / Data URI (safe cap at 2 MB so WPF TextBox stays instant & snappy!)
    if ($fi.Length -le 2MB) {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $b64 = [Convert]::ToBase64String($bytes)
        $uri = "data:$mime;base64,$b64"
        $script:B64State.DataUri = $uri
        $script:B64State.HtmlTag = "<img src=`"$uri`" alt=`"$($fi.BaseName)`" />"
        $script:B64State.CssUrl  = "background-image: url(`"$uri`");"

        $preview = if ($uri.Length -gt 1200) { $uri.Substring(0, 1200) + "... [πλήρες μήκος: $($uri.Length) chars — χρησιμοποίησε τα κουμπιά Copy]" } else { $uri }
        $ui.TxtB64Output.Text = $preview
        $ui.TxtB64Status.Text = "Έτοιμο Data URI ($($uri.Length) chars) + SHA-256 / MD5! Πάτα Copy HTML, CSS ή Data URI."
    } else {
        $script:B64State.DataUri = ""
        $script:B64State.HtmlTag = ""
        $script:B64State.CssUrl  = ""
        $ui.TxtB64Output.Text = "(Το αρχείο είναι >2 MB — υπολογίστηκαν τα SHA-256 & MD5 hashes. Για Base64 web embedding προτείνονται αρχεία <500 KB.)"
        $ui.TxtB64Status.Text = "Υπολογίστηκαν SHA-256 & MD5 ($kb KB)."
    }
}

function Copy-B64Value {
    param([string]$Value, [string]$Label)
    if (-not $Value) {
        $script:B64State.Ui.TxtB64Status.Text = "Δεν υπάρχει περιεχόμενο για αντιγραφή ($Label)."
        return
    }
    try {
        [System.Windows.Clipboard]::SetDataObject($Value, $true)
        $script:B64State.Ui.TxtB64Status.Text = "Αντιγράφηκε ($Label)!"
    } catch {}
}

function Initialize-Base64HashTool {
    param([System.Windows.Window]$MainWindow, [hashtable]$UiMap)
    if ($script:B64State.Initialized) { return }
    $script:B64State.Initialized = $true
    $script:B64State.Ui          = $UiMap

    $UiMap.ZoneB64Drop.Add_DragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
        } else {
            $e.Effects = [System.Windows.DragDropEffects]::None
        }
        $e.Handled = $true
    })

    $UiMap.ZoneB64Drop.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $arr = [string[]]$e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            if ($arr.Length -gt 0) { Process-Base64AndHashFile -FilePath $arr[0] }
        }
    })

    $UiMap.BtnB64Browse.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "Images & Icons (*.svg;*.png;*.jpg;*.webp;*.ico;*.gif)|*.svg;*.png;*.jpg;*.jpeg;*.webp;*.ico;*.gif|All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) { Process-Base64AndHashFile -FilePath $dlg.FileName }
    })

    $UiMap.BtnB64CopyUri.Add_Click({  Copy-B64Value -Value $script:B64State.DataUri -Label "Data URI" })
    $UiMap.BtnB64CopyHtml.Add_Click({ Copy-B64Value -Value $script:B64State.HtmlTag -Label "HTML <img>" })
    $UiMap.BtnB64CopyCss.Add_Click({  Copy-B64Value -Value $script:B64State.CssUrl  -Label "CSS url()" })
    $UiMap.BtnB64CopySha.Add_Click({  Copy-B64Value -Value $script:B64State.Sha256  -Label "SHA-256" })
    $UiMap.BtnB64CopyMd5.Add_Click({  Copy-B64Value -Value $script:B64State.Md5     -Label "MD5" })
}

Export-ModuleMember -Function Initialize-Base64HashTool, Process-Base64AndHashFile
