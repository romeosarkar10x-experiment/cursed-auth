#! /bin/bash

export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 &
sleep 1

fluxbox &

x11vnc -display :99 -nopw -forever -rfbport 5900 &

websockify --web /usr/share/novnc 6080 localhost:5900 &

# Raw chromium — no automation framework
CHROME_BIN=$(node -e "console.log(require('playwright').chromium.executablePath())")

"$CHROME_BIN" \
    --no-sandbox \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-default-apps \
    --force-dark-mode --enable-features=WebContentsForceDark \
    --no-default-browser-check \
    --user-data-dir=/tmp/chrome-profile \
    "https://leetcode.com/accounts/login/" &

echo "🌐 Open http://localhost:6080/vnc.html and log in"
echo "⏳ Waiting for login..."

# Poll for the session cookie in Chrome's sqlite DB
while true; do
    sleep 5
    if sqlite3 /tmp/chrome-profile/Default/Cookies \
        "SELECT value FROM cookies WHERE host_key='.leetcode.com' AND name='LEETCODE_SESSION'" 2>/dev/null | grep -q .; then
        echo "✅ Login detected, extracting cookies..."
        break
    fi
done

# Extract cookies
node dist/extract-cookies.js
