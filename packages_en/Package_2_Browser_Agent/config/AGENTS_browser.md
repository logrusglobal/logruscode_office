# Website rules

- Tasks that involve working on websites in a real browser (opening pages, clicking, filling in forms, collecting contacts and documents, checking the console/network) must be delegated to the `@browser` subagent via the Task tool. Do not try to automate the browser with bash/curl/webfetch commands when real interaction with a website is required.
- Before delegating, make sure Chrome with the debugging port is running (the "Browser for OpenCode" desktop shortcut or the `%USERPROFILE%\.config\opencode\start-browser.cmd` file). If the browser agent reports a connection error, tell the user to launch that shortcut/file and repeat the request.
- The `@browser` agent works through the `chrome-devtools` MCP server connected to the Chrome instance the user launched separately on port 9222.
- The `@browser` agent inherits the primary agent's model (its `agents\browser.md` file has no `model` line — that is intentional). With Plexus that model is `lgplexus/deepseek-deepseek-v4-pro`.
