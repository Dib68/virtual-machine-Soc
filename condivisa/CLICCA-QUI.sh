#!/usr/bin/env bash
# ============================================================================
#  CLICCA QUI  -  Installa tutto e apre il menu della CyberSec AI VM
#  Si lancia da solo: chiede una password (vagrant) e fa il resto.
# ============================================================================
clear
cat <<'BANNER'
   ____      _               ____            _    ___
  / ___|   _| |__   ___ _ __/ ___|  ___  ___| |  / _ \
 | |  | | | | '_ \ / _ \ '__\___ \ / _ \/ __| | | | | |
 | |__| |_| | |_) |  __/ |   ___) |  __/ (__| | | |_| |
  \____\__, |_.__/ \___|_|  |____/ \___|\___|_|  \__\_\
       |___/        Control Center - avvio automatico
BANNER
echo
echo "Sto preparando i tuoi strumenti. Se chiede la password scrivi: vagrant"
echo "(la password non si vede mentre la digiti: e' normale)"
echo

# Trova i file del progetto (cartella condivisa principale)
SRC="/vagrant"
[ -f "$SRC/setup-inside-vm.sh" ] || SRC="$(cd "$(dirname "$0")"/.. 2>/dev/null && pwd)"
[ -f "$SRC/setup-inside-vm.sh" ] || SRC="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SRC/setup-inside-vm.sh" ]; then
  sudo bash "$SRC/setup-inside-vm.sh"
else
  echo "!! Non trovo i file del progetto. Assicurati che la cartella condivisa sia attiva."
fi

echo
echo "============================================================"
echo " Apro il menu degli strumenti..."
echo "============================================================"
sleep 2
if command -v cybermenu >/dev/null 2>&1; then
  cybermenu
else
  echo "Il menu non risulta installato. Controlla i messaggi qui sopra."
  echo "Premi Invio per chiudere."; read
fi
