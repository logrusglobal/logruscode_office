# Установка OfficeCLI (MCP-серверы Word и Excel) — пакет 3
# ============================================================================
# Что делает скрипт (НИЧЕГО не перезаписывает, только добавляет):
#   1. Устанавливает менеджер пакетов uv (если его нет).
#   2. Добавляет MCP-серверы office-word и office-excel в существующий
#      opencode.json (файл сохраняется в бэкап перед изменением).
#   3. Проверяет, что оба сервера запускаются (HANDSHAKE OK).
#
# Запуск (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_officecli.ps1
#
# Параметры:
#   -TargetDir    папка конфигурации OpenCode (по умолчанию %USERPROFILE%\.config\opencode)
# ============================================================================
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".config\opencode")
)

$ErrorActionPreference = "Stop"
$uvDir = Join-Path $env:USERPROFILE ".local\bin"
$configPath = Join-Path $TargetDir "opencode.json"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " OfficeCLI (Word/Excel MCP) - установка" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# ---------- 1. uv ----------
Write-Host "`n[1/3] Проверка uv (менеджер пакетов)..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $uvDir "uv.exe"))) {
    Write-Host "uv не найден. Устанавливаю (около минуты)..."
    powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    if (-not (Test-Path (Join-Path $uvDir "uv.exe"))) { throw "Не удалось установить uv" }
}
Write-Host "uv: OK ($uvDir)" -ForegroundColor Green

# ---------- 2. Merge MCP в opencode.json ----------
Write-Host "`n[2/3] Добавляем MCP-серверы office-word и office-excel в opencode.json..." -ForegroundColor Yellow
if (-not (Test-Path $configPath)) {
    throw "Файл $configPath не найден. Сначала установите пакет 1 (OpenCode + Plexus) и запустите OpenCode хотя бы один раз."
}
$backup = "$configPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $configPath $backup
Write-Host "Создан бэкап конфига: $backup"

$cfg = Get-Content $configPath -Raw | ConvertFrom-Json
$frag = Get-Content (Join-Path $PSScriptRoot "mcp_config.json") -Raw | ConvertFrom-Json

$ht = @{}
$cfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }

$mcp = @{}
if ($ht.ContainsKey("mcp") -and $ht["mcp"] -ne $null) { $ht["mcp"].PSObject.Properties | ForEach-Object { $mcp[$_.Name] = $_.Value } }
$frag.PSObject.Properties | ForEach-Object { $mcp[$_.Name] = $_.Value }
$ht["mcp"] = $mcp

$json = $ht | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding $false))

$check = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $check.mcp."office-word" -or -not $check.mcp."office-excel") {
    throw "Слияние конфига не подтверждено. Восстановите файл из бэкапа и повторите."
}
Write-Host "MCP-серверы office-word и office-excel добавлены." -ForegroundColor Green

# ---------- 3. Проверка серверов ----------
Write-Host "`n[3/3] Проверка серверов..." -ForegroundColor Yellow
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source (Join-Path $PSScriptRoot "test_office_mcp.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Внимание: проверка не пройдена (см. вывод выше). Перезапустите PowerShell (или перезайдите в систему) и повторите." -ForegroundColor Yellow
    }
} else {
    Write-Host "Python не найден - пропускаем автоматическую проверку (не критично)." -ForegroundColor Yellow
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " УСТАНОВКА ЗАВЕРШЕНА" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Дальнейшие шаги:"
Write-Host " 1. Полностью закройте OpenCode Desktop и откройте заново."
Write-Host " 2. Просто попросите в чате, например: «Создай письмо.docx с заголовком и таблицей»"
Write-Host "    или «Посчитай сумму в столбце B файла budget.xlsx»."
