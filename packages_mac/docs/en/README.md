# OpenCode for office staff — installation kit

A kit for installing the OpenCode AI assistant with access to DeepSeek through Plexus. It is installed for employees by administrators (Victor, Oleg Sigutin) — the employee needs neither Terminal nor testing: after the installation they are shown example tasks ([task_examples.md](task_examples.md)).

One kit covers both languages. The interface language of the installer, the documentation and the assistant's own prompts is chosen with `--lang en` or `--lang ru`; without the switch the installer follows the macOS system language.

## What the kit contains

| Package | What it installs | Who needs it |
|---|---|---|
| 1 — [OpenCode + Plexus](package1.md) | The OpenCode Desktop app, DeepSeek access through Plexus (the employee's key), the build agent disabled, the office agent as the primary one | Everyone |
| 2 — [Browser agent](package2.md) | The @browser subagent: driving websites in Chrome, collecting contacts and documents | Anyone who needs "from a website" tasks |
| 3 — [OfficeCLI](package3.md) | Creating and editing Word documents and Excel spreadsheets by plain words in the chat | Anyone who needs Word/Excel documents |

The packages are independent — install any combination with `--packages`. Package 1 must come first: packages 2 and 3 only extend the config it creates.

## Installation for one employee (20–30 minutes)

1. Take the employee's key from Vaultwarden (the entry with the Plexus key, format `sk-air-…`). If there is no entry — create a key in Plexus and record it in Vaultwarden.
2. Copy the kit folder to the employee's computer (for example, `~/Downloads/OpenCode_Kit`).
3. **Double-click `Install.command`** in the kit folder. It asks three things — the language, the employee's Plexus key, and which packages (press Enter for all three) — shows a summary, and does the rest itself. No Terminal knowledge and no administrator password are needed: everything is installed for the current user only.

   For unattended or scripted installs, call the engine directly from Terminal (Spotlight → type `Terminal` → Enter):

   ```bash
cd ~/Downloads/OpenCode_Kit/scripts
   ./install.sh --plexus-key "sk-air-XXXX"
   ./install.sh --plexus-key "sk-air-XXXX" --lang en --packages 1,3
   ```

4. Launch OpenCode Desktop and **show the employee** 2–3 examples from [task_examples.md](task_examples.md) — so they immediately see what they can now do (for example: "create a letter in Word" and "collect contacts from a website into Excel").
5. For package 2: explain that "from a website" tasks need nothing launched by hand — the agent opens Chrome itself; the "Browser for OpenCode" file on the Desktop is only a manual fallback.

### Installer parameters

| Parameter | Meaning |
|---|---|
| `--plexus-key "sk-air-XXXX"` | The employee's key. Required for package 1. |
| `--lang en` \| `ru` | Language of the docs, the agent prompts and the console output. Default: the macOS system language. |
| `--packages 1,2,3` | Which packages to install. Default: all three. |
| `--skip-app-install` | Do not download/install the OpenCode Desktop application. |
| `--keep-build` | Do not disable the build agent (for experienced employees). |
| `--no-shortcut` | Do not put the browser launcher on the Desktop. |
| `--skip-checks` | Skip installing `uv` and the MCP handshake test (offline installs). |
| `--target-dir`, `--data-dir` | Override the OpenCode config and data folders. |


## Removal

**Double-click `Uninstall.command`** in the kit folder. It asks which packages to remove and confirms before touching anything — pressing Enter at the confirmation cancels, so removal only happens on an explicit "y".

Or from Terminal:

```bash
cd ~/Downloads/OpenCode_Kit/scripts
./uninstall.sh                     # all three packages
./uninstall.sh --packages 2         # only the browser agent
./uninstall.sh --packages 2 --purge  # ...and delete the Chrome debug profile too
```

The uninstaller takes back out exactly what the installer put in: its keys in `opencode.json`, its marked blocks in `AGENTS.md`, the agent files, `start-browser.command`, `ensure-browser.command`, the Desktop launcher and the Plexus key in `auth.json`. Settings the employee added by hand are left alone, and the config is backed up first.

Not removed: the employee's documents, the Chrome profile with its logins (use `--purge`), the config backups, and the OpenCode Desktop application itself.

## Per-employee checklist

| Item | Done |
|---|---|
| Package 1 installed, the employee's Plexus key recorded | |
| Model in OpenCode: `lgplexus/deepseek-deepseek-v4-pro`, the Default / High / Max switch is present | |
| The build agent is disabled (in the Tab switcher: office, plan) | |
| Package 2 installed (if needed), the "Browser for OpenCode" file is on the Desktop | |
| Package 3 installed (if needed), HANDSHAKE OK verified | |
| The employee has been shown the example tasks | |

## Notes

- Nothing is overwritten blindly. `opencode.json` is backed up before every change (`opencode.json.backup-…`), a reinstall keeps MCP servers and permissions that are already configured, and re-running the installer is safe — it duplicates nothing.
- For experienced employees build may be left enabled: `--keep-build` (or enable it later — see section 5 of [package1.md](package1.md)).
- First installation: Lapaeva — build disabled, access through Plexus, OfficeCLI.

## Layout of the kit

```
Install.command     double-click to install
Uninstall.command   double-click to remove
scripts/        install.sh, uninstall.sh (the scriptable engines),
                interactive.sh (the prompts behind the two .command files),
                lib/common.sh + lib/kit.py
                and i18n/<lang>.json (all console messages)
docs/<lang>/    this documentation
package1_opencode_plexus/   opencode.json + the office agent, per language
package2_browser_agent/     the chrome-devtools MCP server, start-browser.command,
                            ensure-browser.command,
                            the @browser subagent, per language
package3_officecli/         the Word/Excel MCP servers and their handshake test
```

Language-neutral files (`opencode.json`, the MCP fragments, the `*-browser.command` scripts) exist once. Only prose is duplicated per language, under `locales/<lang>/` and `docs/<lang>/`. To add a language, add `scripts/i18n/<lang>.json` plus the matching `locales/<lang>/` and `docs/<lang>/` folders — any message you do not translate falls back to English.
