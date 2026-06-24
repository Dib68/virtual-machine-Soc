#!/usr/bin/env bash
# ============================================================
#  Integration Test — Mini-SIEM Detection Pipeline
#
#  Verifica che l'intera pipeline funzioni:
#    Attack → Suricata → Filebeat → Logstash → Elasticsearch
#
#  Uso:
#    bash scripts/integration-test.sh           # full test
#    bash scripts/integration-test.sh --quick   # solo curl (no nmap/hydra)
#
#  Prerequisiti: stack in esecuzione (make up)
#  Ritorna:  0 = tutti i test passati | 1 = almeno un test fallito
# ============================================================
set -euo pipefail

ES="${ES_URL:-http://localhost:9200}"
TARGET="${TARGET:-172.20.0.10}"
TARGET_HTTP="http://${TARGET}:8080"
TARGET_SSH="${TARGET}"
TARGET_SSH_PORT="${TARGET_SSH_PORT:-2222}"
WAIT_SECS="${WAIT_SECS:-45}"
QUICK="${1:-}"

GRN='\033[0;32m'; RED='\033[0;31m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'

PASSES=0
FAILS=0
WARNINGS=0

_pass()  { echo -e "  ${GRN}PASS${NC}  $*"; PASSES=$((PASSES+1)); }
_fail()  { echo -e "  ${RED}FAIL${NC}  $*"; FAILS=$((FAILS+1)); }
_warn()  { echo -e "  ${YLW}WARN${NC}  $*"; WARNINGS=$((WARNINGS+1)); }
_info()  { echo -e "  ${BLU}INFO${NC}  $*"; }
_step()  { echo -e "\n${YLW}[Step $*]${NC}"; }

echo -e "\n${YLW}════════════════════════════════════════════════════${NC}"
echo -e "${YLW}  Mini-SIEM Integration Test${NC}"
echo -e "${YLW}  ES: ${ES}   Target: ${TARGET}${NC}"
echo -e "${YLW}════════════════════════════════════════════════════${NC}"

# ── 1. Preflight ────────────────────────────────────────────
_step "1/5  Preflight checks"

if ! curl -sf "${ES}/_cluster/health" >/dev/null 2>&1; then
  echo -e "${RED}FATAL: Elasticsearch non raggiungibile su ${ES}${NC}"
  echo -e "       Avvia lo stack con: ${YLW}make up${NC}"
  exit 1
fi

CLUSTER=$(curl -sf "${ES}/_cluster/health" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
_pass "Elasticsearch up — cluster status: ${CLUSTER}"

if curl -sf -m 3 "${TARGET_HTTP}/" >/dev/null 2>&1; then
  _pass "Target HTTP raggiungibile (${TARGET_HTTP})"
else
  _warn "Target HTTP non raggiungibile — i test web potrebbero non generare alert"
fi

if command -v python3 >/dev/null 2>&1; then
  _pass "python3 disponibile"
else
  _fail "python3 non trovato — necessario per query ES"
fi

# Timestamp di inizio (usato per filtrare solo i nuovi alert)
TS_START=$(python3 -c "
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
")
_info "Timestamp inizio test: ${TS_START}"

# ── 2. Web attacks (T1190) — solo curl, sempre disponibile ──
_step "2/5  Attack simulation — T1190 Web Application Attacks"

_info "Invio payload SQL Injection → SID 9000030"
for payload in \
    "/?id=1'+OR+'1'%3D'1" \
    "/login?user=%27+OR+%271%27%3D%271&pass=x" \
    "/vulnerabilities/sqli/?id=1%27%20OR%20%271%27%3D%271%23"; do
  curl -sf -o /dev/null -m 3 "${TARGET_HTTP}${payload}" 2>/dev/null || true
done

_info "Invio payload XSS → SID 9000031"
curl -sf -o /dev/null -m 3 \
  "${TARGET_HTTP}/vulnerabilities/xss_r/?name=%3Cscript%3Ealert(1)%3C%2Fscript%3E" \
  2>/dev/null || true

_info "Invio payload Directory Traversal → SID 9000032"
for path in "/../../../etc/passwd" "/vulnerabilities/fi/?page=../../../../etc/passwd"; do
  curl -sf -o /dev/null -m 3 "${TARGET_HTTP}${path}" 2>/dev/null || true
done

_info "Invio scanner-style requests (Nikto UA) → SID 9000020"
curl -sf -o /dev/null -m 3 \
  -A "Mozilla/5.0 (Nikto/2.1.6) (Evasions:None) (Test:Port Check)" \
  "${TARGET_HTTP}/" 2>/dev/null || true
for path in /admin /.env /config.php /backup.sql /phpinfo.php /server-status; do
  curl -sf -o /dev/null -m 2 "${TARGET_HTTP}${path}" 2>/dev/null || true
done
_info "Web payload inviati"

# ── 3. SSH brute force (T1110) — se sshpass/ssh disponibile ─
_step "3/5  Attack simulation — T1110 SSH Brute Force"

if [[ "${QUICK}" == "--quick" ]]; then
  _info "Modalità --quick: skip SSH brute force"
elif command -v sshpass >/dev/null 2>&1; then
  _info "sshpass trovato — invio 10 tentativi SSH → SID 9000001"
  for p in password 123456 admin root toor qwerty letmein welcome hunter1 iloveyou; do
    sshpass -p "$p" ssh \
      -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
      -p "${TARGET_SSH_PORT}" "root@${TARGET_SSH}" "id" 2>/dev/null || true
  done
  _info "SSH brute force completato"
else
  _info "sshpass non trovato — uso ssh con wrong user (genera auth.log events)"
  for i in $(seq 1 10); do
    ssh \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=2 \
      -o PasswordAuthentication=no \
      -o PubkeyAuthentication=yes \
      -o BatchMode=yes \
      -p "${TARGET_SSH_PORT}" \
      "baduser${i}@${TARGET_SSH}" "id" 2>/dev/null || true
  done
  _info "SSH auth attempts completati"
fi

# ── 4. Wait for pipeline ────────────────────────────────────
_step "4/5  Attesa pipeline (Suricata → Filebeat → Logstash → ES)"
echo -ne "  Attendo ${WAIT_SECS}s"
for i in $(seq 1 "${WAIT_SECS}"); do
  sleep 1
  if (( i % 5 == 0 )); then echo -ne " ${i}s"; fi
done
echo ""

# ── 5. Verify alerts in ES ──────────────────────────────────
_step "5/5  Verifica alert in Elasticsearch"

_check_count() {
  local label="$1"
  local index="$2"
  local query="$3"
  local min="${4:-1}"

  local count
  count=$(curl -sf -X GET "${ES}/${index}/_count" \
    -H 'Content-Type: application/json' \
    -d "${query}" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" \
    2>/dev/null || echo 0)

  if [ "${count}" -ge "${min}" ]; then
    _pass "${label} — ${count} eventi"
  else
    _fail "${label} — ${count} eventi (attesi >= ${min})"
  fi
}

# Suricata alert events
_check_count \
  "Suricata alert events" \
  "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${TS_START}\"}}}]}}}" \
  1

# Auth log events
_check_count \
  "Auth log events" \
  "siem-auth-*" \
  "{\"query\":{\"range\":{\"@timestamp\":{\"gte\":\"${TS_START}\"}}}}" \
  1

# Verify MITRE fields enriched by Logstash
_check_count \
  "MITRE technique field present" \
  "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"exists\":{\"field\":\"mitre.technique\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${TS_START}\"}}}]}}}" \
  1

# GeoIP enrichment present
_check_count \
  "GeoIP enrichment (source.geo.country_name)" \
  "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"exists\":{\"field\":\"source.geo.country_name\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${TS_START}\"}}}]}}}" \
  1

# ── Summary ─────────────────────────────────────────────────
echo ""
echo -e "${YLW}════════════════════════════════════════════════════${NC}"
TOTAL=$((PASSES + FAILS))
if [ "${FAILS}" -eq 0 ]; then
  echo -e "${GRN}  RISULTATO: TUTTI I ${PASSES}/${TOTAL} TEST PASSATI${NC}"
  echo -e "${GRN}  Pipeline funziona correttamente end-to-end${NC}"
  EXITCODE=0
else
  echo -e "${RED}  RISULTATO: ${FAILS} FALLITI / ${TOTAL} TOTALI${NC}"
  if [ "${WARNINGS}" -gt 0 ]; then
    echo -e "${YLW}  Warnings: ${WARNINGS}${NC}"
  fi
  echo -e "${YLW}  Debug: make logs | grep -E 'suricata|logstash'${NC}"
  EXITCODE=1
fi
if [ "${PASSES}" -gt 0 ] && [ "${FAILS}" -eq 0 ]; then
  echo ""
  echo -e "  Kibana alerts: ${BLU}http://localhost:5601/app/security/alerts${NC}"
fi
echo -e "${YLW}════════════════════════════════════════════════════${NC}"
echo ""
exit "${EXITCODE}"
