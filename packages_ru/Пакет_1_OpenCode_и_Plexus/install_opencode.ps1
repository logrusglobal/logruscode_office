# Установка OpenCode и подключение DeepSeek через Plexus (пакет 1)
# ============================================================================
# Что делает скрипт:
#   1. Устанавливает OpenCode Desktop (скачивает с opencode.ai и ставит тихо),
#      если он ещё не установлен (пропустить: -SkipAppInstall).
#   2. Прописывает в конфиг OpenCode провайдера Plexus (lgplexus) и модель
#      DeepSeek (deepseek-deepseek-v4-pro, с режимами рассуждений High/Max).
#   3. Сохраняет ключ доступа к Plexus в auth.json.
#   4. Отключает агента build и делает основным агента office
#      (для опытных пользователей: -KeepBuild).
#   5. Создаёт бэкапы существующих файлов настройки.
#
# Запуск (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_opencode.ps1 -PlexusKey "sk-air-XXXX"
#
# Параметры:
#   -PlexusKey       ОБЯЗАТЕЛЬНО: ключ доступа к DeepSeek через Plexus
#                    (создаётся в Plexus, хранится в Vaultwarden; формат sk-air-...)
#   -SkipAppInstall  не устанавливать приложение (если уже установлено)
#   -KeepBuild       НЕ отключать агента build (для опытных сотрудников)
#   -TargetDir       папка конфигурации OpenCode (по умолчанию %USERPROFILE%\.config\opencode)
#   -DataDir         папка данных OpenCode (по умолчанию %USERPROFILE%\.local\share\opencode)
# ============================================================================
param(
    [Parameter(Mandatory = $true)][string]$PlexusKey,
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".config\opencode"),
    [string]$DataDir = (Join-Path $env:USERPROFILE ".local\share\opencode"),
    [switch]$SkipAppInstall,
    [switch]$KeepBuild
)

$ErrorActionPreference = "Stop"
$KitDir = Join-Path $PSScriptRoot "config"
$InstallerUrl = "https://opencode.ai/download/stable/windows-x64-nsis"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " OpenCode + Plexus (DeepSeek) - установка" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

if (-not ($PlexusKey -like "sk-*")) {
    throw "Ключ Plexus должен начинаться с 'sk-'. Возьмите его из Vaultwarden."
}

# ---------- 1. Приложение OpenCode Desktop ----------
Write-Host "`n[1/5] Приложение OpenCode Desktop..." -ForegroundColor Yellow
$appDir = Join-Path $env:LOCALAPPDATA "Programs\@opencode-aidesktop"
$installed = Test-Path $appDir
if ($installed -or $SkipAppInstall) {
    Write-Host "Приложение уже установлено или пропущено флагом -SkipAppInstall." 
} else {
    Write-Host "Скачиваю установщик с $InstallerUrl ..."
    $setup = Join-Path $env:TEMP "OpenCodeSetup.exe"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $setup -UseBasicParsing
    Write-Host "Устанавливаю OpenCode Desktop (тихий режим)..."
    $p = Start-Process -FilePath $setup -ArgumentList "/S" -Wait -PassThru
    Remove-Item $setup -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $appDir) -and $p.ExitCode -ne 0) {
        Write-Host "Внимание: тихая установка не подтвердилась (ExitCode $($p.ExitCode)). Установите приложение вручную с https://opencode.ai/download и запустите скрипт ещё раз с -SkipAppInstall." -ForegroundColor Yellow
    }
}

# ---------- 2. Папки конфигурации ----------
Write-Host "`n[2/5] Подготовка папок конфигурации..." -ForegroundColor Yellow
$agentsDir = Join-Path $TargetDir "agents"
New-Item -ItemType Directory -Force -Path $TargetDir, $agentsDir, $DataDir | Out-Null
Write-Host "Конфиг: $TargetDir"

# ---------- 3. Копирование базовой конфигурации ----------
Write-Host "`n[3/5] Копирование базовой конфигурации..." -ForegroundColor Yellow
$configTarget = Join-Path $TargetDir "opencode.json"
$oldCfg = $null
if (Test-Path $configTarget) {
    $backup = "$configTarget.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $configTarget $backup
    Write-Host "Существующий opencode.json сохранён в бэкап: $backup"
    $oldCfg = Get-Content $backup -Raw | ConvertFrom-Json
}
$kitCfg = Get-Content (Join-Path $KitDir "opencode.json") -Raw | ConvertFrom-Json
$ht = @{}
$kitCfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
if ($oldCfg) {
    # Переустановка поверх старого пакета: сохраняем уже настроенные MCP-серверы
    # (браузер, OfficeCLI) и permission, чтобы они не пропали.
    if ($oldCfg.mcp -and -not $ht.ContainsKey("mcp")) { $ht["mcp"] = $oldCfg.mcp }
    if ($oldCfg.permission -and -not $ht.ContainsKey("permission")) { $ht["permission"] = $oldCfg.permission }
}
$json = $ht | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($configTarget, $json, (New-Object System.Text.UTF8Encoding $false))

Copy-Item (Join-Path $KitDir "AGENTS.md") (Join-Path $TargetDir "AGENTS.md") -Force
Copy-Item (Join-Path $KitDir "agents\office.md") (Join-Path $agentsDir "office.md") -Force
Write-Host "Скопировано: opencode.json, AGENTS.md, agents\office.md" -ForegroundColor Green

# ---------- 4. Ключ Plexus в auth.json ----------
Write-Host "`n[4/5] Сохранение ключа Plexus..." -ForegroundColor Yellow
$authPath = Join-Path $DataDir "auth.json"
$auth = @{}
if (Test-Path $authPath) {
    $auth = Get-Content $authPath -Raw | ConvertFrom-Json
    $tmp = @{}
    $auth.PSObject.Properties | ForEach-Object { $tmp[$_.Name] = $_.Value }
    $auth = $tmp
}
$auth["lgplexus"] = @{ "type" = "api"; "key" = $PlexusKey }
$json = $auth | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($authPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Ключ Plexus сохранён в $authPath" -ForegroundColor Green

# ---------- 5. Отключение build / KeepBuild ----------
Write-Host "`n[5/5] Настройка агентов..." -ForegroundColor Yellow
if ($KeepBuild) {
    $cfg = Get-Content $configTarget -Raw | ConvertFrom-Json
    $ht = @{}
    $cfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
    $ht["agent"] = @{ "build" = @{ "disable" = $false } }
    $json = $ht | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($configTarget, $json, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "-KeepBuild: агент build оставлен включённым." 
} else {
    Write-Host "Агент build отключён, основной агент - office." -ForegroundColor Green
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " УСТАНОВКА ЗАВЕРШЕНА" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Дальнейшие шаги:"
Write-Host " 1. Запустите OpenCode Desktop. Модель: lgplexus/deepseek-deepseek-v4-pro."
Write-Host " 2. Справа от названия модели должен появиться переключатель рассуждений:"
Write-Host "    Default / High / Max."
Write-Host " 3. При необходимости установите пакеты: Браузерный агент и/или OfficeCLI."
