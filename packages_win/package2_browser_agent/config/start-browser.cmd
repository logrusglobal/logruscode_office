@echo off
rem Launches a separate Chrome with debugging port 9222 so that the
rem chrome-devtools MCP server (the @browser agent) can drive it.
rem A separate user-data-dir is mandatory: modern Chrome refuses to
rem open the debugging port on a regular profile. Logins and cookies in
rem this profile are kept between launches.
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
