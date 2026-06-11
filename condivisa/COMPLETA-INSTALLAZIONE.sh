#!/usr/bin/env bash
# ============================================================================
#  COMPLETA INSTALLAZIONE  -  installa TUTTO dentro la VM (tool, AI, GUI).
#  Da lanciare DENTRO la VM. Sicuro da rieseguire piu' volte (idempotente).
# ============================================================================
clear
cat <<'BANNER'
============================================================
  CyberSec AI VM - Completamento installazione automatico
============================================================
BANNER
echo "Installo tutti gli strumenti e l'AI. Serve internet e tempo (anche 30+ min)."
echo "Se chiede la password scrivi: vagrant"
echo

SRC="/vagrant"
[ -d "$SRC/provision" ] || SRC="$(cd "$(dirname "$0")"/.. 2>/dev/null && pwd)"
if [ ! -d "$SRC/provision" ]; then
  echo "ERRORE: non trovo i file del progetto (/vagrant). La cartella condivisa non e' attiva."
  read -rp "Premi Invio per chiudere."; exit 1
fi

LOG="/tmp/cybersec-install.log"; : > "$LOG"
run() {
  local title="$1" script="$2"
  echo ""
  echo "============================================================"
  echo ">>> $title"
  echo "============================================================"
  if sudo bash "$SRC/provision/$script" 2>&1 | tee -a "$LOG"; then
    echo "   [OK] $title"
  else
    echo "   [ATTENZIONE] $title ha segnalato errori (continuo comunque)"
  fi
}

run "1/10  Strumenti core (Red Team)"     "01-tools.sh"
run "2/10  AI locale (Ollama + modello)"  "02-ollama.sh"
run "3/10  Blue Team / SOC / DFIR"        "04-blueteam.sh"
run "4/10  Cloud & DevSecOps"             "05-cloud-devsecops.sh"
run "5/10  Active Directory / Pentest"    "07-adpentest.sh"
run "6/10  Laboratorio SOC (Docker)"      "06-soclab.sh"
run "7/10  Utility + GUI"                 "08-utils.sh"
run "7b    GUI Control Center"            "09-gui.sh"
run "8/10  Menu e avvio automatico"       "03-menu.sh"
run "9/10  Branding 'CyberSec AI OS' + GUI all'avvio" "10-branding-kiosk.sh"
run "10/10 Verifica finale"               "11-verify.sh"

echo ""
echo "============================================================"
echo " INSTALLAZIONE COMPLETATA - riepilogo diagnostico:"
echo "============================================================"
command -v cyberdoctor >/dev/null 2>&1 && cyberdoctor || echo "(cyberdoctor non disponibile)"
echo ""
echo "Tutto pronto. Puoi aprire la GUI con:  cybergui"
echo "Log completo salvato in: $LOG"
read -rp "Premi Invio per aprire la GUI..."
cybergui 2>/dev/null || true
