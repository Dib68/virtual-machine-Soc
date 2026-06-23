#!/bin/sh
# Carica i dashboard Kibana salvati via Saved Objects API
set -e

KIBANA="http://kibana:5601"
DASHBOARDS_DIR="/dashboards"

echo "Attendo Kibana..."
until curl -sf "$KIBANA/api/status" | grep -q '"level":"available"'; do
  sleep 5
done
echo "Kibana pronto."

for f in "$DASHBOARDS_DIR"/*.ndjson; do
  [ -f "$f" ] || continue
  echo "Carico: $f"
  curl -sf -X POST "$KIBANA/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@"$f" > /dev/null && echo "  OK" || echo "  WARN: import fallito per $f"
done

echo "Dashboard caricate."
