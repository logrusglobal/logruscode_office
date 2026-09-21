# Installing OpenCode and connecting DeepSeek through Plexus (package 1)
# ============================================================================
# What the script does:
#   1. Installs OpenCode Desktop (downloads it from opencode.ai and installs it
#      silently) if it is not installed yet (skip with: -SkipAppInstall).
#   2. Registers the Plexus provider (lgplexus) and the DeepSeek model
#      (deepseek-deepseek-v4-pro, with the High/Max reasoning modes) in the
#      OpenCode config.
#   3. Saves the Plexus access key in auth.json.
#   4. Disables the build agent and makes office the primary agent
#      (for experienced users: -KeepBuild).
#   5. Creates backups of the existing settings files.
#
# Run (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_opencode.ps1 -PlexusKey "sk-air-XXXX"
#
# Parameters:
#   -PlexusKey       REQUIRED: the access key for DeepSeek through Plexus
#                    (created in Plexus, stored in Vaultwarden; format sk-air-...)
#   -SkipAppInstall  do not install the application (if it is already installed)
#   -KeepBuild       do NOT disable the build agent (for experienced employees)
#   -TargetDir       the OpenCode config folder (default %USERPROFILE%\.config\opencode)
#   -DataDir         the OpenCode data folder (default %USERPROFILE%\.local\share\opencode)
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
Write-Host " OpenCode + Plexus (DeepSeek) - installation" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

if (-not ($PlexusKey -like "sk-*")) {
    throw "The Plexus key must start with 'sk-'. Take it from Vaultwarden."
}

# ---------- 1. The OpenCode Desktop application ----------
Write-Host "`n[1/5] OpenCode Desktop application..." -ForegroundColor Yellow
$appDir = Join-Path $env:LOCALAPPDATA "Programs\@opencode-aidesktop"
$installed = Test-Path $appDir
if ($installed -or $SkipAppInstall) {
    Write-Host "The application is already installed or was skipped with the -SkipAppInstall flag."
} else {
    Write-Host "Downloading the installer from $InstallerUrl ..."
    $setup = Join-Path $env:TEMP "OpenCodeSetup.exe"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $setup -UseBasicParsing
    Write-Host "Installing OpenCode Desktop (silent mode)..."
    $p = Start-Process -FilePath $setup -ArgumentList "/S" -Wait -PassThru
    Remove-Item $setup -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $appDir) -and $p.ExitCode -ne 0) {
        Write-Host "Warning: the silent installation was not confirmed (ExitCode $($p.ExitCode)). Install the application manually from https://opencode.ai/download and run the script again with -SkipAppInstall." -ForegroundColor Yellow
    }
}

# ---------- 2. Config folders ----------
Write-Host "`n[2/5] Preparing the config folders..." -ForegroundColor Yellow
$agentsDir = Join-Path $TargetDir "agents"
New-Item -ItemType Directory -Force -Path $TargetDir, $agentsDir, $DataDir | Out-Null
Write-Host "Config: $TargetDir"

# ---------- 3. Copying the base configuration ----------
Write-Host "`n[3/5] Copying the base configuration..." -ForegroundColor Yellow
$configTarget = Join-Path $TargetDir "opencode.json"
$oldCfg = $null
if (Test-Path $configTarget) {
    $backup = "$configTarget.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $configTarget $backup
    Write-Host "The existing opencode.json was saved to a backup: $backup"
    $oldCfg = Get-Content $backup -Raw | ConvertFrom-Json
}
$kitCfg = Get-Content (Join-Path $KitDir "opencode.json") -Raw | ConvertFrom-Json
$ht = @{}
$kitCfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
if ($oldCfg) {
    # Reinstalling over an older package: keep the MCP servers that are already
    # configured (browser, OfficeCLI) and the permissions, so they are not lost.
    if ($oldCfg.mcp -and -not $ht.ContainsKey("mcp")) { $ht["mcp"] = $oldCfg.mcp }
    if ($oldCfg.permission -and -not $ht.ContainsKey("permission")) { $ht["permission"] = $oldCfg.permission }
}
$json = $ht | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($configTarget, $json, (New-Object System.Text.UTF8Encoding $false))

Copy-Item (Join-Path $KitDir "AGENTS.md") (Join-Path $TargetDir "AGENTS.md") -Force
Copy-Item (Join-Path $KitDir "agents\office.md") (Join-Path $agentsDir "office.md") -Force
Write-Host "Copied: opencode.json, AGENTS.md, agents\office.md" -ForegroundColor Green

# ---------- 4. The Plexus key in auth.json ----------
Write-Host "`n[4/5] Saving the Plexus key..." -ForegroundColor Yellow
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
Write-Host "The Plexus key was saved to $authPath" -ForegroundColor Green

# ---------- 5. Disabling build / KeepBuild ----------
Write-Host "`n[5/5] Configuring the agents..." -ForegroundColor Yellow
if ($KeepBuild) {
    $cfg = Get-Content $configTarget -Raw | ConvertFrom-Json
    $ht = @{}
    $cfg.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
    $ht["agent"] = @{ "build" = @{ "disable" = $false } }
    $json = $ht | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($configTarget, $json, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "-KeepBuild: the build agent was left enabled."
} else {
    Write-Host "The build agent is disabled, the primary agent is office." -ForegroundColor Green
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host " 1. Launch OpenCode Desktop. Model: lgplexus/deepseek-deepseek-v4-pro."
Write-Host " 2. A reasoning switch should appear to the right of the model name:"
Write-Host "    Default / High / Max."
Write-Host " 3. If needed, install the packages: Browser Agent and/or OfficeCLI."
