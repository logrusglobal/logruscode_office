# OpenCode for office staff — installation kit

A kit for installing the OpenCode AI assistant with access to DeepSeek through Plexus. It is installed for employees by administrators (Victor, Oleg Sigutin) — the employee needs neither PowerShell nor testing: after the installation they are shown example tasks ([task_examples.md](task_examples.md)).

One kit covers both languages. The interface language of the installer, the documentation and the assistant's own prompts is chosen with `-Lang en` or `-Lang ru`; without the switch the installer follows the Windows UI language.

## What the kit contains

| Package | What it installs | Who needs it |
|---|---|---|
| 1 — [OpenCode + Plexus](package1.md) | The OpenCode Desktop app, DeepSeek access through Plexus (the employee's key), the build agent disabled, the office agent as the primary one | Everyone |
| 2 — [Browser agent](package2.md) | The @browser subagent: driving websites in Chrome, collecting contacts and documents | Anyone who needs "from a website" tasks |
| 3 — [OfficeCLI](package3.md) | Creating and editing Word documents and Excel spreadsheets by plain words in the chat | Anyone who needs Word/Excel documents |

The packages are independent — install any combination with `-Packages`. Package 1 must come first: packages 2 and 3 only extend the config it creates.

## Installation for one employee (20–30 minutes)

1. Take the employee's key from Vaultwarden (the entry with the Plexus key, format `sk-air-…`). If there is no entry — create a key in Plexus and record it in Vaultwarden.
2. Copy the kit folder to the employee's computer (for example, `D:\OpenCode_Kit`).
3. Run the installer from PowerShell (Start → type `powershell` → Enter):

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   cd "D:\OpenCode_Kit\scripts"
   .\install.ps1 -PlexusKey "sk-air-XXXX"
   ```

   That installs all three packages. To install a subset, name them:

   ```powershell
   .\install.ps1 -PlexusKey "sk-air-XXXX" -Lang en -Packages 1,3
   ```

4. Launch OpenCode Desktop and **show the employee** 2–3 examples from [task_examples.md](task_examples.md) — so they immediately see what they can now do (for example: "create a letter in Word" and "collect contacts from a website into Excel").
5. For package 2: explain that before "from a website" tasks they need to launch the "Browser for OpenCode" shortcut (created on the desktop automatically).

### Installer parameters

| Parameter | Meaning |
|---|---|
| `-PlexusKey "sk-air-XXXX"` | The employee's key. Required for package 1. |
| `-Lang en` \| `ru` | Language of the docs, the agent prompts and the console output. Default: the Windows UI language. |
| `-Packages 1,2,3` | Which packages to install. Default: all three. |
| `-SkipAppInstall` | Do not download/install the OpenCode Desktop application. |
| `-KeepBuild` | Do not disable the build agent (for experienced employees). |
| `-NoShortcut` | Do not create the browser shortcut on the desktop. |
| `-SkipChecks` | Skip installing `uv` and the MCP handshake test (offline installs). |
| `-TargetDir`, `-DataDir` | Override the OpenCode config and data folders. |

From Git Bash, `./install.sh` takes the same arguments and forwards them to PowerShell.

## Removal

```powershell
cd "D:\OpenCode_Kit\scripts"
.\uninstall.ps1                     # all three packages
.\uninstall.ps1 -Packages 2         # only the browser agent
.\uninstall.ps1 -Packages 2 -Purge  # ...and delete the Chrome debug profile too
```

The uninstaller takes back out exactly what the installer put in: its keys in `opencode.json`, its marked blocks in `AGENTS.md`, the agent files, `start-browser.cmd`, the desktop shortcut and the Plexus key in `auth.json`. Settings the employee added by hand are left alone, and the config is backed up first.

Not removed: the employee's documents, the Chrome profile with its logins (use `-Purge`), the config backups, and the OpenCode Desktop application itself.

## Per-employee checklist

| Item | Done |
|---|---|
| Package 1 installed, the employee's Plexus key recorded | |
| Model in OpenCode: `lgplexus/deepseek-deepseek-v4-pro`, the Default / High / Max switch is present | |
| The build agent is disabled (in the Tab switcher: office, plan) | |
| Package 2 installed (if needed), the "Browser for OpenCode" shortcut is on the desktop | |
| Package 3 installed (if needed), HANDSHAKE OK verified | |
| The employee has been shown the example tasks | |

## Notes

- Nothing is overwritten blindly. `opencode.json` is backed up before every change (`opencode.json.backup-…`), a reinstall keeps MCP servers and permissions that are already configured, and re-running the installer is safe — it duplicates nothing.
- For experienced employees build may be left enabled: `-KeepBuild` (or enable it later — see section 5 of [package1.md](package1.md)).
- First installation: Lapaeva — build disabled, access through Plexus, OfficeCLI.

## Layout of the kit

```
scripts/        install.ps1, uninstall.ps1, the .sh wrappers,
                lib/common.ps1 and i18n/<lang>.json (all console messages)
docs/<lang>/    this documentation
package1_opencode_plexus/   opencode.json + the office agent, per language
package2_browser_agent/     the chrome-devtools MCP server, start-browser.cmd,
                            the @browser subagent, per language
package3_officecli/         the Word/Excel MCP servers and their handshake test
```

Language-neutral files (`opencode.json`, the MCP fragments, `start-browser.cmd`) exist once. Only prose is duplicated per language, under `locales/<lang>/` and `docs/<lang>/`. To add a language, add `scripts/i18n/<lang>.json` plus the matching `locales/<lang>/` and `docs/<lang>/` folders — any message you do not translate falls back to English.
