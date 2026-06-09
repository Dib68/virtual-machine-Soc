#!/bin/sh
# Eseguito UNA volta al primo accesso: scarica/crea il modello AI (serve internet).
DONE=/opt/cybersec/.firstboot-done
[ -f "$DONE" ] && exit 0
# si auto-rimuove dall'autostart
rm -f "$HOME/.config/autostart/cybersec-firstboot.desktop" 2>/dev/null || true
command -v notify-send >/dev/null 2>&1 && \
  notify-send "CyberSec AI OS" "Configuro l'assistente AI (serve internet, una sola volta)..." || true
if [ -f /opt/cybersec-src/provision/02-ollama.sh ]; then
  sudo bash /opt/cybersec-src/provision/02-ollama.sh > /tmp/cybersec-ai-firstboot.log 2>&1 || \
       bash /opt/cybersec-src/provision/02-ollama.sh > /tmp/cybersec-ai-firstboot.log 2>&1 || true
fi
sudo touch "$DONE" 2>/dev/null || touch "$DONE" 2>/dev/null || true
command -v notify-send >/dev/null 2>&1 && notify-send "CyberSec AI OS" "AI pronta. Apri 'ai' o la GUI." || true
