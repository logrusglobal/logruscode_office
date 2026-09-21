# OpenCode — browser agent

Installing the @browser subagent: OpenCode drives a real Google Chrome browser (opens pages, clicks, fills in forms, collects contacts and documents from websites).

## Installing browser subagent

**1. Requirements**

- The "OpenCode + Plexus" package is installed (the `%USERPROFILE%\.config\opencode\` folder with the `opencode.json` file exists).
- Google Chrome is installed.
- Node.js LTS is installed (https://nodejs.org) — needed to launch the MCP server through npx.

**2. Installation (automatic)**

Open PowerShell (Start → type `powershell` → Enter) and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd "D:\OpenCode_Kit\Package_2_Browser_Agent"
.\install_browser_agent.ps1
```

The script overwrites nothing — it adds the following to the existing config:

- the `chrome-devtools` MCP server (connects to Chrome on port 9222);
- a ban on the browser tools for every agent except @browser (`"chrome-devtools_*": "deny"`);
- the `agents\browser.md` subagent (it has no `model` line — the agent inherits the primary agent's model);
- the web-task delegation rules in `AGENTS.md`;
- the `start-browser.cmd` script and the "Browser for OpenCode" shortcut on the desktop.

A backup (`opencode.json.backup-…`) is created before `opencode.json` is changed.

**3. How to use it**

1. Launch "Browser for OpenCode" (the desktop shortcut) — Chrome opens with a separate profile.
2. In the OpenCode chat just describe the task in plain words, for example: "Collect the contacts from https://… into a table", "Find the supply terms on the website", "Download the price list and consolidate the prices into Excel".
3. The primary agent hands the task over to the @browser subagent itself; you can watch the agent work in the Chrome window.
4. If the agent replies "Could not connect to the browser" — launch the "Browser for OpenCode" shortcut and repeat the request.

**4. What @browser can do**

- Navigation: open/close/switch tabs, go to a URL, wait for loading (`navigate_page`, `wait_for`, `list_pages`, `select_page`…).
- Actions on the page: clicks, filling in forms, typing text, key presses, hovering (`click`, `fill`, `fill_form`, `type_text`…).
- Reading the page: the text tree of the page (`take_snapshot`) — the primary way of "seeing", plus screenshots on request.
- Extracting data: running JavaScript on the page (`evaluate_script`).
- Debugging: console errors, network requests, performance traces.

Security: the agent works only in your browser with your logins; destructive actions (submitting, deleting, placing orders) happen only after explicit confirmation; it does not enter passwords without a direct instruction.

**5. Example tasks** — see the `Task_examples.md` file in the root of the kit (the "Browser" section).
