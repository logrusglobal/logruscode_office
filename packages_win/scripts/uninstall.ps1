# OpenCode office kit - uninstaller for packages 1-3
# ============================================================================
# Takes back out exactly what install.ps1 put in, and nothing else:
#   - the keys it added to opencode.json (the file is backed up first, and is
#     left in place with any settings the user added by hand);
#   - the blocks it fenced with markers in AGENTS.md (hand-written text in that
#     file survives; the file is deleted only if nothing else remains);
#   - the agent files, start-browser.cmd and the desktop shortcut it created;
#   - the Plexus key in auth.json (package 1).
#
# NOT removed: the user's documents, the Chrome debug profile with its logins
# (pass -Purge), the config backups, and the OpenCode Desktop application.
#
# Run (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\uninstall.ps1
#
# Parameters:
#   -Lang        en | ru - language of the console output. Default: Windows UI language.
#   -Packages    which packages to remove. Default: 1,2,3 (removed in reverse order)
#   -Purge       also delete the Chrome debug profile (logins and cookies!)
#   -TargetDir   OpenCode config folder (default %USERPROFILE%\.config\opencode)
#   -DataDir     OpenCode data folder  (default %USERPROFILE%\.local\share\opencode)
#
# Examples:
#   .\uninstall.ps1
#   .\uninstall.ps1 -Packages 2 -Purge
# ============================================================================
param(
    [ValidateSet('en', 'ru')]
    [string]$Lang,
    [int[]]$Packages = @(1, 2, 3),
    [string]$TargetDir = (Join-Path $env:USERPROFILE '.config\opencode'),
    [string]$DataDir = (Join-Path $env:USERPROFILE '.local\share\opencode'),
    [switch]$Purge
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$Lang = Resolve-KitLanguage $Lang
$M = Import-KitMessages -ScriptsDir $PSScriptRoot -Lang $Lang
Enable-Utf8Console

# Packages are removed high-to-low so that package 1, which owns the base block
# of AGENTS.md, cleans up last.
$Packages = @($Packages | Sort-Object -Unique -Descending)
foreach ($p in $Packages) {
    if ($p -ne 1 -and $p -ne 2 -and $p -ne 3) { throw ($M.err_bad_package -f $p) }
}

Write-Head $M.hdr_uninstall
Write-Host ($M.lang_line -f $Lang, $TargetDir)
Write-Host ($M.pkg_selected -f (@($Packages | Sort-Object) -join ', '))

$agentsDir = Join-Path $TargetDir 'agents'
$configPath = Join-Path $TargetDir 'opencode.json'
$agentsMd = Join-Path $TargetDir 'AGENTS.md'
$hasConfig = Test-Path $configPath

if (-not $hasConfig) { Write-Warn $M.u_no_config }

# The config is read once, edited by every selected package, and written once.
$cfg = $null
if ($hasConfig) {
    Backup-File -Path $configPath -M $M | Out-Null
    $cfg = Read-JsonHashtable $configPath
}
$cleaned = @()

foreach ($pkg in $Packages) {

    # ------------------------------------------------------------------
    if ($pkg -eq 3) {
        Write-Head $M.u_p3
        $touched = $false
        foreach ($server in 'office-word', 'office-excel') {
            if (Remove-HashKey -Parent $cfg -Section 'mcp' -Key $server) {
                $cleaned += "mcp.$server"; $touched = $true
            }
        }
        if (-not $touched) { Write-Host $M.u_nothing }
    }

    # ------------------------------------------------------------------
    if ($pkg -eq 2) {
        Write-Head $M.u_p2
        $touched = $false
        if (Remove-HashKey -Parent $cfg -Section 'mcp' -Key 'chrome-devtools') {
            $cleaned += 'mcp.chrome-devtools'; $touched = $true
        }
        if (Remove-HashKey -Parent $cfg -Section 'permission' -Key 'chrome-devtools_*') {
            $cleaned += 'permission.chrome-devtools_*'; $touched = $true
        }
        if (Remove-KitPath -Path (Join-Path $agentsDir 'browser.md') -M $M) { $touched = $true }
        if (Remove-KitPath -Path (Join-Path $TargetDir 'start-browser.cmd') -M $M) { $touched = $true }
        if (Remove-MarkedBlock -Path $agentsMd -Id 'browser') {
            Write-Host ($M.u_removed -f 'AGENTS.md (web rules)'); $touched = $true
        }

        # The shortcut name is localized, so every language's name is tried -
        # the kit may well have been installed in the other language.
        $desktop = [Environment]::GetFolderPath('Desktop')
        foreach ($lng in (Get-KitLanguages -ScriptsDir $PSScriptRoot)) {
            $name = (Import-KitMessages -ScriptsDir $PSScriptRoot -Lang $lng).p2_shortcut_name
            if (Remove-KitPath -Path (Join-Path $desktop "$name.lnk") -M $M) { $touched = $true }
        }

        $profileDir = Join-Path $TargetDir 'chrome-debug-profile'
        if (Test-Path $profileDir) {
            if ($Purge) {
                if (Remove-KitPath -Path $profileDir -M $M) { $touched = $true }
            } else {
                Write-Warn ($M.u_profile_kept -f $profileDir)
            }
        }
        if (-not $touched) { Write-Host $M.u_nothing }
    }

    # ------------------------------------------------------------------
    if ($pkg -eq 1) {
        Write-Head $M.u_p1
        $touched = $false
        if (Remove-HashKey -Parent $cfg -Section 'provider' -Key 'lgplexus') {
            $cleaned += 'provider.lgplexus'; $touched = $true
        }
        if (Remove-HashKey -Parent $cfg -Section 'agent' -Key 'build') {
            $cleaned += 'agent.build'; $touched = $true
        }
        if ($null -ne $cfg) {
            foreach ($key in 'model', 'small_model') {
                if ((Test-HasKey $cfg $key) -and "$($cfg[$key])" -like 'lgplexus/*') {
                    $cfg.Remove($key); $cleaned += $key; $touched = $true
                }
            }
            if ((Test-HasKey $cfg 'default_agent') -and $cfg['default_agent'] -eq 'office') {
                $cfg.Remove('default_agent'); $cleaned += 'default_agent'; $touched = $true
            }
        }
        if (Remove-KitPath -Path (Join-Path $agentsDir 'office.md') -M $M) { $touched = $true }
        if (Remove-MarkedBlock -Path $agentsMd -Id 'base') {
            Write-Host ($M.u_removed -f 'AGENTS.md (base rules)'); $touched = $true
        }

        $authPath = Join-Path $DataDir 'auth.json'
        if (Test-Path $authPath) {
            $auth = Read-JsonHashtable $authPath
            if (Test-HasKey $auth 'lgplexus') {
                Backup-File -Path $authPath -M $M | Out-Null
                $auth.Remove('lgplexus')
                Write-JsonFile -Path $authPath -Value $auth
                Write-Host ($M.u_removed -f 'auth.json (lgplexus key)')
                $touched = $true
            }
        }
        if (-not $touched) { Write-Host $M.u_nothing }
    }
}

if ($hasConfig) {
    Write-JsonFile -Path $configPath -Value $cfg
    if ($cleaned.Count -gt 0) { Write-Ok ($M.u_config_clean -f ($cleaned -join ', ')) }
}

Write-Head $M.done_uninstall
Write-Host $M.next_steps
Write-Host $M.u_restart_hint
Write-Host $M.u_backups_hint
if ($Packages -contains 1) { Write-Host $M.u_app_hint }
