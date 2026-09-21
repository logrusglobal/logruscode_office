#!/bin/bash
# OpenCode office kit - installer for packages 1-3 (macOS)
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
# blocks added to AGENTS.md are fenced with markers so uninstall.sh can take
# exactly them back out.
#
# Run (Terminal):
#   chmod +x install.sh
#   ./install.sh --plexus-key "sk-air-XXXX"
#
# Options:
#   --plexus-key KEY     the employee's DeepSeek-through-Plexus key (required
#                        for package 1; created in Plexus, kept in Vaultwarden)
#   --lang en|ru         language of the docs, agent prompts and console output.
#                        Default: taken from the macOS system language.
#   --packages 1,2,3     which packages to install. Default: all three
#   --skip-app-install   do not download/install the OpenCode Desktop application
#   --keep-build         do NOT disable the build agent (for experienced staff)
#   --no-shortcut        do not put the browser launcher on the Desktop
#   --skip-checks        skip installing uv and the MCP handshake test (offline)
#   --target-dir DIR     OpenCode config folder (default ~/.config/opencode)
#   --data-dir DIR       OpenCode data folder  (default ~/.local/share/opencode)
#
# Examples:
#   ./install.sh --plexus-key "sk-air-XXXX"
#   ./install.sh --plexus-key "sk-air-XXXX" --lang ru --packages 1,3
#   ./install.sh --packages 2 --no-shortcut
# ============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPTS_DIR")"
# shellcheck source=lib/common.sh
. "$SCRIPTS_DIR/lib/common.sh"
kit_init "$SCRIPTS_DIR"

PLEXUS_KEY=""
LANG_OPT=""
PACKAGES="1,2,3"
TARGET_DIR="$HOME/.config/opencode"
DATA_DIR="$HOME/.local/share/opencode"
SKIP_APP=0
KEEP_BUILD=0
NO_SHORTCUT=0
SKIP_CHECKS=0

while [ $# -gt 0 ]; do
    case "$1" in
        --plexus-key) PLEXUS_KEY="$2"; shift 2 ;;
        --lang) LANG_OPT="$2"; shift 2 ;;
        --packages) PACKAGES="$2"; shift 2 ;;
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --skip-app-install) SKIP_APP=1; shift ;;
        --keep-build) KEEP_BUILD=1; shift ;;
        --no-shortcut) NO_SHORTCUT=1; shift ;;
        --skip-checks) SKIP_CHECKS=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

LANG_CODE="$(resolve_lang "$LANG_OPT")"
load_messages "$SCRIPTS_DIR/i18n" "$LANG_CODE"

# ---------- Validation, before anything is written ----------
PKGS="$(printf '%s' "$PACKAGES" | tr ',;' '  ' | tr -s ' ')"
SELECTED=""
for p in $PKGS; do
    case "$p" in
        1|2|3) case " $SELECTED " in *" $p "*) ;; *) SELECTED="$SELECTED $p" ;; esac ;;
        *) fail "$(msg err_bad_package "$p")" ;;
    esac
done
SELECTED="$(printf '%s' "$SELECTED" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//')"
has_pkg() { case " $SELECTED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

if has_pkg 1; then
    [ -n "$PLEXUS_KEY" ] || fail "$(msg err_need_key)"
    case "$PLEXUS_KEY" in sk-*) ;; *) fail "$(msg err_key_prefix)" ;; esac
fi

head_ "$(msg hdr_install)"
say "$(msg lang_line "$LANG_CODE" "$TARGET_DIR")"
say "$(msg pkg_selected "$(printf '%s' "$SELECTED" | tr ' ' ',')")"

AGENTS_DIR="$TARGET_DIR/agents"
CONFIG="$TARGET_DIR/opencode.json"
AGENTS_MD="$TARGET_DIR/AGENTS.md"
mkdir -p "$AGENTS_DIR"

# An AGENTS.md left by a pre-marker kit version still holds an unmarked copy of
# these rules - in whichever language that install used. It would sit above the
# blocks written below and quietly win, so take it out before writing anything.
HEADINGS_FILE="$(mktemp)"
trap 'rm -f "$HEADINGS_FILE"' EXIT
kit headings \
    "$KIT_ROOT/package1_opencode_plexus/config/locales" \
    "$KIT_ROOT/package2_browser_agent/config/locales" > "$HEADINGS_FILE"
if kit legacy-strip "$AGENTS_MD" "$HEADINGS_FILE"; then
    warn "$(msg legacy_block_removed)"
fi

# ============================================================================
# Package 1 - OpenCode Desktop + Plexus
# ============================================================================
if has_pkg 1; then
    head_ "$(msg p1_head)"
    P1_CONFIG="$KIT_ROOT/package1_opencode_plexus/config"
    P1_LOCALE="$P1_CONFIG/locales/$LANG_CODE"

    step "$(msg p1_app)"
    APP="/Applications/OpenCode.app"
    if [ -d "$APP" ] || [ "$SKIP_APP" = "1" ]; then
        say "$(msg p1_app_present)"
    else
        case "$(uname -m)" in
            arm64)  DMG_URL="https://opencode.ai/download/stable/darwin-aarch64-dmg" ;;
            x86_64) DMG_URL="https://opencode.ai/download/stable/darwin-x64-dmg" ;;
            *) fail "$(msg p1_app_warn "unknown architecture $(uname -m)")" ;;
        esac
        say "$(msg p1_app_download "$DMG_URL")"
        # A directory, not `mktemp -t ... .dmg`: appending the extension to a
        # name mktemp already created would leak the original temp file, and
        # hdiutil wants the .dmg suffix.
        DMG_DIR="$(mktemp -d)"
        DMG="$DMG_DIR/OpenCode.dmg"
        MOUNT_POINT=""
        # Always unmount and clean up, however this block ends.
        cleanup_dmg() {
            [ -n "$MOUNT_POINT" ] && hdiutil detach -quiet "$MOUNT_POINT" 2>/dev/null || true
            rm -rf "$DMG_DIR"
        }
        trap 'cleanup_dmg; rm -f "$HEADINGS_FILE"' EXIT
        if curl -L --fail --silent --show-error -o "$DMG" "$DMG_URL"; then
            say "$(msg p1_app_install)"
            MOUNT_POINT="$(hdiutil attach "$DMG" -nobrowse -readonly | grep -o '/Volumes/.*' | tail -1)"
            APP_SRC="$(find "$MOUNT_POINT" -maxdepth 2 -name '*.app' | head -1)"
            if [ -n "$APP_SRC" ]; then
                cp -R "$APP_SRC" /Applications/
                strip_quarantine "/Applications/$(basename "$APP_SRC")"
            else
                warn "$(msg p1_app_warn "no .app inside the disk image")"
            fi
        else
            warn "$(msg p1_app_warn "download failed")"
        fi
        cleanup_dmg
        MOUNT_POINT=""
        trap 'rm -f "$HEADINGS_FILE"' EXIT
    fi

    step "$(msg p1_config)"
    if [ -f "$CONFIG" ]; then backup_file "$CONFIG"; fi
    if [ "$KEEP_BUILD" = "1" ]; then
        CARRIED="$(kit cfg-base "$P1_CONFIG/opencode.json" "$CONFIG" --keep-build)"
    else
        CARRIED="$(kit cfg-base "$P1_CONFIG/opencode.json" "$CONFIG")"
    fi
    [ "$CARRIED" = "carried" ] && say "$(msg p1_config_kept)"

    kit block-set "$AGENTS_MD" base "$P1_LOCALE/AGENTS.md"
    cp "$P1_LOCALE/agents/office.md" "$AGENTS_DIR/office.md"
    ok "$(msg p1_config_ok)"

    step "$(msg p1_key)"
    mkdir -p "$DATA_DIR"
    kit auth-set "$DATA_DIR/auth.json" lgplexus "$PLEXUS_KEY"
    chmod 600 "$DATA_DIR/auth.json"
    ok "$(msg p1_key_ok "$DATA_DIR/auth.json")"

    if [ "$KEEP_BUILD" = "1" ]; then say "$(msg p1_keepbuild)"; else ok "$(msg p1_build_off)"; fi
fi

# Packages 2 and 3 only extend an existing config.
if { has_pkg 2 || has_pkg 3; } && [ ! -f "$CONFIG" ]; then
    fail "$(msg err_no_config "$CONFIG")"
fi

# ============================================================================
# Package 2 - the @browser subagent
# ============================================================================
if has_pkg 2; then
    head_ "$(msg p2_head)"
    P2_CONFIG="$KIT_ROOT/package2_browser_agent/config"
    P2_LOCALE="$P2_CONFIG/locales/$LANG_CODE"

    command -v node >/dev/null 2>&1 || warn "$(msg p2_node_warn)"
    # An absolute path, not the bare name: OpenCode is launched from the Dock,
    # where it inherits launchd's PATH and never sees the one from .zshrc.
    NPX="$(command -v npx || true)"
    [ -n "$NPX" ] || fail "$(msg err_npx)"

    step "$(msg p2_mcp)"
    backup_file "$CONFIG"
    FRAGMENT="$(mktemp)"
    kit render "$P2_CONFIG/mcp_chrome-devtools.json" "$FRAGMENT" --set "NPX=$NPX"
    kit cfg-merge "$CONFIG" "$FRAGMENT" --permission 'chrome-devtools_*' deny || fail "$(msg err_merge)"
    rm -f "$FRAGMENT"
    ok "$(msg p2_mcp_ok)"

    step "$(msg p2_files)"
    cp "$P2_CONFIG/start-browser.command" "$TARGET_DIR/start-browser.command"
    cp "$P2_CONFIG/ensure-browser.command" "$TARGET_DIR/ensure-browser.command"
    chmod +x "$TARGET_DIR/start-browser.command" "$TARGET_DIR/ensure-browser.command"
    strip_quarantine "$TARGET_DIR/start-browser.command"
    strip_quarantine "$TARGET_DIR/ensure-browser.command"

    # Two substitutions the agent file cannot make for itself:
    #  - the absolute path to ensure-browser.command, because the shell behind
    #    the agent's bash tool does not expand ~ or $HOME inside the prompt;
    #  - the model, because a subagent with no model line does NOT inherit the
    #    caller's model. OpenCode resolves its own default, which lands on the
    #    free tier and is refused by the provider.
    BROWSER_MODEL="$(kit cfg-get "$CONFIG" model)" || fail "$(msg err_no_model)"
    [ -n "$BROWSER_MODEL" ] || fail "$(msg err_no_model)"
    kit render "$P2_LOCALE/agents/browser.md" "$AGENTS_DIR/browser.md" \
        --set "ENSURE_BROWSER=$TARGET_DIR/ensure-browser.command" \
        --set "MODEL=$BROWSER_MODEL"
    say "$(msg p2_model "$BROWSER_MODEL")"

    kit block-set "$AGENTS_MD" browser "$P2_LOCALE/AGENTS_browser.md"
    ok "$(msg p2_files_ok)"

    step "$(msg p2_shortcut)"
    if [ "$NO_SHORTCUT" = "1" ]; then
        say "$(msg p2_shortcut_skip)"
    else
        LAUNCHER="$HOME/Desktop/$(msg p2_shortcut_name).command"
        cp "$P2_CONFIG/start-browser.command" "$LAUNCHER"
        chmod +x "$LAUNCHER"
        strip_quarantine "$LAUNCHER"
        ok "$(msg p2_shortcut_ok "$LAUNCHER")"
    fi
fi

# ============================================================================
# Package 3 - OfficeCLI (Word / Excel MCP servers)
# ============================================================================
if has_pkg 3; then
    head_ "$(msg p3_head)"
    P3_DIR="$KIT_ROOT/package3_officecli"
    UVX="$HOME/.local/bin/uvx"

    if [ "$SKIP_CHECKS" = "1" ]; then
        say "$(msg p3_checks_skip)"
        [ -x "$UVX" ] || UVX="$(command -v uvx || echo "$HOME/.local/bin/uvx")"
    else
        step "$(msg p3_uv)"
        if [ ! -x "$HOME/.local/bin/uv" ]; then
            say "$(msg p3_uv_install)"
            curl -LsSf https://astral.sh/uv/install.sh | sh || fail "$(msg p3_uv_fail)"
        fi
        [ -x "$UVX" ] || fail "$(msg err_uv_path "$UVX")"
        ok "$(msg p3_uv_ok "$UVX")"
    fi

    step "$(msg p3_mcp)"
    backup_file "$CONFIG"
    FRAGMENT="$(mktemp)"
    kit render "$P3_DIR/mcp_config.json" "$FRAGMENT" --set "UVX=$UVX"
    kit cfg-merge "$CONFIG" "$FRAGMENT" || fail "$(msg err_merge)"
    rm -f "$FRAGMENT"
    ok "$(msg p3_mcp_ok)"

    if [ "$SKIP_CHECKS" != "1" ]; then
        step "$(msg p3_test)"
        "$PY" "$P3_DIR/test_office_mcp.py" --lang "$LANG_CODE" || warn "$(msg p3_test_warn)"
    fi
fi

# ============================================================================
head_ "$(msg done_install)"
say "$(msg next_steps)"
say "$(msg next_restart)"
has_pkg 1 && say "$(msg next_model)"
has_pkg 2 && say "$(msg next_browser "$(msg p2_shortcut_name)")"
has_pkg 3 && say "$(msg next_office)"
say "$(msg next_examples "$LANG_CODE")"
exit 0
