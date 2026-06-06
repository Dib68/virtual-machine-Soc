#!/usr/bin/env bash
# ============================================================================
#  build-ova.sh  -  Genera un file .ova distribuibile della CyberSec AI VM
#  Metodo affidabile: costruisce la VM con Vagrant, poi la esporta da
#  VirtualBox in formato .ova (apribile con doppio click da chiunque).
#
#  Richiede: VirtualBox + Vagrant gia' installati (vedi README).
#  Uso:  ./build-ova.sh
# ============================================================================
set -euo pipefail

VM_NAME="CyberSec-AI-VM"
OUT="CyberSecAI.ova"

echo "==> [1/3] Costruzione della VM con Vagrant (puo' richiedere molto tempo)..."
vagrant up

echo "==> [2/3] Spegnimento pulito della VM..."
vagrant halt

echo "==> [3/3] Esportazione in $OUT ..."
# Trova il nome reale della VM in VirtualBox (per sicurezza)
REAL=$(VBoxManage list vms | grep -i "$VM_NAME" | head -n1 | sed -E 's/^"([^"]+)".*/\1/')
REAL=${REAL:-$VM_NAME}

VBoxManage export "$REAL" \
  --output "$OUT" \
  --vsys 0 \
  --product "CyberSec AI VM" \
  --vendor "CyberSec AI VM project" \
  --version "1.0"

echo ""
echo "============================================================"
echo " Fatto! File creato: $OUT"
echo " Distribuiscilo: l'utente fa File > Importa applicazione"
echo " virtuale in VirtualBox e parte la VM (login: vagrant/vagrant)."
echo "============================================================"
