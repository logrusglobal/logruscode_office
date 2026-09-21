# OpenCode

Installing OpenCode Desktop for Windows with the DeepSeek model connected through Plexus. For office staff the "build" agent is disabled (no program code is written) and the office agent becomes the primary assistant.

## Installing OpenCode Desktop for Windows

**1. ACCESS KEY**

Make sure you have been issued an access key for DeepSeek through Plexus. The key is stored in Vaultwarden: open Vaultwarden and find the entry for the employee (a key in the `sk-air-…` format). If there is no entry — go to Plexus, create a key for the DeepSeek model and record it in Vaultwarden.

**2. Installation (automatic, recommended)**

Open PowerShell (Start → type `powershell` → Enter) and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd "D:\OpenCode_Kit\Package_1_OpenCode_and_Plexus"
.\install_opencode.ps1 -PlexusKey "sk-air-XXXX"
```

Substitute the employee's key from Vaultwarden for `sk-air-XXXX`.

The script does everything itself: downloads and silently installs OpenCode Desktop (if it is not installed yet), registers the Plexus provider (`lgplexus`) and the DeepSeek model, saves the key, disables the build agent and makes office the primary agent. The employee's existing settings are saved to a backup (the `opencode.json.backup-…` file next to the config).

**Reinstalling over an older package.** If the machine already had the previous (single combined) package with direct DeepSeek access — just run this script with the Plexus key: it switches the model to `lgplexus`, disables build and at the same time **keeps** the MCP servers that are already configured (browser, OfficeCLI) and the permissions. After reinstalling, run packages 2 and/or 3 once more (they are idempotent — running them again duplicates nothing).

Script parameters:

- `-PlexusKey "sk-air-XXXX"` — required: the employee's key.
- `-SkipAppInstall` — skip installing the application if it is already there.
- `-KeepBuild` — do not disable the build agent (for experienced employees only).

**3. Installing OpenCode manually (ALTERNATIVELY, if the script does not suit you)**

Install OpenCode from the website: https://opencode.ai/ (Windows x64).

Then connect the DeepSeek model through Plexus. Bring up the custom provider dialog **Custom OpenAI Compatible Provider**. To do that, in the OpenCode window EITHER:

- pick the apps icon in the top-left corner, then **Settings**, then **Providers** on the left, scroll the list down and pick **Custom Provider**, or
- in the chat window of a new session press **Ctrl + '**, then **Connect Provider** in the top-right corner, then pick **Custom OpenAI Compatible Provider** at the bottom of the list, or
- in the chat window click **Choose Model**, then **See 70+ More Providers** at the bottom, then pick **Custom OpenAI Compatible Provider** at the bottom of the list.

In that dialog set the following parameters:

- **ProviderID** = `lgplexus`
- **Display name** = `Logrus Global Plexus`
- **Base URL** = `https://aiapi.plexus.logrusglobal.com/v1`
- **API Key** = `sk-air-XXXX` (the employee's key from Vaultwarden)
- **Models:** model-id = `deepseek-deepseek-v4-pro`, Display Name = `deepseek-deepseek-v4-pro`

After connecting the provider manually, run the script with the `-SkipAppInstall` flag to apply the base settings (disabling build, the office agent) and to write the key into auth.json:

```powershell
.\install_opencode.ps1 -PlexusKey "sk-air-XXXX" -SkipAppInstall
```

**4. Reasoning mode**

The package config already enables reasoning modes for the DeepSeek model. After OpenCode starts, a **Default / High / Max** switch appears to the right of the model name.

To check that the model really is reasoning — give it this prompt:

> There are three closed boxes labeled "Apples", "Oranges", and "Both". Every label is known to be incorrect. You are allowed to pick exactly one fruit from one box without looking inside. How do you determine the correct labels for all three boxes? Walk through the logical necessity of every step.

The model should explicitly work through the scenarios and explain why picking from the "Both" box gives complete certainty.

**5. Disabling the build agent**

The build agent is the built-in "programmer": it writes code, creates scripts and runs arbitrary commands. For an office employee it is disabled (in `opencode.json`: `"agent": { "build": { "disable": true } }`), and **office** is set as the primary agent:

- `edit: deny` — writing program code and editing files is forbidden;
- `bash: ask` — console commands only after the employee confirms them;
- only the @browser subagent drives the browser (the "Browser Agent" package).

Disabling build **does not break** either Office CLI or website tasks (verified by end-to-end tests).

**How to turn build back on (for experienced users):** open `C:\Users\<name>\.config\opencode\opencode.json`, in the `"agent": { "build": { "disable": true } }` block replace `true` with `false` (or delete the block entirely), save and fully restart OpenCode. The build agent will appear in the switcher (the Tab key).

**6. What next**

- The "Browser Agent" package — driving websites in Chrome (collecting contacts, documents, data).
- The "OfficeCLI" package — creating and editing Word documents and Excel spreadsheets by plain words in the chat.
- The general list of real-life examples — the `Task_examples.md` file in the root of the kit.
