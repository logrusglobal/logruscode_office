# Installing the @browser browser agent (package 2)
# ============================================================================
# What the script does (it overwrites NOTHING, it only adds):
#   1. Adds the chrome-devtools MCP server to the existing opencode.json
#      (the file is saved to a backup before it is changed).
#   2. Adds a global ban on the browser tools for every agent except @browser.
#   3. Copies the agents\browser.md subagent (it inherits the primary agent's model).
#   4. Adds the web-task delegation rules to AGENTS.md.
#   5. Copies start-browser.cmd and creates a desktop shortcut.
#
# Run (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install_browser_agent.ps1
#
# Parameters:
#   -TargetDir    the OpenCode config folder (default %USERPROFILE%\.config\opencode)
#   -NoShortcut   do not create a desktop shortcut
# ============================================================================
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".config\opencode"),
    [switch]$NoShortcut
)

$ErrorActionPreference = "Stop"
$KitDir = Join-Path $PSScriptRoot "config"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " @browser browser agent - installation" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: Node.js was not found. The chrome-devtools MCP server is launched through npx." -ForegroundColor Yellow
    Write-Host "Install Node.js LTS from https://nodejs.org and run the installation again." -ForegroundColor Yellow
}

# ---------- 1. Folders ----------
Write-Host "`n[1/4] Preparing the folders..." -ForegroundColor Yellow
$agentsDir = Join-Path $TargetDir "agents"
New-Item -ItemType Directory -Force -Path $TargetDir, $agentsDir | Out-Null
Write-Host "Config: $TargetDir"

# ---------- 2. Merging the chrome-devtools MCP + permission into opencode.json ----------
Write-Host "`n[2/4] Adding the chrome-devtools MCP server to opencode.json..." -ForegroundColor Yellow
$configPath = Join-Path $TargetDir "opencode.json"
if (-not (Test-Path $configPath)) {
    throw "The file $configPath was not found. Install package 1 (OpenCode + Plexus) first and launch OpenCode at least once."
}
$backup = "$configPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $configPath $backup
Write-Host "A config backup was created: $backup"

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
    throw "The config merge was not confirmed. Restore the file from the backup and try again."
}
Write-Host "The chrome-devtools MCP server and the chrome-devtools_* ban were added." -ForegroundColor Green

# ---------- 3. The agent and rules files ----------
Write-Host "`n[3/4] Copying the agent and the rules..." -ForegroundColor Yellow
Copy-Item (Join-Path $KitDir "agents\browser.md") (Join-Path $agentsDir "browser.md") -Force

$agentsMd = Join-Path $TargetDir "AGENTS.md"
$rules = Get-Content (Join-Path $KitDir "AGENTS_browser.md") -Raw -Encoding UTF8
if (Test-Path $agentsMd) {
    $existing = Get-Content $agentsMd -Raw -Encoding UTF8
    if ($existing -notlike "*# Website rules*") {
        $combined = $existing.TrimEnd() + "`r`n`r`n" + $rules
        [System.IO.File]::WriteAllText($agentsMd, $combined, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "The web-task delegation rules were added to AGENTS.md"
    } else {
        Write-Host "The web-task rules are already in AGENTS.md - skipping"
    }
} else {
    [System.IO.File]::WriteAllText($agentsMd, $rules, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "AGENTS.md was created"
}

Copy-Item (Join-Path $KitDir "start-browser.cmd") (Join-Path $TargetDir "start-browser.cmd") -Force
Write-Host "Copied: agents\browser.md, start-browser.cmd" -ForegroundColor Green

# ---------- 4. The desktop shortcut ----------
Write-Host "`n[4/4] The desktop shortcut..." -ForegroundColor Yellow
if (-not $NoShortcut) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $lnkPath = Join-Path $desktop "Browser for OpenCode.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath = Join-Path $TargetDir "start-browser.cmd"
    $lnk.WorkingDirectory = $TargetDir
    $lnk.Description = "Launches Chrome with the debugging port for the @browser agent"
    $lnk.Save()
    Write-Host "The shortcut was created: $lnkPath" -ForegroundColor Green
} else {
    Write-Host "The shortcut was skipped (-NoShortcut)."
}

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host " 1. Close OpenCode Desktop completely and open it again."
Write-Host " 2. Before a web task, launch 'Browser for OpenCode' (the desktop shortcut)."
Write-Host " 3. Just ask in the chat, for example: 'Collect the contacts from https://... into a table'."
Write-Host "    The primary agent hands the task over to the @browser subagent itself."
