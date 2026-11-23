# ============================================================================
# Nilly QuickTools — Ultra-Light Native XInput Gamepad / Controller Tester
# created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/
# 100% Pure Native Windows xinput1_4.dll (0 external DLLs, 0% idle CPU)
# Replaces 8+ MB Store Controller Tester apps with ~11 KB lazy-loaded module!
# ============================================================================

$script:GPInitialized = $false
$script:GPTimer = $null
$script:GPRumbleOffTimer = $null
$script:GPUi = $null
$script:GPActiveSlot = 0
$script:GPLeftTrail = New-Object System.Collections.Generic.List[double]
$script:GPRightTrail = New-Object System.Collections.Generic.List[double]
$script:GPBtnBorders = @{}

function Ensure-NillyXInputType {
    if ('NillyXInput' -as [type]) { return }
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class NillyXInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE {
        public uint dwPacketNumber;
        public XINPUT_GAMEPAD Gamepad;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_VIBRATION {
        public ushort wLeftMotorSpeed;
        public ushort wRightMotorSpeed;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_BATTERY_INFORMATION {
        public byte BatteryType;
        public byte BatteryLevel;
    }

    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
    public static extern uint GetState(uint dwUserIndex, out XINPUT_STATE pState);

    [DllImport("xinput1_4.dll", EntryPoint = "XInputSetState")]
    public static extern uint SetState(uint dwUserIndex, ref XINPUT_VIBRATION pVibration);

    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetBatteryInformation")]
    public static extern uint GetBattery(uint dwUserIndex, byte devType, out XINPUT_BATTERY_INFORMATION pBattery);

    public static bool TryPoll(uint idx, out XINPUT_STATE st) {
        try { return GetState(idx, out st) == 0; }
        catch { st = new XINPUT_STATE(); return false; }
    }

    public static void Rumble(uint idx, ushort left, ushort right) {
        try {
            XINPUT_VIBRATION v = new XINPUT_VIBRATION();
            v.wLeftMotorSpeed = left;
            v.wRightMotorSpeed = right;
            SetState(idx, ref v);
        } catch {}
    }

    public static string GetBatteryText(uint idx) {
        try {
            XINPUT_BATTERY_INFORMATION b;
            if (GetBattery(idx, 0, out b) != 0) return "";
            if (b.BatteryType == 0x01) return "Ενσύρματο (USB)";
            if (b.BatteryType == 0x00) return "";
            string lvl = b.BatteryLevel == 3 ? "Πλήρης (100%)" : (b.BatteryLevel == 2 ? "Μεσαία" : (b.BatteryLevel == 1 ? "Χαμηλή" : "Άδεια!"));
            return "Μπαταρία: " + lvl;
        } catch { return ""; }
    }
}
"@ -ErrorAction SilentlyContinue
}

function Stop-GamepadTesterPolling {
    if ($script:GPTimer) { $script:GPTimer.Stop() }
    if ($script:GPRumbleOffTimer) { $script:GPRumbleOffTimer.Stop() }
    try {
        if ('NillyXInput' -as [type]) {
            for ($i = 0; $i -lt 4; $i++) { [NillyXInput]::Rumble([uint32]$i, 0, 0) }
        }
    } catch {}
}

function Update-GPStickVisual {
    param(
        $Dot,
        $TrailPoly,
        $TxtCoord,
        $TxtDrift,
        [short]$RawX,
        [short]$RawY,
        $TrailList
    )
    $nx = [math]::Max(-1.0, [math]::Min(1.0, $RawX / 32767.0))
    $ny = [math]::Max(-1.0, [math]::Min(1.0, $RawY / 32767.0))
    $cx = 75.0 + ($nx * 62.0)
    $cy = 75.0 - ($ny * 62.0)
    [Windows.Controls.Canvas]::SetLeft($Dot, $cx - 6.0)
    [Windows.Controls.Canvas]::SetTop($Dot, $cy - 6.0)

    $mag = [math]::Sqrt($nx * $nx + $ny * $ny)
    $TxtCoord.Text = ("X: {0:0.000}   Y: {1:0.000}" -f $nx, $ny)

    if ($mag -gt 0.82) {
        if ($TrailList.Count -lt 360) {
            $TrailList.Add($mag)
            $TrailPoly.Points.Add([Windows.Point]::new($cx, $cy))
        }
    }

    if ($TrailList.Count -ge 12) {
        $errSum = 0.0
        foreach ($m in $TrailList) { $errSum += [math]::Abs($m - 1.0) }
        $avgErr = [math]::Round(($errSum / $TrailList.Count) * 100.0, 1)
        $TxtDrift.Text = "Circularity Error: $avgErr% ($($TrailList.Count) pts)"
        $TxtDrift.Foreground = if ($avgErr -le 12.0) { $script:GPBrushGreen } else { $script:GPBrushAmber }
    } elseif ($mag -gt 0.10 -and $mag -lt 0.35) {
        $TxtDrift.Text = ("Πιθανό Drift ({0:0.0}%)" -f ($mag * 100.0))
        $TxtDrift.Foreground = $script:GPBrushAmber
    } else {
        $TxtDrift.Text = "Κέντρο OK (Deadzone < 10%)"
        $TxtDrift.Foreground = $script:GPBrushMuted
    }
}

function Poll-GamepadState {
    if (-not $script:GPUi) { return }
    $ui = $script:GPUi

    $st = New-Object NillyXInput+XINPUT_STATE
    $connected = [NillyXInput]::TryPoll([uint32]$script:GPActiveSlot, [ref]$st)

    if (-not $connected) {
        # Auto-find any connected controller 0..3
        for ($i = 0; $i -lt 4; $i++) {
            $tmp = New-Object NillyXInput+XINPUT_STATE
            if ([NillyXInput]::TryPoll([uint32]$i, [ref]$tmp)) {
                $script:GPActiveSlot = $i
                $st = $tmp
                $connected = $true
                if ($ui.CmbGPSlot.SelectedIndex -ne $i) { $ui.CmbGPSlot.SelectedIndex = $i }
                break
            }
        }
    }

    if (-not $connected) {
        $ui.TxtGPStatus.Text = "Δεν εντοπίστηκε συνδεδεμένο XInput χειριστήριο (Xbox / Gamepad). Σύνδεσε με Bluetooth ή USB."
        $ui.TxtGPStatus.Foreground = $script:GPBrushAmber
        $ui.BarGPLT.Value = 0; $ui.TxtGPLT.Text = "0 / 255"
        $ui.BarGPRT.Value = 0; $ui.TxtGPRT.Text = "0 / 255"
        foreach ($b in $script:GPBtnBorders.Values) {
            $b.Background = $script:GPBrushOffBg
            $b.BorderBrush = $script:GPBrushOffBd
        }
        return
    }

    $bat = [NillyXInput]::GetBatteryText([uint32]$script:GPActiveSlot)
    $batPart = if ($bat) { "  •  $bat" } else { "" }
    $ui.TxtGPStatus.Text = "ΣΥΝΔΕΔΕΜΕΝΟ (Player $($script:GPActiveSlot + 1) · XInput 60 FPS)$batPart"
    $ui.TxtGPStatus.Foreground = $script:GPBrushGreen

    $gp = $st.Gamepad
    Update-GPStickVisual -Dot $ui.DotGPLeft -TrailPoly $ui.PolyGPLeft -TxtCoord $ui.TxtGPLeftXY -TxtDrift $ui.TxtGPLeftDrift -RawX $gp.sThumbLX -RawY $gp.sThumbLY -TrailList $script:GPLeftTrail
    Update-GPStickVisual -Dot $ui.DotGPRight -TrailPoly $ui.PolyGPRight -TxtCoord $ui.TxtGPRightXY -TxtDrift $ui.TxtGPRightDrift -RawX $gp.sThumbRX -RawY $gp.sThumbRY -TrailList $script:GPRightTrail

    $ui.BarGPLT.Value = $gp.bLeftTrigger
    $ui.TxtGPLT.Text = "$($gp.bLeftTrigger) / 255"
    $ui.BarGPRT.Value = $gp.bRightTrigger
    $ui.TxtGPRT.Text = "$($gp.bRightTrigger) / 255"

    $maskMap = @{
        Up    = 0x0001; Down  = 0x0002; Left  = 0x0004; Right = 0x0008
        Start = 0x0010; Back  = 0x0020; L3    = 0x0040; R3    = 0x0080
        LB    = 0x0100; RB    = 0x0200
        A     = 0x1000; B     = 0x2000; X     = 0x4000; Y     = 0x8000
    }
    foreach ($k in $maskMap.Keys) {
        $bd = $script:GPBtnBorders[$k]
        if ($bd) {
            $pressed = (($gp.wButtons -band $maskMap[$k]) -ne 0)
            $bd.Background = if ($pressed) { $script:GPBrushOnBg } else { $script:GPBrushOffBg }
            $bd.BorderBrush = if ($pressed) { $script:GPBrushOnBd } else { $script:GPBrushOffBd }
        }
    }
}

function Initialize-GamepadTesterTool {
    param($MainWindow, $UiMap)

    Ensure-NillyXInputType
    $script:GPUi = $UiMap

    if (-not $script:GPInitialized) {
        $bc = [Windows.Media.BrushConverter]::new()
        $script:GPBrushGreen = $bc.ConvertFromString('#22C55E')
        $script:GPBrushAmber = $bc.ConvertFromString('#F59E0B')
        $script:GPBrushMuted = $bc.ConvertFromString('#94A3B8')
        $script:GPBrushOffBg = $bc.ConvertFromString('#131924')
        $script:GPBrushOffBd = $bc.ConvertFromString('#243045')
        $script:GPBrushOnBg  = $bc.ConvertFromString('#2563EB')
        $script:GPBrushOnBd  = $bc.ConvertFromString('#60A5FA')

        # Build clean 14-button live visual matrix inside WrapGPButtons
        $UiMap.WrapGPButtons.Children.Clear()
        $script:GPBtnBorders.Clear()
        $defs = @(
            @('A','A'), @('B','B'), @('X','X'), @('Y','Y'),
            @('LB','LB'), @('RB','RB'), @('Back','View'), @('Start','Menu'),
            @('L3','L3'), @('R3','R3'),
            @('Up','D ↑'), @('Down','D ↓'), @('Left','D ←'), @('Right','D →')
        )
        foreach ($d in $defs) {
            $bd = New-Object Windows.Controls.Border
            $bd.Width = 66; $bd.Height = 36
            $bd.CornerRadius = [Windows.CornerRadius]::new(8)
            $bd.Margin = [Windows.Thickness]::new(0, 0, 7, 7)
            $bd.Background = $script:GPBrushOffBg
            $bd.BorderBrush = $script:GPBrushOffBd
            $bd.BorderThickness = [Windows.Thickness]::new(1)
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text = $d[1]
            $tb.Foreground = [Windows.Media.Brushes]::White
            $tb.FontSize = 12; $tb.FontWeight = 'SemiBold'
            $tb.HorizontalAlignment = 'Center'; $tb.VerticalAlignment = 'Center'
            $bd.Child = $tb
            [void]$UiMap.WrapGPButtons.Children.Add($bd)
            $script:GPBtnBorders[$d[0]] = $bd
        }

        $UiMap.CmbGPSlot.Items.Clear()
        foreach ($lbl in @('Player 1','Player 2','Player 3','Player 4')) { [void]$UiMap.CmbGPSlot.Items.Add($lbl) }
        $UiMap.CmbGPSlot.SelectedIndex = 0
        $UiMap.CmbGPSlot.Add_SelectionChanged({
            if ($script:GPUi.CmbGPSlot.SelectedIndex -ge 0) {
                $script:GPActiveSlot = $script:GPUi.CmbGPSlot.SelectedIndex
            }
        })

        $UiMap.BtnGPResetCirc.Add_Click({
            $script:GPLeftTrail.Clear(); $script:GPRightTrail.Clear()
            $script:GPUi.PolyGPLeft.Points.Clear(); $script:GPUi.PolyGPRight.Points.Clear()
        })

        $script:GPRumbleOffTimer = New-Object Windows.Threading.DispatcherTimer
        $script:GPRumbleOffTimer.Interval = [TimeSpan]::FromMilliseconds(650)
        $script:GPRumbleOffTimer.Add_Tick({
            $script:GPRumbleOffTimer.Stop()
            [NillyXInput]::Rumble([uint32]$script:GPActiveSlot, 0, 0)
        })

        $UiMap.BtnGPRumble.Add_Click({
            [NillyXInput]::Rumble([uint32]$script:GPActiveSlot, 42000, 42000)
            $script:GPRumbleOffTimer.Stop()
            $script:GPRumbleOffTimer.Start()
        })

        $script:GPTimer = New-Object Windows.Threading.DispatcherTimer
        $script:GPTimer.Interval = [TimeSpan]::FromMilliseconds(16) # ~60 FPS live polling ONLY when page is open!
        $script:GPTimer.Add_Tick({ Poll-GamepadState })

        $MainWindow.Add_Closed({ Stop-GamepadTesterPolling })
        $script:GPInitialized = $true
    }

    Poll-GamepadState
    $script:GPTimer.Start()
}

Export-ModuleMember -Function Initialize-GamepadTesterTool, Stop-GamepadTesterPolling
