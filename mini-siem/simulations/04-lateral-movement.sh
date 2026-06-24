#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1021.004 — Remote Services: SSH
#  MITRE ATT&CK: Lateral Movement
# ============================================================
set -euo pipefail

TARGET="${1:-172.20.0.10}"
TARGET_SSH_PORT="${TARGET_SSH_PORT:-2222}"
SUBNET="${SUBNET:-172.20.0.0/24}"
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
    -e TARGET="${TARGET}" \
    -e TARGET_SSH_PORT="${TARGET_SSH_PORT}" \
    -e SUBNET="${SUBNET}" \
    "${ATTACKER_IMG}" \
    bash "/simulations/${SCRIPT_NAME}" "$TARGET"
}

echo -e "${YLW}╔═══════════════════════════════════════════════╗"
echo    "║  MITRE T1021.004 — Lateral Movement via SSH  ║"
echo -e "╚═══════════════════════════════════════════════╝${NC}"

echo -e "\n${GRN}[►] 1/3 — Enumerazione host raggiungibili${NC}"
if command -v nmap >/dev/null 2>&1; then
  nmap -sn "${SUBNET}" --open -oG /tmp/live-hosts.txt 2>/dev/null
  grep "Up" /tmp/live-hosts.txt | awk '{print $2}' || echo "Nessun host trovato in ${SUBNET}"
elif command -v docker >/dev/null 2>&1; then
  _docker_fallback
else
  echo -e "${RED}nmap non trovato — skip host discovery${NC}"
  echo -e "${RED}Installa: apt install nmap  (o usa: make build-attacker)${NC}"
fi

echo -e "\n${GRN}[►] 2/3 — Tentativo connessione SSH laterale${NC}"
echo "Connessione SSH a $TARGET:${TARGET_SSH_PORT} (atteso: alert T1021.004)"
ssh -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -o PasswordAuthentication=yes \
    -o BatchMode=yes \
    -p "${TARGET_SSH_PORT}" \
    "user@$TARGET" "id; hostname" 2>&1 || true
sleep 1

echo -e "\n${GRN}[►] 3/3 — RDP Discovery${NC}"
if command -v nmap >/dev/null 2>&1; then
  nmap -sS -p 3389 "${SUBNET}" --open 2>/dev/null | grep -E "open|Nmap" || true
fi
echo "Trigger atteso: Suricata SID 9000070"

echo
echo "  Alert attesi : SID 9000040 (SSH esterno), 9000070 (RDP scan)"
echo "  Tattica      : Lateral Movement"
echo "  Tecnica      : T1021.004 — Remote Services SSH"
echo -e "\n${GRN}Simulazione completata.${NC}"
