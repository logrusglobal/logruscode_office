# OpenCode office kit for macOS / Комплект OpenCode для офиса (macOS)

One kit, two languages. Один комплект, два языка.

- **English** — [docs/en/README.md](docs/en/README.md)
- **Русский** — [docs/ru/README.md](docs/ru/README.md)

## Simplest way / Самый простой способ

Double-click **`Install.command`** — it asks for the language, the Plexus key and the
packages, then does everything else. **`Uninstall.command`** removes the kit the same way.

Дважды щёлкните **`Install.command`** — он спросит язык, ключ Plexus и пакеты, дальше
сделает всё сам. **`Uninstall.command`** так же удаляет комплект.

If macOS refuses to open a freshly copied `.command` file, make the two entry points
executable once: `chmod +x Install.command Uninstall.command`.

Если macOS отказывается открыть только что скопированный файл `.command`, один раз
сделайте оба файла исполняемыми: `chmod +x Install.command Uninstall.command`.

## Scripted / Для автоматизации

```bash
cd ~/Downloads/OpenCode_Kit/scripts
./install.sh --plexus-key "sk-air-XXXX"            # all packages, language auto-detected
./install.sh --plexus-key "sk-air-XXXX" --lang ru --packages 1,3
./uninstall.sh --packages 2
```

The language is taken from the macOS system language unless `--lang en` / `--lang ru` is given.
Язык берётся из языка системы macOS, если не задан ключ `--lang ru` / `--lang en`.

## Requirements / Требования

- macOS with Python 3 (`xcode-select --install` if `python3` is missing).
- Node.js LTS for package 2, and Google Chrome for the browser agent.
- Package 3 installs `uv` by itself if it is not there yet.

## The Windows kit / Комплект для Windows

The same kit for Windows lives in [`../packages_win`](../packages_win). The two are kept
deliberately parallel — same package layout, same `locales/` and `docs/` split, same
`scripts/i18n/*.json` message keys, same marked blocks in `AGENTS.md` — so a change to
the agent prompts or the install logic can be made in both without re-reading either.

Тот же комплект для Windows — в [`../packages_win`](../packages_win). Они намеренно
устроены одинаково, чтобы правку промптов или логики установки можно было перенести
из одного в другой без перечитывания.
