# Changelog

## 2026-09-21 — browser auto-start, five bug fixes, and a macOS kit

Three commits: `bfa7f30` (the Windows fixes), `bd350b9` (the macOS kit), and
this documentation.

### Why this round happened

The kit shipped working, but three things went wrong in real use on a Windows
install, and chasing each one down turned up a separate root cause:

1. The employee had to launch Chrome by hand before any web task.
2. An English install answered in Russian.
3. The `@browser` subagent never started, so no Chrome window ever appeared and
   the assistant fell back to a plain web search.

A fourth problem was found while verifying the third, and a fifth while
answering "do I have any artifacts left after uninstalling?".

---

### 1. The browser starts itself

**Was:** the employee had to run `start-browser.cmd` (or the desktop shortcut)
before asking for anything web-related. If they forgot, `@browser` failed with
`ECONNREFUSED` and told them to go and launch it.

**Now:** `ensure-browser.cmd` / `ensure-browser.command` — idempotent: it probes
`http://127.0.0.1:9222/json/version`, and if something answers it exits at once
and starts nothing; otherwise it launches Chrome with the separate debug profile
and waits (up to ~30 s) for the port to answer. Exit codes: `0` ready,
`1` Chrome not found, `2` port never opened.

The `@browser` agent runs it itself as step 0 of every task. `start-browser` is
now a thin wrapper around it, so the launch logic lives in one place and the
desktop shortcut still works as a manual fallback.

Giving the agent that one command meant opening up its `bash` permission, which
was `deny`. It is now an allowlist — `"*ensure-browser.cmd*": allow`, `"*": deny`
— so exactly one command is reachable and nothing else.

**Path handling.** The prompt ships a `{{ENSURE_BROWSER}}` placeholder that the
installer replaces with the real absolute path. This is not cosmetic: the shell
behind the agent's `bash` tool does not expand `%USERPROFILE%`, and `cmd /c` gets
mangled by MSYS-style path conversion. Invoking the script directly by absolute
path was the one form that worked. The installer throws (`err_ensure_token`) if
the placeholder is missing.

### 2. An English install answered in Russian

**Root cause:** `AGENTS.md` held *two* copies of the rules — the current English
ones inside `<!-- opencode-kit:… -->` markers, and above them an **unmarked
Russian copy** left by a kit version released before the marker system existed.
`Set-MarkedBlock` only replaces what is between its own markers, so it never saw
the Russian text and simply appended English below it. The model read the
Russian preamble first.

**Fix:** `Get-KitHeadings` + `Remove-LegacyKitSections` (PowerShell) and
`kit.py headings` + `kit.py legacy-strip` (macOS), called at the top of the
installer before any block is written. They collect the kit's top-level headings
from *all* `locales/*/AGENTS*.md` sources — so a stale block in any language is
caught, not just the one being installed — then drop matching sections that sit
outside the markers, printing `legacy_block_removed`. Sections the user added by
hand are left alone.

**Second fix, same symptom.** With the config clean the model still drifted, so
the soft hint `"answer in the user's language"` was replaced in `office.md` and
in the `AGENTS.md` base block with an explicit directive: reply in the language
of the user's *latest* message, overriding the language of the instructions, of
files read, and of anything a subagent returns.

That second part is a prompt-level mitigation against a model tendency, not an
enforced setting. It can drift again.

### 3. The `@browser` subagent could not start

**Symptom:** `OpenCode's free tier can only be used from within OpenCode`, twice,
and no Chrome window.

**Root cause:** `browser.md` had no `model:` line, and the kit's own note
asserted that was deliberate — *"inherits the primary agent's model — that is
intentional."* That assertion was wrong. A subagent with no `model:` does not
inherit the caller's model; OpenCode resolves its own default, which landed on
the free tier and was refused by the provider.

**Fix:** `model: {{MODEL}}`, substituted by the installer from the `model` value
in `opencode.json` (`err_no_model` if there is none), reported as `p2_model`.
The false claim in `AGENTS_browser.md` now states the opposite, in both
languages, and notes that changing the model in `opencode.json` means re-running
package 2.

### 4. The office agent could reach the web without the subagent

**Root cause:** `office.md` denied `chrome-devtools_*` but nothing denied
`websearch` / `webfetch`. "Delegate website tasks to `@browser`" was prose only,
so the model took the cheaper path and never spawned the subagent.

**Fix:** `webfetch: deny` and `websearch: deny` in the office agent's
permissions — `@browser` is now the only route to the web, enforced rather than
requested — plus a rewritten rule: delegate the moment the task needs anything
not already in front of it (a page, a search, a price, a fact), and never answer
a web question from memory instead.

### 5. Uninstalling left the API key in plaintext

**Root cause:** the uninstaller called the generic `Backup-File` helper on
`auth.json`. That is right for `opencode.json`, where the user may have
hand-added settings worth recovering, but wrong here: the only thing the kit
owns in `auth.json` is the Plexus key, and its removal is already surgical. The
backup protected nothing and did one thing only — copy the secret to a new
plaintext file beside the one it was being deleted from. It would have copied
any other provider's key along with it.

**Fix:** no backup of `auth.json`, with a comment explaining why it deliberately
differs from the `opencode.json` path. Because the old behaviour already
shipped, the uninstaller now also sweeps `auth.json.backup-*` from the data
directory and reports the count (`u_auth_backups`).

---

### The macOS kit

`pac_mac_v0` was the pre-repack architecture: Cyrillic folder names, three
standalone `install_*.sh`, Russian only, no `locales/`, no `i18n/`, no marker
system (it appended to `AGENTS.md` and guarded with a `grep` for the heading),
and no uninstaller at all. Several of the fixes above had nowhere to land in it.

It was replaced by `packages_mac/`, rebuilt to the same architecture as
`packages_win/`. A structural diff between the two now differs only where the
platform forces it.

| Windows | macOS |
|---|---|
| `install.ps1`, `uninstall.ps1`, `interactive.ps1` | `install.sh`, `uninstall.sh`, `interactive.sh` |
| `lib/common.ps1` | `lib/common.sh` + `lib/kit.py` |
| `Install.cmd` / `Uninstall.cmd` | `Install.command` / `Uninstall.command` |
| `.lnk` shortcut on the desktop | a `.command` file on the Desktop |
| NSIS installer | DMG mount and copy to `/Applications` |
| bare `npx.cmd` / `uvx` | absolute paths, via `{{NPX}}` / `{{UVX}}` |

`kit.py` exists because JSON merging and marker rewriting in `sed` and `grep` is
how configs get corrupted. It reimplements `common.ps1`'s operations rather than
approximating them; the two files cross-reference each other.

**macOS-specific work beyond porting:**

- v0's `browser.md` told the agent about `start-browser.cmd` and
  `%USERPROFILE%\…` — Windows filenames and paths in a Mac kit. Its prompt was
  also English while `AGENTS.md` was Russian, the same mixed-language setup
  behind problem 2.
- `npx` and `uvx` are recorded as absolute paths: launched from the Dock,
  OpenCode inherits launchd's `PATH`, never the shell's.
- `xattr -dr com.apple.quarantine` on every `.command`, or Finder refuses to run
  a freshly copied one.
- `chmod 600` on `auth.json`.
- The Desktop copy of `start-browser.command` has no sibling
  `ensure-browser.command`, so it falls back to `~/.config/opencode/`.

**Two bugs found and fixed while testing it:** Python's newline translation
injected `\r` into language codes and into the headings file consumed by
`legacy-strip`; and a `mktemp` DMG path leaked its original temp file.

### Repository

- `.gitattributes` pins LF for `packages_mac` and CRLF for `packages_win`. The
  documented workflow copies a kit folder straight onto the target machine, so a
  macOS script checked out with CRLF fails at the shebang with
  `bad interpreter: /bin/bash^M`.
- Executable bits on the macOS scripts recorded with
  `git update-index --chmod=+x`, since `core.filemode` is off on Windows.
- This `CHANGELOG.md` and the root `README.md` added.

---

### What was verified, and what was not

**Windows** — exercised against throwaway config folders: install of package 2,
path substitution, the legacy-block cleanup (including that hand-written
sections survive), uninstall removing both browser scripts, and `auth.json`
losing only the Plexus key while another provider's key survives with no backup
left behind. The maintainer's own machine was then repaired: the stale Russian
block removed, the updated agents installed, the three leaked `auth.json`
backups deleted, and logs and `opencode.db` scanned for key material (none
found).

**macOS** — the kit was exercised on Windows through Git Bash with fake `HOME`
directories: install of 1 / 2,3 / all three, both languages, the interactive
front-end, the legacy-block cleanup, `--no-shortcut`, a Desktop launcher created
under its Russian name and removed by an English-language uninstall, full
uninstall, `--purge`, repeated uninstall reporting "nothing to remove", and the
`auth.json` behaviour.

**Not verified — needs a real Mac:** the DMG download, mount and copy;
`defaults read -g AppleLanguages`; Finder double-click on the `.command` files;
`xattr`; and the actual Chrome launch by `ensure-browser.command`. Those paths
are ported from working v0 code but have not run on macOS. Commit `bd350b9` is
titled "not tested" for this reason.

**Also unverified:** that `websearch: deny` and the hard language rule change
the model's behaviour in the way intended. The first is an enforced permission
and should hold; the second is a prompt instruction and may not.

### Known gap

Picking up a fix to package 1's prose requires re-running the installer, which
demands `-PlexusKey` / `--plexus-key` again even though the key is already in
`auth.json`. Making the key optional when one is already stored would remove the
need to fetch it from Vaultwarden for a prose-only update.
