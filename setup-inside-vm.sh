#!/usr/bin/env bash
# ============================================================================
#  setup-inside-vm.sh  -  Da eseguire DENTRO la VM Kali.
#  Installa il menu, i comandi e l'avvio automatico del menu al login,
#  prendendo i file dalla cartella condivisa /vagrant.
#  Uso (nel terminale della VM):  sudo bash /vagrant/setup-inside-vm.sh
# ============================================================================
set -uo pipefail

SRC="/vagrant"
[ -d "$SRC/menu" ] || SRC="$(cd "$(dirname "$0")" && pwd)"
echo "==> Uso i file da: $SRC"

echo "==> Installo le utility di base (whiptail/dialog)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y whiptail dialog figlet >/dev/null 2>&1 || true

echo "==> Copio tutorial e comandi..."
mkdir -p /opt/cybersec/tutorials /opt/cybersec/gui /opt/cybersec/soc-lab
cp -f "$SRC"/menu/tutorials/*.md /opt/cybersec/tutorials/ 2>/dev/null || true
install -m 0755 "$SRC/menu/cybermenu.sh" /usr/local/bin/cybermenu 2>/dev/null || true
install -m 0755 "$SRC/menu/ai.sh"        /usr/local/bin/ai        2>/dev/null || true
# comandi opzionali (se presenti nel progetto)
[ -f "$SRC/soc-lab/soclab.sh" ] && { cp -rf "$SRC"/soc-lab/* /opt/cybersec/soc-lab/ 2>/dev/null; install -m 0755 "$SRC/soc-lab/soclab.sh" /usr/local/bin/soclab; }
[ -d "$SRC/gui" ] && { cp -f "$SRC"/gui/index.html "$SRC"/gui/server.py "$SRC"/gui/tools.json /opt/cybersec/gui/ 2>/dev/null; install -m 0755 "$SRC/gui/cybergui.sh" /usr/local/bin/cybergui 2>/dev/null || true; }
for u in cyberdoctor ai-explain cyberreport cyberupdate cyberhelp; do
  [ -f "$SRC/tools/$u.sh" ] && install -m 0755 "$SRC/tools/$u.sh" "/usr/local/bin/$u" 2>/dev/null || true
done

echo "==> Configuro l'AVVIO AUTOMATICO del menu al login..."
# Trova l'utente del desktop (di solito vagrant o kali)
USER_HOME="/home/vagrant"; OWNER="vagrant"
[ -d "$USER_HOME" ] || { USER_HOME="/home/kali"; OWNER="kali"; }
[ -d "$USER_HOME" ] || { USER_HOME="$HOME"; OWNER="$(id -un)"; }

mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/cybermenu.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec Menu
Comment=Apre il menu degli strumenti all'avvio
Exec=bash -lc "x-terminal-emulator -e cybermenu || xfce4-terminal -e cybermenu || qterminal -e cybermenu"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
chown -R "$OWNER":"$OWNER" "$USER_HOME/.config" 2>/dev/null || true

# Icona anche sul Desktop
mkdir -p "$USER_HOME/Desktop"
cat > "$USER_HOME/Desktop/CyberSec-Menu.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberSec Menu
Comment=Menu di tutti i tool con tutorial
Exec=bash -lc "x-terminal-emulator -e cybermenu || xfce4-terminal -e cybermenu"
Icon=utilities-terminal
Terminal=false
Categories=Security;
EOF
chmod +x "$USER_HOME/Desktop/CyberSec-Menu.desktop"
chown -R "$OWNER":"$OWNER" "$USER_HOME/Desktop" 2>/dev/null || true

echo ""
echo "============================================================"
echo " FATTO!"
echo " - Ora puoi digitare:  cybermenu"
echo " - Al PROSSIMO avvio della VM il menu si aprira' da solo."
echo "============================================================"
