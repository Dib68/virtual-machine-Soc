#!/usr/bin/env bash
# ============================================================================
#  ai  -  Assistente AI di cybersecurity (Ollama, locale e offline)
# ============================================================================
set -uo pipefail

MODEL="cyberai"
PERSONA=""
MODEL_SET=0

# Opzioni: --model <nome>, --persona <redteam|blueteam|explain>
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)   MODEL="${2:-cyberai}"; MODEL_SET=1; shift 2 ;;
    --persona) PERSONA="${2:-}"; shift 2 ;;
    -h|--help) echo "uso: ai [--model NOME] [--persona redteam|blueteam|explain] [domanda]"; exit 0 ;;
    *)         ARGS+=("$1"); shift ;;
  esac
done
if [ "${#ARGS[@]}" -gt 0 ]; then set -- "${ARGS[@]}"; else set --; fi

# Istruzione di "modalita'" anteposta alla domanda
case "$PERSONA" in
  redteam)  PRE="(Modalita Red Team: offensive security, in ambito autorizzato) " ;;
  blueteam) PRE="(Modalita Blue Team/SOC: difesa, detection, incident response) " ;;
  explain)  PRE="(Spiega in modo molto semplice, passo per passo) " ;;
  *)        PRE="" ;;
esac

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
# (solo quando l'utente non ha scelto esplicitamente un modello con --model)
if [ "$MODEL_SET" -eq 0 ] && ! ollama list 2>/dev/null | grep -q "$MODEL"; then
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
  ollama run "$MODEL" "${PRE}$*"
elif [ ! -t 0 ]; then
  DATA="$(cat)"
  ollama run "$MODEL" "${PRE}${DATA}"
else
  ollama run "$MODEL"
fi
