@echo off
title Uninstall Shortcuts - Nilly PC Manager & Tools v4.0
echo =====================================================================
echo   Nilly PC Manager ^& Tools v4.0 — Clean Shortcut Removal
echo   created by Nilly graphics (Sotiris Christos)
echo   https://nillygraphics.com/
echo =====================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-Process -Name NillyChatterBlocker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue;" ^
  "$links = @(" ^
  "  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'PC Manager & Tools.lnk')," ^
  "  (Join-Path ([Environment]::GetFolderPath('Programs')) 'Nilly PC Manager & Tools.lnk')," ^
  "  (Join-Path ([Environment]::GetFolderPath('Startup')) 'NillyChatterBlocker.lnk')" ^
  ");" ^
  "foreach ($l in $links) { if (Test-Path $l) { Remove-Item $l -Force -ErrorAction SilentlyContinue; Write-Host ('[REMOVED] ' + $l) -ForegroundColor Yellow } }" ^
  "Write-Host '[DONE] All shortcuts & Chatter Blocker stopped cleanly. You can now delete this folder if desired.' -ForegroundColor Green"

echo.
pause
