@echo off
REM Launch RoboGui_V3.ps1 PowerShell script (this window closes immediately; GUI host console hidden)
start "" powershell.exe -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0RoboGui_V3.ps1"