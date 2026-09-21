#!/bin/bash
# ---------------------------------------------------------------------------
# Makes sure a Chrome with remote debugging on port 9222 is running, so that
# the chrome-devtools MCP server (the @browser agent) can drive it.
# Idempotent: if such a Chrome is already up, it exits immediately and starts
# nothing. This is the script the @browser agent is allowed to run itself;
# start-browser.command (the Desktop copy) is a thin wrapper around it.
# Exit codes: 0 - browser is ready, 1 - Chrome not found, 2 - port did not
# open in time.
# ---------------------------------------------------------------------------
PORT=9222
PROFILE="$HOME/.config/opencode/chrome-debug-profile"

probe() { curl -s -f -m 2 -o /dev/null "http://127.0.0.1:$PORT/json/version"; }

if probe; then
    echo "Browser already running on http://127.0.0.1:$PORT"
    exit 0
fi

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME" ]; then
    echo "Chrome not found. Install Google Chrome first."
    exit 1
fi

# A separate user-data-dir is mandatory: modern Chrome refuses to open the
# debugging port on a regular profile. Logins and cookies in this profile are
# kept between launches.
nohup "$CHROME" \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --no-first-run --no-default-browser-check \
    >/dev/null 2>&1 &

# Wait for the debugging port to answer (Chrome needs a moment to come up).
for _ in $(seq 1 30); do
    if probe; then
        echo "Browser started with remote debugging on http://127.0.0.1:$PORT"
        exit 0
    fi
    sleep 1
done

echo "Chrome was started but port $PORT did not answer in time."
exit 2
