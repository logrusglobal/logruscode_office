#!/bin/bash
# OpenCode office kit - uninstaller for packages 1-3 (macOS)
# ============================================================================
# Takes back out exactly what install.sh put in, and nothing else:
#   - the keys it added to opencode.json (the file is backed up first, and is
#     left in place with any settings the user added by hand);
#   - the blocks it fenced with markers in AGENTS.md (hand-written text in that
#     file survives; the file is deleted only if nothing else remains);
#   - the agent files, start-browser.command, ensure-browser.command and the
#     Desktop launcher they are reached through;
#   - the Plexus key in auth.json (package 1), with no backup left behind, plus
#     any auth.json backup an earlier version of this script wrote.
#
# NOT removed: the user's documents, the Chrome debug profile with its logins
# (pass --purge), the config backups, and the OpenCode Desktop application.
#
# Run (Terminal):
#   chmod +x uninstall.sh
#   ./uninstall.sh
#
# Options:
#   --lang en|ru       language of the console output. Default: system language.
#   --packages 1,2,3   which packages to remove. Default: all (in reverse order)
#   --purge            also delete the Chrome debug profile (logins and cookies!)
#   --target-dir DIR   OpenCode config folder (default ~/.config/opencode)
#   --data-dir DIR     OpenCode data folder  (default ~/.local/share/opencode)
#
# Examples:
#   ./uninstall.sh
#   ./uninstall.sh --packages 2 --purge
# ============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPTS_DIR/lib/common.sh"
kit_init "$SCRIPTS_DIR"

LANG_OPT=""
PACKAGES="1,2,3"
TARGET_DIR="$HOME/.config/opencode"
DATA_DIR="$HOME/.local/share/opencode"
PURGE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --lang) LANG_OPT="$2"; shift 2 ;;
        --packages) PACKAGES="$2"; shift 2 ;;
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --purge) PURGE=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

LANG_CODE="$(resolve_lang "$LANG_OPT")"
load_messages "$SCRIPTS_DIR/i18n" "$LANG_CODE"

SELECTED=""
for p in $(printf '%s' "$PACKAGES" | tr ',;' '  '); do
    case "$p" in
        1|2|3) case " $SELECTED " in *" $p "*) ;; *) SELECTED="$SELECTED $p" ;; esac ;;
        *) fail "$(msg err_bad_package "$p")" ;;
    esac
done
has_pkg() { case " $SELECTED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

head_ "$(msg hdr_uninstall)"
say "$(msg lang_line "$LANG_CODE" "$TARGET_DIR")"
say "$(msg pkg_selected "$(printf '%s' "$SELECTED" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/^,//;s/,$//')")"

AGENTS_DIR="$TARGET_DIR/agents"
CONFIG="$TARGET_DIR/opencode.json"
AGENTS_MD="$TARGET_DIR/AGENTS.md"

if [ -f "$CONFIG" ]; then
    backup_file "$CONFIG"
else
    warn "$(msg u_no_config)"
fi

CLEANED=""
note_cleaned() { [ -n "$1" ] && CLEANED="${CLEANED:+$CLEANED,}$1"; }

# Packages are removed high-to-low so that package 1, which owns the base block
# of AGENTS.md, cleans up last.
for pkg in 3 2 1; do
    has_pkg "$pkg" || continue
    touched=0

    # ------------------------------------------------------------------
    if [ "$pkg" = "3" ]; then
        head_ "$(msg u_p3)"
        if [ -f "$CONFIG" ]; then
            if out="$(kit cfg-del "$CONFIG" --section mcp.office-word --section mcp.office-excel)"; then
                note_cleaned "$out"; touched=1
            fi
        fi
    fi

    # ------------------------------------------------------------------
    if [ "$pkg" = "2" ]; then
        head_ "$(msg u_p2)"
        if [ -f "$CONFIG" ]; then
            if out="$(kit cfg-del "$CONFIG" --section mcp.chrome-devtools --section 'permission.chrome-devtools_*')"; then
                note_cleaned "$out"; touched=1
            fi
        fi
        remove_kit_path "$AGENTS_DIR/browser.md" && touched=1
        remove_kit_path "$TARGET_DIR/start-browser.command" && touched=1
        remove_kit_path "$TARGET_DIR/ensure-browser.command" && touched=1
        if kit block-del "$AGENTS_MD" browser; then
            msg u_removed 'AGENTS.md (web rules)'; touched=1
        fi

        # The launcher name is localized, so every language's name is tried -
        # the kit may well have been installed in the other language.
        for lng in $(kit langs "$SCRIPTS_DIR/i18n"); do
            name="$("$PY" "$KIT_PY" msgs "$SCRIPTS_DIR/i18n" "$lng" | sed -n "s/^M_p2_shortcut_name='\(.*\)'$/\1/p")"
            [ -n "$name" ] || continue
            remove_kit_path "$HOME/Desktop/$name.command" && touched=1
        done

        PROFILE_DIR="$TARGET_DIR/chrome-debug-profile"
        if [ -d "$PROFILE_DIR" ]; then
            if [ "$PURGE" = "1" ]; then
                remove_kit_path "$PROFILE_DIR" && touched=1
            else
                warn "$(msg u_profile_kept "$PROFILE_DIR")"
            fi
        fi
    fi

    # ------------------------------------------------------------------
    if [ "$pkg" = "1" ]; then
        head_ "$(msg u_p1)"
        if [ -f "$CONFIG" ]; then
            if out="$(kit cfg-del "$CONFIG" --section provider.lgplexus --section agent.build)"; then
                note_cleaned "$out"; touched=1
            fi
            # model / small_model only when they still point at the kit's provider,
            # and default_agent only when it is still the kit's agent.
            if out="$(kit cfg-del "$CONFIG" --top model --top small_model --prefix 'lgplexus/')"; then
                note_cleaned "$out"; touched=1
            fi
            if out="$(kit cfg-del "$CONFIG" --top default_agent --equals office)"; then
                note_cleaned "$out"; touched=1
            fi
        fi
        remove_kit_path "$AGENTS_DIR/office.md" && touched=1
        if kit block-del "$AGENTS_MD" base; then
            msg u_removed 'AGENTS.md (base rules)'; touched=1
        fi

        # auth.json is NOT backed up on the way out, unlike opencode.json - see
        # the note on auth-del in lib/kit.py for why.
        if kit auth-del "$DATA_DIR/auth.json" lgplexus; then
            msg u_removed 'auth.json (lgplexus key)'; touched=1
        fi

        # Kit versions up to this one did back auth.json up, so a plaintext key
        # can be lying around from an earlier uninstall. Sweep those away too.
        stale=0
        for f in "$DATA_DIR"/auth.json.backup-*; do
            [ -e "$f" ] || continue
            rm -f "$f"; stale=$((stale + 1))
        done
        if [ "$stale" -gt 0 ]; then
            ok "$(msg u_auth_backups "$stale")"; touched=1
        fi
    fi

    [ "$touched" = "0" ] && say "$(msg u_nothing)"
done

[ -n "$CLEANED" ] && ok "$(msg u_config_clean "$CLEANED")"

head_ "$(msg done_uninstall)"
say "$(msg next_steps)"
say "$(msg u_restart_hint)"
say "$(msg u_backups_hint)"
has_pkg 1 && say "$(msg u_app_hint)"
exit 0
