#!/usr/bin/env bash
# ============================================================
#  Daily SOC Digest — Mini-SIEM Lab
#  Briefing di inizio turno: statistiche ultime 24h,
#  top attaccanti, alert critici, stato dei servizi.
#
#  Uso: bash scripts/daily-digest.sh
#       bash scripts/daily-digest.sh --yesterday   # ultime 48h
#       0 * * * * bash /opt/mini-siem/scripts/daily-digest.sh >> /var/log/siem-digest.log 2>&1
# ============================================================
set -euo pipefail

ES="${ES_URL:-http://localhost:9200}"
KIBANA="${KIBANA_URL:-http://localhost:5601}"
WINDOW="${1:-now-24h}"
if [ "$WINDOW" = "--yesterday" ]; then WINDOW="now-48h"; fi

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
BLU='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

_es() {
  local idx="$1" body="$2"
  curl -sf -X POST "${ES}/${idx}/_search" \
    -H 'Content-Type: application/json' \
    -d "${body}" 2>/dev/null
}

_count() {
  local idx="$1" body="$2"
  curl -sf -X POST "${ES}/${idx}/_count" \
    -H 'Content-Type: application/json' \
    -d "${body}" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))" 2>/dev/null \
    || echo 0
}

_agg() {
  local idx="$1" body="$2" path="$3"
  _es "$idx" "$body" \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
buckets=d
for k in '${path}'.split('.'):
    buckets=buckets.get(k,{})
for b in (buckets if isinstance(buckets,list) else []):
    print(f\"{b.get('doc_count',0):>6}  {b.get('key','?')}\")
" 2>/dev/null || true
}

# ── Header ─────────────────────────────────────────────────
DATE_STR=$(date '+%Y-%m-%d %H:%M %Z')
echo ""
echo -e "${BOLD}${YLW}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${YLW}║  Mini-SIEM Daily SOC Digest — ${DATE_STR}  ║${NC}"
echo -e "${BOLD}${YLW}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Preflight ──────────────────────────────────────────────
if ! curl -sf "${ES}/_cluster/health" >/dev/null 2>&1; then
  echo -e "${RED}✗ Elasticsearch non raggiungibile su ${ES}${NC}"
  echo -e "  Avvia lo stack: ${YLW}make up${NC}"
  exit 1
fi

CLUSTER_STATUS=$(curl -sf "${ES}/_cluster/health" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'])" 2>/dev/null)
STATUS_COLOR="${GRN}"
[ "$CLUSTER_STATUS" = "yellow" ] && STATUS_COLOR="${YLW}"
[ "$CLUSTER_STATUS" = "red" ]    && STATUS_COLOR="${RED}"

echo -e "  ES cluster  : ${STATUS_COLOR}${CLUSTER_STATUS}${NC}"
echo -e "  Kibana      : ${BLU}${KIBANA}${NC}"
echo -e "  Window      : last 24h  (${WINDOW} → now)"
echo ""

# ── KPIs ──────────────────────────────────────────────────
echo -e "${BOLD}── KPI Ultime 24h ───────────────────────────────────────${NC}"

TOTAL_ALERTS=$(_count "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}}}")

CRITICAL_ALERTS=$(_count "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"term\":{\"suricata.alert.severity\":1}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}}}")

HIGH_ALERTS=$(_count "siem-suricata-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"term\":{\"suricata.alert.severity\":2}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}}}")

SSH_FAILS=$(_count "siem-auth-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"event.outcome\":\"failure\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}}}")

SSH_OK=$(_count "siem-auth-*" \
  "{\"query\":{\"bool\":{\"must\":[{\"term\":{\"event.outcome\":\"success\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}}}")

echo -e "  Total alerts   : ${BOLD}${TOTAL_ALERTS}${NC}"
if [ "${CRITICAL_ALERTS}" -gt 0 ]; then
  echo -e "  Critical       : ${RED}${BOLD}${CRITICAL_ALERTS}${NC} ← ATTENZIONE"
else
  echo -e "  Critical       : ${GRN}${CRITICAL_ALERTS}${NC}"
fi
echo -e "  High           : ${YLW}${HIGH_ALERTS}${NC}"
echo -e "  SSH failures   : ${SSH_FAILS}"
if [ "${SSH_OK}" -gt 0 ]; then
  echo -e "  SSH successes  : ${YLW}${BOLD}${SSH_OK}${NC} ← verifica se atteso"
else
  echo -e "  SSH successes  : ${GRN}${SSH_OK}${NC}"
fi
echo ""

# ── Top 5 Attaccanti ──────────────────────────────────────
echo -e "${BOLD}── Top 5 Source IP (Suricata alerts) ───────────────────${NC}"
_agg "siem-suricata-*" \
  "{\"size\":0,\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}},\"aggs\":{\"top_src\":{\"terms\":{\"field\":\"source.ip\",\"size\":5}}}}" \
  "aggregations.top_src.buckets" \
  | while IFS= read -r line; do echo "  ${line}"; done
echo ""

# ── Top 5 Regole ──────────────────────────────────────────
echo -e "${BOLD}── Top 5 Suricata Rules ────────────────────────────────${NC}"
_agg "siem-suricata-*" \
  "{\"size\":0,\"query\":{\"bool\":{\"must\":[{\"term\":{\"suricata.event_type\":\"alert\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}},\"aggs\":{\"top_rules\":{\"terms\":{\"field\":\"rule.name.keyword\",\"size\":5}}}}" \
  "aggregations.top_rules.buckets" \
  | while IFS= read -r line; do echo "  ${line}"; done
echo ""

# ── MITRE Technique Breakdown ─────────────────────────────
echo -e "${BOLD}── MITRE ATT&CK Techniques (ultime 24h) ────────────────${NC}"
_agg "siem-suricata-*" \
  "{\"size\":0,\"query\":{\"bool\":{\"must\":[{\"exists\":{\"field\":\"mitre.technique\"}},{\"range\":{\"@timestamp\":{\"gte\":\"${WINDOW}\"}}}]}},\"aggs\":{\"by_technique\":{\"terms\":{\"field\":\"mitre.technique.keyword\",\"size\":10}}}}" \
  "aggregations.by_technique.buckets" \
  | while IFS= read -r line; do echo "  ${line}"; done || echo "  (nessun dato — esegui: make attack-all)"
echo ""

# ── Indici ES ─────────────────────────────────────────────
echo -e "${BOLD}── Elasticsearch Indices ───────────────────────────────${NC}"
curl -sf "${ES}/_cat/indices/siem-*?h=index,docs.count,store.size&s=docs.count:desc" \
  2>/dev/null | head -8 | while IFS= read -r line; do echo "  ${line}"; done || true
echo ""

# ── Azioni Raccomandate ───────────────────────────────────
echo -e "${BOLD}── Azioni Turno ────────────────────────────────────────${NC}"
if [ "${CRITICAL_ALERTS}" -gt 0 ]; then
  echo -e "  ${RED}▶ PRIORITÀ: ${CRITICAL_ALERTS} alert critici — avvia triage: make triage-high${NC}"
fi
if [ "${SSH_OK}" -gt 0 ]; then
  echo -e "  ${YLW}▶ VERIFICA: ${SSH_OK} login SSH riusciti — potenziale accesso non autorizzato${NC}"
fi
if [ "${TOTAL_ALERTS}" -eq 0 ]; then
  echo -e "  ${YLW}▶ ZERO alert — verifica che il lab sia attivo: make up${NC}"
elif [ "${CRITICAL_ALERTS}" -eq 0 ] && [ "${SSH_OK}" -eq 0 ]; then
  echo -e "  ${GRN}✓ Nessuna azione urgente. Esegui triage completo: make triage${NC}"
fi
echo -e "  ${BLU}▶ Kibana Security: ${KIBANA}/app/security/alerts${NC}"
echo ""
echo -e "${YLW}════════════════════════════════════════════════════════${NC}"
echo ""
