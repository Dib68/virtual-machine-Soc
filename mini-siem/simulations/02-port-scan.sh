#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1046 — Network Service Discovery
#  MITRE ATT&CK: Discovery > Network Service Scanning
# ============================================================
set -euo pipefail

TARGET="${1:-172.20.0.10}"
ATTACKER_IMG="${ATTACKER_IMG:-siem-attacker}"
YLW='\033[1;33m'; GRN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

_docker_fallback() {
  if ! docker image inspect "${ATTACKER_IMG}" >/dev/null 2>&1; then
    echo -e "${YLW}[Docker] Building attacker image (first run ~2 min)...${NC}"
    docker build -q -t "${ATTACKER_IMG}" "${SCRIPT_DIR}/"
  fi
  echo -e "${YLW}[Docker] Running ${SCRIPT_NAME} in attacker container...${NC}"
  exec docker run --rm \
    --network siem-net \
    -v "${SCRIPT_DIR}:/simulations:ro" \
    "${ATTACKER_IMG}" \
    bash "/simulations/${SCRIPT_NAME}" "$TARGET"
}

check_tools() {
  if ! command -v nmap >/dev/null 2>&1; then
    echo -e "${YLW}nmap non trovato.${NC}"
    if command -v docker >/dev/null 2>&1; then _docker_fallback; fi
    echo -e "${RED}Installa: apt install nmap  (o usa: make build-attacker)${NC}"; exit 1
  fi
}

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
check_tools

step "1/3 — SYN Stealth Scan (top 1000 porte)"
nmap -sS -T4 --top-ports 1000 "$TARGET" -oN /tmp/scan-syn.txt
grep -E "open|filtered" /tmp/scan-syn.txt || true

step "2/3 — Service Version Detection"
nmap -sV -T3 -p 22,80,443,2222,3389,8080,8443 "$TARGET" -oN /tmp/scan-svc.txt
grep "open" /tmp/scan-svc.txt || true

step "3/3 — OS Detection"
sudo nmap -O "$TARGET" -oN /tmp/scan-os.txt 2>/dev/null | grep -E "OS:|Running:" || true

echo
echo "  Alert attesi : Suricata SID 9000010, 9000011"
echo "  Tattica      : Discovery"
echo "  Tecnica      : T1046 - Network Service Scanning"
echo -e "\n${GRN}Scan completato. Controlla gli alert su Kibana.${NC}"
