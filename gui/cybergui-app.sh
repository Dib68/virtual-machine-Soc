#!/usr/bin/env bash
# ============================================================================
#  cybergui-app - apre la GUI "Control Center" in una FINESTRA APP dedicata
#  (chromeless, senza barre del browser). Non usa una scheda di Firefox.
# ============================================================================
set -uo pipefail
PORT="${CYBERGUI_PORT:-8910}"; URL="http://127.0.0.1:$PORT"

# Avvia il server se non e' gia' attivo
if ! curl -s "$URL/api/status" >/dev/null 2>&1; then
  setsid python3 /opt/cybersec/gui/server.py >/tmp/cybergui.log 2>&1 </dev/null &
  for i in $(seq 1 20); do curl -s "$URL/api/status" >/dev/null 2>&1 && break; sleep 1; done
fi

# Finestra app (chromeless): prova i browser basati su Chromium.
APP_FLAGS="--app=$URL --no-first-run --no-default-browser-check --disable-translate --window-size=1280,820 --class=CyberSecAI --user-data-dir=$HOME/.config/cybersec-app"
for b in chromium chromium-browser google-chrome google-chrome-stable brave-browser microsoft-edge; do
  if command -v "$b" >/dev/null 2>&1; then exec "$b" $APP_FLAGS; fi
done

# Fallback: Firefox in modalita' kiosk (a tutto schermo, senza barre)
for b in firefox-esr firefox; do
  if command -v "$b" >/dev/null 2>&1; then exec "$b" --kiosk "$URL"; fi
done

# Ultimo fallback
xdg-open "$URL" 2>/dev/null || echo "Apri manualmente: $URL"
