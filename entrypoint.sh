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

# Poll for the LEETCODE_SESSION cookie. NOTE: the `sqlite3` CLI is NOT installed
# in this image — use better-sqlite3 (a project dependency) via node instead.
# It opens the live DB read-only, which works fine while Chrome is running.
while true; do
    sleep 5
    if node -e '
        const Database = require("better-sqlite3");
        try {
            const db = new Database("/tmp/chrome-profile/Default/Cookies", { readonly: true });
            const row = db.prepare(
                "SELECT 1 FROM cookies WHERE name = ? AND length(encrypted_value) > 0"
            ).get("LEETCODE_SESSION");
            process.exit(row ? 0 : 1);
        } catch {
            process.exit(1);
        }
    '; then
        echo "✅ Login detected, extracting cookies..."
        sleep 3600
        break
    fi
done

# Extract cookies
node dist/extract-cookies.js
