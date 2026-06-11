#!/usr/bin/env bash
# ai-explain - invia un file o l'output di un comando all'AI per spiegazione
# Uso:
#   ai-explain file.txt
#   nmap -sV target | ai-explain
#   ai-explain --cmd "nmap -sV 10.0.0.1"
set -uo pipefail

# Ollama installato?
if ! command -v ollama >/dev/null 2>&1; then
  echo "L'AI (Ollama) non e' installata. Installala con:" >&2
  echo "  sudo bash /vagrant/provision/02-ollama.sh" >&2
  exit 1
fi
# Avvia il servizio se non risponde (cosi' ai-explain parte da solo)
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  sudo -n systemctl start ollama 2>/dev/null || (setsid ollama serve >/tmp/ollama.log 2>&1 </dev/null &)
  for i in $(seq 1 20); do curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done
fi
MODEL="cyberai"; ollama list 2>/dev/null | grep -q "^$MODEL" || MODEL="llama3.2"
PROMPT="Sei un analista di cybersecurity. Spiega il seguente output/contenuto, evidenzia rischi, vulnerabilita' e prossimi passi pratici. Rispondi in italiano.\n\n"
if [ "${1:-}" = "--cmd" ] && [ -n "${2:-}" ]; then
  DATA=$(eval "$2" 2>&1)
elif [ -n "${1:-}" ] && [ -f "$1" ]; then
  DATA=$(cat "$1")
else
  DATA=$(cat)   # da stdin (pipe)
fi
printf '%b%s' "$PROMPT" "$DATA" | ollama run "$MODEL"
