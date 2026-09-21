# OpenCode — OfficeCLI

OfficeCLI is two local MCP servers (office-word and office-excel) that let OpenCode create, read and edit Word documents (.docx) and Excel spreadsheets (.xlsx) directly, without MS Office installed and without writing any programs.

## Installing OfficeCLI

**1. Requirements**

- The "OpenCode + Plexus" package is installed (the `%USERPROFILE%\.config\opencode\opencode.json` file exists).
- An internet connection for the first launch (the servers download their packages once).

**2. Installation (automatic)**

Open PowerShell (Start → type `powershell` → Enter) and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd "D:\OpenCode_Kit\Package_3_OfficeCLI"
.\install_officecli.ps1
```

The script overwrites nothing — it adds the `office-word` and `office-excel` MCP servers to the existing config (a backup `opencode.json.backup-…` is created before the change), installs the `uv` package manager if it is missing, and checks that the servers start.

A successful check looks like this:

```
office-word: HANDSHAKE OK
office-excel: HANDSHAKE OK
```

**3. How to use it**

Close OpenCode Desktop completely and open it again. After that just write your tasks in plain words:

- "Create a confirmation letter for a client: a heading, the salutation, the body text and a table with the details."
- "Sum up column B in budget.xlsx and print the total."
- "Read contract.docx and list all the deadlines in a table."
- "Collect the data from several Excel files into one summary table."

The agent calls the `office-word_*` (Word) and `office-excel_*` (Excel) tools itself. Creating the first file after the installation may take up to a minute — the server is downloading its packages; after that it is faster.

**4. Limitations**

- Files with VBA macros (.docm/.xlsm) and complex formatting must always be opened in Word/Excel and checked visually after an automatic edit.
- PowerPoint presentations are not part of this package.

**5. Example tasks** — see the `Task_examples.md` file in the root of the kit (the "Excel" and "Word" sections).
