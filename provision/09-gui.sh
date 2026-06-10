#!/usr/bin/env bash
# ============================================================================
#  09-gui.sh  -  Installa la GUI moderna "Control Center"
# ============================================================================
set -uo pipefail
echo "==> Installazione GUI Control Center..."

# Dipendenze necessarie: python3, curl e almeno un terminale grafico
export DEBIAN_FRONTEND=noninteractive
apt-get install -y python3 curl xterm >/dev/null 2>&1 || true
# almeno un emulatore di terminale (Kali XFCE ha qterminal/xfce4-terminal)
command -v qterminal >/dev/null 2>&1 || command -v xfce4-terminal >/dev/null 2>&1 \
  || apt-get install -y xterm >/dev/null 2>&1 || true

mkdir -p /opt/cybersec/gui
cp -f /vagrant/gui/index.html /vagrant/gui/server.py /vagrant/gui/tools.json /opt/cybersec/gui/
 cp -f /vagrant/gui/favicon.png /opt/cybersec/gui/ 2>/dev/null || true
cp -f /vagrant/VERSION /opt/cybersec/VERSION 2>/dev/null || true
install -m 0755 /vagrant/gui/cybergui.sh /usr/local/bin/cybergui
install -m 0755 /vagrant/gui/cybergui-app.sh /usr/local/bin/cybergui-app 2>/dev/null || true

# Icona sul desktop
DESK="/home/vagrant/Desktop"; mkdir -p "$DESK"
cat > "$DESK/CyberSec-ControlCenter.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberSec Control Center
Comment=GUI moderna con tutti i tool, AI e SOC lab
Exec=cybergui-app
Icon=security-high
Terminal=false
Categories=Security;
EOF
chmod +x "$DESK/CyberSec-ControlCenter.desktop"
chown -R vagrant:vagrant "$DESK" 2>/dev/null || true

# Avvio automatico del server al login (cosi' la GUI e' sempre pronta)
mkdir -p /home/vagrant/.config/autostart
cat > /home/vagrant/.config/autostart/cybergui.desktop <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec GUI server
Exec=python3 /opt/cybersec/gui/server.py
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
chown -R vagrant:vagrant /home/vagrant/.config 2>/dev/null || true

echo "==> GUI installata. Comando: cybergui  (oppure icona sul Desktop)"
