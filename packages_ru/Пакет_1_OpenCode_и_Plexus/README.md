# OpenCode

Установка OpenCode Desktop для Windows с подключением модели DeepSeek через Plexus. Для офисных сотрудников агент «build» отключается (программный код не пишется), основным помощником становится агент office.

## Installing OpenCode Desktop for Windows

**1. КЛЮЧ ДОСТУПА**

Убедитесь, что вам выдан ключ доступа к DeepSeek через Plexus. Ключ хранится в Vaultwarden: откройте Vaultwarden, найдите запись для сотрудника (ключ формата `sk-air-…`). Если записи нет — зайдите в Plexus, создайте ключ к модели DeepSeek и запишите его в Vaultwarden.

**2. Установка (автоматически, рекомендуется)**

Откройте PowerShell (Пуск → наберите `powershell` → Enter) и выполните:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd "D:\OpenCode_Kit\Пакет_1_OpenCode_и_Plexus"
.\install_opencode.ps1 -PlexusKey "sk-air-XXXX"
```

Вместо `sk-air-XXXX` подставьте ключ сотрудника из Vaultwarden.

Скрипт сделает всё сам: скачает и тихо установит OpenCode Desktop (если он ещё не установлен), пропишет провайдера Plexus (`lgplexus`) и модель DeepSeek, сохранит ключ, отключит агента build и сделает основным агента office. Существующие настройки сотрудника будут сохранены в бэкап (файл `opencode.json.backup-…` рядом с конфигом).

**Переустановка поверх старого пакета.** Если на машине уже стоял прежний (единый) пакет с прямым DeepSeek — просто запустите этот скрипт с ключом Plexus: он переключит модель на `lgplexus`, отключит build и при этом **сохранит** уже настроенные MCP-серверы (браузер, OfficeCLI) и права. После переустановки прогоните пакеты 2 и/или 3 ещё раз (они идемпотентны — повторный запуск ничего не задваивает).

Параметры скрипта:

- `-PlexusKey "sk-air-XXXX"` — обязательный: ключ сотрудника.
- `-SkipAppInstall` — пропустить установку приложения, если оно уже стоит.
- `-KeepBuild` — не отключать агента build (только для опытных сотрудников).

**3. Установка OpenCode вручную (ЛИБО, если скрипт не подходит)**

Установите OpenCode с сайта: https://opencode.ai/ (Windows x64).

Затем подключите модель DeepSeek через Plexus. Вызовите окно подключения кастомного провайдера **Custom OpenAI Compatible Provider**. Для этого в окне OpenCode ЛИБО:

- выберите значок приложений в левом верхнем углу, затем **Settings**, затем **Providers** слева, промотайте список вниз и выберите **Custom Provider**, или
- в окне чата нового сеанса нажмите **Ctrl + '**, затем **Connect Provider** в правом верхнем углу, затем внизу списка выберите **Custom OpenAI Compatible Provider**, или
- в окне чата щёлкните **Choose Model**, затем внизу **See 70+ More Providers**, затем внизу списка выберите **Custom OpenAI Compatible Provider**.

В этом окне выберите следующие параметры:

- **ProviderID** = `lgplexus`
- **Display name** = `Logrus Global Plexus`
- **Base URL** = `https://aiapi.plexus.logrusglobal.com/v1`
- **API Key** = `sk-air-XXXX` (ключ сотрудника из Vaultwarden)
- **Models:** model-id = `deepseek-deepseek-v4-pro`, Display Name = `deepseek-deepseek-v4-pro`

После ручного подключения провайдера выполните скрипт с флагом `-SkipAppInstall`, чтобы применить базовые настройки (отключение build, агент office) и записать ключ в auth.json:

```powershell
.\install_opencode.ps1 -PlexusKey "sk-air-XXXX" -SkipAppInstall
```

**4. Режим рассуждений (reasoning)**

В конфиге пакета для модели DeepSeek уже включены режимы рассуждений. После запуска OpenCode справа от названия модели появится переключатель **Default / High / Max**.

Проверка, что модель действительно рассуждает — задайте промпт:

> There are three closed boxes labeled "Apples", "Oranges", and "Both". Every label is known to be incorrect. You are allowed to pick exactly one fruit from one box without looking inside. How do you determine the correct labels for all three boxes? Walk through the logical necessity of every step.

Модель должна явно пройтись по сценариям и объяснить, почему выбор из коробки «Both» даёт полную уверенность.

**5. Отключение агента build**

Агент build — встроенный «программист»: пишет код, создаёт скрипты и запускает любые команды. Для офисного сотрудника он отключён (в `opencode.json`: `"agent": { "build": { "disable": true } }`), основным назначен агент **office**:

- `edit: deny` — программный код и правка файлов запрещены;
- `bash: ask` — консольные команды только после подтверждения сотрудником;
- браузером управляет только субагент @browser (пакет «Браузерный агент»).

Отключение build **не ломает** ни Office CLI, ни задачи по сайтам (проверено сквозными тестами).

**Как включить build обратно (для опытных):** откройте `C:\Users\<имя>\.config\opencode\opencode.json`, в блоке `"agent": { "build": { "disable": true } }` замените `true` на `false` (или удалите блок целиком), сохраните и полностью перезапустите OpenCode. Агент build появится в переключателе (клавиша Tab).

**6. Что дальше**

- Пакет «Браузерный агент» — управление сайтами в Chrome (сбор контактов, документов, данных).
- Пакет «OfficeCLI» — создание и правка документов Word и таблиц Excel словами в чате.
- Общий список жизненных примеров — файл `Примеры_задач.md` в корне комплекта.
