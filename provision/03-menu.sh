#!/usr/bin/env bash
# ============================================================================
#  03-menu.sh  -  Installa il menu interattivo, i tutorial e l'autostart
# ============================================================================
set -euo pipefail

echo "==> Installazione menu interattivo e tutorial..."
apt-get install -y whiptail dialog figlet >/dev/null 2>&1 || true
mkdir -p /opt/cybersec/tutorials

if [ -d /vagrant/menu/tutorials ]; then
  cp -f /vagrant/menu/tutorials/*.md /opt/cybersec/tutorials/ 2>/dev/null || true
fi

install -m 0755 /vagrant/menu/cybermenu.sh /usr/local/bin/cybermenu
install -m 0755 /vagrant/menu/ai.sh        /usr/local/bin/ai

cat > /etc/profile.d/cybersec-welcome.sh <<'EOF'
if [ -t 1 ]; then
  echo ""
  figlet -f small "CyberSec AI VM" 2>/dev/null || echo "=== CyberSec AI VM ==="
  echo "  cybermenu   -> menu interattivo (tool + tutorial)"
  echo "  cybergui    -> GUI moderna nel browser"
  echo "  ai          -> assistente AI di sicurezza"
  echo ""
fi
EOF
chmod 0644 /etc/profile.d/cybersec-welcome.sh

# Icona sul Desktop
DESK="/home/vagrant/Desktop"; mkdir -p "$DESK"
cat > "$DESK/CyberMenu.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberSec Menu
Comment=Menu interattivo con tutti i tool e i tutorial
Exec=bash -lc "x-terminal-emulator -e cybermenu || xfce4-terminal -e cybermenu || qterminal -e cybermenu"
Icon=utilities-terminal
Terminal=false
Categories=Security;
EOF
chmod +x "$DESK/CyberMenu.desktop"

# AVVIO AUTOMATICO del menu al login
mkdir -p /home/vagrant/.config/autostart
cat > /home/vagrant/.config/autostart/cybermenu.desktop <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec Menu
Comment=Apre il menu degli strumenti all'avvio
Exec=bash -lc "x-terminal-emulator -e cybermenu || xfce4-terminal -e cybermenu || qterminal -e cybermenu"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

chown -R vagrant:vagrant /home/vagrant/Desktop /home/vagrant/.config 2>/dev/null || true

echo "==> Menu installato. Si aprira' automaticamente al login. Comando: cybermenu"
