#!/usr/bin/env bash
# ============================================================================
#  soclab  -  Gestore del laboratorio SOC (stack Docker)
#  Avvia/ferma SIEM, threat intel, incident response e bersagli vulnerabili.
#
#  USO:
#    soclab targets up|down    # DVWA + Juice Shop + WebGoat (bersagli)
#    soclab splunk  up|down    # Splunk Free (SIEM)
#    soclab elk     up|down    # Elasticsearch + Kibana (SIEM/log)
#    soclab wazuh   up|down    # Wazuh (SIEM + EDR)
#    soclab misp    up|down    # MISP (threat intelligence)
#    soclab thehive up|down    # TheHive + Cortex (incident response)
#    soclab webui   up|down    # OpenWebUI (AI web, stile ChatGPT)
#    soclab status             # container attivi
#    soclab urls               # indirizzi web dei servizi
#    soclab stopall            # ferma tutti gli stack
# ============================================================================
set -uo pipefail

LAB_DIR="/opt/cybersec/soc-lab"
WAZUH_DIR="$LAB_DIR/wazuh-docker"
WAZUH_VER="v4.9.2"

dc() {
  if docker compose version >/dev/null 2>&1; then docker compose "$@";
  else docker-compose "$@"; fi
}

need_docker() {
  command -v docker >/dev/null 2>&1 || { echo "Docker non installato."; exit 1; }
  docker info >/dev/null 2>&1 || { echo "Avvio Docker..."; sudo systemctl start docker; sleep 2; }
}

wazuh() {
  need_docker
  if [ ! -d "$WAZUH_DIR" ]; then
    echo "Scarico Wazuh single-node ($WAZUH_VER)..."
    git clone --depth 1 -b "$WAZUH_VER" https://github.com/wazuh/wazuh-docker.git "$WAZUH_DIR" \
      || { echo "Clone fallito."; exit 1; }
  fi
  cd "$WAZUH_DIR/single-node"
  case "${1:-up}" in
    up)
      dc -f generate-indexer-certs.yml run --rm generator || true
      dc up -d
      echo "Wazuh -> https://localhost:443  (admin / SecretPassword)"
      echo "ATTENZIONE: richiede molta RAM (consigliati 10+ GB alla VM)." ;;
    down) dc down ;;
    *) echo "uso: soclab wazuh up|down" ;;
  esac
}

stack() {
  local name="$1" action="${2:-up}"
  need_docker
  cd "$LAB_DIR/$name" || { echo "Stack $name non trovato"; exit 1; }
  case "$action" in
    up)   dc up -d; echo "Stack '$name' avviato."; urls ;;
    down) dc down;  echo "Stack '$name' fermato." ;;
    *) echo "uso: soclab $name up|down" ;;
  esac
}

urls() {
  cat <<EOF

  Indirizzi dei servizi (quando attivi):
    Wazuh SIEM ....... https://localhost:443     (admin / SecretPassword)
    Splunk ........... http://localhost:8000      (admin / Changeme123!)
    Kibana (ELK) ..... http://localhost:5601
    MISP ............. https://localhost:8443      (admin@admin.test / admin)
    TheHive .......... http://localhost:9000
    Cortex ........... http://localhost:9001
    OpenWebUI (AI) ... http://localhost:3001
    DVWA ............. http://localhost:8080       (admin / password)
    OWASP Juice Shop . http://localhost:3000
    WebGoat .......... http://localhost:8081/WebGoat
EOF
}

status() {
  need_docker
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

stopall() {
  need_docker
  for s in targets splunk elk misp thehive webui; do
    [ -d "$LAB_DIR/$s" ] && (cd "$LAB_DIR/$s" && dc down 2>/dev/null) || true
  done
  [ -d "$WAZUH_DIR/single-node" ] && (cd "$WAZUH_DIR/single-node" && dc down 2>/dev/null) || true
  echo "Tutti gli stack fermati."
}

case "${1:-}" in
  wazuh)   shift; wazuh "${1:-up}" ;;
  splunk|elk|misp|thehive|targets|webui) name="$1"; shift; stack "$name" "${1:-up}" ;;
  status)  status ;;
  urls)    urls ;;
  stopall) stopall ;;
  *) echo "uso: soclab {targets|splunk|elk|wazuh|misp|thehive|webui} {up|down} | status | urls | stopall" ;;
esac
