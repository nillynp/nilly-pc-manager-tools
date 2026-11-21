' Nilly PC Manager & Tools v4.0 — Portable Silent Launcher (0 MB background RAM)
' created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
extraArg = ""
If WScript.Arguments.Count > 0 Then
    extraArg = " -StartPage """ & WScript.Arguments(0) & """"
End If
WshShell.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\PCManagerLite.ps1""" & extraArg, 0, False
