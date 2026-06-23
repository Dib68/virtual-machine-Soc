#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1021.004 — Remote Services: SSH
#  MITRE ATT&CK: Lateral Movement
# ============================================================
set -euo pipefail

TARGET="${1:-192.168.56.10}"
YLW='\033[1;33m'; GRN='\033[0;32m'; NC='\033[0m'

echo -e "${YLW}╔═══════════════════════════════════════════════╗"
echo    "║  MITRE T1021.004 — Lateral Movement via SSH  ║"
echo -e "╚═══════════════════════════════════════════════╝${NC}"

echo -e "\n${GRN}[►] 1/3 — Enumerazione host raggiungibili${NC}"
nmap -sn 192.168.56.0/24 --open -oG /tmp/live-hosts.txt 2>/dev/null
grep "Up" /tmp/live-hosts.txt | awk '{print $2}' || echo "Nessun host trovato in 192.168.56.0/24"

echo -e "\n${GRN}[►] 2/3 — Tentativo connessione SSH laterale${NC}"
echo "Connessione SSH a $TARGET (atteso: alert T1021.004)"
ssh -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -o PasswordAuthentication=yes \
    -o BatchMode=yes \
    "user@$TARGET" "id; hostname" 2>&1 || true
sleep 1

echo -e "\n${GRN}[►] 3/3 — RDP Discovery${NC}"
nmap -sS -p 3389 192.168.56.0/24 --open 2>/dev/null | grep -E "open|Nmap"
echo "Trigger atteso: Suricata SID 9000070"

echo
echo "  Alert attesi : SID 9000040 (SSH esterno), 9000070 (RDP scan)"
echo "  Tattica      : Lateral Movement"
echo "  Tecnica      : T1021.004 — Remote Services SSH"
echo -e "\n${GRN}Simulazione completata.${NC}"
