@echo off
title Setup - Nilly PC Manager & Tools v4.1
echo =====================================================================
echo   Nilly PC Manager ^& Tools v4.1 — Portable Setup (0 MB background)
echo   created by Nilly graphics (Sotiris Christos)
echo   https://nillygraphics.com/
echo =====================================================================
echo.
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$dir = '%APP_DIR%';" ^
  "Get-ChildItem -Path $dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue;" ^
  "$sh = New-Object -ComObject WScript.Shell;" ^
  "$targets = @(" ^
  "  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'PC Manager & Tools.lnk')," ^
  "  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Nilly PC Manager & Tools.lnk')" ^
  ");" ^
  "foreach ($lnk in $targets) {" ^
  "  $sc = $sh.CreateShortcut($lnk);" ^
  "  $sc.TargetPath = 'C:\Windows\System32\wscript.exe';" ^
  "  $sc.Arguments = '\"' + (Join-Path $dir 'Launch_PCManagerLite.vbs') + '\"';" ^
  "  $sc.WorkingDirectory = $dir;" ^
  "  $sc.IconLocation = (Join-Path $dir 'PCManagerLite.ico') + ',0';" ^
  "  $sc.Description = 'Nilly PC Manager & Tools v4.1 - created by Nilly graphics (Sotiris Christos) | https://nillygraphics.com/';" ^
  "  $sc.Save();" ^
  "}" ^
  "Write-Host '[OK] Files unblocked (Windows MOTW cleared)!' -ForegroundColor Green;" ^
  "Write-Host '[OK] Desktop & Start Menu shortcuts created!' -ForegroundColor Green;" ^
  "Write-Host '[OK] Zero admin rights, zero services, 0 MB background RAM.' -ForegroundColor Cyan"

echo.
echo Eisai etoimos! Anoikse to 'PC Manager & Tools' apo tin Epifaneia Ergasias i to Start Menu.
pause
