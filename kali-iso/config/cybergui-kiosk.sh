#!/usr/bin/env bash
# cybergui-kiosk - apre la GUI Control Center a TUTTO SCHERMO (modalita' kiosk)
set -uo pipefail
PORT="${CYBERGUI_PORT:-8910}"; URL="http://127.0.0.1:$PORT"
if ! curl -s "$URL/api/status" >/dev/null 2>&1; then
  setsid python3 /opt/cybersec/gui/server.py >/tmp/cybergui.log 2>&1 &
  for i in $(seq 1 15); do curl -s "$URL/api/status" >/dev/null 2>&1 && break; sleep 1; done
fi
exec firefox-esr --kiosk "$URL" 2>/dev/null || exec firefox --kiosk "$URL" 2>/dev/null \
  || (xdg-open "$URL"; echo "Apri manualmente $URL")
