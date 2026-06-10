#!/usr/bin/env bash
# ============================================================================
#  10-branding-kiosk.sh  -  Rende Kali "CyberSec AI OS": branding (nome, sfondo,
#  splash) e apertura automatica della GUI in una finestra app dedicata.
#  Idempotente: si puo' rieseguire senza problemi.
# ============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
SRC="/vagrant"; [ -d "$SRC/gui" ] || SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_NAME="${SUDO_USER:-vagrant}"
HOME_DIR="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6)"; HOME_DIR="${HOME_DIR:-/home/$USER_NAME}"
BR="$SRC/kali-iso/config/branding"

echo "==> [1/5] Browser per la finestra app (Chromium)..."
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y chromium >/dev/null 2>&1 || apt-get install -y chromium-browser >/dev/null 2>&1 || true

echo "==> [2/5] Launcher finestra-app..."
install -m 0755 "$SRC/gui/cybergui-app.sh" /usr/local/bin/cybergui-app 2>/dev/null || true

echo "==> [3/5] Nome del sistema + messaggio di benvenuto..."
if [ -f /etc/os-release ] && ! grep -q "CyberSec AI OS" /etc/os-release; then
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="CyberSec AI OS (based on Kali Linux)"/' /etc/os-release || true
fi
[ -f "$BR/motd" ] && cp -f "$BR/motd" /etc/motd 2>/dev/null || true

echo "==> [4/5] Sfondo del desktop..."
if [ -f "$BR/wallpaper.png" ]; then
  mkdir -p /usr/share/backgrounds
  cp -f "$BR/wallpaper.png" /usr/share/backgrounds/cybersec-wallpaper.png
  XDIR="$HOME_DIR/.config/xfce4/xfconf/xfce-perchannel-xml"; mkdir -p "$XDIR"
  cat > "$XDIR/xfce4-desktop.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/cybersec-wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
      <property name="monitorVirtual-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/cybersec-wallpaper.png"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XML
fi

echo "==> [5/5] Avvio automatico della GUI al login..."
ASDIR="$HOME_DIR/.config/autostart"; mkdir -p "$ASDIR"
PY="$(command -v python3 || echo /usr/bin/python3)"
# 1) Server della GUI sempre pronto (affidabile, parte presto, nessuna finestra)
cat > "$ASDIR/cybergui-server.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec GUI server
Exec=$PY /opt/cybersec/gui/server.py
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
# 2) Finestra app dedicata (attende il server e poi apre Chromium --app)
rm -f "$ASDIR/cybergui.desktop" 2>/dev/null || true
cat > "$ASDIR/cybergui-app.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec Control Center
Comment=Apre la GUI in una finestra dedicata all'avvio
Exec=cybergui-app
Icon=security-high
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Security;
EOF
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.config" 2>/dev/null || true

# Splash di avvio Plymouth (best-effort)
PLY="$BR/plymouth/cybersec"
if [ -d "$PLY" ] && command -v plymouth-set-default-theme >/dev/null 2>&1; then
  mkdir -p /usr/share/plymouth/themes/cybersec
  cp -rf "$PLY"/* /usr/share/plymouth/themes/cybersec/ 2>/dev/null || true
  plymouth-set-default-theme cybersec 2>/dev/null || true
  update-initramfs -u >/dev/null 2>&1 || true
fi

echo "==> Fatto. Al prossimo login la GUI si aprira' da sola in una finestra dedicata."
