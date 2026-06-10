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

echo "==> [2/5] Launcher finestra-app + icona logo..."
install -m 0755 "$SRC/gui/cybergui-app.sh" /usr/local/bin/cybergui-app 2>/dev/null || true
# Logo come icona dell'app/launcher
ICON="security-high"
if [ -f "$BR/logo.png" ]; then
  install -m 0644 "$BR/logo.png" /usr/share/pixmaps/cybersec.png 2>/dev/null && ICON="/usr/share/pixmaps/cybersec.png" || true
fi

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

echo "==> [5/5] Avvio automatico della GUI..."
PY="$(command -v python3 || echo /usr/bin/python3)"
# 1) Server della GUI come servizio systemd: parte al boot, indipendente dal
#    login, si riavvia da solo. (L'autostart del desktop verrebbe ucciso.)
if command -v systemctl >/dev/null 2>&1; then
  cat > /etc/systemd/system/cybergui.service <<EOF
[Unit]
Description=CyberSec AI - GUI Control Center server
After=network.target

[Service]
Type=simple
User=$USER_NAME
ExecStart=$PY /opt/cybersec/gui/server.py
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable --now cybergui.service 2>/dev/null || true
fi
# 2) Finestra app dedicata al login (attende il server e apre Chromium --app)
ASDIR="$HOME_DIR/.config/autostart"; mkdir -p "$ASDIR"
rm -f "$ASDIR/cybergui.desktop" "$ASDIR/cybergui-server.desktop" 2>/dev/null || true
cat > "$ASDIR/cybergui-app.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CyberSec Control Center
Comment=Apre la GUI in una finestra dedicata all'avvio
Exec=cybergui-app
Icon=$ICON
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Security;
EOF
# Aggiorna anche l'icona sul Desktop, se presente
DESKF="$HOME_DIR/Desktop/CyberSec-ControlCenter.desktop"
[ -f "$DESKF" ] && sed -i "s|^Icon=.*|Icon=$ICON|" "$DESKF" 2>/dev/null || true
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.config" 2>/dev/null || true

# Splash di avvio con il TUO logo (Plymouth) al posto di quello di Kali
echo "==> Splash di avvio personalizzato (Plymouth)..."
PLY="$BR/plymouth/cybersec"
if [ -d "$PLY" ]; then
  command -v plymouth >/dev/null 2>&1 || apt-get install -y plymouth plymouth-themes >/dev/null 2>&1 || true
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    mkdir -p /usr/share/plymouth/themes/cybersec
    cp -rf "$PLY"/* /usr/share/plymouth/themes/cybersec/ 2>/dev/null || true
    # Abilita lo splash grafico nel boot (serve 'splash' nella cmdline del kernel)
    if [ -f /etc/default/grub ]; then
      if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        grep -q 'splash' /etc/default/grub || sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
        grep -q 'quiet'  /etc/default/grub || sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet"/'  /etc/default/grub
      else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' >> /etc/default/grub
      fi
      grep -q '^GRUB_GFXPAYLOAD_LINUX=' /etc/default/grub || echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /etc/default/grub
      # Nome nel menu GRUB: "CyberSec AI OS" invece di Kali
      if grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
        sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="CyberSec AI OS"/' /etc/default/grub
      else
        echo 'GRUB_DISTRIBUTOR="CyberSec AI OS"' >> /etc/default/grub
      fi
      command -v update-grub >/dev/null 2>&1 && update-grub >/dev/null 2>&1 || true
    fi
    # Imposta il tema e rigenera l'initramfs (-R) cosi' il logo appare al boot
    plymouth-set-default-theme -R cybersec >/dev/null 2>&1 \
      || { plymouth-set-default-theme cybersec >/dev/null 2>&1; update-initramfs -u >/dev/null 2>&1; } || true
  fi
fi

# Schermata di LOGIN (lightdm-gtk-greeter) col tuo sfondo e logo
echo "==> Schermata di login personalizzata..."
GCONF="/etc/lightdm/lightdm-gtk-greeter.conf"
if [ -d /etc/lightdm ]; then
  WPG="/usr/share/backgrounds/cybersec-wallpaper.png"
  LOGO="/usr/share/pixmaps/cybersec.png"
  [ -f "$WPG" ] || WPG="$BR/wallpaper.png"
  [ -f "$GCONF" ] && cp -n "$GCONF" "$GCONF.bak" 2>/dev/null || true
  cat > "$GCONF" <<EOF
[greeter]
background = $WPG
default-user-image = $LOGO
hide-user-image = false
position = 50%,center 50%,center
EOF
fi

echo "==> Fatto. Avvio totalmente brandizzato: GRUB + splash + login + desktop + GUI."
