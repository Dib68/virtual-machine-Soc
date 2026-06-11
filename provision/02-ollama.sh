#!/usr/bin/env bash
# ============================================================================
#  02-ollama.sh  -  Installa l'AI locale (Ollama) e crea il modello "cyberai".
#  Sceglie un modello PIU' POTENTE se la RAM lo permette, con fallback leggero.
# ============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Installazione di Ollama (AI locale)..."
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi
# Tieni il modello "caldo" in RAM 30 min dopo l'uso: le risposte successive
# sono molto piu' rapide (evita il ricaricamento da disco a ogni domanda).
if [ -d /etc/systemd/system ]; then
  mkdir -p /etc/systemd/system/ollama.service.d
  cat > /etc/systemd/system/ollama.service.d/keepalive.conf <<'EOF'
[Service]
Environment="OLLAMA_KEEP_ALIVE=30m"
EOF
  systemctl daemon-reload 2>/dev/null || true
fi
systemctl enable ollama 2>/dev/null || true
systemctl start  ollama 2>/dev/null || true
# Avvio manuale di scorta se non c'e' systemd attivo
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  setsid ollama serve >/var/log/ollama.log 2>&1 < /dev/null &
fi
echo "==> Attendo il servizio Ollama..."
for i in $(seq 1 40); do curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && break; sleep 2; done

# ----------------------------------------------------------------------------
# Scelta del modello in base alla RAM disponibile:
#   >= 7 GB  -> qwen2.5:7b  (molto piu' capace su tecnica/comandi)
#   altrimenti -> llama3.2 (3B, leggero)
# ----------------------------------------------------------------------------
RAM_GB=$(free -g 2>/dev/null | awk '/Mem:/{print $2}'); RAM_GB=${RAM_GB:-4}
[[ "$RAM_GB" =~ ^[0-9]+$ ]] || RAM_GB=4
if   [ "$RAM_GB" -ge 28 ]; then BASE="qwen2.5:14b"   # workstation: piu' preciso
elif [ "$RAM_GB" -ge 7  ]; then BASE="qwen2.5:7b"    # standard: ottimo compromesso
else                            BASE="llama3.2"; fi   # leggero: gira ovunque
echo "==> RAM ${RAM_GB}GB -> modello base scelto: $BASE"

echo "==> Scarico il modello (puo' richiedere parecchio: alcuni GB)..."
# Pull con piu' tentativi (la rete puo' fallire a meta'): non lasciare buchi.
pull_retry() {
  local m="$1" i
  for i in 1 2 3; do
    echo "   - pull '$m' (tentativo $i/3)..."
    if ollama pull "$m"; then return 0; fi
    sleep 3
  done
  return 1
}
if ! pull_retry "$BASE"; then
  echo "   !! '$BASE' non scaricato dopo 3 tentativi, passo al modello leggero llama3.2"
  BASE="llama3.2"
  pull_retry "$BASE" || echo "   !! anche llama3.2 ha fallito: controlla la connessione internet"
fi
# Modello leggero sempre presente come riserva (fallback della GUI)
[ "$BASE" = "llama3.2" ] || pull_retry llama3.2 || true

# ----------------------------------------------------------------------------
# Modello specializzato "cyberai": tutor esperto di cybersecurity.
# ----------------------------------------------------------------------------
mkdir -p /opt/cybersec
cat > /opt/cybersec/Modelfile <<EOF
FROM $BASE

PARAMETER temperature 0.35
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

SYSTEM """
Sei "CyberAI", un assistente esperto di cybersecurity integrato in una macchina
virtuale di laboratorio basata su Kali Linux (progetto "CyberSec AI VM").
Sei al tempo stesso un mentore per Penetration Tester e per SOC Analyst.

In questa VM sono disponibili, tra gli altri: nmap, masscan, Metasploit, Burp
Suite, OWASP ZAP, sqlmap, gobuster, nikto, OpenVAS/Greenbone, Hydra, John,
Hashcat, Wireshark, tcpdump, Bettercap, Aircrack-ng, theHarvester, Recon-ng,
SpiderFoot, Autopsy, Volatility3, binwalk, ExifTool, radare2, Ghidra, GDB,
NetExec, Impacket, Responder, Evil-WinRM, BloodHound, Kerbrute, Suricata, Snort,
Zeek, YARA, OSQuery, Velociraptor, nuclei, httpx, subfinder, AWS/Azure/GCP CLI,
kubectl, Terraform, Trivy, Prowler; e gli stack SOC via Docker (Splunk, Wazuh,
ELK, MISP, TheHive) tramite il comando 'soclab'.

Regole di risposta:
- Rispondi SEMPRE in italiano, in modo chiaro, pratico e ordinato.
- Quando spieghi uno strumento usa questa struttura: (1) a cosa serve in una
  riga; (2) comando/i pronti all'uso in un blocco; (3) un esempio realistico;
  (4) eventuali note o errori comuni.
- Fornisci comandi concreti e corretti per Kali Linux. Niente fronzoli.
- Se la domanda e' ambigua, fai una sola domanda di chiarimento, poi procedi.
- La conversazione ha memoria: tieni conto dei messaggi precedenti, non ripetere
  cose gia' dette e collega le risposte alle domande precedenti dell'utente.
- Ricorda all'utente, quando pertinente, di operare SOLO su sistemi propri o
  autorizzati: usare questi strumenti senza permesso e' illegale.
"""
EOF

echo "==> Creo il modello 'cyberai' (base: $BASE)..."
# Crea con verifica + un secondo tentativo. NIENTE 2>/dev/null: vogliamo vedere
# gli errori se qualcosa va storto (in passato fallivano in silenzio).
model_exists() { ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -q "^cyberai"; }
if ! model_exists; then ollama create cyberai -f /opt/cybersec/Modelfile || true; fi
if ! model_exists; then
  echo "   ...secondo tentativo di creazione di 'cyberai'..."
  ollama create cyberai -f /opt/cybersec/Modelfile || true
fi

# ----------------------------------------------------------------------------
# Verifica finale: se 'cyberai' non esiste, lo segnaliamo FORTE e lasciamo un
# marcatore che cyberdoctor e la GUI possono rilevare (niente fallimenti muti).
# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
if model_exists; then
  rm -f /opt/cybersec/ai_install_failed 2>/dev/null || true
  echo " AI locale PRONTA. Modello: cyberai (base $BASE)"
  echo " Avvio:  ai     oppure:  ollama run cyberai"
else
  echo "AI_INSTALL_FAILED: modello 'cyberai' NON creato (base $BASE)." > /opt/cybersec/ai_install_failed
  echo " !! ATTENZIONE: l'AI NON e' stata installata correttamente."
  echo " !! Riprova con:  sudo bash /vagrant/provision/02-ollama.sh"
  echo " !! (serve connessione internet per scaricare il modello)"
fi
echo "============================================================"
