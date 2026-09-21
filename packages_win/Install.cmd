@echo off
rem OpenCode office kit - double-click this file to install.
rem
rem It asks for the language, the employee's Plexus key and which packages to
rem install, then does everything else on its own. No PowerShell knowledge and
rem no administrator rights are needed: everything is installed for the current
rem user only.
rem
rem For unattended installs use scripts\install.ps1 directly - it takes the same
rem work as parameters (-PlexusKey, -Lang, -Packages, ...).

rem UTF-8 console, so Russian text is readable.
chcp 65001 >nul 2>&1
title OpenCode kit - install
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\interactive.ps1" -Mode install

rem The script pauses on its own when it finishes or fails. This only catches
rem the case where PowerShell could not start at all, so the window does not
rem vanish before the error can be read.
if errorlevel 9009 (
  echo.
  echo PowerShell could not be started. Ask your administrator to run
  echo scripts\install.ps1 from a PowerShell window instead.
  pause
)
