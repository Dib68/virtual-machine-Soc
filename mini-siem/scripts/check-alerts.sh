#!/usr/bin/env bash
# Mostra un riepilogo degli alert delle ultime 24 ore via Elasticsearch API
set -euo pipefail

ES="http://localhost:9200"
GRN='\033[0;32m'; YLW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${YLW}=== Mini-SIEM Alert Summary (last 24h) ===${NC}\n"

# Controlla che ES sia raggiungibile
curl -sf "$ES/_cluster/health" > /dev/null || {
  echo -e "${RED}Elasticsearch non raggiungibile su $ES${NC}"
  exit 1
}

# Conta alert per tipo (suricata alerts)
echo -e "${GRN}Top Suricata Alert Rules:${NC}"
curl -sf -X GET "$ES/siem-suricata-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "query": {
      "bool": {
        "must": [
          {"term": {"suricata.event_type": "alert"}},
          {"range": {"@timestamp": {"gte": "now-24h"}}}
        ]
      }
    },
    "aggs": {
      "top_rules": {
        "terms": {"field": "suricata.alert.signature.keyword", "size": 10}
      }
    }
  }' 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
buckets = data.get('aggregations', {}).get('top_rules', {}).get('buckets', [])
for b in buckets:
    print(f\"  {b['doc_count']:>5}  {b['key']}\")
" 2>/dev/null || echo "  (nessun dato — avvia il lab e lancia una simulazione)"

echo ""
echo -e "${GRN}SSH Failed Logins (auth.log):${NC}"
curl -sf -X GET "$ES/siem-auth-*/_count" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"term": {"event.outcome": "failure"}},
          {"range": {"@timestamp": {"gte": "now-24h"}}}
        ]
      }
    }
  }' 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"  {data.get('count', 0)} failed login attempts\")
" 2>/dev/null || echo "  (nessun dato)"

echo ""
echo -e "  Kibana: ${GRN}http://localhost:5601${NC}"
