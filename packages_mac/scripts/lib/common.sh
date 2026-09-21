#!/bin/bash
# Shared helpers for the OpenCode office kit (install.sh / uninstall.sh).
#
# This file is deliberately ASCII-only: every user-visible string lives in
# scripts/i18n/*.json and is loaded through kit.py, so no translation is ever
# embedded in a shell script.
#
# Anything that has to parse JSON or rewrite Markdown is delegated to
# lib/kit.py - see the note at the top of that file.

KIT_PY=""
PY=""

kit_init() {
    # $1 = scripts dir
    local scripts_dir="$1"
    KIT_PY="$scripts_dir/lib/kit.py"

    if command -v python3 >/dev/null 2>&1; then PY="python3"
    elif command -v python >/dev/null 2>&1; then PY="python"
    else
        echo "ERROR: python3 was not found. Install it with: xcode-select --install" >&2
        exit 1
    fi
    [ -f "$KIT_PY" ] || { echo "ERROR: $KIT_PY is missing - the kit files are damaged." >&2; exit 1; }
}

kit() { "$PY" "$KIT_PY" "$@"; }

resolve_lang() {
    # $1 = requested language ('' to auto-detect). macOS reports the user's
    # preferred languages through AppleLanguages, e.g. ("ru-RU", "en-US").
    local want="$1"
    if [ -n "$want" ]; then printf '%s\n' "$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"; return; fi
    local ui=""
    if command -v defaults >/dev/null 2>&1; then
        ui="$(defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n"()' | cut -d, -f1)"
    fi
    [ -n "$ui" ] || ui="${LANG:-en}"
    case "$ui" in ru*) echo ru ;; *) echo en ;; esac
}

load_messages() {
    # $1 = i18n dir, $2 = language. Defines M_<key> variables in the caller.
    local table
    table="$(kit msgs "$1" "$2")" || exit 1
    eval "$table"
}

msg() {
    # msg KEY [args...] - substitutes {0}, {1}, ... positionally.
    local name="M_$1"; shift
    local text="${!name-}"
    local i=0 arg
    for arg in "$@"; do
        text="${text//\{$i\}/$arg}"
        i=$((i + 1))
    done
    printf '%s\n' "$text"
}

# ---------- Output ----------
# Colours are skipped when stdout is not a terminal, so a piped log stays clean.
if [ -t 1 ]; then
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_OFF=$'\033[0m'
else
    C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_OFF=""
fi

say()   { printf '%s\n' "$*"; }
head_() { printf '\n%s======================================================%s\n' "$C_CYAN" "$C_OFF"
          printf '%s %s%s\n' "$C_CYAN" "$*" "$C_OFF"
          printf '%s======================================================%s\n' "$C_CYAN" "$C_OFF"; }
step()  { printf '\n%s%s%s\n' "$C_YELLOW" "$*" "$C_OFF"; }
ok()    { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_OFF"; }
warn()  { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_OFF"; }
fail()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }

backup_file() {
    # Copies $1 next to itself with a timestamp; prints the path it used.
    # Only opencode.json goes through this - see kit.py auth-del for why
    # auth.json deliberately does not.
    local path="$1"
    [ -f "$path" ] || return 0
    local stamp backup i
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$path.backup-$stamp"
    i=1
    while [ -e "$backup" ]; do backup="$path.backup-$stamp-$i"; i=$((i + 1)); done
    cp "$path" "$backup"
    msg backup_created "$backup"
}

remove_kit_path() {
    # remove_kit_path PATH - deletes it and reports; returns 1 if absent.
    [ -e "$1" ] || return 1
    rm -rf "$1"
    msg u_removed "$1"
    return 0
}

strip_quarantine() {
    # Files copied out of a downloaded folder carry com.apple.quarantine, which
    # makes Finder refuse to run a .command on double-click.
    [ -e "$1" ] || return 0
    xattr -dr com.apple.quarantine "$1" 2>/dev/null || true
}
