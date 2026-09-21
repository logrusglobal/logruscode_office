#!/bin/bash
# OpenCode office kit - double-click this file to remove the kit.
#
# It asks which packages to remove and confirms before touching anything.
# Documents are never touched, opencode.json is backed up first, and settings
# added by hand are left alone. Pressing Enter at the confirmation cancels:
# removal only happens if you answer "y".
#
# For unattended removal use scripts/uninstall.sh directly.
cd "$(dirname "$0")" || exit 1
exec bash "./scripts/interactive.sh" uninstall
