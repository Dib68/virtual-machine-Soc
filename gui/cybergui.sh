#!/usr/bin/env bash
# cybergui - avvia la GUI "Control Center" e apre il browser
set -uo pipefail
GUI_DIR="/opt/cybersec/gui"
PORT="${CYBERGUI_PORT:-8910}"
URL="http://127.0.0.1:$PORT"

# Avvia il server se non e' gia' attivo
if ! curl -s "$URL/api/status" >/dev/null 2>&1; then
  echo "Avvio il server della GUI..."
  setsid python3 "$GUI_DIR/server.py" >/tmp/cybergui.log 2>&1 &
  for i in $(seq 1 15); do curl -s "$URL/api/status" >/dev/null 2>&1 && break; sleep 1; done
fi

echo "GUI pronta su $URL"
# Apri il browser (prova diverse opzioni)
( xdg-open "$URL" >/dev/null 2>&1 || x-www-browser "$URL" >/dev/null 2>&1 \
  || firefox "$URL" >/dev/null 2>&1 || firefox-esr "$URL" >/dev/null 2>&1 ) &
