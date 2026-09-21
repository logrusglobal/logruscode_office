# Installing OfficeCLI (the Word and Excel MCP servers) — package 3
# ============================================================================
# What the script does (it overwrites NOTHING, it only adds):
#   1. Installs the uv package manager (if it is missing).
#   2. Adds the office-word and office-excel MCP servers to the existing
#      opencode.json (the file is saved to a backup before it is changed).
#   3. Checks that both servers start (HANDSHAKE OK).
#
# Run (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_officecli.ps1
#
# Parameters:
#   -TargetDir    the OpenCode config folder (default %USERPROFILE%\.config\opencode)
# ============================================================================
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".config\opencode")
)

$ErrorActionPreference = "Stop"
$uvDir = Join-Path $env:USERPROFILE ".local\bin"
$configPath = Join-Path $TargetDir "opencode.json"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " OfficeCLI (Word/Excel MCP) - installation" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# ---------- 1. uv ----------
Write-Host "`n[1/3] Checking uv (the package manager)..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $uvDir "uv.exe"))) {
    Write-Host "uv was not found. Installing it (about a minute)..."
    powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    if (-not (Test-Path (Join-Path $uvDir "uv.exe"))) { throw "Failed to install uv" }
}
Write-Host "uv: OK ($uvDir)" -ForegroundColor Green

# ---------- 2. Merging the MCP servers into opencode.json ----------
Write-Host "`n[2/3] Adding the office-word and office-excel MCP servers to opencode.json..." -ForegroundColor Yellow
if (-not (Test-Path $configPath)) {
    throw "The file $configPath was not found. Install package 1 (OpenCode + Plexus) first and launch OpenCode at least once."
}
$backup = "$configPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $configPath $backup
Write-Host "A config backup was created: $backup"

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
    throw "The config merge was not confirmed. Restore the file from the backup and try again."
}
Write-Host "The office-word and office-excel MCP servers were added." -ForegroundColor Green

# ---------- 3. Checking the servers ----------
Write-Host "`n[3/3] Checking the servers..." -ForegroundColor Yellow
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source (Join-Path $PSScriptRoot "test_office_mcp.py")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: the check did not pass (see the output above). Restart PowerShell (or sign out and back in) and try again." -ForegroundColor Yellow
    }
} else {
    Write-Host "Python was not found - skipping the automatic check (not critical)." -ForegroundColor Yellow
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host " 1. Close OpenCode Desktop completely and open it again."
Write-Host " 2. Just ask in the chat, for example: 'Create letter.docx with a heading and a table'"
Write-Host "    or 'Sum up column B in budget.xlsx'."
