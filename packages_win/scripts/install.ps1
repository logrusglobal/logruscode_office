# OpenCode office kit - installer for packages 1-3
# ============================================================================
# One script for the whole kit. All three packages write into the SAME
# opencode.json / AGENTS.md, so they are merged here in one pass instead of by
# three separate installers.
#
# Package 1  OpenCode Desktop + the Plexus provider (DeepSeek), agent office,
#            agent build disabled.
# Package 2  the @browser subagent (drives a real Chrome through chrome-devtools).
# Package 3  OfficeCLI - the office-word and office-excel MCP servers.
#
# Nothing is overwritten blindly: opencode.json is backed up before every
# change, existing MCP servers and permissions survive a reinstall, and the
# blocks added to AGENTS.md are fenced with markers so uninstall.ps1 can take
# exactly them back out.
#
# Run (PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\install.ps1 -PlexusKey "sk-air-XXXX"
#
# Parameters:
#   -PlexusKey       the employee's DeepSeek-through-Plexus key (required for
#                    package 1; created in Plexus, stored in Vaultwarden)
#   -Lang            en | ru - language of the docs, agent prompts and console
#                    output. Default: taken from the Windows UI language.
#   -Packages        which packages to install. Default: 1,2,3
#   -SkipAppInstall  do not download/install the OpenCode Desktop application
#   -KeepBuild       do NOT disable the build agent (for experienced employees)
#   -NoShortcut      do not create the browser shortcut on the desktop
#   -SkipChecks      skip installing uv and the MCP handshake test (offline installs)
#   -TargetDir       OpenCode config folder (default %USERPROFILE%\.config\opencode)
#   -DataDir         OpenCode data folder  (default %USERPROFILE%\.local\share\opencode)
#
# Examples:
#   .\install.ps1 -PlexusKey "sk-air-XXXX"
#   .\install.ps1 -PlexusKey "sk-air-XXXX" -Lang ru -Packages 1,3
#   .\install.ps1 -Packages 2 -NoShortcut
# ============================================================================
param(
    [string]$PlexusKey,
    [ValidateSet('en', 'ru')]
    [string]$Lang,
    [int[]]$Packages = @(1, 2, 3),
    [string]$TargetDir = (Join-Path $env:USERPROFILE '.config\opencode'),
    [string]$DataDir = (Join-Path $env:USERPROFILE '.local\share\opencode'),
    [switch]$SkipAppInstall,
    [switch]$KeepBuild,
    [switch]$NoShortcut,
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$KitRoot = Split-Path -Parent $PSScriptRoot
$Lang = Resolve-KitLanguage $Lang
$M = Import-KitMessages -ScriptsDir $PSScriptRoot -Lang $Lang
Enable-Utf8Console

$InstallerUrl = 'https://opencode.ai/download/stable/windows-x64-nsis'

# ---------- Validation, before anything is written ----------
$Packages = @($Packages | Sort-Object -Unique)
foreach ($p in $Packages) {
    if ($p -ne 1 -and $p -ne 2 -and $p -ne 3) { throw ($M.err_bad_package -f $p) }
}
if ($Packages -contains 1) {
    if (-not $PlexusKey) { throw $M.err_need_key }
    if ($PlexusKey -notlike 'sk-*') { throw $M.err_key_prefix }
}

Write-Head $M.hdr_install
Write-Host ($M.lang_line -f $Lang, $TargetDir)
Write-Host ($M.pkg_selected -f ($Packages -join ', '))

$agentsDir = Join-Path $TargetDir 'agents'
$configPath = Join-Path $TargetDir 'opencode.json'
$agentsMd = Join-Path $TargetDir 'AGENTS.md'
New-Item -ItemType Directory -Force -Path $TargetDir, $agentsDir | Out-Null

# An AGENTS.md left by a pre-marker kit version still holds an unmarked copy of
# these rules - in whichever language that install used. It would sit above the
# blocks written below and quietly win, so take it out before writing anything.
if (Remove-LegacyKitSections -Path $agentsMd -Headings (Get-KitHeadings -KitRoot $KitRoot)) {
    Write-Warn $M.legacy_block_removed
}

# ============================================================================
# Package 1 - OpenCode Desktop + Plexus
# ============================================================================
if ($Packages -contains 1) {
    Write-Head $M.p1_head
    $p1Config = Join-Path $KitRoot 'package1_opencode_plexus\config'
    $p1Locale = Join-Path $p1Config "locales\$Lang"

    Write-Step $M.p1_app
    $appDir = Join-Path $env:LOCALAPPDATA 'Programs\@opencode-aidesktop'
    if ((Test-Path $appDir) -or $SkipAppInstall) {
        Write-Host $M.p1_app_present
    } else {
        Write-Host ($M.p1_app_download -f $InstallerUrl)
        $setup = Join-Path $env:TEMP 'OpenCodeSetup.exe'
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $setup -UseBasicParsing
        Write-Host $M.p1_app_install
        $proc = Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru
        Remove-Item $setup -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $appDir) -and $proc.ExitCode -ne 0) {
            Write-Warn ($M.p1_app_warn -f $proc.ExitCode)
        }
    }

    Write-Step $M.p1_config
    $cfg = Read-JsonHashtable (Join-Path $p1Config 'opencode.json')
    if (Test-Path $configPath) {
        Backup-File -Path $configPath -M $M | Out-Null
        $old = Read-JsonHashtable $configPath
        # Reinstall over an older kit: keep MCP servers and permissions that
        # packages 2 and 3 may already have merged in.
        $carried = $false
        if (Test-HasKey $old 'mcp') { $cfg['mcp'] = $old['mcp']; $carried = $true }
        if (Test-HasKey $old 'permission') { $cfg['permission'] = $old['permission']; $carried = $true }
        if ($carried) { Write-Host $M.p1_config_kept }
    }
    if ($KeepBuild) { $cfg.Remove('agent') }
    Write-JsonFile -Path $configPath -Value $cfg

    Set-MarkedBlock -Path $agentsMd -Id 'base' `
        -Content (Get-Content -LiteralPath (Join-Path $p1Locale 'AGENTS.md') -Raw -Encoding UTF8)
    Copy-Item (Join-Path $p1Locale 'agents\office.md') (Join-Path $agentsDir 'office.md') -Force
    Write-Ok $M.p1_config_ok

    Write-Step $M.p1_key
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    $authPath = Join-Path $DataDir 'auth.json'
    $auth = [ordered]@{}
    if (Test-Path $authPath) { $auth = Read-JsonHashtable $authPath }
    $auth['lgplexus'] = @{ 'type' = 'api'; 'key' = $PlexusKey }
    Write-JsonFile -Path $authPath -Value $auth
    Write-Ok ($M.p1_key_ok -f $authPath)

    if ($KeepBuild) { Write-Host $M.p1_keepbuild } else { Write-Ok $M.p1_build_off }
}

# Packages 2 and 3 only extend an existing config.
if (($Packages -contains 2 -or $Packages -contains 3) -and -not (Test-Path $configPath)) {
    throw ($M.err_no_config -f $configPath)
}

# ============================================================================
# Package 2 - the @browser subagent
# ============================================================================
if ($Packages -contains 2) {
    Write-Head $M.p2_head
    $p2Config = Join-Path $KitRoot 'package2_browser_agent\config'
    $p2Locale = Join-Path $p2Config "locales\$Lang"

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Warn $M.p2_node_warn }

    Write-Step $M.p2_mcp
    Backup-File -Path $configPath -M $M | Out-Null
    $cfg = Read-JsonHashtable $configPath
    $frag = Read-JsonHashtable (Join-Path $p2Config 'mcp_chrome-devtools.json')

    if (-not (Test-HasKey $cfg 'mcp') -or $null -eq $cfg['mcp']) { $cfg['mcp'] = [ordered]@{} }
    foreach ($entry in $frag.GetEnumerator()) { $cfg['mcp'][$entry.Key] = $entry.Value }

    if (-not (Test-HasKey $cfg 'permission') -or $null -eq $cfg['permission']) { $cfg['permission'] = [ordered]@{} }
    $cfg['permission']['chrome-devtools_*'] = 'deny'

    Write-JsonFile -Path $configPath -Value $cfg
    $check = Read-JsonHashtable $configPath
    if (-not (Test-HasKey $check['mcp'] 'chrome-devtools') -or -not (Test-HasKey $check['permission'] 'chrome-devtools_*')) {
        throw $M.err_merge
    }
    Write-Ok $M.p2_mcp_ok

    Write-Step $M.p2_files
    Copy-Item (Join-Path $p2Config 'start-browser.cmd') (Join-Path $TargetDir 'start-browser.cmd') -Force
    Copy-Item (Join-Path $p2Config 'ensure-browser.cmd') (Join-Path $TargetDir 'ensure-browser.cmd') -Force

    # The @browser agent starts the browser itself by running ensure-browser.cmd,
    # so its prompt needs the real absolute path: the shell behind the agent's
    # bash tool does not expand %USERPROFILE%.
    $browserAgent = Get-Content -LiteralPath (Join-Path $p2Locale 'agents\browser.md') -Raw -Encoding UTF8
    if ($browserAgent -notmatch '\{\{ENSURE_BROWSER\}\}') { throw $M.err_ensure_token }
    $browserAgent = $browserAgent.Replace('{{ENSURE_BROWSER}}', (Join-Path $TargetDir 'ensure-browser.cmd'))

    # A subagent with no model line does NOT inherit the caller's model - OpenCode
    # resolves its own default, which lands on the free tier and is refused by the
    # provider. Pin @browser to whatever model the config runs on.
    $browserModel = $cfg['model']
    if (-not $browserModel) { throw $M.err_no_model }
    $browserAgent = $browserAgent.Replace('{{MODEL}}', $browserModel)
    Write-Host ($M.p2_model -f $browserModel)
    Write-TextFile -Path (Join-Path $agentsDir 'browser.md') -Text $browserAgent
    Set-MarkedBlock -Path $agentsMd -Id 'browser' `
        -Content (Get-Content -LiteralPath (Join-Path $p2Locale 'AGENTS_browser.md') -Raw -Encoding UTF8)
    Write-Ok $M.p2_files_ok

    Write-Step $M.p2_shortcut
    if ($NoShortcut) {
        Write-Host $M.p2_shortcut_skip
    } else {
        $lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ($M.p2_shortcut_name + '.lnk')
        # WScript.Shell cannot save to a path holding characters outside the
        # system ANSI codepage (the Russian shortcut name on an English Windows
        # fails with FileNotFoundException). Save to an ASCII path, then let
        # .NET - which is Unicode-clean - move it into place.
        $tempRoot = [System.IO.Path]::GetTempPath()
        if ($tempRoot -match '[^ -~]') { $tempRoot = Join-Path $env:SystemRoot 'Temp' }
        $tempLnk = Join-Path $tempRoot ('opencode-kit-{0}.lnk' -f [guid]::NewGuid())
        # Same codepage limit applies to the tooltip text, which WScript.Shell
        # stores as ANSI: on a Russian Windows cp1251 carries it fine, elsewhere
        # it would turn into "??????". Fall back to English rather than ship that.
        $description = $M.p2_shortcut_desc
        $ansi = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
        if ($ansi.GetString($ansi.GetBytes($description)) -ne $description) {
            $description = (Import-KitMessages -ScriptsDir $PSScriptRoot -Lang 'en').p2_shortcut_desc
        }
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($tempLnk)
        $lnk.TargetPath = Join-Path $TargetDir 'start-browser.cmd'
        $lnk.WorkingDirectory = $TargetDir
        $lnk.Description = $description
        $lnk.Save()
        Move-Item -LiteralPath $tempLnk -Destination $lnkPath -Force
        Write-Ok ($M.p2_shortcut_ok -f $lnkPath)
    }
}

# ============================================================================
# Package 3 - OfficeCLI (Word / Excel MCP servers)
# ============================================================================
if ($Packages -contains 3) {
    Write-Head $M.p3_head
    $p3Dir = Join-Path $KitRoot 'package3_officecli'
    $uvDir = Join-Path $env:USERPROFILE '.local\bin'

    if ($SkipChecks) {
        Write-Host $M.p3_checks_skip
    } else {
        Write-Step $M.p3_uv
        if (-not (Test-Path (Join-Path $uvDir 'uv.exe'))) {
            Write-Host $M.p3_uv_install
            powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
            if (-not (Test-Path (Join-Path $uvDir 'uv.exe'))) { throw $M.p3_uv_fail }
        }
        Write-Ok ($M.p3_uv_ok -f $uvDir)
    }

    Write-Step $M.p3_mcp
    Backup-File -Path $configPath -M $M | Out-Null
    $cfg = Read-JsonHashtable $configPath
    $frag = Read-JsonHashtable (Join-Path $p3Dir 'mcp_config.json')

    if (-not (Test-HasKey $cfg 'mcp') -or $null -eq $cfg['mcp']) { $cfg['mcp'] = [ordered]@{} }
    foreach ($entry in $frag.GetEnumerator()) { $cfg['mcp'][$entry.Key] = $entry.Value }

    Write-JsonFile -Path $configPath -Value $cfg
    $check = Read-JsonHashtable $configPath
    if (-not (Test-HasKey $check['mcp'] 'office-word') -or -not (Test-HasKey $check['mcp'] 'office-excel')) {
        throw $M.err_merge
    }
    Write-Ok $M.p3_mcp_ok

    if (-not $SkipChecks) {
        Write-Step $M.p3_test
        $py = Get-Command python -ErrorAction SilentlyContinue
        if ($py) {
            & $py.Source (Join-Path $p3Dir 'test_office_mcp.py') --lang $Lang
            if ($LASTEXITCODE -ne 0) { Write-Warn $M.p3_test_warn }
        } else {
            Write-Warn $M.p3_no_python
        }
    }
}

# ============================================================================
Write-Head $M.done_install
Write-Host $M.next_steps
Write-Host $M.next_restart
if ($Packages -contains 1) { Write-Host $M.next_model }
if ($Packages -contains 2) { Write-Host ($M.next_browser -f $M.p2_shortcut_name) }
if ($Packages -contains 3) { Write-Host $M.next_office }
Write-Host ($M.next_examples -f $Lang)
