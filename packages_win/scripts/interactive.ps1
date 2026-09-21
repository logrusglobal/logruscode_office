# OpenCode office kit - interactive front-end for Install.cmd / Uninstall.cmd
# ============================================================================
# Asks only for what cannot be guessed (language, the employee's Plexus key,
# which packages), shows what is about to happen, then calls install.ps1 or
# uninstall.ps1 to do the actual work. Those two stay fully scriptable for
# unattended installs - this file only collects answers.
#
# Not meant to be launched by hand: double-click Install.cmd or Uninstall.cmd
# in the kit folder instead.
#
# Like the other .ps1 files here this one is ASCII-only; every visible string,
# including the language names in the first prompt, comes from scripts\i18n.
# ============================================================================
param(
    [ValidateSet('install', 'uninstall')]
    [string]$Mode = 'install',
    # Not asked for in the prompts - forwarded to install.ps1/uninstall.ps1 when
    # given, so the launcher can be exercised against a throwaway folder.
    [string]$TargetDir,
    [string]$DataDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\common.ps1')
Enable-Utf8Console

function Read-Answer {
    param([string]$Prompt)
    Write-Host ''
    Write-Host "$Prompt " -ForegroundColor Cyan -NoNewline
    return (Read-Host).Trim()
}

# ---------- Language ----------
$languages = @(Get-KitLanguages -ScriptsDir $PSScriptRoot)
$messages = @{}
foreach ($code in $languages) { $messages[$code] = Import-KitMessages -ScriptsDir $PSScriptRoot -Lang $code }
$lang = Resolve-KitLanguage ''
if ($languages.Count -gt 1) {
    Write-Head (($languages | ForEach-Object { $messages[$_].ui_lang_prompt }) -join ' / ')
    for ($i = 0; $i -lt $languages.Count; $i++) {
        $marker = if ($languages[$i] -eq $lang) { '*' } else { ' ' }
        Write-Host ("  [{0}]{1} {2}" -f ($i + 1), $marker, $messages[$languages[$i]].ui_lang_name)
    }
    $picked = Read-Answer ('1-{0} [*]' -f $languages.Count)
    if ($picked -match '^\d+$' -and [int]$picked -ge 1 -and [int]$picked -le $languages.Count) {
        $lang = $languages[[int]$picked - 1]
    }
}
$M = $messages[$lang]

# ---------- Collect answers ----------
$key = $null
$purge = $false
Write-Head $(if ($Mode -eq 'install') { $M.ui_title_install } else { $M.ui_title_uninstall })
if ($Mode -eq 'uninstall') { Write-Warn $M.ui_uninstall_warn }

if ($Mode -eq 'install') {
    while ($true) {
        $key = Read-Answer $M.ui_key_prompt
        if ($key -eq '') { Write-Warn $M.ui_cancelled; Read-Host $M.ui_press_enter | Out-Null; exit 0 }
        if ($key -like 'sk-*') { break }
        Write-Warn $M.ui_key_invalid
    }
}

$packagePrompt = if ($Mode -eq 'install') { $M.ui_packages_prompt } else { $M.ui_packages_prompt_remove }
$packages = $null
while ($null -eq $packages) {
    $raw = Read-Answer $packagePrompt
    if ($raw -eq '') { $packages = @(1, 2, 3); break }
    $parsed = @($raw -split '[,;\s]+' | Where-Object { $_ -ne '' })
    if (($parsed.Count -gt 0) -and -not ($parsed | Where-Object { $_ -notmatch '^[123]$' })) {
        $packages = @($parsed | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    } else {
        Write-Warn $M.ui_packages_invalid
    }
}

if ($Mode -eq 'uninstall' -and ($packages -contains 2)) {
    $purge = (Read-Answer $M.ui_purge_prompt) -match $M.ui_yes_pattern
}

# ---------- Confirm ----------
Write-Host ''
Write-Host $M.ui_summary
Write-Host ('  ' + ($M.ui_sum_lang -f $messages[$lang].ui_lang_name))
Write-Host ('  ' + ($M.ui_sum_packages -f ($packages -join ', ')))
if ($Mode -eq 'install') {
    $shown = if ($key.Length -gt 14) { $key.Substring(0, 7) + '...' + $key.Substring($key.Length - 4) } else { '...' }
    Write-Host ('  ' + ($M.ui_sum_key -f $shown))
}
$shownTarget = if ($TargetDir) { $TargetDir } else { Join-Path $env:USERPROFILE '.config\opencode' }
Write-Host ('  ' + ($M.ui_sum_target -f $shownTarget))
if ($purge) { Write-Warn ('  ' + $M.ui_sum_purge) }

if ($Mode -eq 'install') {
    # Enter means yes: the summary has already been shown and nothing is destructive.
    if ((Read-Answer $M.ui_confirm) -match $M.ui_no_pattern) {
        Write-Warn $M.ui_cancelled; Read-Host $M.ui_press_enter | Out-Null; exit 0
    }
} else {
    # Removal defaults to NO: Enter must never delete anything.
    if ((Read-Answer $M.ui_confirm_remove) -notmatch $M.ui_yes_pattern) {
        Write-Warn $M.ui_cancelled; Read-Host $M.ui_press_enter | Out-Null; exit 0
    }
}

# ---------- Run ----------
try {
    $params = @{ Lang = $lang; Packages = $packages }
    if ($TargetDir) { $params['TargetDir'] = $TargetDir }
    if ($DataDir) { $params['DataDir'] = $DataDir }
    if ($Mode -eq 'install') {
        & (Join-Path $PSScriptRoot 'install.ps1') -PlexusKey $key @params
    } else {
        if ($purge) { $params['Purge'] = $true }
        & (Join-Path $PSScriptRoot 'uninstall.ps1') @params
    }
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Warn $M.ui_failed
    Read-Host $M.ui_press_enter | Out-Null
    exit 1
}

Write-Host ''
Read-Host $M.ui_press_enter | Out-Null
