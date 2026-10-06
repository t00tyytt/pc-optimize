@echo off
rem Win11 context-menu manager (interactive). Prefers PowerShell 7, falls back to built-in 5.1.
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0context-menu-manager.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0context-menu-manager.ps1" %*
)
