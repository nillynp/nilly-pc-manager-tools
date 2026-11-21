' Nilly PC Manager & Tools v3.0 — Portable Silent Launcher (0 MB background RAM)
' created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\PCManagerLite.ps1""", 0, False
