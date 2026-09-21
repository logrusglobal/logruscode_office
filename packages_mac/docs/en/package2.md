# Package 2 — browser agent

Installs the @browser subagent: OpenCode drives a real Google Chrome browser (opens pages, clicks, fills in forms, collects contacts and documents from websites).

**1. Requirements**

- Package 1 is installed (the `~/.config/opencode\` folder with the `opencode.json` file exists).
- Google Chrome is installed.
- Node.js LTS is installed (https://nodejs.org) — needed to launch the MCP server through npx.

**2. Installation (automatic)**

Open Terminal (Spotlight → type `Terminal` → Enter) and run:

```bash
cd ~/Downloads/OpenCode_Kit/scripts
./install.sh --packages 2
```

The script overwrites nothing — it adds the following to the existing config:

- the `chrome-devtools` MCP server (connects to Chrome on port 9222);
- a ban on the browser tools for every agent except @browser (`"chrome-devtools_*": "deny"`);
- the `agents/browser.md` subagent (it has no `model` line — the agent inherits the primary agent's model);
- the web-task delegation rules in `AGENTS.md`, fenced with markers so they can be removed again cleanly;
- the `ensure-browser.command` script (the @browser agent runs it itself to bring Chrome up), the `start-browser.command` script and the "Browser for OpenCode" shortcut on the desktop.

A backup (`opencode.json.backup-…`) is created before `opencode.json` is changed. Pass `--no-shortcut` to skip the desktop shortcut.

**3. How to use it**

1. Nothing to launch by hand: before its first browser action the @browser agent runs `ensure-browser.command`, which opens Chrome with the separate profile if it is not already running. The "Browser for OpenCode" desktop shortcut does the same thing manually — use it if you want the browser open before you start.
2. In the OpenCode chat just describe the task in plain words, for example: "Collect the contacts from https://… into a table", "Find the supply terms on the website", "Download the price list and consolidate the prices into Excel".
3. The primary agent hands the task over to the @browser subagent itself; you can watch the agent work in the Chrome window.
4. If the agent replies "Chrome not found" — install Google Chrome. If it replies "Could not connect to the browser" even after retrying, launch the "Browser for OpenCode" shortcut by hand and repeat the request.

**4. What @browser can do**

- Navigation: open/close/switch tabs, go to a URL, wait for loading (`navigate_page`, `wait_for`, `list_pages`, `select_page`…).
- Actions on the page: clicks, filling in forms, typing text, key presses, hovering (`click`, `fill`, `fill_form`, `type_text`…).
- Reading the page: the text tree of the page (`take_snapshot`) — the primary way of "seeing", plus screenshots on request.
- Extracting data: running JavaScript on the page (`evaluate_script`).
- Debugging: console errors, network requests, performance traces.

Security: the agent works only in your browser with your logins; destructive actions (submitting, deleting, placing orders) happen only after explicit confirmation; it does not enter passwords without a direct instruction.

**5. A separate Chrome profile**

`ensure-browser.command` first probes `http://127.0.0.1:9222/json/version`; if something answers, it exits at once and starts nothing. Otherwise it launches Chrome with `--remote-debugging-port=9222` and its own `user-data-dir` (`~/.config/opencode\chrome-debug-profile`). The separate profile is mandatory: modern Chrome refuses to open the debugging port on a regular profile. Logins and cookies in that profile are kept between launches.

**6. Removal**

```bash
./uninstall.sh --packages 2          # keeps the Chrome profile with its logins
./uninstall.sh --packages 2 --purge   # deletes the profile as well
```

Removes the MCP server, the permission rule, `agents/browser.md`, `start-browser.command`, `ensure-browser.command`, the desktop shortcut and the web-task block from `AGENTS.md`.

**7. Example tasks** — see [task_examples.md](task_examples.md) (the "Browser" section).
