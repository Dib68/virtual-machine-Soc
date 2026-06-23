#!/usr/bin/env bash
# ============================================================
#  Threat Intel Enrichment — AbuseIPDB + ip-api.com
#  Estrae gli IP dagli alert Elasticsearch e li arricchisce
#  con reputazione, geolocalizzazione e ASN.
#
#  Uso: ./scripts/enrich-iocs.sh [--limit N]
#  Prerequisiti: curl, python3, jq (opzionale)
#  API key AbuseIPDB: export ABUSEIPDB_KEY="<your-key>"
# ============================================================
set -euo pipefail

ES="http://localhost:9200"
LIMIT="${2:-10}"
KEY="${ABUSEIPDB_KEY:-}"
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'

banner() {
  echo -e "${YLW}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  Threat Intel Enrichment — Mini-SIEM Lab             ║"
  echo "║  Sources: AbuseIPDB · ip-api.com · BGP ranking       ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

check_es() {
  curl -sf "$ES/_cluster/health" > /dev/null 2>&1 || {
    echo -e "${RED}Elasticsearch non raggiungibile su $ES${NC}"
    echo "Avvia il lab con: make up"
    exit 1
  }
}

# Estrai top IP offensivi da Elasticsearch
extract_ips() {
  curl -sf -X GET "$ES/siem-suricata-*,siem-auth-*/_search" \
    -H 'Content-Type: application/json' \
    -d "{
      \"size\": 0,
      \"query\": {
        \"bool\": {
          \"must\": [
            {\"range\": {\"@timestamp\": {\"gte\": \"now-24h\"}}},
            {\"exists\": {\"field\": \"source.ip\"}}
          ],
          \"must_not\": [
            {\"terms\": {\"source.ip\": [
              \"127.0.0.1\", \"::1\",
              \"192.168.0.1\", \"192.168.56.1\",
              \"10.0.2.2\", \"172.17.0.1\"
            ]}}
          ]
        }
      },
      \"aggs\": {
        \"top_ips\": {
          \"terms\": {\"field\": \"source.ip\", \"size\": $LIMIT}
        }
      }
    }" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for b in data.get('aggregations', {}).get('top_ips', {}).get('buckets', []):
    print(b['key'])
" 2>/dev/null || echo ""
}

# GeoIP + ASN (ip-api.com, no key needed)
geo_lookup() {
  local ip="$1"
  curl -sf "http://ip-api.com/json/$ip?fields=status,country,countryCode,city,isp,org,as,proxy,hosting" \
    2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('status') == 'success':
    proxy = '⚠ VPN/Proxy/Tor' if d.get('proxy') or d.get('hosting') else ''
    print(f\"  Country : {d.get('country','?')} ({d.get('countryCode','?')}) — {d.get('city','?')}\")
    print(f\"  ISP     : {d.get('isp','?')}\")
    print(f\"  ASN     : {d.get('as','?')}\")
    if proxy:
        print(f\"  Flag    : {proxy}\")
else:
    print('  GeoIP   : lookup failed')
" 2>/dev/null || echo "  GeoIP   : unavailable"
}

# AbuseIPDB (richiede API key)
abuseipdb_lookup() {
  local ip="$1"
  if [ -z "$KEY" ]; then
    echo "  AbuseIPDB: no API key set (export ABUSEIPDB_KEY=<your-key>)"
    return
  fi
  curl -sf "https://api.abuseipdb.com/api/v2/check" \
    -H "Key: $KEY" \
    -H "Accept: application/json" \
    -G --data-urlencode "ipAddress=$ip" \
    --data "maxAgeInDays=30" \
    --data "verbose" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin).get('data', {})
score = d.get('abuseConfidenceScore', 0)
color = '\033[0;31m' if score > 50 else ('\033[1;33m' if score > 10 else '\033[0;32m')
nc = '\033[0m'
print(f\"  AbuseIPDB: {color}Score {score}/100{nc} · Reports: {d.get('totalReports',0)} · ISP: {d.get('isp','?')}\")
print(f\"  Usage     : {d.get('usageType','?')} · Domain: {d.get('domain','?')}\")
" 2>/dev/null || echo "  AbuseIPDB: lookup failed"
}

# ── Main ───────────────────────────────────────────────────
banner
check_es

echo -e "${GRN}Estraggo top $LIMIT IP offensivi dagli alert (ultime 24h)...${NC}\n"
IPS=$(extract_ips)

if [ -z "$IPS" ]; then
  echo "Nessun IP trovato. Lancia una simulazione prima: make attack-all"
  exit 0
fi

COUNT=0
while IFS= read -r IP; do
  [ -z "$IP" ] && continue
  COUNT=$((COUNT+1))
  echo -e "${RED}[$COUNT] $IP${NC}"

  geo_lookup "$IP"
  abuseipdb_lookup "$IP"

  # Controllo RFC1918 (IP privato)
  if echo "$IP" | python3 -c "
import sys, ipaddress
ip = ipaddress.ip_address(sys.stdin.read().strip())
print('PRIVATE' if ip.is_private else 'PUBLIC')
" 2>/dev/null | grep -q PRIVATE; then
    echo -e "  ${YLW}⚠ IP privato — possibile compromissione interna${NC}"
  fi

  echo ""
done <<< "$IPS"

echo -e "${GRN}Enrichment completato per $COUNT IP.${NC}"
echo -e "Kibana: ${BLU}http://localhost:5601${NC}"
