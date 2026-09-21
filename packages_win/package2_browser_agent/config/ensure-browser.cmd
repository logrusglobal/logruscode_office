@echo off
setlocal
rem ---------------------------------------------------------------------------
rem Makes sure a Chrome with remote debugging on port 9222 is running, so that
rem the chrome-devtools MCP server (the @browser agent) can drive it.
rem Idempotent: if such a Chrome is already up, it exits immediately and starts
rem nothing. This is the script the @browser agent is allowed to run itself;
rem start-browser.cmd (the desktop shortcut) is a thin wrapper around it.
rem Exit codes: 0 - browser is ready, 1 - Chrome not found, 2 - port did not
rem open in time.
rem ---------------------------------------------------------------------------
set "PORT=9222"
set "PROFILE=%USERPROFILE%\.config\opencode\chrome-debug-profile"

call :probe && (
  echo Browser already running on http://127.0.0.1:%PORT%
  exit /b 0
)

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
  echo Chrome not found. Install Google Chrome first.
  exit /b 1
)

rem A separate user-data-dir is mandatory: modern Chrome refuses to open the
rem debugging port on a regular profile. Logins and cookies in this profile are
rem kept between launches.
start "" "%CHROME%" --remote-debugging-port=%PORT% --user-data-dir="%PROFILE%" --no-first-run --no-default-browser-check

rem Wait for the debugging port to answer (Chrome needs a moment to come up).
for /l %%i in (1,1,30) do (
  call :probe && (
    echo Browser started with remote debugging on http://127.0.0.1:%PORT%
    exit /b 0
  )
  >nul ping -n 2 127.0.0.1
)

echo Chrome was started but port %PORT% did not answer in time.
exit /b 2

:probe
curl.exe -s -f -m 2 -o nul "http://127.0.0.1:%PORT%/json/version"
exit /b %errorlevel%
