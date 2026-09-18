@echo off
setlocal
title TBS One-click Test
set "GODOT=D:\Shana Program\Godot\Godot_v4.7.1-stable_win64.exe"

echo ================================================
echo   TBS_Game_Godot One-click Test Run
echo   Launch main scene: scenes/main.tscn
echo ================================================
echo.

if not exist "%GODOT%" (
    echo [ERROR] Godot engine not found: %GODOT%
    echo Install Godot 4.7.1, or edit the GODOT path on line 4.
    echo.
    pause
    exit /b 1
)

echo Engine : %GODOT%
echo Project: %~dp0.
echo Running game... close the game window to end this script.
echo.
"%GODOT%" --path "%~dp0." res://scenes/main.tscn

echo.
echo Test finished. Press any key...
pause >nul
endlocal