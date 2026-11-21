<#
.SYNOPSIS
    Nilly PC Manager & Tools v3.2 — Ultra-Light On-Demand System, Design & SEO Suite
    0 MB background RAM | No services | No autostart | Runs only when opened

.DESCRIPTION
    created by Nilly graphics (Sotiris Christos)
    https://nillygraphics.com/

    Modular Architecture (14 lazy-loaded modules under .\tools\ — 0 KB RAM until clicked!):
      - System: Boost, My Hub (RAM/Firefox/Backup/G-Phonor), On-Demand Apps, Deep Cleaner, RAM Processes, Hardware & Specs, Security
      - Design & SEO: Color Picker Pro, QR & Barcode Pro (9 GS1/ISO), Print & DPI Calc, Pixel Ruler & Capture, Image Resizer, Images -> PDF, Batch Renamer SEO, SEO & Text Tools, SVG/Base64 & Hash
      - Utilities: Notes & Snippets, File Locksmith, Always On Top

    Safe Guarantee: NEVER touches Docker, Documents, Xbox, WebView2,
    Phone Link, cookies, passwords, or personal files.
#>

param(
    [switch]$TestOnly
)

$ErrorActionPreference = "SilentlyContinue"
$AppVersion = "3.2"
$AppAuthor  = "created by Nilly graphics (Sotiris Christos)"
$AppWebsite = "https://nillygraphics.com/"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Ultra-fast native Win32 & .NET helpers (no slow WMI/CIM, no external DLLs)
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public static class NillyNative {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    [DllImport("kernel32.dll")]
    public static extern ulong GetTickCount64();

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MEMORYSTATUSEX {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    public static MEMORYSTATUSEX GetMemory() {
        var m = new MEMORYSTATUSEX();
        m.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        GlobalMemoryStatusEx(ref m);
        return m;
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static void EnableDarkTitleBar(IntPtr hwnd) {
        if (hwnd == IntPtr.Zero) return;
        int useDark = 1;
        if (DwmSetWindowAttribute(hwnd, 20, ref useDark, sizeof(int)) != 0) {
            DwmSetWindowAttribute(hwnd, 19, ref useDark, sizeof(int));
        }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct SHQUERYRBINFO {
        public int cbSize;
        public long i64Size;
        public long i64NumItems;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHQueryRecycleBin(string pszRootPath, ref SHQUERYRBINFO pSHQueryRBInfo);

    public static long GetRecycleBinBytes() {
        var info = new SHQUERYRBINFO();
        info.cbSize = Marshal.SizeOf(typeof(SHQUERYRBINFO));
        if (SHQueryRecycleBin(null, ref info) == 0) return info.i64Size;
        return 0;
    }

    public static long GetDirSize(string rootPath) {
        if (string.IsNullOrEmpty(rootPath) || !Directory.Exists(rootPath)) return 0;
        long total = 0;
        var stack = new System.Collections.Generic.Stack<string>();
        stack.Push(rootPath);
        while (stack.Count > 0) {
            string dir = stack.Pop();
            try {
                foreach (string file in Directory.EnumerateFiles(dir)) {
                    try { total += new FileInfo(file).Length; } catch {}
                }
                foreach (string sub in Directory.EnumerateDirectories(dir)) {
                    try {
                        var attrs = File.GetAttributes(sub);
                        if ((attrs & FileAttributes.ReparsePoint) == 0) stack.Push(sub);
                    } catch {}
                }
            } catch {}
        }
        return total;
    }
}
"@ -ErrorAction SilentlyContinue

[void][NillyNative]::SetProcessDPIAware()

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Nilly PC Manager &amp; Tools v3.2 — created by Nilly graphics (Sotiris Christos)"
        Height="700" Width="880"
        MinHeight="600" MinWidth="740"
        WindowStartupLocation="CenterScreen"
        Background="#0B0F17"
        Foreground="#F1F5F9"
        FontFamily="Segoe UI">

    <Window.Resources>
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="13,10"/>
            <Setter Property="Margin" Value="10,2"/>
            <Setter Property="FontSize" Value="12.8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#1B2332"/>
                                <Setter Property="Foreground" Value="#F8FAFC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="#38BDF8"/>
            <Setter Property="Foreground" Value="#072235"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13.5"/>
            <Setter Property="Padding" Value="18,10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#7DD3FC"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#0EA5E9"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Background" Value="#273244"/>
                                <Setter Property="Foreground" Value="#64748B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="EmeraldButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#10B981"/>
            <Setter Property="Foreground" Value="#032219"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#34D399"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#059669"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="#1C2433"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Padding" Value="13,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="#2C384D" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#253045"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource SecondaryButton}">
            <Setter Property="Background" Value="#341821"/>
            <Setter Property="Foreground" Value="#FDA4AF"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="#7F1D1D" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#4C1D2B"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#F43F5E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CardButton" TargetType="Button">
            <Setter Property="Background" Value="#131924"/>
            <Setter Property="Foreground" Value="#F1F5F9"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Top"/>
            <Setter Property="Padding" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#1A2232"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="LinkButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#38BDF8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <TextBlock x:Name="tb" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" FontSize="{TemplateBinding FontSize}" FontWeight="{TemplateBinding FontWeight}"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tb" Property="TextDecorations" Value="Underline"/>
                                <Setter Property="Foreground" Value="#7DD3FC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,6"/>
        </Style>

        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#0F141F"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="BorderBrush" Value="#1F293B"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GridViewColumnHeader">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ListViewItem">
            <Setter Property="Padding" Value="4,5"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#1E3A5F"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1B2537"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition x:Name="ColSidebar" Width="212"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR -->
        <Border Grid.Column="0" Background="#0F141F" BorderBrush="#1C2536" BorderThickness="0,0,1,0">
            <DockPanel LastChildFill="True">
                <!-- App Brand -->
                <StackPanel DockPanel.Dock="Top" Margin="16,18,16,12">
                    <DockPanel>
                        <TextBlock Text="PC Manager &amp; Tools" FontSize="14.5" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                        <Border Background="#0C2A3E" BorderBrush="#1E4E6D" BorderThickness="1" CornerRadius="5" Padding="5,2" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <TextBlock Text="v3.2" FontSize="9.5" FontWeight="Bold" Foreground="#38BDF8"/>
                        </Border>
                    </DockPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                        <Ellipse Width="7" Height="7" Fill="#22C55E" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBlock Text="0 MB background RAM" FontSize="11" Foreground="#94A3B8"/>
                    </StackPanel>
                </StackPanel>

                <!-- Bottom Safe Badge + Nilly Graphics SEO Footer -->
                <StackPanel DockPanel.Dock="Bottom" Margin="12,8,12,14">
                    <Border Background="#121A26" CornerRadius="8" Padding="9" BorderBrush="#1E2C3E" BorderThickness="1" Margin="0,0,0,8">
                        <StackPanel>
                            <TextBlock Text="Ασφαλής λειτουργία" FontSize="10.5" FontWeight="SemiBold" Foreground="#22C55E"/>
                            <TextBlock Text="Δεν αγγίζει Docker, Documents, Xbox, Phone Link ή WebView2." FontSize="9.8" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        </StackPanel>
                    </Border>

                    <Border Background="#101827" CornerRadius="8" Padding="10" BorderBrush="#1B3049" BorderThickness="1">
                        <StackPanel>
                            <TextBlock Text="created by Nilly graphics" FontSize="10.5" FontWeight="SemiBold" Foreground="#E2E8F0"/>
                            <TextBlock Text="(Sotiris Christos)" FontSize="10" Foreground="#94A3B8" Margin="0,1,0,4"/>
                            <Button x:Name="BtnSidebarSite" Content="https://nillygraphics.com/" Style="{StaticResource LinkButton}" FontSize="10.5" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <!-- Navigation List (scrollable if small window) -->
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="0,2,0,4">
                        <TextBlock Text="ΣΥΣΤΗΜΑ" FontSize="10" FontWeight="Bold" Foreground="#475569" Margin="18,6,0,4"/>

                        <Button x:Name="BtnNavHome" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE80F;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Αρχική" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavMyHub" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE945;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="My Hub (RAM / FF / Backup)" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavOnDemand" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7E8;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="On-Demand Apps" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavClean" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE74D;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Καθαρισμός" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavProcs" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Διεργασίες (RAM)" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavHardware" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE950;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Hardware &amp; Specs" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavTools" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEA18;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Προστασία &amp; About" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <Separator Background="#1C2536" Margin="14,8,14,5"/>
                        <TextBlock Text="DESIGN &amp; SEO" FontSize="10" FontWeight="Bold" Foreground="#38BDF8" Margin="18,2,0,4"/>

                        <Button x:Name="BtnNavColorPicker" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEF3C;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Color Picker Pro" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavQrBarcode" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xED14;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="QR &amp; Barcode Pro" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavPrintDpi" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE749;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Print &amp; DPI Calc" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavPixelRuler" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xECC6;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Pixel Ruler &amp; Capture" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavImageResizer" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEB9F;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Image Resizer" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavImgPdf" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xEA90;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Images → PDF" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavBatchRenamer" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8AC;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Batch Renamer SEO" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavSeoText" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE8D2;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="SEO &amp; Text Tools" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavBase64Hash" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE943;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="SVG / Base64 &amp; Hash" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>

                        <Separator Background="#1C2536" Margin="14,8,14,5"/>
                        <TextBlock Text="UTILITIES" FontSize="10" FontWeight="Bold" Foreground="#94A3B8" Margin="18,2,0,4"/>

                        <Button x:Name="BtnNavNotes" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE70B;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Notes &amp; Snippets" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavFileLocksmith" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE72E;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="File Locksmith" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnNavAlwaysOnTop" Style="{StaticResource NavButton}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE718;" FontSize="14.5" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Always On Top" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </StackPanel>
                </ScrollViewer>
            </DockPanel>
        </Border>

        <!-- MAIN CONTENT AREA (Responsive Container) -->
        <Grid Grid.Column="1" Margin="22,18,22,16">

            <!-- PAGE 1: HOME -->
            <ScrollViewer x:Name="PageHome" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Επισκόπηση Συστήματος" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock x:Name="TxtSysSpec" Text="Φόρτωση στοιχείων..." FontSize="11.5" Foreground="#64748B" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnRefreshHome" Content="Ανανέωση" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="13,6" FontSize="12"/>
                    </DockPanel>

                    <!-- PC Boost Card -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="18" Margin="0,4,0,14">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,12">
                                <StackPanel>
                                    <TextBlock Text="PC Boost" FontSize="16" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                    <TextBlock Text="Ελευθέρωση αδρανούς RAM (Working Set Trim) &amp; καθαρισμός User Temp" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                                </StackPanel>
                                <TextBlock x:Name="TxtUptime" Text="Uptime: --" FontSize="11.5" Foreground="#64748B" DockPanel.Dock="Right" VerticalAlignment="Top"/>
                            </DockPanel>

                            <Grid Margin="0,0,0,14">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="18"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <StackPanel Grid.Column="0">
                                    <DockPanel>
                                        <TextBlock x:Name="TxtRamPct" Text="--%" FontSize="24" FontWeight="Bold" Foreground="#38BDF8"/>
                                        <TextBlock x:Name="TxtRamDetail" Text="-- / -- GB" FontSize="12" Foreground="#94A3B8" VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                                    </DockPanel>
                                    <TextBlock Text="Χρήση Μνήμης (RAM)" FontSize="11.5" Foreground="#94A3B8" Margin="0,1,0,6"/>
                                    <ProgressBar x:Name="BarRam" Height="7" Minimum="0" Maximum="100" Value="0" Background="#1E293B" Foreground="#38BDF8" BorderThickness="0"/>
                                </StackPanel>

                                <StackPanel Grid.Column="2">
                                    <DockPanel>
                                        <TextBlock x:Name="TxtTempSize" Text="-- MB" FontSize="24" FontWeight="Bold" Foreground="#F59E0B"/>
                                        <TextBlock x:Name="TxtBgHeavy" Text="" FontSize="11.5" Foreground="#94A3B8" VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                                    </DockPanel>
                                    <TextBlock Text="Προσωρινά αρχεία (User Temp)" FontSize="11.5" Foreground="#94A3B8" Margin="0,1,0,6"/>
                                    <ProgressBar x:Name="BarTemp" Height="7" Minimum="0" Maximum="2048" Value="0" Background="#1E293B" Foreground="#F59E0B" BorderThickness="0"/>
                                </StackPanel>
                            </Grid>

                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="BtnBoost" Grid.Column="0" Content="Boost Τώρα" Style="{StaticResource PrimaryButton}" Height="40"/>
                                <Button x:Name="BtnHomeColorPicker" Grid.Column="2" Content="Color Picker" Style="{StaticResource SecondaryButton}" Height="40" Padding="15,0"/>
                                <Button x:Name="BtnHomeOnDemand" Grid.Column="4" Content="On-Demand Apps →" Style="{StaticResource SecondaryButton}" Height="40" Padding="15,0"/>
                            </Grid>
                            <TextBlock x:Name="TxtBoostStatus" Text="" FontSize="12" Foreground="#22C55E" Margin="0,8,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                    </Border>

                    <!-- Multi-Disk Card -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,0,14">
                        <StackPanel>
                            <TextBlock Text="Αποθηκευτικός Χώρος Δίσκων" FontSize="14.5" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,0,0,10"/>
                            <ItemsControl x:Name="ListDrives">
                                <ItemsControl.ItemTemplate>
                                    <DataTemplate>
                                        <StackPanel Margin="0,0,0,9">
                                            <DockPanel Margin="0,0,0,4">
                                                <TextBlock Text="{Binding Label}" FontSize="12.5" FontWeight="SemiBold" Foreground="#E2E8F0"/>
                                                <TextBlock Text="{Binding FreeText}" FontSize="12" FontWeight="SemiBold" Foreground="{Binding AccentBrush}" HorizontalAlignment="Right"/>
                                            </DockPanel>
                                            <ProgressBar Height="6" Minimum="0" Maximum="100" Value="{Binding UsedPct}" Background="#1E293B" Foreground="{Binding AccentBrush}" BorderThickness="0"/>
                                        </StackPanel>
                                    </DataTemplate>
                                </ItemsControl.ItemTemplate>
                            </ItemsControl>
                        </StackPanel>
                    </Border>

                    <!-- Responsive 2x2 Quick Actions -->
                    <UniformGrid Columns="2" Margin="-6,0,-6,0">
                        <Button x:Name="BtnQuickClean" Style="{StaticResource CardButton}" Margin="6">
                            <StackPanel>
                                <TextBlock Text="Βαθύς Καθαρισμός" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Browser caches, Chrome AI, Spotify, npm, Temp" FontSize="11.5" Foreground="#94A3B8" Margin="0,4,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Button>

                        <Button x:Name="BtnQuickProcs" Style="{StaticResource CardButton}" Margin="6">
                            <StackPanel>
                                <TextBlock Text="Διεργασίες (RAM)" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtProcCount" Text="Δες τι καταναλώνει μνήμη τώρα" FontSize="11.5" Foreground="#94A3B8" Margin="0,4,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Button>

                        <Button x:Name="BtnQuickStartup" Style="{StaticResource CardButton}" Margin="6">
                            <StackPanel>
                                <TextBlock Text="Εκκίνηση (Startup)" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Διαχείριση εφαρμογών εκκίνησης Windows" FontSize="11.5" Foreground="#94A3B8" Margin="0,4,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Button>

                        <Button x:Name="BtnQuickTaskbar" Style="{StaticResource CardButton}" Margin="6">
                            <StackPanel>
                                <TextBlock Text="Επισκευή Taskbar" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Καθαρή επανεκκίνηση του Explorer" FontSize="11.5" Foreground="#94A3B8" Margin="0,4,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Button>
                    </UniformGrid>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 2: ON-DEMAND APPS -->
            <ScrollViewer x:Name="PageOnDemand" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,8">
                        <TextBlock Text="Εφαρμογές Κατά Ζήτηση (On-Demand)" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                        <Button x:Name="BtnRefreshOD" Content="Ανανέωση" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="13,6" FontSize="12"/>
                    </DockPanel>
                    <TextBlock Text="Κλείσε προσωρινά βαριές background εφαρμογές όταν δουλεύεις ή παίζεις και ξανάνοιξέ τες με 1 κλικ όποτε τις χρειαστείς. Δεν απεγκαθιστά τίποτα!" FontSize="12" Foreground="#94A3B8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                    <Border Background="#111C2D" BorderBrush="#1E3A5F" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,14">
                        <DockPanel>
                            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                                <Button x:Name="BtnFocusMode" Content="Focus / Game Mode" Style="{StaticResource EmeraldButton}" Padding="14,8" FontSize="12.5" Margin="0,0,8,0"/>
                                <Button x:Name="BtnRestoreOD" Content="Άνοιγμα Όλων" Style="{StaticResource SecondaryButton}" Padding="12,8" FontSize="12"/>
                            </StackPanel>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock x:Name="TxtODTotal" Text="Συνολική RAM αυτών των 4 εφαρμογών: -- MB" FontSize="13.5" FontWeight="SemiBold" Foreground="#38BDF8"/>
                                <TextBlock Text="Focus Mode: κλείνει Dropbox, Razer Synapse &amp; Logi Options+ και κάνει RAM Trim (κρατάει G HUB για το G5→F13)." FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnToggleDropbox" Content="..." Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="135" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Dropbox Sync" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtDropboxInfo" Text="Έλεγχος..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnToggleRazer" Content="..." Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="135" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Razer Synapse 4 (DeathAdder V2 X)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtRazerInfo" Text="Έλεγχος..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnToggleLogiOpt" Content="..." Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="135" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Logi Options+ (MX Master 2S)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtLogiOptInfo" Text="Έλεγχος..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnToggleGHUB" Content="..." Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="135" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Logitech G HUB (G915 Keyboard)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtGHUBInfo" Text="Έλεγχος..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="11">
                        <TextBlock x:Name="TxtODStatus" Text="Tip: Το DeathAdder V2 X &amp; το G915 κρατούν βασικά DPI / On-Board profiles στη μνήμη τους ακόμα κι όταν το software είναι κλειστό." FontSize="11.5" Foreground="#94A3B8" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 3: DEEP CLEANUP -->
            <ScrollViewer x:Name="PageClean" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <TextBlock Text="Βαθύς Ασφαλής Καθαρισμός" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                        <Button x:Name="BtnScanClean" Content="Σάρωση" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="14,6" FontSize="12"/>
                    </DockPanel>

                    <TextBlock Text="Επίλεξε τι θέλεις να καθαριστεί. Δεν διαγράφονται ποτέ cookies, κωδικοί, Docker, Documents ή προσωπικά αρχεία." FontSize="12" Foreground="#94A3B8" Margin="0,0,0,14" TextWrapping="Wrap"/>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,0,14">
                        <StackPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkTemp" Content="User Temp (Προσωρινά αρχεία Windows)" IsChecked="True"/>
                                <TextBlock x:Name="LblTemp" Text="..." Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkBrowsers" Content="Browser Caches (Firefox / Brave / Chrome / Edge — μόνο Cache)" IsChecked="True"/>
                                <TextBlock x:Name="LblBrowsers" Text="..." Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkChromeAI" Content="Chrome On-Device AI Model Cache (OptGuideOnDeviceModel)" IsChecked="True"/>
                                <TextBlock x:Name="LblChromeAI" Text="..." Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkDev" Content="Dev &amp; Updater Caches (npm-cache, pip, CrashDumps, updaters)" IsChecked="True"/>
                                <TextBlock x:Name="LblDev" Text="..." Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkSpotify" Content="Spotify Cache (Browser &amp; Default Cache — κρατάει login/playlists)" IsChecked="False"/>
                                <TextBlock x:Name="LblSpotify" Text="..." Foreground="#F59E0B" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>
                            <DockPanel>
                                <CheckBox x:Name="ChkRecycle" Content="Κάδος Ανακύκλωσης (Recycle Bin)" IsChecked="False"/>
                                <TextBlock x:Name="LblRecycle" Text="..." Foreground="#F59E0B" VerticalAlignment="Center" HorizontalAlignment="Right" FontWeight="SemiBold"/>
                            </DockPanel>

                            <Separator Background="#1F293B" Margin="0,10"/>

                            <DockPanel>
                                <TextBlock Text="Σύνολο επιλεγμένων:" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                                <TextBlock x:Name="LblCleanTotal" Text="0 MB" FontSize="16" FontWeight="Bold" Foreground="#22C55E" HorizontalAlignment="Right"/>
                            </DockPanel>
                        </StackPanel>
                    </Border>

                    <WrapPanel Margin="0,0,0,12">
                        <Button x:Name="BtnRunClean" Content="Καθαρισμός Επιλεγμένων" Style="{StaticResource PrimaryButton}" Width="225" Margin="0,0,10,6"/>
                        <Button x:Name="BtnWinUpdateClean" Content="Windows Update Cleanup (Admin)" Style="{StaticResource SecondaryButton}" Margin="0,0,0,6"/>
                    </WrapPanel>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="12">
                        <TextBlock x:Name="TxtCleanLog" Text="Πάτα 'Σάρωση' για ενημέρωση μεγεθών ή 'Καθαρισμός Επιλεγμένων'." FontSize="12" Foreground="#CBD5E1" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 4: PROCESSES -->
            <Grid x:Name="PageProcs" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <DockPanel Grid.Row="0" Margin="0,0,0,10">
                    <TextBlock Text="Κορυφαίες Διεργασίες (RAM)" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                    <Button x:Name="BtnRefreshProcs" Content="Ανανέωση" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="14,6" FontSize="12"/>
                </DockPanel>

                <DockPanel Grid.Row="1" Margin="0,0,0,10">
                    <TextBlock Text="Φίλτρο:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,8,0" FontSize="12.5"/>
                    <TextBox x:Name="TxtProcFilter" Background="#131924" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#263349" BorderThickness="1" Padding="8,6" FontSize="12.5"/>
                </DockPanel>

                <ListView x:Name="ListProcs" Grid.Row="2" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12.5">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Εφαρμογή" Width="260" DisplayMemberBinding="{Binding Name}"/>
                            <GridViewColumn Header="Διεργασίες" Width="90" DisplayMemberBinding="{Binding Count}"/>
                            <GridViewColumn Header="RAM (MB)" Width="110" DisplayMemberBinding="{Binding RAM_MB}"/>
                            <GridViewColumn Header="Τύπος" Width="120" DisplayMemberBinding="{Binding Type}"/>
                        </GridView>
                    </ListView.View>
                </ListView>

                <DockPanel Grid.Row="3" Margin="0,12,0,0">
                    <TextBlock x:Name="TxtProcStatus" Text="Επίλεξε μια εφαρμογή χρήστη για τερματισμό (οι διεργασίες Windows, Docker &amp; FanControl προστατεύονται)." FontSize="11.5" Foreground="#94A3B8" VerticalAlignment="Center" TextWrapping="Wrap"/>
                    <Button x:Name="BtnKillProc" Content="Τερματισμός Εφαρμογής" Style="{StaticResource DangerButton}" DockPanel.Dock="Right" Margin="12,0,0,0"/>
                </DockPanel>
            </Grid>

            <!-- PAGE 5: PROTECTION & ABOUT -->
            <ScrollViewer x:Name="PageTools" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <TextBlock Text="Προστασία, Συντομεύσεις &amp; Πληροφορίες" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,0,0,14"/>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnDefenderScan" Content="Quick Scan" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" Padding="16,8" FontSize="13"/>
                            <StackPanel Margin="0,0,10,0">
                                <TextBlock Text="Windows Defender (Έλεγχος Ιών)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtDefenderInfo" Text="Έλεγχος κατάστασης..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
                        <DockPanel>
                            <Button x:Name="BtnNetCheck" Content="Έλεγχος &amp; Flush DNS" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right"/>
                            <StackPanel Margin="0,0,10,0">
                                <TextBlock Text="Έλεγχος Δικτύου &amp; DNS" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtNetInfo" Text="Έλεγχος σύνδεσης (ping 1.1.1.1) και καθαρισμός DNS cache" FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <UniformGrid Columns="2" Margin="-5,0,-5,10">
                        <Button x:Name="BtnWinUpdate" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Windows Update" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Έλεγχος ενημερώσεων Windows" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnWinSecurity" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Windows Security" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Άνοιγμα κέντρου ασφαλείας" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnInstalledApps" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Εγκατεστημένες Εφαρμογές" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Απεγκατάσταση προγραμμάτων" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnStorageSense" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Storage Sense" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Ρυθμίσεις αποθήκευσης Windows" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnOpenScripts" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Φάκελος Εφαρμογής" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Άνοιγμα φακέλου PC Manager &amp; Tools" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnTaskbarRepair2" Style="{StaticResource CardButton}" Margin="5">
                            <StackPanel>
                                <TextBlock Text="Επισκευή Taskbar" FontSize="13.5" FontWeight="SemiBold"/>
                                <TextBlock Text="Καθαρή επανεκκίνηση Explorer" FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0"/>
                            </StackPanel>
                        </Button>
                    </UniformGrid>

                    <!-- SEO Branding About Card -->
                    <Border Background="#101827" BorderBrush="#1E3A5F" BorderThickness="1" CornerRadius="10" Padding="16">
                        <DockPanel>
                            <Button x:Name="BtnAboutSite" Content="Επίσκεψη Site →" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Nilly PC Manager &amp; Tools v3.2 — Ultra-Light On-Demand Edition" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock Text="created by Nilly graphics (Sotiris Christos)" FontSize="12.5" FontWeight="SemiBold" Foreground="#38BDF8" Margin="0,4,0,2"/>
                                <TextBlock Text="https://nillygraphics.com/  •  0 MB RAM στο παρασκήνιο  •  14 Modular QuickTools" FontSize="11.5" Foreground="#94A3B8" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 6: NILLY QUICKTOOLS #1 — COLOR PICKER PRO -->
            <ScrollViewer x:Name="PageColorPicker" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Color Picker Pro" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Μεγεθυντικός φακός οθόνης (11×11 Loupe) · HEX / RGB / HSL / CMYK · WCAG Contrast" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                            <Button x:Name="BtnCPPickScreen" Content="Επιλογή από Οθόνη (Loupe)" Style="{StaticResource PrimaryButton}" Padding="15,9" Margin="0,0,8,0"/>
                            <Button x:Name="BtnCPLiveSpy" Content="Live Spy (Click/F2)" Style="{StaticResource SecondaryButton}" Padding="13,9"/>
                        </StackPanel>
                    </DockPanel>

                    <!-- Main Swatch Preview + Manual HEX Input -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,4,0,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="150"/>
                                <ColumnDefinition Width="18"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border x:Name="BoxCPPreview" Grid.Column="0" Height="96" CornerRadius="10" Background="#38BDF8" BorderBrush="#334155" BorderThickness="1">
                                <TextBlock x:Name="TxtCPPreviewHex" Text="#38BDF8" FontFamily="Consolas" FontSize="16" FontWeight="Bold" Foreground="#0B0F17" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <StackPanel Grid.Column="2" VerticalAlignment="Center">
                                <TextBlock Text="Εισαγωγή ή επικόλληση HEX (Enter για μετατροπή):" FontSize="12" Foreground="#94A3B8" Margin="0,0,0,6"/>
                                <DockPanel Margin="0,0,0,10">
                                    <Button x:Name="BtnCPApplyHex" Content="Εφαρμογή" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Margin="8,0,0,0" Padding="14,7"/>
                                    <TextBox x:Name="TxtCPInputHex" Text="#38BDF8" FontFamily="Consolas" FontSize="14" FontWeight="SemiBold" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="10,7"/>
                                </DockPanel>
                                <TextBlock x:Name="TxtCPContrast" Text="WCAG Contrast..." FontSize="11.5" Foreground="#CBD5E1" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Responsive Copy Format Cards -->
                    <UniformGrid Columns="2" Margin="-5,0,-5,10">
                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="9" Padding="12" Margin="5">
                            <DockPanel>
                                <Button x:Name="BtnCopyHex" Content="Copy" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,8,0">
                                    <TextBlock Text="HEX" FontSize="10.5" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="ValCPHex" Text="#38BDF8" FontFamily="Consolas" FontSize="13.5" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                                </StackPanel>
                            </DockPanel>
                        </Border>

                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="9" Padding="12" Margin="5">
                            <DockPanel>
                                <Button x:Name="BtnCopyRgb" Content="Copy" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,8,0">
                                    <TextBlock Text="RGB" FontSize="10.5" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="ValCPRgb" Text="rgb(56, 189, 248)" FontFamily="Consolas" FontSize="13" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                                </StackPanel>
                            </DockPanel>
                        </Border>

                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="9" Padding="12" Margin="5">
                            <DockPanel>
                                <Button x:Name="BtnCopyHsl" Content="Copy" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,8,0">
                                    <TextBlock Text="HSL" FontSize="10.5" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="ValCPHsl" Text="hsl(198, 93%, 60%)" FontFamily="Consolas" FontSize="13" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                                </StackPanel>
                            </DockPanel>
                        </Border>

                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="9" Padding="12" Margin="5">
                            <DockPanel>
                                <Button x:Name="BtnCopyCmyk" Content="Copy" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,8,0">
                                    <TextBlock Text="CMYK (Εκτύπωση)" FontSize="10.5" FontWeight="Bold" Foreground="#38BDF8"/>
                                    <TextBlock x:Name="ValCPCmyk" Text="cmyk(77%, 24%, 0%, 3%)" FontFamily="Consolas" FontSize="12.5" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                                </StackPanel>
                            </DockPanel>
                        </Border>
                    </UniformGrid>

                    <!-- CSS Variable Row -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="9" Padding="12" Margin="0,0,0,12">
                        <DockPanel>
                            <Button x:Name="BtnCopyCss" Content="Copy CSS" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="12,5" FontSize="11.5"/>
                            <StackPanel Margin="0,0,8,0">
                                <TextBlock Text="CSS VARIABLE" FontSize="10.5" FontWeight="Bold" Foreground="#64748B"/>
                                <TextBlock x:Name="ValCPCss" Text="--brand-color: #38BDF8;" FontFamily="Consolas" FontSize="13" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <!-- Tints & Shades Strip -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,12">
                        <StackPanel>
                            <TextBlock Text="Αποχρώσεις (Tints &amp; Shades — κλικ σε οποιοδήποτε πλακίδιο για αντιγραφή)" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" Margin="0,0,0,8"/>
                            <UniformGrid x:Name="PanelCPShades" Columns="7"/>
                        </StackPanel>
                    </Border>

                    <!-- Recent Colors History -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="Πρόσφατα Χρώματα" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                <Button x:Name="BtnCPClearHist" Content="Καθαρισμός" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="10,4" FontSize="11"/>
                            </DockPanel>
                            <WrapPanel x:Name="PanelCPHistory"/>
                        </StackPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtCPStatus" Text="Πάτα 'Επιλογή από Οθόνη (Loupe)' · Αριστερό κλικ = αντιγραφή HEX · Βελάκια = μετακίνηση 1 pixel · Esc = ακύρωση." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 7: NILLY QUICKTOOLS #2 — QR CODE & BARCODE PRO -->
            <ScrollViewer x:Name="PageQrBarcode" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="QR Code &amp; Barcode Pro" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="100% Static (Δεν λήγουν ποτέ!) · iPhone &amp; Android Camera Native · Vector SVG &amp; 300-DPI PNG" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnQRGenerate" Content="Δημιουργία" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="18,9"/>
                    </DockPanel>

                    <!-- Responsive 2-Column Split: Controls Left + Live Preview Right -->
                    <Grid Margin="0,2,0,12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="1.25*"/>
                            <ColumnDefinition Width="14"/>
                            <ColumnDefinition Width="1*"/>
                        </Grid.ColumnDefinitions>

                        <!-- LEFT: Inputs & Options -->
                        <Border Grid.Column="0" Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="15">
                            <StackPanel>
                                <!-- Mode & Template Selectors -->
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="10"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="Τύπος Κωδικού:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                        <ComboBox x:Name="CmbQRMode" SelectedIndex="0" FontSize="12.5" Padding="6,5">
                                            <ComboBoxItem Content="QR Code (iPhone/Android)" Tag="QR"/>
                                            <ComboBoxItem Content="Barcode (Εκτύπωση/Προϊόν)" Tag="BARCODE"/>
                                        </ComboBox>
                                    </StackPanel>

                                    <StackPanel x:Name="PanelQROptions" Grid.Column="2">
                                        <TextBlock Text="Πρότυπο QR:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                        <ComboBox x:Name="CmbQRTpl" SelectedIndex="0" FontSize="12.5" Padding="6,5">
                                            <ComboBoxItem Content="URL / Website" Tag="URL"/>
                                            <ComboBoxItem Content="vCard 3.0 (Επαφή iPhone)" Tag="VCARD"/>
                                            <ComboBoxItem Content="Wi-Fi (1-tap iPhone)" Tag="WIFI"/>
                                            <ComboBoxItem Content="Τηλέφωνο (tel:)" Tag="PHONE"/>
                                            <ComboBoxItem Content="WhatsApp Direct" Tag="WHATSAPP"/>
                                            <ComboBoxItem Content="Ελεύθερο Κείμενο" Tag="TEXT"/>
                                        </ComboBox>
                                    </StackPanel>

                                    <StackPanel x:Name="PanelBCOptions" Grid.Column="2" Visibility="Collapsed">
                                        <TextBlock Text="Πρότυπο Barcode (Προϊόντα &amp; Συσκευασίες):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                        <ComboBox x:Name="CmbBCFormat" SelectedIndex="0" FontSize="12.5" Padding="6,5">
                                            <ComboBoxItem Content="EAN-13 (Προϊόντα Ελλάδας 520... / ΕΕ)" Tag="EAN13"/>
                                            <ComboBoxItem Content="EAN-8 (Μικρές συσκευασίες / Καλλυντικά)" Tag="EAN8"/>
                                            <ComboBoxItem Content="ITF-14 (Κούτες / Χαρτοκιβώτια GS1)" Tag="ITF14"/>
                                            <ComboBoxItem Content="UPC-A (Εξαγωγές ΗΠΑ / Amazon)" Tag="UPCA"/>
                                            <ComboBoxItem Content="UPC-E (Μικρές συσκευασίες ΗΠΑ)" Tag="UPCE"/>
                                            <ComboBoxItem Content="ISBN-13 (Βιβλία &amp; Εξώφυλλα 978...)" Tag="ISBN13"/>
                                            <ComboBoxItem Content="ISSN (Περιοδικά &amp; Έντυπα 977...)" Tag="ISSN"/>
                                            <ComboBoxItem Content="Code 128 Auto B/C (SKU / Αποθήκη / Courier)" Tag="CODE128"/>
                                            <ComboBoxItem Content="Code 39 (Βιομηχανικά / Κωδικοί A-Z)" Tag="CODE39"/>
                                        </ComboBox>
                                    </StackPanel>
                                </Grid>

                                <!-- Main Input -->
                                <DockPanel Margin="0,0,0,4">
                                    <Button x:Name="BtnQRSample" Content="Παράδειγμα" Style="{StaticResource LinkButton}" DockPanel.Dock="Right" FontSize="11" FontWeight="SemiBold" Visibility="Collapsed"/>
                                    <TextBlock x:Name="LblQRMain" Text="URL / Website:" FontSize="11.5" Foreground="#CBD5E1" TextWrapping="Wrap"/>
                                </DockPanel>
                                <TextBox x:Name="TxtQRMain" Text="https://nillygraphics.com/" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="9,7" FontSize="13" Margin="0,0,0,8"/>

                                <!-- Extra dynamic fields (vCard / WiFi / WhatsApp) -->
                                <StackPanel x:Name="RowQRExtra1" Visibility="Collapsed" Margin="0,0,0,7">
                                    <TextBlock x:Name="LblQRExtra1" Text="Πεδίο 1:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtQRExtra1" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12.5"/>
                                </StackPanel>
                                <StackPanel x:Name="RowQRExtra2" Visibility="Collapsed" Margin="0,0,0,7">
                                    <TextBlock x:Name="LblQRExtra2" Text="Πεδίο 2:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtQRExtra2" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12.5"/>
                                </StackPanel>
                                <StackPanel x:Name="RowQRExtra3" Visibility="Collapsed" Margin="0,0,0,7">
                                    <TextBlock x:Name="LblQRExtra3" Text="Πεδίο 3:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtQRExtra3" Text="https://nillygraphics.com/" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12.5"/>
                                </StackPanel>

                                <!-- Caption & Colors & ECC -->
                                <Grid Margin="0,2,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="1.4*"/>
                                        <ColumnDefinition Width="8"/>
                                        <ColumnDefinition Width="0.8*"/>
                                        <ColumnDefinition Width="8"/>
                                        <ColumnDefinition Width="0.8*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="Λεζάντα κάτω (προαιρετικό):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                        <TextBox x:Name="TxtQRCaption" Text="nillygraphics.com" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2">
                                        <TextBlock Text="Χρώμα:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                        <TextBox x:Name="TxtQRFg" Text="#000000" FontFamily="Consolas" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,6" FontSize="12"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="4">
                                        <TextBlock Text="Φόντο:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                        <TextBox x:Name="TxtQRBg" Text="#FFFFFF" FontFamily="Consolas" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,6" FontSize="12"/>
                                    </StackPanel>
                                </Grid>

                                <DockPanel Margin="0,2,0,0">
                                    <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                                        <TextBlock Text="Διόρθωση (ECC):" FontSize="11.5" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                        <ComboBox x:Name="CmbQREcc" SelectedIndex="2" Width="105" FontSize="11.5" Padding="5,4">
                                            <ComboBoxItem Content="L (7%)" Tag="0"/>
                                            <ComboBoxItem Content="M (15%)" Tag="1"/>
                                            <ComboBoxItem Content="Q (25%)" Tag="2"/>
                                            <ComboBoxItem Content="H (30% Max)" Tag="3"/>
                                        </ComboBox>
                                    </StackPanel>
                                    <CheckBox x:Name="ChkQRRounded" Content="Rounded Dots" DockPanel.Dock="Right" FontSize="12" Margin="10,0,0,0"/>
                                </DockPanel>
                            </StackPanel>
                        </Border>

                        <!-- RIGHT: Live Preview & Export Buttons -->
                        <Border Grid.Column="2" Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="12" Padding="14">
                            <StackPanel>
                                <Border Background="#FFFFFF" CornerRadius="8" Padding="10" Height="225" Margin="0,0,0,10">
                                    <Image x:Name="ImgQRPreview" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
                                </Border>
                                <TextBlock x:Name="TxtQRMeta" Text="..." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,10" TextAlignment="Center"/>
                                <UniformGrid Columns="2" Margin="-3,0,-3,6">
                                    <Button x:Name="BtnQRSaveSvg" Content="Εξαγωγή SVG" Style="{StaticResource EmeraldButton}" Margin="3" Padding="8,8" FontSize="12"/>
                                    <Button x:Name="BtnQRSavePng" Content="Εξαγωγή PNG" Style="{StaticResource PrimaryButton}" Margin="3" Padding="8,8" FontSize="12"/>
                                </UniformGrid>
                                <Button x:Name="BtnQRCopyImg" Content="Αντιγραφή Εικόνας (Clipboard)" Style="{StaticResource SecondaryButton}" Padding="10,7" FontSize="12"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- Client Archive (Saved locally in saved_codes.json — ready for GitHub backup!) -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="Αρχείο Κωδικών Πελατών (saved_codes.json — διπλό κλικ για φόρτωση)" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                                    <TextBox x:Name="TxtQRClientName" Width="170" ToolTip="Όνομα πελάτη / project" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,4" FontSize="12" Margin="0,0,6,0"/>
                                    <Button x:Name="BtnQRSaveClient" Content="Αποθήκευση Πελάτη" Style="{StaticResource SecondaryButton}" Padding="10,5" FontSize="11.5"/>
                                </StackPanel>
                            </DockPanel>
                            <ListView x:Name="ListQRSaved" Height="105" Background="#0B0F17" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="11.5">
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="Πελάτης / Project" Width="165" DisplayMemberBinding="{Binding Client}"/>
                                        <GridViewColumn Header="Τύπος" Width="75" DisplayMemberBinding="{Binding Type}"/>
                                        <GridViewColumn Header="Δεδομένα" Width="260" DisplayMemberBinding="{Binding Payload}"/>
                                        <GridViewColumn Header="Ημερομηνία" Width="115" DisplayMemberBinding="{Binding Date}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>
                        </StackPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtQRStatus" Text="100% Static ISO κωδικοί — δεν λήγουν ποτέ και σκανάρονται ακαριαία σε iPhone &amp; Android!" FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 8: NILLY QUICKTOOLS #3 — IMAGE RESIZER & CONVERTER -->
            <ScrollViewer x:Name="PageImageResizer" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Image Resizer &amp; Converter" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Drag &amp; Drop · EXIF-safe για iPhone φωτό · Σώζει πάντα σε νέο φάκελο '_resized' (0 πείραγμα στα πρωτότυπα)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnIRRun" Content="Εκτέλεση Resize" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="16,9"/>
                    </DockPanel>

                    <Border x:Name="ZoneIRDrop" AllowDrop="True" Background="#111C2D" BorderBrush="#38BDF8" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,2,0,12">
                        <DockPanel>
                            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                                <Button x:Name="BtnIRBrowse" Content="Επιλογή Εικόνων" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                <Button x:Name="BtnIRClear" Content="Καθαρισμός" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                            <StackPanel VerticalAlignment="Center">
                                <TextBlock Text="Ρίξε εδώ εικόνες ή φάκελο (Drag &amp; Drop)" FontSize="13.5" FontWeight="SemiBold" Foreground="#38BDF8"/>
                                <TextBlock Text="Υποστηρίζει PNG, JPG, JPEG, BMP, GIF, TIFF" FontSize="11.5" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <!-- Presets & Quality -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="1.3*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="0.7*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="0.9*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Μέγεθος (Preset):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                <ComboBox x:Name="CmbIRPreset" SelectedIndex="1" FontSize="12" Padding="6,5">
                                    <ComboBoxItem Content="Full HD (1920px max)" Tag="1920"/>
                                    <ComboBoxItem Content="Web / Site (1200px max)" Tag="1200"/>
                                    <ComboBoxItem Content="Social / Instagram (1080px)" Tag="1080"/>
                                    <ComboBoxItem Content="Thumbnail (600px max)" Tag="600"/>
                                    <ComboBoxItem Content="Μισό μέγεθος (50%)" Tag="PCT50"/>
                                    <ComboBoxItem Content="Προσαρμοσμένο (Custom px)" Tag="CUSTOM"/>
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Custom px:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                <TextBox x:Name="TxtIRCustomPx" Text="1600" IsEnabled="False" Background="#0B0F17" Foreground="#F8FAFC" BorderBrush="#2C384D" BorderThickness="1" Padding="7,6" FontSize="12"/>
                            </StackPanel>
                            <StackPanel Grid.Column="4">
                                <TextBlock Text="Μορφή Εξόδου:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                <ComboBox x:Name="CmbIRFormat" SelectedIndex="0" FontSize="12" Padding="6,5">
                                    <ComboBoxItem Content="Ίδια μορφή" Tag="ORIG"/>
                                    <ComboBoxItem Content="JPG (Ελαφρύ)" Tag="JPG"/>
                                    <ComboBoxItem Content="PNG (Lossless)" Tag="PNG"/>
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Grid.Column="6" VerticalAlignment="Center">
                                <DockPanel Margin="0,0,0,4">
                                    <TextBlock Text="Ποιότητα JPG:" FontSize="11" Foreground="#94A3B8"/>
                                    <TextBlock x:Name="LblIRQuality" Text="85%" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" HorizontalAlignment="Right"/>
                                </DockPanel>
                                <Slider x:Name="SliderIRQuality" Minimum="50" Maximum="100" Value="85" TickFrequency="5" IsSnapToTickEnabled="True"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <ListView x:Name="ListIRFiles" AllowDrop="True" Height="215" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12" Margin="0,0,0,10">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Αρχείο" Width="260" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Μέγεθος" Width="90" DisplayMemberBinding="{Binding Size}"/>
                                <GridViewColumn Header="Διαδρομή" Width="260" DisplayMemberBinding="{Binding Path}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>

                    <DockPanel>
                        <Button x:Name="BtnIROpenOut" Content="Άνοιγμα _resized" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Margin="10,0,0,0"/>
                        <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                            <TextBlock x:Name="TxtIRStatus" Text="Ρίξε εικόνες και πάτα 'Εκτέλεση Resize'." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                        </Border>
                    </DockPanel>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 9: NILLY QUICKTOOLS #4 — BATCH RENAMER & SEO SLUG -->
            <ScrollViewer x:Name="PageBatchRenamer" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Batch Renamer &amp; SEO Slug" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Μαζική μετονομασία · Ελληνικά → καθαρά SEO URLs · Live Preview &amp; 1-Click Undo" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                            <Button x:Name="BtnBRUndo" Content="Undo" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="13,9"/>
                            <Button x:Name="BtnBRApply" Content="Εφαρμογή" Style="{StaticResource PrimaryButton}" Padding="16,9"/>
                        </StackPanel>
                    </DockPanel>

                    <Border x:Name="ZoneBRDrop" AllowDrop="True" Background="#111C2D" BorderBrush="#38BDF8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,2,0,12">
                        <DockPanel>
                            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                                <Button x:Name="BtnBRBrowse" Content="Επιλογή Αρχείων" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                <Button x:Name="BtnBRClear" Content="Καθαρισμός" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                            <TextBlock Text="Ρίξε εδώ αρχεία ή φάκελο για Live Preview μετονομασίας" FontSize="13" FontWeight="SemiBold" Foreground="#38BDF8" VerticalAlignment="Center"/>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
                        <StackPanel>
                            <UniformGrid Columns="4" Margin="-4,0,-4,8">
                                <StackPanel Margin="4,0">
                                    <TextBlock Text="Αναζήτηση (Find):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtBRFind" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,5" FontSize="12"/>
                                </StackPanel>
                                <StackPanel Margin="4,0">
                                    <TextBlock Text="Αντικατάσταση:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtBRReplace" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,5" FontSize="12"/>
                                </StackPanel>
                                <StackPanel Margin="4,0">
                                    <TextBlock Text="Πρόθεμα (Prefix):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtBRPrefix" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,5" FontSize="12"/>
                                </StackPanel>
                                <StackPanel Margin="4,0">
                                    <TextBlock Text="Επίθεμα (Suffix):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,3"/>
                                    <TextBox x:Name="TxtBRSuffix" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="7,5" FontSize="12"/>
                                </StackPanel>
                            </UniformGrid>
                            <WrapPanel>
                                <CheckBox x:Name="ChkBRSeoSlug" Content="Μετατροπή σε Clean SEO Slug (Ελληνικά → latin-kebab-case)" IsChecked="True" Margin="0,2,18,0" FontSize="12.5"/>
                                <CheckBox x:Name="ChkBRNumbering" Content="Προσθήκη αρίθμησης (-001, -002...)" IsChecked="False" Margin="0,2,0,0" FontSize="12.5"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>

                    <ListView x:Name="ListBRPreview" AllowDrop="True" Height="220" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12" Margin="0,0,0,10">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Παλιό Όνομα" Width="255" DisplayMemberBinding="{Binding OldName}"/>
                                <GridViewColumn Header="Νέο Όνομα (Preview)" Width="265" DisplayMemberBinding="{Binding NewName}"/>
                                <GridViewColumn Header="Κατάσταση" Width="85" DisplayMemberBinding="{Binding Changed}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtBRStatus" Text="Παράδειγμα SEO Slug: 'Φωτογραφία Προϊόντος 01.JPG' → 'fotografia-proiontos-01.jpg'." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 10: NILLY QUICKTOOLS #5 — FILE LOCKSMITH -->
            <Grid x:Name="PageFileLocksmith" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <TextBlock Text="File Locksmith" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                    <TextBlock Text="Δες ποιο πρόγραμμα κρατάει κλειδωμένο ένα αρχείο που δεν σβήνεται (Windows Restart Manager API)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                </StackPanel>

                <Border x:Name="ZoneFLDrop" Grid.Row="1" AllowDrop="True" Background="#111C2D" BorderBrush="#38BDF8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                    <DockPanel>
                        <Button x:Name="BtnFLBrowse" Content="Επιλογή Αρχείου" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right"/>
                        <TextBlock Text="Ρίξε εδώ ένα κλειδωμένο αρχείο (Drag &amp; Drop) για άμεσο έλεγχο" FontSize="13" FontWeight="SemiBold" Foreground="#38BDF8" VerticalAlignment="Center"/>
                    </DockPanel>
                </Border>

                <DockPanel Grid.Row="2" Margin="0,0,0,10">
                    <Button x:Name="BtnFLScan" Content="Έλεγχος" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" Margin="8,0,0,0" Padding="16,7"/>
                    <TextBox x:Name="TxtFLPath" Background="#131924" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="9,7" FontSize="12.5"/>
                </DockPanel>

                <ListView x:Name="ListFLLocks" Grid.Row="3" AllowDrop="True" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12.5">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Διεργασία" Width="190" DisplayMemberBinding="{Binding ProcessName}"/>
                            <GridViewColumn Header="PID" Width="80" DisplayMemberBinding="{Binding PID}"/>
                            <GridViewColumn Header="Εφαρμογή" Width="220" DisplayMemberBinding="{Binding AppName}"/>
                            <GridViewColumn Header="Τύπος" Width="95" DisplayMemberBinding="{Binding Protected}"/>
                        </GridView>
                    </ListView.View>
                </ListView>

                <DockPanel Grid.Row="4" Margin="0,10,0,0">
                    <Button x:Name="BtnFLKill" Content="Τερματισμός &amp; Ξεκλείδωμα" Style="{StaticResource DangerButton}" DockPanel.Dock="Right" Margin="10,0,0,0"/>
                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtFLStatus" Text="Επίλεξε ένα αρχείο για να δεις αν το κλειδώνει κάποια διεργασία." FontSize="11.5" Foreground="#94A3B8" TextWrapping="Wrap"/>
                    </Border>
                </DockPanel>
            </Grid>

            <!-- PAGE 11: NILLY QUICKTOOLS #6 — ALWAYS ON TOP -->
            <Grid x:Name="PageAlwaysOnTop" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <DockPanel Grid.Row="0" Margin="0,0,0,12">
                    <StackPanel>
                        <TextBlock Text="Always On Top (Καρφίτσωμα Παραθύρων)" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                        <TextBlock Text="Κράτησε οποιοδήποτε παράθυρο μόνιμα μπροστά από τα άλλα με 1 κλικ (0 MB στο παρασκήνιο)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                        <Button x:Name="BtnAOTUnpinAll" Content="Ξεκαρφίτσωμα Όλων" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                        <Button x:Name="BtnAOTRefresh" Content="Ανανέωση" Style="{StaticResource SecondaryButton}"/>
                    </StackPanel>
                </DockPanel>

                <ListView x:Name="ListAOTWindows" Grid.Row="1" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12.5">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Κατάσταση" Width="95" DisplayMemberBinding="{Binding Status}"/>
                            <GridViewColumn Header="Εφαρμογή" Width="140" DisplayMemberBinding="{Binding Process}"/>
                            <GridViewColumn Header="Τίτλος Παραθύρου" Width="360" DisplayMemberBinding="{Binding Title}"/>
                        </GridView>
                    </ListView.View>
                </ListView>

                <DockPanel Grid.Row="2" Margin="0,12,0,0">
                    <Button x:Name="BtnAOTToggle" Content="Pin / Unpin Επιλεγμένου" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" Margin="10,0,0,0"/>
                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtAOTStatus" Text="Επίλεξε ένα παράθυρο (ή διπλό κλικ) για Pin / Unpin." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </DockPanel>
            </Grid>

            <!-- PAGE 12: MY HUB (CLEAN RAM + FIREFOX CACHE + BACKUPS + G-PHONOR) -->
            <ScrollViewer x:Name="PageMyHub" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="My Hub — Γρήγορες Ενέργειες, Backup &amp; G-Phonor" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Ενοποιεί Clean_RAM, Clean_Firefox_Cache, Master Backup (H:) &amp; G-Phonor σε ένα σημείο" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnHubRefresh" Content="Ανανέωση" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center"/>
                    </DockPanel>

                    <!-- Card 1: Clean RAM Now -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="15" Margin="0,4,0,10">
                        <DockPanel>
                            <Button x:Name="BtnHubCleanRam" Content="Clean RAM Τώρα" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" MinWidth="165" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Καθαρισμός RAM (Working Set Purge — αντικαθιστά Clean_RAM.bat)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtHubRamInfo" Text="Έλεγχος RAM..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <!-- Card 2: Firefox Cache Clean & Restart -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="15" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnHubCleanFF" Content="Clean &amp; Restart FF" Style="{StaticResource EmeraldButton}" DockPanel.Dock="Right" MinWidth="165" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="Καθαρισμός Firefox Cache &amp; Επανεκκίνηση (αντικαθιστά RUN_Clean_Firefox_Cache)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtHubFFInfo" Text="Έλεγχος Firefox..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <!-- Card 3: NillyGraphics Master Backup -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="15" Margin="0,0,0,10">
                        <DockPanel>
                            <Button x:Name="BtnHubRunBackup" Content="Backup Τώρα (H:)" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="165" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="NillyGraphics Works — Master ZIP Backup (H:)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtHubBackupInfo" Text="Έλεγχος Backup..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <!-- Card 4: G-Phonor Voice-to-Text -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="15" Margin="0,0,0,12">
                        <DockPanel>
                            <Button x:Name="BtnHubToggleGPhonor" Content="Εκκίνηση G-Phonor" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" MinWidth="165" VerticalAlignment="Center"/>
                            <StackPanel Margin="0,0,12,0">
                                <TextBlock Text="G-Phonor (Ελληνική Φωνητική Πληκτρολόγηση — G5 / F13)" FontSize="14" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                                <TextBlock x:Name="TxtHubGPhonorInfo" Text="Έλεγχος G-Phonor..." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </DockPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="11">
                        <TextBlock x:Name="TxtHubStatus" Text="Όλα τα προσωπικά σου scripts &amp; γρήγορες ενέργειες σε ένα σημείο (0 MB background RAM)." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 13: HARDWARE & SPECS (CPU-Z + GPU-Z REPLACEMENT) -->
            <Grid x:Name="PageHardware" Visibility="Collapsed">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <DockPanel Grid.Row="0" Margin="0,0,0,10">
                    <StackPanel>
                        <TextBlock Text="Hardware &amp; System Specs" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                        <TextBlock Text="Ελαφριά αντικατάσταση CPU-Z &amp; GPU-Z · CPU, Μητρική, RAM Slots, GPU VRAM, Υγεία SSD &amp; IP" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                        <Button x:Name="BtnHWCopy" Content="Copy Specs" Style="{StaticResource PrimaryButton}" Margin="0,0,8,0" Padding="14,8"/>
                        <Button x:Name="BtnHWRefresh" Content="Ανανέωση" Style="{StaticResource SecondaryButton}"/>
                    </StackPanel>
                </DockPanel>

                <ListView x:Name="ListHWSpecs" Grid.Row="1" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Κατηγορία" Width="95" DisplayMemberBinding="{Binding Category}"/>
                            <GridViewColumn Header="Στοιχείο" Width="155" DisplayMemberBinding="{Binding Item}"/>
                            <GridViewColumn Header="Τιμή / Λεπτομέρειες" Width="360" DisplayMemberBinding="{Binding Value}"/>
                        </GridView>
                    </ListView.View>
                </ListView>

                <Border Grid.Row="2" Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,10,0,0">
                    <TextBlock x:Name="TxtHWStatus" Text="Ανάγνωση υλικού..." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                </Border>
            </Grid>

            <!-- PAGE 14: IMAGES TO PDF CREATOR (LIGHTWEIGHT PDF CREATION) -->
            <ScrollViewer x:Name="PageImgPdf" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Images → PDF Creator" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Φτιάξε πολυσέλιδα PDF από εικόνες/μακέτες (100% native — χωρίς βαρύ PDF editor)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnPdfBuild" Content="Δημιουργία PDF" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="16,9"/>
                    </DockPanel>

                    <Border x:Name="ZonePdfDrop" AllowDrop="True" Background="#111C2D" BorderBrush="#38BDF8" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,2,0,10">
                        <DockPanel>
                            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                                <Button x:Name="BtnPdfBrowse" Content="Επιλογή Εικόνων" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                <Button x:Name="BtnPdfClear" Content="Καθαρισμός" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                            <TextBlock Text="Ρίξε εδώ 1–100 εικόνες (Drag &amp; Drop) για ένωση σε ένα PDF" FontSize="13" FontWeight="SemiBold" Foreground="#38BDF8" VerticalAlignment="Center"/>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Μέγεθος Σελίδας:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                <ComboBox x:Name="CmbPdfPage" SelectedIndex="0" FontSize="12" Padding="6,5">
                                    <ComboBoxItem Content="A4 Κάθετο (Portrait)" Tag="A4P"/>
                                    <ComboBoxItem Content="A4 Οριζόντιο (Landscape)" Tag="A4L"/>
                                    <ComboBoxItem Content="Ακριβές μέγεθος εικόνας (Full Bleed)" Tag="FIT"/>
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Ποιότητα PDF:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                <ComboBox x:Name="CmbPdfQuality" SelectedIndex="1" FontSize="12" Padding="6,5">
                                    <ComboBoxItem Content="Εκτύπωση (95% — Μεγαλύτερο)" Tag="95"/>
                                    <ComboBoxItem Content="Ισορροπημένο (85% — Ιδανικό)" Tag="85"/>
                                    <ComboBoxItem Content="Web / Email (72% — Ελαφρύ)" Tag="72"/>
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Grid.Column="4" Orientation="Horizontal" VerticalAlignment="Bottom">
                                <Button x:Name="BtnPdfUp" Content="▲ Πάνω" Style="{StaticResource SecondaryButton}" Margin="0,0,6,0" Padding="10,6"/>
                                <Button x:Name="BtnPdfDown" Content="▼ Κάτω" Style="{StaticResource SecondaryButton}" Padding="10,6"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <ListView x:Name="ListPdfFiles" AllowDrop="True" Height="220" Background="#131924" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12" Margin="0,0,0,10">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Σελίδα" Width="70" DisplayMemberBinding="{Binding Page}"/>
                                <GridViewColumn Header="Εικόνα" Width="260" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Μέγεθος" Width="90" DisplayMemberBinding="{Binding Size}"/>
                                <GridViewColumn Header="Διαδρομή" Width="190" DisplayMemberBinding="{Binding Path}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtPdfStatus" Text="Ρίξε εικόνες, βάλε τες στη σειρά και πάτα 'Δημιουργία PDF'." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 15: QUICK NOTES & CLIENT SNIPPETS (STICKY NOTES REPLACEMENT) -->
            <ScrollViewer x:Name="PageNotes" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Quick Notes &amp; Client Snippets" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Ελαφριά αντικατάσταση Sticky Notes · Ιδιωτική τοπική αποθήκευση (notes.json, εκτός GitHub)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnQNSaveScratch" Content="Αποθήκευση Σημειώσεων" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="15,8"/>
                    </DockPanel>

                    <!-- Scratchpad -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,2,0,12">
                        <StackPanel>
                            <TextBlock Text="Γρήγορες Σημειώσεις (Scratchpad):" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" Margin="0,0,0,6"/>
                            <TextBox x:Name="TxtQNScratch" Height="130" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="10,8" FontSize="12.5"/>
                        </StackPanel>
                    </Border>

                    <!-- Reusable 1-Click Snippets -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Έτοιμα Snippets (ΑΦΜ, IBAN, Υπογραφή, SEO — διπλό κλικ για Copy):" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" Margin="0,0,0,8"/>
                            <Grid Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1*"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="2*"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="TxtQNSnipTitle" Grid.Column="0" ToolTip="Τίτλος (π.χ. IBAN / Υπογραφή)" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12"/>
                                <TextBox x:Name="TxtQNSnipBody" Grid.Column="2" ToolTip="Κείμενο προς αντιγραφή" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12"/>
                                <Button x:Name="BtnQNAddSnip" Grid.Column="4" Content="+ Προσθήκη" Style="{StaticResource EmeraldButton}" Padding="13,6" FontSize="12"/>
                            </Grid>

                            <ListView x:Name="ListQNSnippets" Height="155" Background="#0B0F17" Foreground="#E2E8F0" BorderBrush="#1F293B" BorderThickness="1" FontSize="12" Margin="0,0,0,8">
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="Τίτλος" Width="180" DisplayMemberBinding="{Binding Title}"/>
                                        <GridViewColumn Header="Περιεχόμενο" Width="410" DisplayMemberBinding="{Binding Body}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>

                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button x:Name="BtnQNCopySnip" Content="Copy Επιλεγμένου" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                <Button x:Name="BtnQNDelSnip" Content="Διαγραφή" Style="{StaticResource DangerButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtQNStatus" Text="Οι σημειώσεις σου αποθηκεύονται μόνο τοπικά στο PC σου (notes.json)." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 16: PRINT, DPI & SOCIAL SIZES CALCULATOR -->
            <ScrollViewer x:Name="PagePrintDpi" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Print, DPI &amp; Social Sizes Calculator" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Άμεση μετατροπή mm / cm ↔ px (72 / 150 / 300 / 600 DPI) + Bleed (+3mm / +5mm) + Aspect Ratio" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnPDCopy" Content="Copy Διαστάσεις" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="15,8"/>
                    </DockPanel>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,2,0,12">
                        <StackPanel>
                            <TextBlock Text="Έτοιμο Preset (Εκτύπωση &amp; Social Media):" FontSize="11.5" Foreground="#94A3B8" Margin="0,0,0,5"/>
                            <ComboBox x:Name="CmbPDPreset" FontSize="12.5" Padding="8,6" Margin="0,0,0,12"/>

                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="8"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="84"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="108"/>
                                    <ColumnDefinition Width="10"/>
                                    <ColumnDefinition Width="118"/>
                                </Grid.ColumnDefinitions>

                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="Πλάτος (W):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                    <TextBox x:Name="TxtPDWidth" Text="210" FontFamily="Consolas" FontSize="13.5" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6"/>
                                </StackPanel>

                                <Button x:Name="BtnPDSwap" Grid.Column="2" Content="⇄" ToolTip="Εναλλαγή Πλάτους / Ύψους" Style="{StaticResource SecondaryButton}" VerticalAlignment="Bottom" Padding="10,6" FontSize="14"/>

                                <StackPanel Grid.Column="4">
                                    <TextBlock Text="Ύψος (H):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                    <TextBox x:Name="TxtPDHeight" Text="297" FontFamily="Consolas" FontSize="13.5" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6"/>
                                </StackPanel>

                                <StackPanel Grid.Column="6">
                                    <TextBlock Text="Μονάδα:" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                    <ComboBox x:Name="CmbPDUnit" SelectedIndex="0" FontSize="12.5" Padding="6,6">
                                        <ComboBoxItem Content="mm" Tag="mm"/>
                                        <ComboBoxItem Content="cm" Tag="cm"/>
                                        <ComboBoxItem Content="px" Tag="px"/>
                                    </ComboBox>
                                </StackPanel>

                                <StackPanel Grid.Column="8">
                                    <TextBlock Text="Ανάλυση (DPI):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                    <ComboBox x:Name="CmbPDDpi" SelectedIndex="2" FontSize="12.5" Padding="6,6">
                                        <ComboBoxItem Content="72 DPI" Tag="72"/>
                                        <ComboBoxItem Content="150 DPI" Tag="150"/>
                                        <ComboBoxItem Content="300 DPI" Tag="300"/>
                                        <ComboBoxItem Content="600 DPI" Tag="600"/>
                                    </ComboBox>
                                </StackPanel>

                                <StackPanel Grid.Column="10">
                                    <TextBlock Text="Bleed (Ξάκρισμα):" FontSize="11" Foreground="#94A3B8" Margin="0,0,0,4"/>
                                    <ComboBox x:Name="CmbPDBleed" SelectedIndex="1" FontSize="12.5" Padding="6,6">
                                        <ComboBoxItem Content="0 mm" Tag="0"/>
                                        <ComboBoxItem Content="+3 mm" Tag="3"/>
                                        <ComboBoxItem Content="+5 mm" Tag="5"/>
                                    </ComboBox>
                                </StackPanel>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <!-- Live Output Cards -->
                    <UniformGrid Columns="2" Margin="-5,0,-5,12">
                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="5">
                            <StackPanel>
                                <TextBlock Text="ΤΕΛΙΚΕΣ ΔΙΑΣΤΑΣΕΙΣ PIXELS" FontSize="10.5" FontWeight="Bold" Foreground="#38BDF8"/>
                                <TextBlock x:Name="ValPDPixels" Text="--" FontFamily="Consolas" FontSize="15.5" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,5,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="5">
                            <StackPanel>
                                <TextBlock Text="ΦΥΣΙΚΟ ΜΕΓΕΘΟΣ ΕΚΤΥΠΩΣΗΣ" FontSize="10.5" FontWeight="Bold" Foreground="#10B981"/>
                                <TextBlock x:Name="ValPDMm" Text="--" FontFamily="Consolas" FontSize="14.5" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,5,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="5">
                            <StackPanel>
                                <TextBlock Text="ΜΕ BLEED (ΓΙΑ ΤΥΠΟΓΡΑΦΕΙΟ)" FontSize="10.5" FontWeight="Bold" Foreground="#F59E0B"/>
                                <TextBlock x:Name="ValPDBleed" Text="--" FontFamily="Consolas" FontSize="13.5" FontWeight="SemiBold" Foreground="#FDE68A" Margin="0,5,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="5">
                            <StackPanel>
                                <TextBlock Text="ASPECT RATIO &amp; MEGAPIXELS" FontSize="10.5" FontWeight="Bold" Foreground="#A78BFA"/>
                                <TextBlock x:Name="ValPDRatio" Text="--" FontFamily="Consolas" FontSize="14.5" FontWeight="SemiBold" Foreground="#F8FAFC" Margin="0,5,0,0" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </UniformGrid>

                    <!-- Proportional Resize Helper -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <DockPanel>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="Αναλογική κλίμακα — Αν το νέο Πλάτος είναι:" FontSize="12" Foreground="#CBD5E1" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <TextBox x:Name="TxtPDScaleW" Width="90" Text="1080" FontFamily="Consolas" FontSize="13" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,5"/>
                            </StackPanel>
                            <TextBlock x:Name="TxtPDScaleRes" Text="—" FontFamily="Consolas" FontSize="13.5" FontWeight="Bold" Foreground="#38BDF8" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                        </DockPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtPDStatus" Text="Tip: 300 DPI + 3mm Bleed είναι το στάνταρ για κάρτες, flyers &amp; έντυπα · 150 DPI για banners/roll-ups." FontSize="11.5" Foreground="#94A3B8" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 17: SCREEN PIXEL RULER & QUICK REGION SCREENSHOT -->
            <ScrollViewer x:Name="PagePixelRuler" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="Pixel Ruler &amp; Quick Capture" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Μέτρηση διαστάσεων οθόνης σε pixels (W × H) &amp; άμεσο Screenshot με Copy στο Clipboard (120 FPS)" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnPRStart" Content="Μέτρηση &amp; Λήψη Οθόνης" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="16,9"/>
                    </DockPanel>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,2,0,12">
                        <DockPanel>
                            <CheckBox x:Name="ChkPRAutoCopy" Content="Αυτόματη αντιγραφή Screenshot στο Clipboard (έτοιμο για Ctrl+V σε Photoshop / Figma / Chat)" IsChecked="True" Margin="0"/>
                        </DockPanel>
                    </Border>

                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,10">
                                <TextBlock x:Name="TxtPRDims" Text="Καμία μέτρηση ακόμα — πάτα 'Μέτρηση &amp; Λήψη Οθόνης' και σύρε με το ποντίκι." FontFamily="Consolas" FontSize="13" FontWeight="SemiBold" Foreground="#38BDF8" VerticalAlignment="Center" TextWrapping="Wrap"/>
                                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                                    <Button x:Name="BtnPRCopyDims" Content="Copy W×H" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                    <Button x:Name="BtnPRCopyImg" Content="Copy PNG" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                    <Button x:Name="BtnPRSavePng" Content="Αποθήκευση PNG" Style="{StaticResource EmeraldButton}" Padding="13,7" FontSize="12.5"/>
                                </StackPanel>
                            </DockPanel>
                            <Border Background="#0B0F17" BorderBrush="#263348" BorderThickness="1" CornerRadius="8" MinHeight="270" MaxHeight="360" Padding="8">
                                <Image x:Name="ImgPRPreview" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
                            </Border>
                        </StackPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtPRStatus" Text="0 MB background RAM · Esc ή Δεξί κλικ για ακύρωση κατά την επιλογή περιοχής." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 18: SEO, TEXT CLEANER & PASSWORD TOOLKIT -->
            <ScrollViewer x:Name="PageSeoText" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="SEO, Text &amp; Password Toolkit" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Google SERP Title/Meta Checker · Greek → SEO Slug · Plain Text Cleaner · Crypto Password Generator" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                            <Button x:Name="BtnSEOCopySlug" Content="Copy Slug" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                            <Button x:Name="BtnSEOCopyMeta" Content="Copy HTML Meta" Style="{StaticResource PrimaryButton}" Padding="14,8"/>
                        </StackPanel>
                    </DockPanel>

                    <!-- Google SERP Checker Card -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,2,0,12">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,4">
                                <TextBlock Text="SEO Title (ιδανικά έως 60 χαρακτήρες):" FontSize="11.5" Foreground="#CBD5E1"/>
                                <TextBlock x:Name="LblSEOTitleCount" Text="0 / 60 chars" FontFamily="Consolas" FontSize="11.5" FontWeight="Bold" HorizontalAlignment="Right" Foreground="#22C55E"/>
                            </DockPanel>
                            <TextBox x:Name="TxtSEOTitle" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12.5"/>
                            <ProgressBar x:Name="BarSEOTitle" Height="4" Minimum="0" Maximum="80" Value="0" Background="#1E293B" Foreground="#38BDF8" BorderThickness="0" Margin="0,4,0,10"/>

                            <DockPanel Margin="0,0,0,4">
                                <TextBlock Text="Meta Description (ιδανικά έως 155 χαρακτήρες):" FontSize="11.5" Foreground="#CBD5E1"/>
                                <TextBlock x:Name="LblSEODescCount" Text="0 / 155 chars" FontFamily="Consolas" FontSize="11.5" FontWeight="Bold" HorizontalAlignment="Right" Foreground="#22C55E"/>
                            </DockPanel>
                            <TextBox x:Name="TxtSEODesc" Height="54" AcceptsReturn="True" TextWrapping="Wrap" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12"/>
                            <ProgressBar x:Name="BarSEODesc" Height="4" Minimum="0" Maximum="200" Value="0" Background="#1E293B" Foreground="#10B981" BorderThickness="0" Margin="0,4,0,10"/>

                            <!-- Live Google SERP Preview -->
                            <Border Background="#0B0F17" BorderBrush="#253349" BorderThickness="1" CornerRadius="8" Padding="11">
                                <StackPanel>
                                    <TextBlock x:Name="TxtSEOSlugOut" Text="https://nillygraphics.com/" FontSize="11" Foreground="#94A3B8" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="PrevSEOTitle" Text="Title Preview" FontSize="14.5" FontWeight="SemiBold" Foreground="#60A5FA" Margin="0,2,0,2" TextWrapping="Wrap"/>
                                    <TextBlock x:Name="PrevSEODesc" Text="Description Preview" FontSize="11.5" Foreground="#CBD5E1" TextWrapping="Wrap"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </Border>

                    <!-- Plain Text Cleaner & Case Converter -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,12">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,6">
                                <TextBlock Text="Καθαρισμός Κειμένου &amp; Μετατροπή Κεφαλαίων / Πεζών:" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1"/>
                                <TextBlock x:Name="LblSEOTextStats" Text="0 λέξεις • 0 χαρακτήρες • 0 γραμμές" FontFamily="Consolas" FontSize="11" Foreground="#94A3B8" HorizontalAlignment="Right"/>
                            </DockPanel>
                            <TextBox x:Name="TxtSEOCleaner" Height="82" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#0B0F17" Foreground="#F8FAFC" CaretBrush="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6" FontSize="12" Margin="0,0,0,8"/>
                            <WrapPanel>
                                <Button x:Name="BtnSEOCleanSpaces" Content="Καθαρισμός Κενών" Style="{StaticResource SecondaryButton}" Margin="0,0,8,4"/>
                                <Button x:Name="BtnSEOUpper" Content="ΚΕΦΑΛΑΙΑ" Style="{StaticResource SecondaryButton}" Margin="0,0,8,4"/>
                                <Button x:Name="BtnSEOLower" Content="πεζά" Style="{StaticResource SecondaryButton}" Margin="0,0,8,4"/>
                                <Button x:Name="BtnSEOTitleCase" Content="Title Case" Style="{StaticResource SecondaryButton}" Margin="0,0,8,4"/>
                                <Button x:Name="BtnSEOCopyPlain" Content="Copy Plain Text" Style="{StaticResource EmeraldButton}" Padding="13,7" FontSize="12" Margin="0,0,0,4"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>

                    <!-- Crypto Password Generator -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="95"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtSEOPassOut" Grid.Column="0" IsReadOnly="True" FontFamily="Consolas" FontSize="13.5" FontWeight="Bold" Background="#0B0F17" Foreground="#38BDF8" BorderBrush="#2C384D" BorderThickness="1" Padding="10,7"/>
                            <ComboBox x:Name="CmbSEOPassLen" Grid.Column="2" SelectedIndex="1" FontSize="12" Padding="6,6" VerticalAlignment="Center">
                                <ComboBoxItem Content="12 chars" Tag="12"/>
                                <ComboBoxItem Content="16 chars" Tag="16"/>
                                <ComboBoxItem Content="24 chars" Tag="24"/>
                            </ComboBox>
                            <CheckBox x:Name="ChkSEOPassSym" Grid.Column="4" Content="Σύμβολα" IsChecked="True" Margin="0" VerticalAlignment="Center"/>
                            <Button x:Name="BtnSEOGenPass" Grid.Column="6" Content="Νέος &amp; Copy" Style="{StaticResource PrimaryButton}" Padding="13,7" FontSize="12.5"/>
                        </Grid>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtSEOStatus" Text="100% offline · Ιδανικό για WordPress, WooCommerce, Elementor, Meta Tags &amp; πελάτες." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <!-- PAGE 19: SVG / IMAGE TO BASE64 DATA URI & FILE HASH -->
            <ScrollViewer x:Name="PageBase64Hash" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel MaxWidth="1100">
                    <DockPanel Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="SVG / Image → Base64 &amp; File Hash" FontSize="20" FontWeight="SemiBold" Foreground="#F8FAFC"/>
                            <TextBlock Text="Μετατροπή SVG / PNG / JPG / ICO σε Data URI, HTML &lt;img&gt; &amp; CSS url() + SHA-256 &amp; MD5 έλεγχος αρχείων" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button x:Name="BtnB64Browse" Content="Επιλογή Αρχείου" Style="{StaticResource PrimaryButton}" DockPanel.Dock="Right" VerticalAlignment="Center" Padding="15,8"/>
                    </DockPanel>

                    <Border x:Name="ZoneB64Drop" AllowDrop="True" Background="#111C2D" BorderBrush="#38BDF8" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,2,0,12">
                        <StackPanel>
                            <TextBlock Text="Ρίξε εδώ SVG, Logo, PNG, WebP, ICO ή οποιοδήποτε αρχείο (Drag &amp; Drop)" FontSize="13.5" FontWeight="SemiBold" Foreground="#38BDF8"/>
                            <TextBlock x:Name="TxtB64Info" Text="Κανένα αρχείο επιλεγμένο ακόμα." FontSize="11.5" Foreground="#94A3B8" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Border>

                    <!-- Hashes Card -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,12">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <Button x:Name="BtnB64CopySha" Content="Copy SHA-256" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,10,0">
                                    <TextBlock Text="SHA-256:" FontSize="10.5" FontWeight="Bold" Foreground="#38BDF8"/>
                                    <TextBox x:Name="ValB64Sha" IsReadOnly="True" Text="—" FontFamily="Consolas" FontSize="11.5" Background="Transparent" Foreground="#E2E8F0" BorderThickness="0"/>
                                </StackPanel>
                            </DockPanel>
                            <DockPanel>
                                <Button x:Name="BtnB64CopyMd5" Content="Copy MD5" Style="{StaticResource SecondaryButton}" DockPanel.Dock="Right" Padding="11,5" FontSize="11.5"/>
                                <StackPanel Margin="0,0,10,0">
                                    <TextBlock Text="MD5:" FontSize="10.5" FontWeight="Bold" Foreground="#10B981"/>
                                    <TextBox x:Name="ValB64Md5" IsReadOnly="True" Text="—" FontFamily="Consolas" FontSize="11.5" Background="Transparent" Foreground="#E2E8F0" BorderThickness="0"/>
                                </StackPanel>
                            </DockPanel>
                        </StackPanel>
                    </Border>

                    <!-- Base64 Output + 1-Click Copy -->
                    <Border Background="#131924" BorderBrush="#1F293B" BorderThickness="1" CornerRadius="10" Padding="13" Margin="0,0,0,10">
                        <StackPanel>
                            <DockPanel Margin="0,0,0,8">
                                <TextBlock Text="Base64 Data URI Προεπισκόπηση:" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                                    <Button x:Name="BtnB64CopyUri" Content="Copy Data URI" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                    <Button x:Name="BtnB64CopyHtml" Content="Copy HTML &lt;img&gt;" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                                    <Button x:Name="BtnB64CopyCss" Content="Copy CSS url()" Style="{StaticResource EmeraldButton}" Padding="13,7" FontSize="12"/>
                                </StackPanel>
                            </DockPanel>
                            <TextBox x:Name="TxtB64Output" Height="115" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11.5" Background="#0B0F17" Foreground="#CBD5E1" BorderBrush="#2C384D" BorderThickness="1" Padding="8,6"/>
                        </StackPanel>
                    </Border>

                    <Border Background="#0F141F" BorderBrush="#1C2536" BorderThickness="1" CornerRadius="8" Padding="10">
                        <TextBlock x:Name="TxtB64Status" Text="Tip: Ιδανικό για email υπογραφές, inline SVG icons στο CSS/WordPress &amp; έλεγχο ακεραιότητας αρχείων." FontSize="11.5" Foreground="#22C55E" TextWrapping="Wrap"/>
                    </Border>
                </StackPanel>
            </ScrollViewer>

        </Grid>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Apply custom icon
$icoPath = Join-Path $PSScriptRoot "PCManagerLite.ico"
if (Test-Path $icoPath) {
    try { $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new($icoPath)) } catch {}
}

# Native Windows 11 Dark Titlebar
$window.Add_SourceInitialized({
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    [NillyNative]::EnableDarkTitleBar($hwnd)
})

# Responsive sidebar adjustment on narrow vs wide windows
$window.Add_SizeChanged({
    if ($window.ActualWidth -lt 810) {
        $ui.ColSidebar.Width = [System.Windows.GridLength]::new(192)
    } else {
        $ui.ColSidebar.Width = [System.Windows.GridLength]::new(212)
    }
})

# Guarantee 0 MB footprint after closing
$window.Add_Closed({
    [Environment]::Exit(0)
})

# Grab all named UI controls
$ctrlNames = @(
    'ColSidebar',
    'BtnNavHome','BtnNavMyHub','BtnNavOnDemand','BtnNavClean','BtnNavProcs','BtnNavTools','BtnNavColorPicker','BtnNavQrBarcode','BtnNavPrintDpi','BtnNavPixelRuler','BtnNavImageResizer','BtnNavBatchRenamer','BtnNavSeoText','BtnNavBase64Hash','BtnNavFileLocksmith','BtnNavAlwaysOnTop','BtnNavHardware','BtnNavImgPdf','BtnNavNotes','BtnSidebarSite',
    'PageHome','PageMyHub','PageOnDemand','PageClean','PageProcs','PageTools','PageColorPicker','PageQrBarcode','PagePrintDpi','PagePixelRuler','PageImageResizer','PageBatchRenamer','PageSeoText','PageBase64Hash','PageFileLocksmith','PageAlwaysOnTop','PageHardware','PageImgPdf','PageNotes',
    'TxtSysSpec','TxtUptime','BtnRefreshHome','TxtRamPct','TxtRamDetail','BarRam','TxtTempSize','TxtBgHeavy','BarTemp',
    'BtnBoost','BtnHomeColorPicker','BtnHomeOnDemand','TxtBoostStatus','ListDrives',
    'BtnQuickClean','BtnQuickProcs','BtnQuickStartup','BtnQuickTaskbar','TxtProcCount',
    'BtnRefreshOD','BtnFocusMode','BtnRestoreOD','TxtODTotal',
    'BtnToggleDropbox','TxtDropboxInfo','BtnToggleRazer','TxtRazerInfo',
    'BtnToggleLogiOpt','TxtLogiOptInfo','BtnToggleGHUB','TxtGHUBInfo','TxtODStatus',
    'BtnScanClean','ChkTemp','ChkBrowsers','ChkChromeAI','ChkDev','ChkSpotify','ChkRecycle',
    'LblTemp','LblBrowsers','LblChromeAI','LblDev','LblSpotify','LblRecycle','LblCleanTotal',
    'BtnRunClean','BtnWinUpdateClean','TxtCleanLog',
    'BtnRefreshProcs','TxtProcFilter','ListProcs','TxtProcStatus','BtnKillProc',
    'BtnDefenderScan','TxtDefenderInfo','BtnNetCheck','TxtNetInfo',
    'BtnWinUpdate','BtnWinSecurity','BtnInstalledApps','BtnStorageSense','BtnOpenScripts','BtnTaskbarRepair2','BtnAboutSite',
    'BtnCPPickScreen','BtnCPLiveSpy','BoxCPPreview','TxtCPPreviewHex','TxtCPInputHex','BtnCPApplyHex','TxtCPContrast',
    'ValCPHex','ValCPRgb','ValCPHsl','ValCPCmyk','ValCPCss',
    'BtnCopyHex','BtnCopyRgb','BtnCopyHsl','BtnCopyCmyk','BtnCopyCss',
    'PanelCPShades','PanelCPHistory','BtnCPClearHist','TxtCPStatus',
    'BtnQRGenerate','BtnQRSample','CmbQRMode','PanelQROptions','PanelBCOptions','CmbQRTpl','CmbBCFormat',
    'LblQRMain','TxtQRMain','RowQRExtra1','LblQRExtra1','TxtQRExtra1','RowQRExtra2','LblQRExtra2','TxtQRExtra2','RowQRExtra3','LblQRExtra3','TxtQRExtra3',
    'TxtQRCaption','TxtQRFg','TxtQRBg','CmbQREcc','ChkQRRounded',
    'ImgQRPreview','TxtQRMeta','BtnQRSaveSvg','BtnQRSavePng','BtnQRCopyImg',
    'TxtQRClientName','BtnQRSaveClient','ListQRSaved','TxtQRStatus',
    'BtnIRRun','ZoneIRDrop','BtnIRBrowse','BtnIRClear','CmbIRPreset','TxtIRCustomPx','CmbIRFormat','SliderIRQuality','LblIRQuality','ListIRFiles','BtnIROpenOut','TxtIRStatus',
    'BtnBRUndo','BtnBRApply','ZoneBRDrop','BtnBRBrowse','BtnBRClear','TxtBRFind','TxtBRReplace','TxtBRPrefix','TxtBRSuffix','ChkBRSeoSlug','ChkBRNumbering','ListBRPreview','TxtBRStatus',
    'ZoneFLDrop','BtnFLBrowse','BtnFLScan','TxtFLPath','ListFLLocks','BtnFLKill','TxtFLStatus',
    'BtnAOTUnpinAll','BtnAOTRefresh','ListAOTWindows','BtnAOTToggle','TxtAOTStatus',
    'BtnHubRefresh','BtnHubCleanRam','TxtHubRamInfo','BtnHubCleanFF','TxtHubFFInfo','BtnHubRunBackup','TxtHubBackupInfo','BtnHubToggleGPhonor','TxtHubGPhonorInfo','TxtHubStatus',
    'BtnHWCopy','BtnHWRefresh','ListHWSpecs','TxtHWStatus',
    'BtnPdfBuild','ZonePdfDrop','BtnPdfBrowse','BtnPdfClear','CmbPdfPage','CmbPdfQuality','BtnPdfUp','BtnPdfDown','ListPdfFiles','TxtPdfStatus',
    'BtnQNSaveScratch','TxtQNScratch','TxtQNSnipTitle','TxtQNSnipBody','BtnQNAddSnip','ListQNSnippets','BtnQNCopySnip','BtnQNDelSnip','TxtQNStatus',
    'CmbPDPreset','TxtPDWidth','TxtPDHeight','CmbPDUnit','CmbPDDpi','CmbPDBleed','BtnPDSwap','BtnPDCopy','ValPDPixels','ValPDMm','ValPDBleed','ValPDRatio','TxtPDScaleW','TxtPDScaleRes','TxtPDStatus',
    'BtnPRStart','ChkPRAutoCopy','ImgPRPreview','TxtPRDims','BtnPRCopyImg','BtnPRCopyDims','BtnPRSavePng','TxtPRStatus',
    'TxtSEOTitle','LblSEOTitleCount','BarSEOTitle','TxtSEODesc','LblSEODescCount','BarSEODesc','TxtSEOSlugOut','PrevSEOTitle','PrevSEODesc','BtnSEOCopySlug','BtnSEOCopyMeta','TxtSEOCleaner','LblSEOTextStats','BtnSEOCleanSpaces','BtnSEOUpper','BtnSEOLower','BtnSEOTitleCase','BtnSEOCopyPlain','CmbSEOPassLen','ChkSEOPassSym','TxtSEOPassOut','BtnSEOGenPass','TxtSEOStatus',
    'ZoneB64Drop','BtnB64Browse','TxtB64Info','ValB64Sha','ValB64Md5','TxtB64Output','BtnB64CopyUri','BtnB64CopyHtml','BtnB64CopyCss','BtnB64CopySha','BtnB64CopyMd5','TxtB64Status'
)
$ui = @{}
foreach ($n in $ctrlNames) {
    $c = $window.FindName($n)
    if ($null -eq $c) { throw "Missing XAML control: $n" }
    $ui[$n] = $c
}

# Lazy loader for QuickTools modules (0 ms startup cost until clicked!)
$script:LoadedTools = @{}
function Ensure-ToolLoaded([string]$ToolName) {
    if ($script:LoadedTools[$ToolName]) { return }
    $toolFile = Join-Path (Join-Path $PSScriptRoot "tools") "$ToolName.psm1"
    if (Test-Path $toolFile) {
        Import-Module $toolFile -Global -Force -DisableNameChecking
        $script:LoadedTools[$ToolName] = $true
    }
}

function Get-FolderBytes([string[]]$Paths) {
    [long]$sum = 0
    foreach ($p in $Paths) {
        if ($p -and (Test-Path $p)) { $sum += [NillyNative]::GetDirSize($p) }
    }
    return $sum
}

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N0} KB" -f ($Bytes / 1KB)) }
    return "0 MB"
}

function Get-UptimeText {
    $ts = [TimeSpan]::FromMilliseconds([NillyNative]::GetTickCount64())
    if ($ts.Days -gt 0) { return "Uptime: $($ts.Days)η $($ts.Hours)ω $($ts.Minutes)λ" }
    return "Uptime: $($ts.Hours)ω $($ts.Minutes)λ"
}

function Get-BrowserCachePaths {
    $list = @()
    foreach ($r in @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data",
        "$env:LOCALAPPDATA\Google\Chrome\User Data",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    )) {
        if (Test-Path $r) {
            Get-ChildItem $r -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(Default|Profile )' } | ForEach-Object {
                foreach ($sub in @('Cache','Code Cache','GPUCache')) {
                    $fp = Join-Path $_.FullName $sub
                    if (Test-Path $fp) { $list += $fp }
                }
            }
        }
    }
    $ffRoot = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffRoot) {
        Get-ChildItem $ffRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $c2 = Join-Path $_.FullName "cache2"
            if (Test-Path $c2) { $list += $c2 }
        }
    }
    return $list
}

function Get-SpotifyCachePaths {
    return @(
        "$env:LOCALAPPDATA\Spotify\Browser\Cache",
        "$env:LOCALAPPDATA\Spotify\Browser\Code Cache",
        "$env:LOCALAPPDATA\Spotify\Default\Cache",
        "$env:LOCALAPPDATA\Spotify\Default\Code Cache",
        "$env:LOCALAPPDATA\Spotify\Data",
        "$env:LOCALAPPDATA\Spotify\Storage"
    )
}

function Get-DevCachePaths {
    return @(
        "$env:LOCALAPPDATA\npm-cache",
        "$env:LOCALAPPDATA\pip\cache",
        "$env:LOCALAPPDATA\CrashDumps",
        "$env:LOCALAPPDATA\antigravity-updater"
    )
}

$script:CpuName = ((Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction SilentlyContinue).ProcessorNameString) -replace '\s+', ' '
if ($script:CpuName) { $script:CpuName = $script:CpuName.Trim() } else { $script:CpuName = "Windows PC" }
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$buildNum = 0; [void][int]::TryParse("$($cv.CurrentBuildNumber)", [ref]$buildNum)
$osVer = if ($buildNum -ge 22000) { "Windows 11" } else { "Windows 10" }
$osEd  = if ($cv.EditionID) { " $($cv.EditionID)" } else { "" }
$script:OsLabel = "$osVer$osEd"

$script:ODApps = @{
    Dropbox = @{ Procs = @('Dropbox','DropboxUpdate'); Exe = 'C:\Program Files (x86)\Dropbox\Client\Dropbox.exe'; Args = '' }
    Razer   = @{ Procs = @('RazerAppEngine'); Exe = 'C:\Program Files\Razer\RazerAppEngine\RazerAppEngine.exe'; Args = '--url-params=apps=synapse --launch-force-hidden=synapse' }
    LogiOpt = @{ Procs = @('logioptionsplus','logioptionsplus_agent','logioptionsplus_appbroker','LogiPluginService','LogiPluginServiceExt','logi_crashpad_handler'); Exe = 'C:\Program Files\LogiOptionsPlus\logioptionsplus_agent.exe'; Args = '' }
    GHUB    = @{ Procs = @('lghub_system_tray','lghub_agent','lghub','lghub_gl'); Exe = 'C:\Program Files\LGHUB\system_tray\lghub_system_tray.exe'; Args = '--minimized' }
}

function Get-AppRamMB([string[]]$ProcNames) {
    $procs = Get-Process -Name $ProcNames -ErrorAction SilentlyContinue
    if (-not $procs) { return @{ Running=$false; Count=0; MB=0.0 } }
    return @{ Running=$true; Count=$procs.Count; MB=[math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1) }
}

function Refresh-OnDemandPage {
    $d = Get-AppRamMB $script:ODApps.Dropbox.Procs
    $r = Get-AppRamMB $script:ODApps.Razer.Procs
    $l = Get-AppRamMB $script:ODApps.LogiOpt.Procs
    $g = Get-AppRamMB $script:ODApps.GHUB.Procs
    $tot = [math]::Round($d.MB + $r.MB + $l.MB + $g.MB, 1)
    $ui.TxtODTotal.Text = "Συνολική RAM αυτών των 4 εφαρμογών τώρα: $tot MB"

    if ($d.Running) { $ui.TxtDropboxInfo.Text = "ΑΝΟΙΧΤΟ — $($d.Count) διεργασίες, $($d.MB) MB RAM"; $ui.BtnToggleDropbox.Content = "Κλείσιμο (−$($d.MB) MB)"; $ui.BtnToggleDropbox.IsEnabled = $true }
    elseif (-not (Test-Path $script:ODApps.Dropbox.Exe)) { $ui.TxtDropboxInfo.Text = "Δεν είναι εγκατεστημένο σε αυτό το PC"; $ui.BtnToggleDropbox.Content = "Μη διαθέσιμο"; $ui.BtnToggleDropbox.IsEnabled = $false }
    else { $ui.TxtDropboxInfo.Text = "ΚΛΕΙΣΤΟ — 0 MB RAM"; $ui.BtnToggleDropbox.Content = "Άνοιγμα Dropbox"; $ui.BtnToggleDropbox.IsEnabled = $true }

    if ($r.Running) { $ui.TxtRazerInfo.Text = "ΑΝΟΙΧΤΟ — $($r.Count) διεργασίες, $($r.MB) MB RAM"; $ui.BtnToggleRazer.Content = "Κλείσιμο (−$($r.MB) MB)"; $ui.BtnToggleRazer.IsEnabled = $true }
    elseif (-not (Test-Path $script:ODApps.Razer.Exe)) { $ui.TxtRazerInfo.Text = "Δεν είναι εγκατεστημένο σε αυτό το PC"; $ui.BtnToggleRazer.Content = "Μη διαθέσιμο"; $ui.BtnToggleRazer.IsEnabled = $false }
    else { $ui.TxtRazerInfo.Text = "ΚΛΕΙΣΤΟ — 0 MB RAM (το DeathAdder κρατάει τα DPI του)"; $ui.BtnToggleRazer.Content = "Άνοιγμα Synapse"; $ui.BtnToggleRazer.IsEnabled = $true }

    if ($l.Running) { $ui.TxtLogiOptInfo.Text = "ΑΝΟΙΧΤΟ — $($l.Count) διεργασίες, $($l.MB) MB RAM"; $ui.BtnToggleLogiOpt.Content = "Κλείσιμο (−$($l.MB) MB)"; $ui.BtnToggleLogiOpt.IsEnabled = $true }
    elseif (-not (Test-Path $script:ODApps.LogiOpt.Exe)) { $ui.TxtLogiOptInfo.Text = "Δεν είναι εγκατεστημένο σε αυτό το PC"; $ui.BtnToggleLogiOpt.Content = "Μη διαθέσιμο"; $ui.BtnToggleLogiOpt.IsEnabled = $false }
    else { $ui.TxtLogiOptInfo.Text = "ΚΛΕΙΣΤΟ — 0 MB RAM"; $ui.BtnToggleLogiOpt.Content = "Άνοιγμα Options+"; $ui.BtnToggleLogiOpt.IsEnabled = $true }

    if ($g.Running) { $ui.TxtGHUBInfo.Text = "ΑΝΟΙΧΤΟ — $($g.Count) διεργασίες, $($g.MB) MB RAM"; $ui.BtnToggleGHUB.Content = "Κλείσιμο (−$($g.MB) MB)"; $ui.BtnToggleGHUB.IsEnabled = $true }
    elseif (-not (Test-Path $script:ODApps.GHUB.Exe)) { $ui.TxtGHUBInfo.Text = "Δεν είναι εγκατεστημένο σε αυτό το PC"; $ui.BtnToggleGHUB.Content = "Μη διαθέσιμο"; $ui.BtnToggleGHUB.IsEnabled = $false }
    else { $ui.TxtGHUBInfo.Text = "ΚΛΕΙΣΤΟ — 0 MB RAM"; $ui.BtnToggleGHUB.Content = "Άνοιγμα G HUB"; $ui.BtnToggleGHUB.IsEnabled = $true }
}

function Toggle-OnDemandApp([string]$Key, [string]$Friendly) {
    $cfg = $script:ODApps[$Key]
    $st = Get-AppRamMB $cfg.Procs
    if ($st.Running) {
        foreach ($p in $cfg.Procs) { Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 450
        $ui.TxtODStatus.Text = "Έκλεισε το $Friendly (ελευθερώθηκαν ~$($st.MB) MB RAM)."
    } else {
        if (Test-Path $cfg.Exe) {
            if ($cfg.Args) { Start-Process -FilePath $cfg.Exe -ArgumentList $cfg.Args } else { Start-Process -FilePath $cfg.Exe }
            Start-Sleep -Milliseconds 700
            $ui.TxtODStatus.Text = "Ξεκίνησε το $Friendly."
        } else { $ui.TxtODStatus.Text = "Δεν βρέθηκε το $Friendly." }
    }
    Refresh-OnDemandPage
}

$script:CleanSizes = @{ Temp=0; Browsers=0; ChromeAI=0; Dev=0; Spotify=0; Recycle=0 }

function Update-CleanTotal {
    [long]$total = 0
    if ($ui.ChkTemp.IsChecked)     { $total += $script:CleanSizes.Temp }
    if ($ui.ChkBrowsers.IsChecked) { $total += $script:CleanSizes.Browsers }
    if ($ui.ChkChromeAI.IsChecked) { $total += $script:CleanSizes.ChromeAI }
    if ($ui.ChkDev.IsChecked)      { $total += $script:CleanSizes.Dev }
    if ($ui.ChkSpotify.IsChecked)  { $total += $script:CleanSizes.Spotify }
    if ($ui.ChkRecycle.IsChecked)  { $total += $script:CleanSizes.Recycle }
    $ui.LblCleanTotal.Text = Format-Size $total
}

function Scan-CleanupTargets {
    $ui.TxtCleanLog.Text = "Γρήγορη σάρωση caches..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $script:CleanSizes.Temp     = Get-FolderBytes @($env:TEMP)
    $script:CleanSizes.Browsers = Get-FolderBytes (Get-BrowserCachePaths)
    $script:CleanSizes.ChromeAI = Get-FolderBytes @("$env:LOCALAPPDATA\Google\Chrome\User Data\OptGuideOnDeviceModel")
    $script:CleanSizes.Dev      = Get-FolderBytes (Get-DevCachePaths)
    $script:CleanSizes.Spotify  = Get-FolderBytes (Get-SpotifyCachePaths)
    $script:CleanSizes.Recycle  = [NillyNative]::GetRecycleBinBytes()

    $ui.LblTemp.Text     = Format-Size $script:CleanSizes.Temp
    $ui.LblBrowsers.Text = Format-Size $script:CleanSizes.Browsers
    $ui.LblChromeAI.Text = Format-Size $script:CleanSizes.ChromeAI
    $ui.LblDev.Text      = Format-Size $script:CleanSizes.Dev
    $ui.LblSpotify.Text  = Format-Size $script:CleanSizes.Spotify
    $ui.LblRecycle.Text  = Format-Size $script:CleanSizes.Recycle
    Update-CleanTotal
    $ui.TxtCleanLog.Text = "Η σάρωση ολοκληρώθηκε. Πάτα 'Καθαρισμός Επιλεγμένων' για εκτέλεση."
}

function Refresh-HomeStats {
    $mem = [NillyNative]::GetMemory()
    $totalGB = [math]::Round($mem.ullTotalPhys / 1GB, 1)
    $availGB = [math]::Round($mem.ullAvailPhys / 1GB, 1)
    $usedGB  = [math]::Round($totalGB - $availGB, 1)
    $pct     = [int]$mem.dwMemoryLoad

    $ui.TxtSysSpec.Text   = "$($script:CpuName)  •  $totalGB GB RAM  •  $($script:OsLabel)"
    $ui.TxtUptime.Text    = Get-UptimeText
    $ui.TxtRamPct.Text    = "$pct%"
    $ui.TxtRamDetail.Text = "$usedGB / $totalGB GB"
    $ui.BarRam.Value      = $pct

    $tempBytes = Get-FolderBytes @($env:TEMP)
    $ui.TxtTempSize.Text = Format-Size $tempBytes
    $ui.BarTemp.Value    = [math]::Min(2048, [math]::Round($tempBytes / 1MB, 0))

    $odRam = [math]::Round(
        (Get-AppRamMB $script:ODApps.Dropbox.Procs).MB +
        (Get-AppRamMB $script:ODApps.Razer.Procs).MB +
        (Get-AppRamMB $script:ODApps.LogiOpt.Procs).MB +
        (Get-AppRamMB $script:ODApps.GHUB.Procs).MB, 0
    )
    $ui.TxtBgHeavy.Text = "On-Demand: $odRam MB"

    $driveRows = @()
    foreach ($drv in ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })) {
        $totGB  = [math]::Round($drv.TotalSize / 1GB, 1)
        $freeGB = [math]::Round($drv.AvailableFreeSpace / 1GB, 1)
        $usedD  = [math]::Round($totGB - $freeGB, 1)
        $usedP  = if ($totGB -gt 0) { [math]::Round(($usedD / $totGB) * 100, 0) } else { 0 }
        $brush  = if ($usedP -ge 85) { "#F59E0B" } elseif ($drv.Name -eq "C:\") { "#38BDF8" } else { "#22C55E" }
        $vol    = if ($drv.VolumeLabel) { " ($($drv.VolumeLabel))" } else { "" }
        $driveRows += [PSCustomObject]@{
            Label       = "Δίσκος $($drv.Name.TrimEnd('\'))$vol  —  $usedD / $totGB GB ($usedP%)"
            FreeText    = "$freeGB GB ελεύθερα"
            UsedPct     = $usedP
            AccentBrush = $brush
        }
    }
    $ui.ListDrives.ItemsSource = $driveRows

    $appCount = (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }).Count
    $ui.TxtProcCount.Text = "$appCount ανοιχτές εφαρμογές — δες κατανάλωση RAM"
}

$script:ProtectedProcs = @(
    'System','Idle','Registry','smss','csrss','wininit','services','lsass','winlogon',
    'svchost','dwm','explorer','MsMpEng','MpDefenderCoreService','NisSrv','SecurityHealthService',
    'Memory Compression','Secure System','LsaIso','fontdrvhost','audiodg','spoolsv','powershell','pwsh',
    'Docker Desktop','com.docker.backend','com.docker.build','vmmemWSL','wslservice',
    'FanControl','FanControl.Service','KeyboardChatterBlocker'
)
$script:AllProcRows = @()

function Apply-ProcFilter {
    $q = $ui.TxtProcFilter.Text.Trim()
    if ([string]::IsNullOrEmpty($q)) { $ui.ListProcs.ItemsSource = $script:AllProcRows }
    else { $ui.ListProcs.ItemsSource = @($script:AllProcRows | Where-Object { $_.Name -like "*$q*" }) }
}

function Refresh-Processes {
    $script:AllProcRows = @(Get-Process | Group-Object Name | ForEach-Object {
        $ram = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
        $isProtected = $script:ProtectedProcs -contains $_.Name
        [PSCustomObject]@{
            Name   = $_.Name
            Count  = $_.Count
            RAM_MB = $ram
            Type   = if ($isProtected) { "Προστατευμένη" } else { "Εφαρμογή" }
        }
    } | Sort-Object RAM_MB -Descending | Select-Object -First 35)
    Apply-ProcFilter
}

function Refresh-DefenderInfo {
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        $rt = if ($mp.RealTimeProtectionEnabled) { "Ενεργή" } else { "Απενεργοποιημένη!" }
        $ui.TxtDefenderInfo.Text = "Real-Time: $rt  |  Τελευταίο Quick Scan: $($mp.QuickScanEndTime)"
    } else { $ui.TxtDefenderInfo.Text = "Άνοιξε το Windows Security για έλεγχο." }
}

function Set-ActivePage([string]$Page) {
    if ($Page -ne 'ColorPicker' -and (Get-Command Stop-NillyColorSpy -ErrorAction SilentlyContinue)) {
        Stop-NillyColorSpy
    }
    $pages = @{
        Home          = $ui.PageHome
        MyHub         = $ui.PageMyHub
        OnDemand      = $ui.PageOnDemand
        Clean         = $ui.PageClean
        Procs         = $ui.PageProcs
        Tools         = $ui.PageTools
        ColorPicker   = $ui.PageColorPicker
        QrBarcode     = $ui.PageQrBarcode
        PrintDpi      = $ui.PagePrintDpi
        PixelRuler    = $ui.PagePixelRuler
        ImageResizer  = $ui.PageImageResizer
        BatchRenamer  = $ui.PageBatchRenamer
        SeoText       = $ui.PageSeoText
        Base64Hash    = $ui.PageBase64Hash
        FileLocksmith = $ui.PageFileLocksmith
        AlwaysOnTop   = $ui.PageAlwaysOnTop
        Hardware      = $ui.PageHardware
        ImgPdf        = $ui.PageImgPdf
        Notes         = $ui.PageNotes
    }
    foreach ($k in $pages.Keys) {
        $pages[$k].Visibility = if ($k -eq $Page) { 'Visible' } else { 'Collapsed' }
    }

    $conv = [Windows.Media.BrushConverter]::new()
    $navMap = @{
        Home          = $ui.BtnNavHome
        MyHub         = $ui.BtnNavMyHub
        OnDemand      = $ui.BtnNavOnDemand
        Clean         = $ui.BtnNavClean
        Procs         = $ui.BtnNavProcs
        Tools         = $ui.BtnNavTools
        ColorPicker   = $ui.BtnNavColorPicker
        QrBarcode     = $ui.BtnNavQrBarcode
        PrintDpi      = $ui.BtnNavPrintDpi
        PixelRuler    = $ui.BtnNavPixelRuler
        ImageResizer  = $ui.BtnNavImageResizer
        BatchRenamer  = $ui.BtnNavBatchRenamer
        SeoText       = $ui.BtnNavSeoText
        Base64Hash    = $ui.BtnNavBase64Hash
        FileLocksmith = $ui.BtnNavFileLocksmith
        AlwaysOnTop   = $ui.BtnNavAlwaysOnTop
        Hardware      = $ui.BtnNavHardware
        ImgPdf        = $ui.BtnNavImgPdf
        Notes         = $ui.BtnNavNotes
    }
    foreach ($k in $navMap.Keys) {
        if ($k -eq $Page) {
            $navMap[$k].Background = $conv.ConvertFromString('#182436')
            $navMap[$k].Foreground = $conv.ConvertFromString('#38BDF8')
        } else {
            $navMap[$k].Background = [Windows.Media.Brushes]::Transparent
            $navMap[$k].Foreground = $conv.ConvertFromString('#94A3B8')
        }
    }
}

function Open-ColorPickerPage {
    try {
        Ensure-ToolLoaded 'ColorPicker'
        Initialize-ColorPickerTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'ColorPicker'
    } catch {
        $errLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ColorPicker load error: $($_.Exception.Message)"
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value $errLine -ErrorAction SilentlyContinue
        $ui.TxtBoostStatus.Text = "Σφάλμα φόρτωσης Color Picker: $($_.Exception.Message)"
    }
}

function Open-QrBarcodePage {
    try {
        Ensure-ToolLoaded 'QrBarcode'
        Initialize-QrBarcodeTool -MainWindow $window -UiMap $ui -RootDir $PSScriptRoot
        Set-ActivePage 'QrBarcode'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] QrBarcode error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
        $ui.TxtBoostStatus.Text = "Σφάλμα φόρτωσης QR & Barcode: $($_.Exception.Message)"
    }
}

function Open-ImageResizerPage {
    try {
        Ensure-ToolLoaded 'ImageResizer'
        Initialize-ImageResizerTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'ImageResizer'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ImageResizer error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-BatchRenamerPage {
    try {
        Ensure-ToolLoaded 'BatchRenamer'
        Initialize-BatchRenamerTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'BatchRenamer'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] BatchRenamer error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-FileLocksmithPage {
    try {
        Ensure-ToolLoaded 'FileLocksmith'
        Initialize-FileLocksmithTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'FileLocksmith'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] FileLocksmith error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-AlwaysOnTopPage {
    try {
        Ensure-ToolLoaded 'AlwaysOnTop'
        Initialize-AlwaysOnTopTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'AlwaysOnTop'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] AlwaysOnTop error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-MyHubPage {
    try {
        Ensure-ToolLoaded 'MyHub'
        Initialize-MyHubTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'MyHub'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] MyHub error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-HardwarePage {
    try {
        Ensure-ToolLoaded 'HardwareSpecs'
        Initialize-HardwareSpecsTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'Hardware'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Hardware error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-ImgPdfPage {
    try {
        Ensure-ToolLoaded 'ImagesToPdf'
        Initialize-ImagesToPdfTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'ImgPdf'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ImagesToPdf error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-NotesPage {
    try {
        Ensure-ToolLoaded 'QuickNotes'
        Initialize-QuickNotesTool -MainWindow $window -UiMap $ui -RootDir $PSScriptRoot
        Set-ActivePage 'Notes'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] QuickNotes error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-PrintDpiPage {
    try {
        Ensure-ToolLoaded 'PrintDpi'
        Initialize-PrintDpiTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'PrintDpi'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PrintDpi error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-PixelRulerPage {
    try {
        Ensure-ToolLoaded 'PixelRuler'
        Initialize-PixelRulerTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'PixelRuler'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] PixelRuler error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-SeoTextPage {
    try {
        Ensure-ToolLoaded 'SeoText'
        Initialize-SeoTextTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'SeoText'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SeoText error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Open-Base64HashPage {
    try {
        Ensure-ToolLoaded 'Base64Hash'
        Initialize-Base64HashTool -MainWindow $window -UiMap $ui
        Set-ActivePage 'Base64Hash'
    } catch {
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Base64Hash error: $($_.Exception.Message)" -ErrorAction SilentlyContinue
    }
}

function Restart-TaskbarExplorer {
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 600
    if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) { Start-Process "explorer.exe" }
}

# Wire Navigation
$ui.BtnNavHome.Add_Click({ Set-ActivePage 'Home'; Refresh-HomeStats })
$ui.BtnNavMyHub.Add_Click({ Open-MyHubPage })
$ui.BtnNavOnDemand.Add_Click({ Set-ActivePage 'OnDemand'; Refresh-OnDemandPage })
$ui.BtnNavClean.Add_Click({ Set-ActivePage 'Clean'; Scan-CleanupTargets })
$ui.BtnNavProcs.Add_Click({ Set-ActivePage 'Procs'; Refresh-Processes })
$ui.BtnNavTools.Add_Click({ Set-ActivePage 'Tools'; Refresh-DefenderInfo })
$ui.BtnNavColorPicker.Add_Click({ Open-ColorPickerPage })
$ui.BtnNavQrBarcode.Add_Click({ Open-QrBarcodePage })
$ui.BtnNavPrintDpi.Add_Click({ Open-PrintDpiPage })
$ui.BtnNavPixelRuler.Add_Click({ Open-PixelRulerPage })
$ui.BtnNavImageResizer.Add_Click({ Open-ImageResizerPage })
$ui.BtnNavBatchRenamer.Add_Click({ Open-BatchRenamerPage })
$ui.BtnNavSeoText.Add_Click({ Open-SeoTextPage })
$ui.BtnNavBase64Hash.Add_Click({ Open-Base64HashPage })
$ui.BtnNavFileLocksmith.Add_Click({ Open-FileLocksmithPage })
$ui.BtnNavAlwaysOnTop.Add_Click({ Open-AlwaysOnTopPage })
$ui.BtnNavHardware.Add_Click({ Open-HardwarePage })
$ui.BtnNavImgPdf.Add_Click({ Open-ImgPdfPage })
$ui.BtnNavNotes.Add_Click({ Open-NotesPage })

$ui.BtnSidebarSite.Add_Click({ Start-Process $AppWebsite })
$ui.BtnAboutSite.Add_Click({ Start-Process $AppWebsite })

$ui.BtnRefreshHome.Add_Click({ Refresh-HomeStats })
$ui.BtnHomeColorPicker.Add_Click({ Open-ColorPickerPage })
$ui.BtnHomeOnDemand.Add_Click({ Set-ActivePage 'OnDemand'; Refresh-OnDemandPage })
$ui.BtnQuickClean.Add_Click({ Set-ActivePage 'Clean'; Scan-CleanupTargets })
$ui.BtnQuickProcs.Add_Click({ Set-ActivePage 'Procs'; Refresh-Processes })
$ui.BtnQuickStartup.Add_Click({ Start-Process "ms-settings:startupapps" })
$ui.BtnQuickTaskbar.Add_Click({ Restart-TaskbarExplorer; $ui.TxtBoostStatus.Text = "Το Taskbar / Explorer επανεκκινήθηκε." })

# Boost
$ui.BtnBoost.Add_Click({
    $ui.BtnBoost.IsEnabled = $false
    $ui.TxtBoostStatus.Text = "Εκτέλεση Boost..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $beforeRam  = [NillyNative]::GetMemory().ullAvailPhys
    $beforeDisk = ([System.IO.DriveInfo]::new("C")).AvailableFreeSpace
    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ($_.Handle -and ($script:ProtectedProcs -notcontains $_.Name)) { [void][NillyNative]::EmptyWorkingSet($_.Handle) } } catch {}
    }
    Start-Sleep -Milliseconds 350
    $freedRamMB  = [math]::Max(0, [math]::Round(([NillyNative]::GetMemory().ullAvailPhys - $beforeRam) / 1MB, 0))
    $freedDiskMB = [math]::Max(0, [math]::Round((([System.IO.DriveInfo]::new("C")).AvailableFreeSpace - $beforeDisk) / 1MB, 1))
    Refresh-HomeStats
    $ui.TxtBoostStatus.Text = "Έτοιμο! Ελευθερώθηκαν ~$freedRamMB MB RAM και ~$freedDiskMB MB στον C:."
    $ui.BtnBoost.IsEnabled = $true
})

# On-Demand Toggles
$ui.BtnRefreshOD.Add_Click({ Refresh-OnDemandPage })
$ui.BtnToggleDropbox.Add_Click({ Toggle-OnDemandApp 'Dropbox' 'Dropbox' })
$ui.BtnToggleRazer.Add_Click({ Toggle-OnDemandApp 'Razer' 'Razer Synapse 4' })
$ui.BtnToggleLogiOpt.Add_Click({ Toggle-OnDemandApp 'LogiOpt' 'Logi Options+' })
$ui.BtnToggleGHUB.Add_Click({ Toggle-OnDemandApp 'GHUB' 'Logitech G HUB' })

$ui.BtnFocusMode.Add_Click({
    $beforeRam = [NillyNative]::GetMemory().ullAvailPhys
    foreach ($key in @('Dropbox','Razer','LogiOpt')) {
        foreach ($p in $script:ODApps[$key].Procs) { Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
    }
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ($_.Handle -and ($script:ProtectedProcs -notcontains $_.Name)) { [void][NillyNative]::EmptyWorkingSet($_.Handle) } } catch {}
    }
    Start-Sleep -Milliseconds 500
    $freedMB = [math]::Max(0, [math]::Round(([NillyNative]::GetMemory().ullAvailPhys - $beforeRam) / 1MB, 0))
    Refresh-OnDemandPage
    $ui.TxtODStatus.Text = "Focus / Game Mode ενεργό! Έκλεισαν Dropbox, Razer & Logi Options+ (+~$freedMB MB RAM ελεύθερα)."
})

$ui.BtnRestoreOD.Add_Click({
    foreach ($key in @('Dropbox','Razer','LogiOpt','GHUB')) {
        $cfg = $script:ODApps[$key]
        if (-not (Get-AppRamMB $cfg.Procs).Running -and (Test-Path $cfg.Exe)) {
            if ($cfg.Args) { Start-Process -FilePath $cfg.Exe -ArgumentList $cfg.Args } else { Start-Process -FilePath $cfg.Exe }
        }
    }
    Start-Sleep -Milliseconds 800
    Refresh-OnDemandPage
    $ui.TxtODStatus.Text = "Επαναφέρθηκαν όλες οι On-Demand εφαρμογές."
})

# Cleanup
foreach ($chk in @($ui.ChkTemp,$ui.ChkBrowsers,$ui.ChkChromeAI,$ui.ChkDev,$ui.ChkSpotify,$ui.ChkRecycle)) {
    $chk.Add_Checked({ Update-CleanTotal })
    $chk.Add_Unchecked({ Update-CleanTotal })
}
$ui.BtnScanClean.Add_Click({ Scan-CleanupTargets })
$ui.BtnRunClean.Add_Click({
    $ui.BtnRunClean.IsEnabled = $false
    $ui.TxtCleanLog.Text = "Καθαρισμός σε εξέλιξη..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $beforeFree = ([System.IO.DriveInfo]::new("C")).AvailableFreeSpace
    $doneList = @()
    if ($ui.ChkTemp.IsChecked)     { Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }; $doneList += "Temp" }
    if ($ui.ChkBrowsers.IsChecked) { foreach ($bp in (Get-BrowserCachePaths)) { Remove-Item "$bp\*" -Recurse -Force -ErrorAction SilentlyContinue }; $doneList += "Browser Caches" }
    if ($ui.ChkChromeAI.IsChecked) { $cai = "$env:LOCALAPPDATA\Google\Chrome\User Data\OptGuideOnDeviceModel"; if (Test-Path $cai) { Remove-Item $cai -Recurse -Force -ErrorAction SilentlyContinue }; $doneList += "Chrome AI Cache" }
    if ($ui.ChkDev.IsChecked)      { foreach ($dp in (Get-DevCachePaths)) { if (Test-Path $dp) { Remove-Item "$dp\*" -Recurse -Force -ErrorAction SilentlyContinue } }; $doneList += "Dev Caches" }
    if ($ui.ChkSpotify.IsChecked)  { foreach ($sp in (Get-SpotifyCachePaths)) { if (Test-Path $sp) { Remove-Item "$sp\*" -Recurse -Force -ErrorAction SilentlyContinue } }; $doneList += "Spotify Cache" }
    if ($ui.ChkRecycle.IsChecked)  { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; $doneList += "Κάδος" }
    $freedMB = [math]::Max(0, [math]::Round((([System.IO.DriveInfo]::new("C")).AvailableFreeSpace - $beforeFree) / 1MB, 1))
    Scan-CleanupTargets
    Refresh-HomeStats
    $ui.TxtCleanLog.Text = "Έτοιμο! Καθαρίστηκαν: $($doneList -join ', '). Ελευθερώθηκαν ~$freedMB MB στον C:."
    $ui.BtnRunClean.IsEnabled = $true
})
$ui.BtnWinUpdateClean.Add_Click({
    $cmd = 'Write-Host "Nilly PC Manager & Tools v3.2 - created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/" -ForegroundColor Cyan; DISM.exe /Online /Cleanup-Image /StartComponentCleanup; Stop-Service wuauserv -Force; Remove-Item C:\Windows\SoftwareDistribution\Download\* -Recurse -Force -ErrorAction SilentlyContinue; Start-Service wuauserv; Write-Host "DONE!" -ForegroundColor Green'
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command',$cmd
})

# Processes
$ui.BtnRefreshProcs.Add_Click({ Refresh-Processes })
$ui.TxtProcFilter.Add_TextChanged({ Apply-ProcFilter })
$ui.BtnKillProc.Add_Click({
    $sel = $ui.ListProcs.SelectedItem
    if (-not $sel) { $ui.TxtProcStatus.Text = "Επίλεξε πρώτα μια εφαρμογή από τη λίστα."; return }
    if ($script:ProtectedProcs -contains $sel.Name) { $ui.TxtProcStatus.Text = "Η διεργασία '$($sel.Name)' είναι προστατευμένη."; return }
    Stop-Process -Name $sel.Name -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    Refresh-Processes
    Refresh-HomeStats
    $ui.TxtProcStatus.Text = "Τερματίστηκε η εφαρμογή: $($sel.Name)."
})

# Tools & Shortcuts
$ui.BtnDefenderScan.Add_Click({ $ui.TxtDefenderInfo.Text = "Εκκίνηση Windows Defender Quick Scan..."; Start-Process "windowsdefender://threat"; Start-Job -ScriptBlock { Start-MpScan -ScanType QuickScan } | Out-Null })
$ui.BtnNetCheck.Add_Click({
    $ui.TxtNetInfo.Text = "Έλεγχος σύνδεσης & καθαρισμός DNS..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Render)
    ipconfig /flushdns | Out-Null
    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 1 -ErrorAction SilentlyContinue
    if ($ping) { $ui.TxtNetInfo.Text = "Σύνδεση OK! Latency προς 1.1.1.1: $($ping.ResponseTime) ms  |  DNS Cache καθαρίστηκε." }
    else { $ui.TxtNetInfo.Text = "Δεν βρέθηκε απάντηση από 1.1.1.1. DNS Cache καθαρίστηκε." }
})
$ui.BtnWinUpdate.Add_Click({ Start-Process "ms-settings:windowsupdate" })
$ui.BtnWinSecurity.Add_Click({ Start-Process "windowsdefender:" })
$ui.BtnInstalledApps.Add_Click({ Start-Process "ms-settings:appsfeatures" })
$ui.BtnStorageSense.Add_Click({ Start-Process "ms-settings:storagesense" })
$ui.BtnOpenScripts.Add_Click({ Start-Process "explorer.exe" -ArgumentList "`"$PSScriptRoot`"" })
$ui.BtnTaskbarRepair2.Add_Click({ Restart-TaskbarExplorer })

# Initial Load
Set-ActivePage 'Home'
Refresh-HomeStats

if ($TestOnly) {
    Refresh-OnDemandPage
    Scan-CleanupTargets
    Refresh-Processes
    Refresh-DefenderInfo
    Open-ColorPickerPage
    $ui.TxtCPInputHex.Text = "#FF6432"
    $ui.BtnCPApplyHex.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $ui.BtnCopyCmyk.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    Open-QrBarcodePage
    $ui.CmbQRMode.SelectedIndex = 1
    $ui.CmbBCFormat.SelectedIndex = 2 # ITF-14
    $ui.TxtQRMain.Text = "1520123456789"
    $ui.BtnQRGenerate.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $bcMeta = $ui.TxtQRMeta.Text
    $ui.CmbQRMode.SelectedIndex = 0
    $ui.TxtQRMain.Text = "https://nillygraphics.com/"
    $ui.BtnQRGenerate.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    $qrMeta = $ui.TxtQRMeta.Text
    Open-ImageResizerPage
    Open-BatchRenamerPage
    $slugTest = Convert-GreekToSeoSlug -Text "Φωτογραφία Προϊόντος 01"
    Open-FileLocksmithPage
    Open-AlwaysOnTopPage
    Open-MyHubPage
    Open-HardwarePage
    Open-ImgPdfPage
    Open-NotesPage
    Open-PrintDpiPage
    $pdPx = $ui.ValPDPixels.Text
    $pdBleed = $ui.ValPDBleed.Text
    Open-PixelRulerPage
    $prCtorOk = $false
    try {
        $rf = New-Object NillyRulerCaptureForm
        $prCtorOk = $true
        $rf.Dispose()
    } catch { throw "PixelRuler ctor failed: $($_.Exception.Message)" }
    Open-SeoTextPage
    $seoSlug = Convert-TextToSeoSlugLocal -Text "Σχεδιασμός Λογοτύπου & Συσκευασίας 2026"
    $seoPwLen = (New-CryptoPassword -Length 24 -IncludeSymbols $true).Length
    Open-Base64HashPage
    Process-Base64AndHashFile -FilePath (Join-Path $PSScriptRoot "PCManagerLite.ico")
    $b64Ok = $ui.ValB64Sha.Text.Length -eq 64 -and $ui.ValB64Md5.Text.Length -eq 32 -and $ui.TxtB64Output.Text.StartsWith("data:image/x-icon;base64,")
    $hwRows = @($ui.ListHWSpecs.ItemsSource).Count
    Write-Output "SELF-TEST PASSED! Version=$AppVersion | Modules=$($script:LoadedTools.Count) | RAM=$($ui.TxtRamPct.Text) | Drives=$($ui.ListDrives.ItemsSource.Count) | ColorPicker=$($ui.ValCPHex.Text)/$($ui.ValCPCmyk.Text) | QR=[$qrMeta] | BC=[$bcMeta] | Slug=[$slugTest] | HWRows=$hwRows | PrintDPI=[$pdPx | $pdBleed] | RulerCtor=$prCtorOk | SeoSlug=[$seoSlug] PwLen=$seoPwLen | B64Hash=$b64Ok"
    exit 0
}

# Proper WPF Application loop (allows Hide/Show for Screen Loupe WITHOUT closing app!)
$wpfApp = [System.Windows.Application]::Current
if (-not $wpfApp) { $wpfApp = New-Object System.Windows.Application }
$wpfApp.ShutdownMode = [System.Windows.ShutdownMode]::OnMainWindowClose

# Global crash shield: never silently disappear on an unexpected UI exception
$wpfApp.Add_DispatcherUnhandledException({
    param($sender, $e)
    try {
        $errLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] UI Exception: $($e.Exception.Message)"
        Add-Content -Path (Join-Path $PSScriptRoot "error.log") -Value $errLine -ErrorAction SilentlyContinue
        if ($ui.TxtCPStatus) { $ui.TxtCPStatus.Text = "Σφάλμα: $($e.Exception.Message)" }
        if ($ui.TxtBoostStatus) { $ui.TxtBoostStatus.Text = "Σφάλμα: $($e.Exception.Message)" }
    } catch {}
    $e.Handled = $true
})

[void]$wpfApp.Run($window)
