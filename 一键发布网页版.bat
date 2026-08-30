@echo off
setlocal
title TBS Web Publish
echo ================================================
echo   TBS_Game_Godot Web Publish (GitHub Pages)
echo   Headless export and push to gh-pages
echo ================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\deploy_web.ps1"
echo.
echo Publish process finished. Press any key to close...
pause >nul
endlocal
