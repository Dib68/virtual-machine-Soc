#!/usr/bin/env bash
# cyberupdate - aggiorna sistema, database e modelli AI
set -uo pipefail
echo "==> apt update/upgrade..."; sudo apt-get update -y && sudo apt-get upgrade -y
echo "==> searchsploit..."; sudo searchsploit -u 2>/dev/null || true
echo "==> nuclei templates..."; nuclei -update-templates 2>/dev/null || true
echo "==> suricata rules..."; sudo suricata-update 2>/dev/null || true
echo "==> ClamAV..."; sudo freshclam 2>/dev/null || true
echo "==> modelli Ollama..."; ollama list 2>/dev/null | awk 'NR>1{print $1}' | while read m; do ollama pull "$m" 2>/dev/null || true; done
echo "==> Fatto."
