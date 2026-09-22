# OpenCode office kits

Installation kits that turn [OpenCode](https://opencode.ai) into a ready-to-use
assistant for a non-technical office employee: Word and Excel by plain words in
the chat, websites driven in a real Chrome, DeepSeek reached through Logrus
Plexus. An administrator installs a kit on the employee's machine; the employee
never opens a terminal.

There are two kits, one per platform, kept deliberately parallel:

| Kit | Platform | Entry points |
|---|---|---|
| [`packages_win/`](packages_win/) | Windows 10/11 | `Install.cmd`, `Uninstall.cmd` (double-click) |
| [`packages_mac/`](packages_mac/) | macOS (Apple Silicon or Intel) | `Install.command`, `Uninstall.command` (double-click) |

Each kit documents itself in English and Russian — start at
[`packages_win/docs/en/README.md`](packages_win/docs/en/README.md) or
[`packages_mac/docs/en/README.md`](packages_mac/docs/en/README.md).
[`CHANGELOG.md`](CHANGELOG.md) records what has changed and why.

## The three packages

Both kits install the same three packages. They are independent — install any
combination — except that package 1 must come first, because packages 2 and 3
only extend the configuration it creates.

| Package | What the employee gets |
|---|---|
| 1 — OpenCode + Plexus | The OpenCode Desktop app, DeepSeek through Plexus with the employee's key, the `build` agent disabled, `office` as the primary agent |
| 2 — Browser agent | The `@browser` subagent: it opens and drives a real Chrome, fills forms, collects contacts and documents from websites |
| 3 — OfficeCLI | The `office-word` and `office-excel` MCP servers: create and edit `.docx` and `.xlsx` by asking in the chat |

## Quick start

Windows, from the kit folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd scripts
.\install.ps1 -PlexusKey "sk-air-XXXX"              # all packages, language auto-detected
.\install.ps1 -PlexusKey "sk-air-XXXX" -Lang ru -Packages 1,3
.\uninstall.ps1 -Packages 2
```

macOS, from the kit folder:

```bash
cd scripts
./install.sh --plexus-key "sk-air-XXXX"             # all packages, language auto-detected
./install.sh --plexus-key "sk-air-XXXX" --lang ru --packages 1,3
./uninstall.sh --packages 2
```

Or just double-click `Install.cmd` / `Install.command`, which asks for the
language, the key and the packages, then does the rest.

The employee's Plexus key (`sk-air-…`) comes from Vaultwarden.

## How the two kits stay in step

The kits share a design so that a change to the agent prompts or the install
logic can be carried from one to the other without re-reading both:

- **Same package layout.** `package1_opencode_plexus/`, `package2_browser_agent/`,
  `package3_officecli/`, with `config/locales/<lang>/` inside.
- **Same split between prose and logic.** Language-neutral files
  (`opencode.json`, the MCP fragments, the browser launchers) exist once; only
  prose is duplicated per language, under `locales/<lang>/` and `docs/<lang>/`.
- **Same message keys.** `scripts/i18n/en.json` and `ru.json` hold every
  user-visible string under identical key names in both kits; a missing
  translation falls back to English. No translated string is ever embedded in a
  script, which also keeps the scripts themselves ASCII-only.
- **Same marked blocks.** What the kit adds to the employee's `AGENTS.md` is
  fenced with `<!-- opencode-kit:<id>:start -->` … `:end` markers, so uninstall
  removes exactly those blocks and leaves anything hand-written alone.
- **Same install-time placeholders.** `{{ENSURE_BROWSER}}` and `{{MODEL}}` are
  substituted into the `@browser` prompt when it is installed.
- **Same guarantees.** Nothing is overwritten blindly: `opencode.json` is backed
  up before every change, a reinstall keeps MCP servers and permissions that are
  already configured, and re-running an installer duplicates nothing.

What legitimately differs is the platform: PowerShell against bash + Python,
`.cmd` against `.command`, a `.lnk` shortcut against a file on the Desktop, an
NSIS installer against a DMG, and — only on macOS — absolute paths to `npx` and
`uvx`, because an app launched from the Dock inherits launchd's `PATH` rather
than the one from the user's shell profile.

## Working in this repository

- Change both kits, or say in the commit why only one moved.
- Line endings are load-bearing: `.gitattributes` pins LF for `packages_mac` and
  CRLF for `packages_win`. The documented workflow copies a kit folder straight
  onto the target machine, so a macOS script checked out with CRLF fails at the
  shebang with `bad interpreter: /bin/bash^M`.
- The macOS shell scripts and `Install.command` / `Uninstall.command` need their
  executable bit recorded in git (`git update-index --chmod=+x`), because
  `core.filemode` is off on Windows checkouts.
- The employee's API key is a secret at rest. It lives only in
  `auth.json`; nothing in either kit may copy it anywhere else, including into a
  backup — see the note on `auth-del` / the uninstaller for the reasoning.
