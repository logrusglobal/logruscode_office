# Shared helpers for the OpenCode office kit (install.ps1 / uninstall.ps1).
#
# This file is deliberately ASCII-only: every user-visible string lives in
# scripts\i18n\*.json, so Windows PowerShell 5.1 never has to parse non-ASCII
# literals out of a BOM-less .ps1 (a classic source of mojibake).

function Enable-Utf8Console {
    # Makes Cyrillic output readable in terminals that default to a legacy codepage.
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $global:OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        # Some hosts (ISE, redirected output) refuse this; not fatal.
    }
}

function Resolve-KitLanguage {
    param([string]$Lang)
    if ($Lang) { return $Lang.ToLower() }
    try { $ui = (Get-UICulture).TwoLetterISOLanguageName } catch { $ui = 'en' }
    if ($ui -eq 'ru') { return 'ru' }
    return 'en'
}

function ConvertTo-Hashtable {
    # Deep PSCustomObject -> ordered hashtable, so nested JSON can be edited and
    # removed from. Ordered on purpose: a plain @{} would reshuffle opencode.json
    # on every write, which makes the file hard to read and every diff noisy.
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in @($InputObject.Keys)) { $h[$k] = ConvertTo-Hashtable $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    if ($InputObject -is [object[]]) {
        return , @($InputObject | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    return $InputObject
}

function Test-HasKey {
    # Works for both @{} and [ordered]@{}: OrderedDictionary has no ContainsKey()
    # in Windows PowerShell 5.1, only Contains().
    param($Dictionary, [Parameter(Mandatory = $true)][string]$Key)
    if ($null -eq $Dictionary) { return $false }
    if ($Dictionary -is [System.Collections.IDictionary]) { return $Dictionary.Contains($Key) }
    return $false
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Read-JsonHashtable {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (ConvertTo-Hashtable (Read-JsonFile $Path))
}

function Write-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path, $Value)
    $json = $Value | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Write-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Import-KitMessages {
    # Loads en.json as the base, then overlays the requested language, so a missing
    # translation degrades to English instead of printing an empty line.
    param(
        [Parameter(Mandatory = $true)][string]$ScriptsDir,
        [Parameter(Mandatory = $true)][string]$Lang
    )
    $base = Join-Path $ScriptsDir 'i18n\en.json'
    if (-not (Test-Path -LiteralPath $base)) { throw "Message file not found: $base" }
    $m = Read-JsonHashtable $base
    if ($Lang -ne 'en') {
        $loc = Join-Path $ScriptsDir "i18n\$Lang.json"
        if (Test-Path -LiteralPath $loc) {
            foreach ($entry in (Read-JsonHashtable $loc).GetEnumerator()) { $m[$entry.Key] = $entry.Value }
        }
    }
    return $m
}

function Get-KitLanguages {
    param([Parameter(Mandatory = $true)][string]$ScriptsDir)
    return @(Get-ChildItem -LiteralPath (Join-Path $ScriptsDir 'i18n') -Filter '*.json' |
        ForEach-Object { $_.BaseName })
}

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host '======================================================' -ForegroundColor Cyan
}

function Write-Step { param([string]$Text) Write-Host ''; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$Path, [hashtable]$M)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Path.backup-$stamp"
    $i = 1
    while (Test-Path -LiteralPath $backup) { $backup = "$Path.backup-$stamp-$i"; $i++ }
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    Write-Host ($M.backup_created -f $backup)
    return $backup
}

function Get-BlockMarkers {
    param([Parameter(Mandatory = $true)][string]$Id)
    return @{
        Start = "<!-- opencode-kit:${Id}:start -->"
        End   = "<!-- opencode-kit:${Id}:end -->"
    }
}

function Set-MarkedBlock {
    # Writes $Content into $Path between HTML-comment markers, replacing an earlier
    # copy of the same block if present. Markers are what makes uninstall precise:
    # anything the user added to the file by hand is left alone.
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $mk = Get-BlockMarkers $Id
    $block = "$($mk.Start)`r`n" + $Content.Trim() + "`r`n$($mk.End)"
    if (Test-Path -LiteralPath $Path) {
        $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $pattern = [regex]::Escape($mk.Start) + '[\s\S]*?' + [regex]::Escape($mk.End)
        if ([regex]::IsMatch($text, $pattern)) {
            $text = [regex]::Replace($text, $pattern, { $block })
        } else {
            $text = $text.TrimEnd() + "`r`n`r`n" + $block
        }
    } else {
        $text = $block
    }
    Write-TextFile -Path $Path -Text ($text.TrimEnd() + "`r`n")
}

function Get-KitHeadings {
    # The top-level headings the kit writes into AGENTS.md, collected from the
    # locale sources themselves - every language, not just the one being
    # installed, and no copy of the prose to keep in sync here.
    param([Parameter(Mandatory = $true)][string]$KitRoot)
    $found = New-Object System.Collections.Generic.List[string]
    $sources = @(
        (Join-Path $KitRoot 'package1_opencode_plexus\config\locales'),
        (Join-Path $KitRoot 'package2_browser_agent\config\locales')
    )
    foreach ($dir in $sources) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Recurse -Filter 'AGENTS*.md' -File)) {
            foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding UTF8)) {
                if ($line -match '^#\s+\S' -and -not $found.Contains($line.Trim())) { $found.Add($line.Trim()) | Out-Null }
            }
        }
    }
    return $found
}

function Remove-LegacyKitSections {
    # Kit versions released before the marker system wrote these sections into
    # AGENTS.md with no markers around them. Set-MarkedBlock cannot find such a
    # section, so on the next install it survives as a second copy of the rules -
    # and, when the language was changed between installs, a copy in the OTHER
    # language, which is what actually drives the model's answers. Strip any kit
    # section that sits outside the markers. Returns $true when something went.
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Headings
    )
    if (-not (Test-Path -LiteralPath $Path) -or $Headings.Count -eq 0) { return $false }

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $out = New-Object System.Collections.Generic.List[string]
    $inMarked = $false
    $dropping = $false
    $removed = $false
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^<!-- opencode-kit:[^:]+:start -->$') {
            $inMarked = $true; $dropping = $false
        } elseif ($line -match '^<!-- opencode-kit:[^:]+:end -->$') {
            $inMarked = $false; $out.Add($line) | Out-Null; continue
        }
        if (-not $inMarked) {
            if ($Headings -contains $line.Trim()) { $dropping = $true; $removed = $true }
            elseif ($dropping -and $line -match '^#\s+\S') { $dropping = $false }
        }
        if (-not $dropping) { $out.Add($line) | Out-Null }
    }
    if (-not $removed) { return $false }

    $clean = ($out -join "`r`n") -replace "(`r`n){3,}", "`r`n`r`n"
    Write-TextFile -Path $Path -Text ($clean.Trim() + "`r`n")
    return $true
}

function Remove-MarkedBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Id
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $mk = Get-BlockMarkers $Id
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $pattern = [regex]::Escape($mk.Start) + '[\s\S]*?' + [regex]::Escape($mk.End)
    if (-not [regex]::IsMatch($text, $pattern)) { return $false }
    $text = ([regex]::Replace($text, $pattern, '')).Trim()
    if ($text.Length -eq 0) {
        Remove-Item -LiteralPath $Path -Force
    } else {
        Write-TextFile -Path $Path -Text ($text + "`r`n")
    }
    return $true
}

function Remove-KitPath {
    param([Parameter(Mandatory = $true)][string]$Path, [hashtable]$M)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    Remove-Item -LiteralPath $Path -Force -Recurse
    Write-Host ($M.u_removed -f $Path)
    return $true
}

function Remove-HashKey {
    # Removes $Key from the nested hashtable $Parent.$Section, dropping the section
    # itself once it is empty. Returns $true when something was actually removed.
    # $node must NOT be called $section: PowerShell variable names are
    # case-insensitive, so it would overwrite the [string]-typed $Section
    # parameter and silently stringify the dictionary.
    param($Parent, [string]$Section, [string]$Key)
    if (-not (Test-HasKey $Parent $Section)) { return $false }
    $node = $Parent[$Section]
    if (-not (Test-HasKey $node $Key)) { return $false }
    $node.Remove($Key)
    if ($node.Count -eq 0) { $Parent.Remove($Section) }
    return $true
}
