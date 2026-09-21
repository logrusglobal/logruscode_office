#!/usr/bin/env bash
# OpenCode office kit - uninstaller (bash wrapper).
#
# The kit removes Windows-side files, registry-free config and a desktop .lnk
# shortcut, so the real work lives in uninstall.ps1. This wrapper exists so the
# kit can be driven from Git Bash / WSL-style shells: it finds PowerShell and
# forwards every argument unchanged.
#
#   ./uninstall.sh
#   ./uninstall.sh -Packages 2 -Purge
#
# See uninstall.ps1 for the full parameter list.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/uninstall.ps1"

shell=""
for candidate in pwsh powershell.exe powershell; do
    if command -v "$candidate" >/dev/null 2>&1; then
        shell="$candidate"
        break
    fi
done

if [ -z "$shell" ]; then
    echo "PowerShell was not found. This kit targets Windows - run uninstall.ps1 from a PowerShell window:" >&2
    echo "    Set-ExecutionPolicy -Scope Process Bypass" >&2
    echo "    .\\uninstall.ps1" >&2
    exit 1
fi

# Git Bash hands POSIX paths to a Windows binary, which cannot read them.
if command -v cygpath >/dev/null 2>&1; then
    script="$(cygpath -w "$script")"
fi

exec "$shell" -NoProfile -ExecutionPolicy Bypass -File "$script" "$@"
