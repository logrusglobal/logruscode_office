# OpenCode for office staff: a kit of three packages

A kit for installing the OpenCode AI assistant with access to DeepSeek through Plexus. It is installed for employees by administrators (Victor, Oleg Sigutin) — the employee needs neither PowerShell nor testing: after the installation they are shown example tasks (the `Task_examples.md` file).

## What the kit contains

| Package | What it installs | Who needs it |
|---|---|---|
| `Package_1_OpenCode_and_Plexus` | The OpenCode Desktop app, DeepSeek access through Plexus (the employee's key), the build agent disabled, the office agent as the primary one | Everyone |
| `Package_2_Browser_Agent` | The @browser subagent: driving websites in Chrome, collecting contacts and documents | Anyone who needs "from a website" tasks |
| `Package_3_OfficeCLI` | Creating and editing Word documents and Excel spreadsheets by plain words in the chat | Anyone who needs Word/Excel documents |

The packages are independent: you can install any combination (for example, only 1+3 without the browser, or only 1+2). The installation scripts overwrite nothing — they add their settings to the existing config and create backups.

## Installation order for one employee (20–30 minutes)

1. Take the employee's key from Vaultwarden (the entry with the Plexus key, format `sk-air-…`). If there is no entry — create a key in Plexus and record it in Vaultwarden.
2. Copy the kit folder to the employee's computer (for example, `D:\OpenCode_Kit`).
3. Install package 1:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   cd "D:\OpenCode_Kit\Package_1_OpenCode_and_Plexus"
   .\install_opencode.ps1 -PlexusKey "sk-air-Wh2AvCAtu2owl9GUKrGPtP4G0JHQSm8I"
   ```

4. If needed — package 2:

   ```powershell
   cd "D:\OpenCode_Kit\Package_2_Browser_Agent"
   .\install_browser_agent.ps1
   ```

5. If needed — package 3:

   ```powershell
   cd "D:\OpenCode_Kit\Package_3_OfficeCLI"
   .\install_officecli.ps1
   ```

6. Launch OpenCode Desktop and **show the employee** 2–3 examples from `Task_examples.md` — so they immediately see what they can now do (for example: "create a letter in Word" and "collect contacts from a website into Excel").
7. For package 2: explain that before "from a website" tasks they need to launch the "Browser for OpenCode" shortcut (created on the desktop automatically).

## Per-employee checklist

| Item | Done |
|---|---|
| Package 1 installed, the employee's Plexus key recorded | |
| Model in OpenCode: `lgplexus/deepseek-deepseek-v4-pro`, the Default / High / Max switch is present | |
| The build agent is disabled (in the Tab switcher: office, plan) | |
| Package 2 installed (if needed), the "Browser for OpenCode" shortcut is on the desktop | |
| Package 3 installed (if needed), HANDSHAKE OK verified | |
| The employee has been shown the example tasks | |

## Important

- For experienced employees build may be left enabled: run package 1 with the `-KeepBuild` flag (or enable it later — see section 5 in `Package_1_OpenCode_and_Plexus\README.md`).
- First installation: Lapaeva — build disabled, access through Plexus, OfficeCLI.
- The old version of the single combined package is in `_Old_versions` (for reference, do not use).
