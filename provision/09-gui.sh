#!/usr/bin/env bash
# ============================================================================
#  09-gui.sh  -  Installa la GUI moderna "Control Center"
# ============================================================================
set -uo pipefail
echo "==> Installazione GUI Control Center..."
mkdir -p /opt/cybersec/gui
cp -f /vagrant/gui/index.html /vagrant/gui/server.py /vagrant/gui/tools.json /opt/cybersec/gui/
install -m 0755 /vagrant/gui/cybergui.sh /usr/local/bin/cybergui

# Icona sul desktop
DESK="/home/vagrant/Desktop"; mkdir -p "$DESK"
cat > "$DESK/CyberSec-ControlCenter.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberSec Control Center
Comment=GUI moderna con tutti i tool, AI e SOC lab
Exec=cybergui
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
