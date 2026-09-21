@echo off
rem OpenCode office kit - double-click this file to remove the kit.
rem
rem It asks which packages to remove and confirms before touching anything.
rem Documents are never touched, opencode.json is backed up first, and settings
rem added by hand are left alone. Pressing Enter at the confirmation cancels:
rem removal only happens if you answer "y".
rem
rem For unattended removal use scripts\uninstall.ps1 directly.

rem UTF-8 console, so Russian text is readable.
chcp 65001 >nul 2>&1
title OpenCode kit - remove
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\interactive.ps1" -Mode uninstall

rem The script pauses on its own when it finishes or fails. This only catches
rem the case where PowerShell could not start at all, so the window does not
rem vanish before the error can be read.
if errorlevel 9009 (
  echo.
  echo PowerShell could not be started. Ask your administrator to run
  echo scripts\uninstall.ps1 from a PowerShell window instead.
  pause
)
