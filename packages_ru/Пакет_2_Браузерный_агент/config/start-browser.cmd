@echo off
rem Запускает отдельный Chrome с отладочным портом 9222,
rem чтобы MCP-сервер chrome-devtools (агент @browser) мог им управлять.
rem Отдельный user-data-dir обязателен: современный Chrome отказывается
rem открывать отладочный порт на обычном профиле. Логины и куки в этом
rem профиле сохраняются между запусками.
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
  echo Chrome not found. Install Google Chrome first.
  pause
  exit /b 1
)
start "" "%CHROME%" --remote-debugging-port=9222 --user-data-dir="%USERPROFILE%\.config\opencode\chrome-debug-profile" --no-first-run --no-default-browser-check
echo Chrome started with remote debugging on http://127.0.0.1:9222
