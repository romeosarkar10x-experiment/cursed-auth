#! /bin/bash

export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 &
sleep 1

fluxbox &

# Password-protect the VNC session. The public ngrok URL is reachable by anyone,
# so require a password (RFB uses only the first 8 chars). Store it hashed in a
# file rather than passing it on the command line where `ps` could leak it.
if [ -z "$VNC_PASSWORD" ]; then
    echo "❌ VNC_PASSWORD is not set — refusing to expose an unauthenticated VNC session." >&2
    exit 1
fi
x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass
x11vnc -display :99 -rfbauth /tmp/vncpass -forever -rfbport 5900 &

websockify --web /usr/share/novnc 6080 localhost:5900 &

# Expose noVNC (port 6080) publicly via ngrok so a human can log in from a
# GitHub Actions run. The agent auto-reads NGROK_AUTHTOKEN from the environment;
# map our NGROK_AUTH_TOKEN onto it (exported, so it stays out of `ps`).
if [ -z "$NGROK_AUTH_TOKEN" ]; then
    echo "❌ NGROK_AUTH_TOKEN is not set — cannot open the tunnel." >&2
    exit 1
fi
export NGROK_AUTHTOKEN="$NGROK_AUTH_TOKEN"
ngrok http 6080 --log stdout --log-format logfmt > /tmp/ngrok.log 2>&1 &

# Poll ngrok's local API until the public URL is assigned, then print it.
echo "⏳ Starting tunnel..."
NGROK_URL=""
for _ in $(seq 1 30); do
    NGROK_URL=$(node -e '
        fetch("http://127.0.0.1:4040/api/tunnels")
            .then(r => r.json())
            .then(d => { const t = (d.tunnels || []).find(t => t.public_url?.startsWith("https")); if (t) console.log(t.public_url); })
            .catch(() => {});
    ')
    [ -n "$NGROK_URL" ] && break
    sleep 1
done
if [ -z "$NGROK_URL" ]; then
    echo "❌ ngrok did not come up. Log:" >&2
    cat /tmp/ngrok.log >&2
    exit 1
fi

echo "============================================================"
echo "🔗 Open this URL and log in:  ${NGROK_URL}/vnc.html"
echo "🔑 VNC password: (the VNC_PASSWORD you configured, first 8 chars)"
echo "============================================================"

# Raw chromium — no automation framework
CHROME_BIN=$(node -e "console.log(require('playwright').chromium.executablePath())")

PROFILE_DIR=/tmp/chrome-profile

mkdir -p "$PROFILE_DIR/Default"
cat > "$PROFILE_DIR/Default/Preferences" <<'EOF'
{
  "credentials_enable_service": false,
  "profile": {
    "password_manager_enabled": false
  }
}
EOF

"$CHROME_BIN" \
    --no-sandbox \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-default-apps \
    --force-dark-mode --enable-features=WebContentsForceDark \
    --no-default-browser-check \
    --user-data-dir=${PROFILE_DIR} \
    "https://leetcode.com/accounts/login/" &

echo "⏳ Waiting for login..."

# Poll for the LEETCODE_SESSION cookie. NOTE: the `sqlite3` CLI is NOT installed
# in this image — use better-sqlite3 (a project dependency) via node instead.
# It opens the live DB read-only, which works fine while Chrome is running.
while true; do
    sleep 2
    if node -e '
        import Database from "better-sqlite3";
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
        break
    fi
done

# Extract cookies
node dist/extract-cookies.js
