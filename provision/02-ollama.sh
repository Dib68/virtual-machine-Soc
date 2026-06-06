#!/usr/bin/env bash
# ============================================================================
#  02-ollama.sh  -  Installa l'AI locale (Ollama) dentro la VM
#  Ollama esegue modelli LLM (es. Llama 3) localmente: gratis, offline,
#  nessuna API key richiesta. E' il "cervello" dell'assistente AI integrato.
# ============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Installazione di Ollama (AI locale)..."

# Installazione ufficiale di Ollama
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "    Ollama gia' presente."
fi

# Abilita e avvia il servizio Ollama
systemctl enable ollama 2>/dev/null || true
systemctl start  ollama 2>/dev/null || true

# Attendi che il servizio risponda
echo "==> Attendo l'avvio del servizio Ollama..."
for i in $(seq 1 30); do
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "    Servizio attivo."
    break
  fi
  sleep 2
done

# ----------------------------------------------------------------------------
# Scarica un modello di default.
# llama3.2 (3B) e' leggero e gira bene anche con 6 GB di RAM.
# Per macchine piu' potenti si possono aggiungere modelli piu' grandi.
# ----------------------------------------------------------------------------
echo "==> Scarico il modello AI di default (llama3.2)..."
ollama pull llama3.2 || echo "    !! Download modello non riuscito (riprovare con: ollama pull llama3.2)"

# Modello opzionale piu' piccolo come fallback
ollama pull qwen2.5:1.5b 2>/dev/null || true

# ----------------------------------------------------------------------------
# Crea un "Modelfile" specializzato in cybersecurity: l'assistente AI
# risponde come un tutor esperto di sicurezza informatica, in italiano.
# ----------------------------------------------------------------------------
mkdir -p /opt/cybersec
cat > /opt/cybersec/Modelfile <<'EOF'
FROM llama3.2

SYSTEM """
Sei "CyberAI", un assistente esperto di cybersecurity integrato in una
macchina virtuale di laboratorio basata su Kali Linux. Aiuti l'utente a:
- capire e usare i tool di sicurezza (nmap, Metasploit, Burp, Wireshark, ecc.)
- spiegare comandi, opzioni ed esempi pratici
- ragionare su pentest, vulnerability assessment, OSINT e forensics
Rispondi in italiano, in modo chiaro e pratico, con esempi di comando quando utile.
Ricorda sempre all'utente di operare SOLO su sistemi propri o autorizzati,
perche' usare questi strumenti senza permesso e' illegale.
"""

PARAMETER temperature 0.6
EOF

echo "==> Creo il modello specializzato 'cyberai'..."
ollama create cyberai -f /opt/cybersec/Modelfile 2>/dev/null || \
  echo "    !! Creazione modello 'cyberai' rimandata (creabile dopo con: ollama create cyberai -f /opt/cybersec/Modelfile)"

echo ""
echo "============================================================"
echo " AI locale installata."
echo " Avvio assistente:   ai          (oppure: ollama run cyberai)"
echo "============================================================"
