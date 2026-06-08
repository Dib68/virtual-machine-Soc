#!/usr/bin/env bash
# ai-explain - invia un file o l'output di un comando all'AI per spiegazione
# Uso:
#   ai-explain file.txt
#   nmap -sV target | ai-explain
#   ai-explain --cmd "nmap -sV 10.0.0.1"
set -uo pipefail
MODEL="cyberai"; ollama list 2>/dev/null | grep -q "$MODEL" || MODEL="llama3.2"
PROMPT="Sei un analista di cybersecurity. Spiega il seguente output/contenuto, evidenzia rischi, vulnerabilita' e prossimi passi pratici. Rispondi in italiano.\n\n"
if [ "${1:-}" = "--cmd" ] && [ -n "${2:-}" ]; then
  DATA=$(eval "$2" 2>&1)
elif [ -n "${1:-}" ] && [ -f "$1" ]; then
  DATA=$(cat "$1")
else
  DATA=$(cat)   # da stdin (pipe)
fi
printf '%b%s' "$PROMPT" "$DATA" | ollama run "$MODEL"
