#! /bin/bash

# 1. Virtual display
Xvfb :99 -screen 0 1280x900x24 &
sleep 1

# 2. Window manager (so you can drag/resize)
fluxbox &

# 3. VNC server
x11vnc -display :99 -nopw -forever -shared -rfbport 5900 &

# 4. noVNC web client
websockify --web /usr/share/novnc 6080 localhost:5900 &
sleep 1

echo "============================================"
echo "🔓 Open http://localhost:6080/vnc.html"
echo "============================================"

# 5. Launch browser and wait for login
pnpm exec playwright install chromium --with-deps 2>/dev/null

node dist/index.js
