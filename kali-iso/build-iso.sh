#!/usr/bin/env bash
# ============================================================================
#  build-iso.sh  -  Costruisce una ISO di Kali PERSONALIZZATA ("CyberSec AI OS")
#  che integra questo progetto e avvia la GUI in automatico.
#  Eseguire su un host Debian/Kali con internet e ~20 GB liberi.
#  Uso:  sudo bash kali-iso/build-iso.sh
# ============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/.." && pwd)"
WORK="${1:-$HOME/cybersec-iso-build}"

echo "==> [1/5] Installo gli strumenti di build (live-build)..."
sudo apt-get update
sudo apt-get install -y git live-build cdebootstrap curl

echo "==> [2/5] Scarico la configurazione live-build ufficiale di Kali..."
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git
cd live-build-config
C=kali-config/common

echo "==> [3/5] Inietto i pacchetti e gli hook del progetto..."
mkdir -p "$C/package-lists" "$C/hooks/live" \
         "$C/includes.chroot/opt/cybersec-src" \
         "$C/includes.chroot/etc/skel/.config/autostart"
cp "$HERE/config/package-lists/cybersec.list.chroot" "$C/package-lists/"
cp "$HERE/config/hooks/0100-cybersec.hook.chroot"     "$C/hooks/live/"

echo "==> [4/5] Copio i file del progetto dentro la ISO..."
cp -r "$PROJ"/provision "$PROJ"/menu "$PROJ"/tools "$PROJ"/soc-lab "$PROJ"/gui \
      "$C/includes.chroot/opt/cybersec-src/"
install -m 0755 "$HERE/config/firstboot/cybersec-firstboot.sh" \
      "$C/includes.chroot/usr/local/bin/cybersec-firstboot" 2>/dev/null || \
      { mkdir -p "$C/includes.chroot/usr/local/bin"; cp "$HERE/config/firstboot/cybersec-firstboot.sh" "$C/includes.chroot/usr/local/bin/cybersec-firstboot"; }
# autostart: GUI ad ogni login + setup AI al primo avvio
cp "$HERE/config/autostart/cybergui.desktop"          "$C/includes.chroot/etc/skel/.config/autostart/"
cp "$HERE/config/autostart/cybersec-firstboot.desktop" "$C/includes.chroot/etc/skel/.config/autostart/"

echo "==> [5/5] Costruisco la ISO (puo' richiedere 30-90 minuti)..."
sudo ./build.sh --variant xfce --verbose

echo ""
echo "============================================================"
echo " ISO creata! La trovi in:  $WORK/live-build-config/images/"
echo " Masterizzala/scrivila su USB e all'avvio partira' la GUI."
echo "============================================================"
