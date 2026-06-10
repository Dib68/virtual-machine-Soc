#!/usr/bin/env bash
# ============================================================================
#  ai  -  Assistente AI di cybersecurity (Ollama, locale e offline)
# ============================================================================
set -uo pipefail

MODEL="cyberai"

# Verifica che Ollama sia attivo
if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama non e' installato. Esegui di nuovo il provisioning oppure:"
  echo "  curl -fsSL https://ollama.com/install.sh | sh"
  exit 1
fi

# Avvia il servizio se non e' attivo
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "Avvio il servizio Ollama..."
  sudo systemctl start ollama 2>/dev/null || (ollama serve >/dev/null 2>&1 &)
  sleep 3
fi

# Se il modello specializzato non esiste, ricade su llama3.2
if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
  if [ -f /opt/cybersec/Modelfile ]; then
    ollama create "$MODEL" -f /opt/cybersec/Modelfile 2>/dev/null || MODEL="llama3.2"
  else
    MODEL="llama3.2"
  fi
fi

echo "============================================================"
echo "  CyberAI - assistente di sicurezza (modello: $MODEL)"
echo "  Scrivi la tua domanda. Esci con /bye o Ctrl+D."
echo "============================================================"

# Se l'utente passa una domanda come argomento, risposta singola.
# Se l'input arriva da una pipe (es. "cat log | ai"), lo legge come domanda.
if [ "$#" -gt 0 ]; then
  ollama run "$MODEL" "$*"
elif [ ! -t 0 ]; then
  DATA="$(cat)"
  ollama run "$MODEL" "$DATA"
else
  ollama run "$MODEL"
fi
