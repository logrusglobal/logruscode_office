#!/bin/bash
# Double-click entry point: launches the debugging Chrome that the
# chrome-devtools MCP server (the @browser agent) drives. The actual work is in
# ensure-browser.command, which the @browser agent also runs on its own - so
# starting the browser by hand is optional, not required.
#
# This file is installed twice: next to ensure-browser.command in the OpenCode
# config folder, and as a standalone copy on the Desktop. The Desktop copy has
# no sibling, so fall back to the config folder.
here="$(cd "$(dirname "$0")" && pwd)"
ENSURE="$here/ensure-browser.command"
[ -x "$ENSURE" ] || ENSURE="$HOME/.config/opencode/ensure-browser.command"
if [ ! -x "$ENSURE" ]; then
    echo "ensure-browser.command not found. Reinstall package 2 of the OpenCode kit."
    read -r -n 1 -s -p "Press any key to close..."
    echo ""
    exit 1
fi

"$ENSURE"
status=$?
if [ "$status" -ne 0 ]; then
    read -r -n 1 -s -p "Press any key to close..."
    echo ""
fi
exit "$status"
