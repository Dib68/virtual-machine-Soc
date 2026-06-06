#!/usr/bin/env bash
# cyberdoctor - verifica lo stato della VM (tool, AI, docker, risorse)
GREEN="\e[32m"; RED="\e[31m"; YEL="\e[33m"; NC="\e[0m"
ok(){ echo -e "  ${GREEN}[OK]${NC} $1"; }
no(){ echo -e "  ${RED}[--]${NC} $1"; }
chk(){ command -v "$1" >/dev/null 2>&1 && ok "$1" || no "$1 (mancante)"; }

echo "============================================================"
echo " CyberDoctor - diagnostica CyberSec AI VM"
echo "============================================================"
echo "Sistema: $(. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME")"
echo "Kernel : $(uname -r)"
echo "RAM    : $(free -h | awk '/Mem:/{print $2" tot, "$7" disp"}')"
echo "Disco  : $(df -h / | awk 'NR==2{print $4" liberi su "$2}')"
echo ""
echo "-- Strumenti core --"
for t in nmap msfconsole burpsuite wireshark sqlmap hydra hashcat john \
         nuclei suricata zeek yara osqueryi trivy aws kubectl terraform \
         netexec impacket-scripts bloodhound; do chk "$t"; done
echo ""
echo "-- AI locale (Ollama) --"
if command -v ollama >/dev/null 2>&1; then
  ok "ollama installato"
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    ok "servizio attivo"; echo "  modelli: $(ollama list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ' ')"
  else no "servizio non attivo (sudo systemctl start ollama)"; fi
else no "ollama non installato"; fi
echo ""
echo "-- Docker / lab SOC --"
if command -v docker >/dev/null 2>&1; then
  ok "docker installato"
  docker info >/dev/null 2>&1 && ok "docker attivo" || no "docker non attivo"
else no "docker non installato"; fi
echo ""
if [ -f /opt/cybersec/missing_tools.txt ]; then
  echo -e "${YEL}Pacchetti non installati durante il provisioning:${NC}"
  sort -u /opt/cybersec/missing_tools.txt | sed 's/^/  - /'
fi
echo "============================================================"
