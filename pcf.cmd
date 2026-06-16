@echo off
REM Convenience wrapper so Windows users can run:  pcf play pcf5
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pcf.ps1" %*
