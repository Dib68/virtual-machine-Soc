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
if [ "$RAM_GB" -ge 7 ]; then BASE="qwen2.5:7b"; else BASE="llama3.2"; fi
echo "==> RAM ${RAM_GB}GB -> modello base scelto: $BASE"

echo "==> Scarico il modello (puo' richiedere parecchio: alcuni GB)..."
if ! ollama pull "$BASE"; then
  echo "   !! '$BASE' non scaricato, passo a llama3.2"; BASE="llama3.2"; ollama pull "$BASE" || true
fi
# Modello leggero sempre presente come riserva
ollama pull llama3.2 2>/dev/null || true

# ----------------------------------------------------------------------------
# Modello specializzato "cyberai": tutor esperto di cybersecurity.
# ----------------------------------------------------------------------------
mkdir -p /opt/cybersec
cat > /opt/cybersec/Modelfile <<EOF
FROM $BASE

PARAMETER temperature 0.35
PARAMETER top_p 0.9
PARAMETER num_ctx 4096

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
- Ricorda all'utente, quando pertinente, di operare SOLO su sistemi propri o
  autorizzati: usare questi strumenti senza permesso e' illegale.
"""
EOF

echo "==> Creo il modello 'cyberai' (base: $BASE)..."
ollama create cyberai -f /opt/cybersec/Modelfile 2>/dev/null \
  || echo "   !! creazione 'cyberai' rimandata (poi: ollama create cyberai -f /opt/cybersec/Modelfile)"

echo ""
echo "============================================================"
echo " AI locale pronta. Modello: cyberai (base $BASE)"
echo " Avvio:  ai     oppure:  ollama run cyberai"
echo "============================================================"
