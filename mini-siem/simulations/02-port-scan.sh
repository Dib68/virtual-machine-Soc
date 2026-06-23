#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1046 — Network Service Discovery
#  MITRE ATT&CK: Discovery > Network Service Scanning
# ============================================================
set -euo pipefail

TARGET="${1:-192.168.56.10}"
YLW='\033[1;33m'; GRN='\033[0;32m'; NC='\033[0m'

banner() {
  echo -e "${YLW}"
  echo "╔═══════════════════════════════════════════════╗"
  echo "║  MITRE T1046 — Network Service Discovery      ║"
  echo "║  Target: $TARGET                              ║"
  echo "╚═══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

step() { echo -e "\n${GRN}[►] $*${NC}"; }

banner

step "1/3 — SYN Stealth Scan (top 1000 porte)"
nmap -sS -T4 --top-ports 1000 "$TARGET" -oN /tmp/scan-syn.txt
cat /tmp/scan-syn.txt | grep -E "open|filtered"

step "2/3 — Service Version Detection"
nmap -sV -T3 -p 22,80,443,3389,8080,8443 "$TARGET" -oN /tmp/scan-svc.txt
cat /tmp/scan-svc.txt | grep "open"

step "3/3 — OS Detection"
sudo nmap -O "$TARGET" -oN /tmp/scan-os.txt 2>/dev/null | grep -E "OS:|Running:" || true

echo
echo "  Alert attesi : Suricata SID 9000010, 9000011"
echo "  Tattica      : Discovery"
echo "  Tecnica      : T1046 - Network Service Scanning"
echo -e "\n${GRN}Scan completato. Controlla gli alert su Kibana.${NC}"
