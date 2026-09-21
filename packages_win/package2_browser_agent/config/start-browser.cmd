@echo off
rem Desktop-shortcut entry point: launches the debugging Chrome that the
rem chrome-devtools MCP server (the @browser agent) drives. The actual work is
rem in ensure-browser.cmd, which the @browser agent also runs on its own - so
rem starting the browser by hand is optional, not required.
call "%~dp0ensure-browser.cmd"
if errorlevel 1 pause
