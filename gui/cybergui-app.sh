#!/usr/bin/env bash
# ============================================================================
#  cybergui-app - apre la GUI "Control Center" in una FINESTRA APP dedicata
#  (chromeless, senza barre del browser). Non usa una scheda di Firefox.
#  Robusto all'avvio automatico: avvia il server e ATTENDE che risponda.
# ============================================================================
set -uo pipefail
PORT="${CYBERGUI_PORT:-8910}"; URL="http://127.0.0.1:$PORT"
PY="$(command -v python3 || echo /usr/bin/python3)"

# Verifica "porta aperta" senza dipendere da curl (utile all'autostart).
is_up(){ timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$PORT" >/dev/null 2>&1; }

# Avvia il server se non risponde, poi attende fino a ~25s che sia pronto.
if ! is_up; then
  setsid "$PY" /opt/cybersec/gui/server.py >/tmp/cybergui.log 2>&1 </dev/null &
fi
for i in $(seq 1 25); do is_up && break; sleep 1; done

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
