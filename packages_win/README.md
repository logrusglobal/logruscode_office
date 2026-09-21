# OpenCode office kit / Комплект OpenCode для офиса

One kit, two languages. Один комплект, два языка.

- **English** — [docs/en/README.md](docs/en/README.md)
- **Русский** — [docs/ru/README.md](docs/ru/README.md)

## Quick start / Быстрый старт

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd "D:\OpenCode_Kit\scripts"
.\install.ps1 -PlexusKey "sk-air-XXXX"            # all packages, language auto-detected
.\install.ps1 -PlexusKey "sk-air-XXXX" -Lang ru -Packages 1,3
.\uninstall.ps1 -Packages 2
```

The language is taken from the Windows UI language unless `-Lang en` / `-Lang ru` is given.
Язык берётся из языка интерфейса Windows, если не задан ключ `-Lang ru` / `-Lang en`.

From Git Bash use `./install.sh` and `./uninstall.sh` — they take the same arguments and
forward them to PowerShell.
