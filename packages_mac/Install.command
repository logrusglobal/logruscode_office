#!/bin/bash
# OpenCode office kit - double-click this file to install.
#
# It asks for the language, the employee's Plexus key and which packages to
# install, then does everything else on its own. No Terminal knowledge and no
# administrator password are needed: everything is installed for the current
# user only.
#
# For unattended installs use scripts/install.sh directly - it takes the same
# work as options (--plexus-key, --lang, --packages, ...).
cd "$(dirname "$0")" || exit 1
exec bash "./scripts/interactive.sh" install
