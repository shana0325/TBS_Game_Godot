@echo off
chcp 65001 >nul
title TBS 网页版发布
echo ================================================
echo   TBS_Game_Godot 网页版一键发布（GitHub Pages）
echo   步骤：无头导出 Web 构建 - 推送 gh-pages 分支
echo ================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\deploy_web.ps1"
echo.
echo 发布流程结束。按任意键关闭窗口...
pause >nul