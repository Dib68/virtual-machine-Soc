#!/usr/bin/env bash
# ============================================================================
#  installa.sh  -  Installer automatico CyberSec AI VM (Linux / macOS)
#  Installa VirtualBox + Vagrant se mancanti, poi crea/avvia la VM.
#  Uso:  ./installa.sh     (oppure doppio click se reso eseguibile)
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

echo "=============================================="
echo " CyberSec AI VM - Installazione automatica"
echo "=============================================="

have(){ command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  if ! have brew; then
    echo "Installo Homebrew..."; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  have VBoxManage || { echo "Installo VirtualBox..."; brew install --cask virtualbox; }
  have vagrant   || { echo "Installo Vagrant...";    brew install --cask vagrant; }
elif [ "$OS" = "Linux" ]; then
  SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
  if have apt-get; then
    $SUDO apt-get update -y
    have VBoxManage || { echo "Installo VirtualBox..."; $SUDO apt-get install -y virtualbox; }
    have vagrant   || { echo "Installo Vagrant...";    $SUDO apt-get install -y vagrant; }
  else
    echo "Gestore pacchetti non apt: installa VirtualBox e Vagrant manualmente."; 
  fi
else
  echo "Sistema non riconosciuto ($OS). Installa VirtualBox e Vagrant manualmente."
fi

have vagrant || { echo "Vagrant non disponibile. Installazione interrotta."; exit 1; }

vagrant plugin list 2>/dev/null | grep -q vagrant-disksize || vagrant plugin install vagrant-disksize 2>/dev/null || true

echo "=============================================="
echo " Creazione della VM (puo' richiedere molto tempo)"
echo "=============================================="
vagrant up

echo ""
echo "FATTO! VM pronta. Login: vagrant / vagrant"
echo "Dentro la VM digita 'cybermenu'."
