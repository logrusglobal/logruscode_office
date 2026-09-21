# Установка браузерного агента @browser (пакет 2)
# ============================================================================
# Что делает скрипт (НИЧЕГО не перезаписывает, только добавляет):
#   1. Добавляет MCP-сервер chrome-devtools в существующий opencode.json
#      (файл сохраняется в бэкап перед изменением).
#   2. Добавляет глобальный запрет браузерных инструментов для всех агентов,
#      кроме @browser.
#   3. Копирует субагента agents\browser.md (наследует модель основного агента).
#   4. Добавляет правила делегирования веб-задач в AGENTS.md.
#   5. Копирует start-browser.cmd и создаёт ярлык на рабочем столе.
#
# Запуск (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_browser_agent.ps1
#
# Параметры:
#   -TargetDir    папка конфигурации OpenCode (по умолчанию %USERPROFILE%\.config\opencode)
#   -NoShortcut   не создавать ярлык на рабочем столе
# ============================================================================
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".config\opencode"),
    [switch]$NoShortcut
)

$ErrorActionPreference = "Stop"
$KitDir = Join-Path $PSScriptRoot "config"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Браузерный агент @browser - установка" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "ВНИМАНИЕ: Node.js не найден. MCP-сервер chrome-devtools запускается через npx." -ForegroundColor Yellow
    Write-Host "Установите Node.js LTS с https://nodejs.org и повторите установку." -ForegroundColor Yellow
}

# ---------- 1. Папки ----------
Write-Host "`n[1/4] Подготовка папок..." -ForegroundColor Yellow
$agentsDir = Join-Path $TargetDir "agents"
New-Item -ItemType Directory -Force -Path $TargetDir, $agentsDir | Out-Null
Write-Host "Конфиг: $TargetDir"

# ---------- 2. Merge MCP chrome-devtools + permission в opencode.json ----------
Write-Host "`n[2/4] Добавляем MCP-сервер chrome-devtools в opencode.json..." -ForegroundColor Yellow
$configPath = Join-Path $TargetDir "opencode.json"
if (-not (Test-Path $configPath)) {
    throw "Файл $configPath не найден. Сначала установите пакет 1 (OpenCode + Plexus) и запустите OpenCode хотя бы один раз."
}
$backup = "$configPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $configPath $backup
Write-Host "Создан бэкап конфига: $backup"

$cfg = Get-Content $configPath -Raw | ConvertFrom-Json
$frag = Get-Content (Join-Path $KitDir "mcp_chrome-devtools.json") -Raw | ConvertFrom-Json

$ht = @{}
$cfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }

$mcp = @{}
if ($ht.ContainsKey("mcp") -and $ht["mcp"] -ne $null) { $ht["mcp"].PSObject.Properties | ForEach-Object { $mcp[$_.Name] = $_.Value } }
$frag.PSObject.Properties | ForEach-Object { $mcp[$_.Name] = $_.Value }
$ht["mcp"] = $mcp

$perm = @{}
if ($ht.ContainsKey("permission") -and $ht["permission"] -ne $null) { $ht["permission"].PSObject.Properties | ForEach-Object { $perm[$_.Name] = $_.Value } }
$perm["chrome-devtools_*"] = "deny"
$ht["permission"] = $perm

$json = $ht | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding $false))

$check = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $check.mcp."chrome-devtools" -or -not $check.permission."chrome-devtools_*") {
    throw "Слияние конфига не подтверждено. Восстановите файл из бэкапа и повторите."
}
Write-Host "MCP-сервер chrome-devtools и запрет chrome-devtools_* добавлены." -ForegroundColor Green

# ---------- 3. Файлы агента и правил ----------
Write-Host "`n[3/4] Копирование агента и правил..." -ForegroundColor Yellow
Copy-Item (Join-Path $KitDir "agents\browser.md") (Join-Path $agentsDir "browser.md") -Force

$agentsMd = Join-Path $TargetDir "AGENTS.md"
$rules = Get-Content (Join-Path $KitDir "AGENTS_browser.md") -Raw -Encoding UTF8
if (Test-Path $agentsMd) {
    $existing = Get-Content $agentsMd -Raw -Encoding UTF8
    if ($existing -notlike "*# Правила работы с веб-сайтами*") {
        $combined = $existing.TrimEnd() + "`r`n`r`n" + $rules
        [System.IO.File]::WriteAllText($agentsMd, $combined, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "Правила делегирования веб-задач добавлены в AGENTS.md"
    } else {
        Write-Host "Правила веб-задач уже есть в AGENTS.md - пропускаю"
    }
} else {
    [System.IO.File]::WriteAllText($agentsMd, $rules, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "AGENTS.md создан"
}

Copy-Item (Join-Path $KitDir "start-browser.cmd") (Join-Path $TargetDir "start-browser.cmd") -Force
Write-Host "Скопировано: agents\browser.md, start-browser.cmd" -ForegroundColor Green

# ---------- 4. Ярлык на рабочем столе ----------
Write-Host "`n[4/4] Ярлык на рабочем столе..." -ForegroundColor Yellow
if (-not $NoShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $lnkPath = Join-Path $desktop "Браузер для OpenCode.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath = Join-Path $TargetDir "start-browser.cmd"
    $lnk.WorkingDirectory = $TargetDir
    $lnk.Description = "Запуск Chrome с отладочным портом для агента @browser"
    $lnk.Save()
    Write-Host "Ярлык создан: $lnkPath" -ForegroundColor Green
} else {
    Write-Host "Ярлык пропущен (-NoShortcut)."
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " УСТАНОВКА ЗАВЕРШЕНА" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Дальнейшие шаги:"
Write-Host " 1. Полностью закройте OpenCode Desktop и откройте заново."
Write-Host " 2. Перед веб-задачей запустите «Браузер для OpenCode» (ярлык на рабочем столе)."
Write-Host " 3. Просто попросите в чате, например: «Собери контакты с сайта https://... в таблицу»."
Write-Host "    Основной агент сам передаст задачу субагенту @browser."
