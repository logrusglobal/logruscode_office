#!/bin/bash
# OpenCode office kit - interactive front-end for Install.command / Uninstall.command
# ============================================================================
# Asks only for what cannot be guessed (language, the employee's Plexus key,
# which packages), shows what is about to happen, then calls install.sh or
# uninstall.sh to do the actual work. Those two stay fully scriptable for
# unattended installs - this file only collects answers.
#
# Not meant to be launched by hand: double-click Install.command or
# Uninstall.command in the kit folder instead.
#
# Like the other scripts here this one is ASCII-only; every visible string,
# including the language names in the first prompt, comes from scripts/i18n.
# ============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPTS_DIR/lib/common.sh"
kit_init "$SCRIPTS_DIR"

MODE="${1:-install}"
shift || true
# Not asked for in the prompts - forwarded when given, so the launcher can be
# exercised against a throwaway folder.
EXTRA=("$@")

TARGET_SHOWN="$HOME/.config/opencode"
i=0
while [ $i -lt ${#EXTRA[@]} ]; do
    [ "${EXTRA[$i]}" = "--target-dir" ] && TARGET_SHOWN="${EXTRA[$((i + 1))]}"
    i=$((i + 1))
done

ask() {
    # ask PROMPT -> echoes the trimmed answer
    local prompt="$1" answer
    printf '\n%s%s%s ' "$C_CYAN" "$prompt" "$C_OFF" >&2
    IFS= read -r answer || answer=""
    printf '%s' "$answer" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# ---------- Language ----------
LANGS=()
while IFS= read -r l; do LANGS+=("$l"); done < <(kit langs "$SCRIPTS_DIR/i18n")
LANG_CODE="$(resolve_lang "")"

lang_name() { "$PY" "$KIT_PY" msgs "$SCRIPTS_DIR/i18n" "$1" | sed -n "s/^M_ui_lang_name='\(.*\)'$/\1/p"; }
lang_prompt() { "$PY" "$KIT_PY" msgs "$SCRIPTS_DIR/i18n" "$1" | sed -n "s/^M_ui_lang_prompt='\(.*\)'$/\1/p"; }

if [ "${#LANGS[@]}" -gt 1 ]; then
    prompts=""
    for l in "${LANGS[@]}"; do prompts="${prompts:+$prompts / }$(lang_prompt "$l")"; done
    head_ "$prompts"
    n=1
    for l in "${LANGS[@]}"; do
        marker=" "; [ "$l" = "$LANG_CODE" ] && marker="*"
        printf '  [%d]%s %s\n' "$n" "$marker" "$(lang_name "$l")"
        n=$((n + 1))
    done
    picked="$(ask "1-${#LANGS[@]} [*]")"
    case "$picked" in
        ''|*[!0-9]*) ;;
        *) if [ "$picked" -ge 1 ] && [ "$picked" -le "${#LANGS[@]}" ]; then
               LANG_CODE="${LANGS[$((picked - 1))]}"
           fi ;;
    esac
fi
load_messages "$SCRIPTS_DIR/i18n" "$LANG_CODE"

finish() { printf '\n'; printf '%s ' "$(msg ui_press_enter)"; IFS= read -r _ || true; }

# ---------- Collect answers ----------
KEY=""
PURGE=0
if [ "$MODE" = "install" ]; then head_ "$(msg ui_title_install)"; else head_ "$(msg ui_title_uninstall)"; fi
[ "$MODE" = "uninstall" ] && warn "$(msg ui_uninstall_warn)"

if [ "$MODE" = "install" ]; then
    while true; do
        KEY="$(ask "$(msg ui_key_prompt)")"
        if [ -z "$KEY" ]; then warn "$(msg ui_cancelled)"; finish; exit 0; fi
        case "$KEY" in sk-*) break ;; *) warn "$(msg ui_key_invalid)" ;; esac
    done
fi

if [ "$MODE" = "install" ]; then PKG_PROMPT="$(msg ui_packages_prompt)"; else PKG_PROMPT="$(msg ui_packages_prompt_remove)"; fi
PACKAGES=""
while [ -z "$PACKAGES" ]; do
    raw="$(ask "$PKG_PROMPT")"
    if [ -z "$raw" ]; then PACKAGES="1,2,3"; break; fi
    normalized="$(printf '%s' "$raw" | tr ',;' '  ' | tr -s ' ')"
    bad=0
    for p in $normalized; do case "$p" in 1|2|3) ;; *) bad=1 ;; esac; done
    if [ "$bad" = "0" ] && [ -n "$normalized" ]; then
        PACKAGES="$(printf '%s' "$normalized" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')"
    else
        warn "$(msg ui_packages_invalid)"
    fi
done

if [ "$MODE" = "uninstall" ] && printf '%s' "$PACKAGES" | grep -q 2; then
    answer="$(ask "$(msg ui_purge_prompt)")"
    printf '%s' "$answer" | grep -Eqi "$(msg ui_yes_pattern)" && PURGE=1
fi

# ---------- Confirm ----------
printf '\n%s\n' "$(msg ui_summary)"
say "  $(msg ui_sum_lang "$(lang_name "$LANG_CODE")")"
say "  $(msg ui_sum_packages "$PACKAGES")"
if [ "$MODE" = "install" ]; then
    if [ "${#KEY}" -gt 14 ]; then
        shown="${KEY:0:7}...${KEY: -4}"
    else
        shown="..."
    fi
    say "  $(msg ui_sum_key "$shown")"
fi
say "  $(msg ui_sum_target "$TARGET_SHOWN")"
[ "$PURGE" = "1" ] && warn "  $(msg ui_sum_purge)"

if [ "$MODE" = "install" ]; then
    # Enter means yes: the summary has already been shown and nothing is destructive.
    answer="$(ask "$(msg ui_confirm)")"
    if printf '%s' "$answer" | grep -Eqi "$(msg ui_no_pattern)"; then
        warn "$(msg ui_cancelled)"; finish; exit 0
    fi
else
    # Removal defaults to NO: Enter must never delete anything.
    answer="$(ask "$(msg ui_confirm_remove)")"
    if ! printf '%s' "$answer" | grep -Eqi "$(msg ui_yes_pattern)"; then
        warn "$(msg ui_cancelled)"; finish; exit 0
    fi
fi

# ---------- Run ----------
set +e
if [ "$MODE" = "install" ]; then
    bash "$SCRIPTS_DIR/install.sh" --plexus-key "$KEY" --lang "$LANG_CODE" --packages "$PACKAGES" "${EXTRA[@]+"${EXTRA[@]}"}"
else
    if [ "$PURGE" = "1" ]; then
        bash "$SCRIPTS_DIR/uninstall.sh" --lang "$LANG_CODE" --packages "$PACKAGES" --purge "${EXTRA[@]+"${EXTRA[@]}"}"
    else
        bash "$SCRIPTS_DIR/uninstall.sh" --lang "$LANG_CODE" --packages "$PACKAGES" "${EXTRA[@]+"${EXTRA[@]}"}"
    fi
fi
status=$?
set -e

if [ "$status" -ne 0 ]; then
    printf '\n'
    warn "$(msg ui_failed)"
    finish
    exit 1
fi

finish
