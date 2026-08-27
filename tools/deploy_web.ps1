# 一键发布网页版到 GitHub Pages（gh-pages 分支）。
# 用法：powershell -File tools/deploy_web.ps1
# 流程：无头导出 Web 构建 -> 用独立 worktree 整体重建 gh-pages 分支并强推 -> 清理。
# 前置：Godot 4.7.1 Web 导出模板已安装、gh CLI 已登录、origin 指向 GitHub。
# 主分支工作区全程不受影响；后续每次想更新网页版，重跑本脚本即可。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe'
$out = Join-Path $root 'web_build'
$work = Join-Path $root '.deploy_gh_pages'

Write-Host '== 1/3 导出 Web 构建 ==' -ForegroundColor Cyan
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $godot --headless --path $root --export-release 'Web' (Join-Path $out 'index.html')
if ($LASTEXITCODE -ne 0) { throw "Godot 导出失败 (exit $LASTEXITCODE)" }

Write-Host '== 2/3 重建 gh-pages 分支并推送 ==' -ForegroundColor Cyan
git -C $root fetch origin 2>$null
git -C $root branch -f gh-pages main 2>$null
if (Test-Path $work) { git -C $root worktree remove $work --force }
git -C $root worktree add -f $work gh-pages
Get-ChildItem -LiteralPath $work -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
}
Copy-Item (Join-Path $out '*') $work -Recurse -Force
git -C $work add -A
git -C $work commit -m "deploy: web build $(Get-Date -Format 'yyyy-MM-dd HH:mm')" --allow-empty
git -C $work push -f origin gh-pages

Write-Host '== 3/3 清理 ==' -ForegroundColor Cyan
git -C $root worktree remove $work --force
Write-Host '发布完成。访问 https://shana0325.github.io/TBS_Game_Godot/' -ForegroundColor Green