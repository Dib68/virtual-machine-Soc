#!/usr/bin/env bash
# ============================================================================
#  01-tools.sh  -  Installa tutti gli strumenti di cybersecurity
#  Eseguito automaticamente da Vagrant (come root).
#  Pensato per gli strumenti piu' richiesti negli annunci di lavoro:
#  network scanning, vulnerability assessment, web app testing, forensics,
#  reverse engineering, OSINT, password cracking, ecc.
# ============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Aggiornamento del sistema..."
apt-get update -y
apt-get upgrade -y

# ----------------------------------------------------------------------------
# Funzione di supporto: installa un pacchetto e continua anche se fallisce,
# registrando i fallimenti (cosi' la VM si costruisce sempre).
# ----------------------------------------------------------------------------
FAILED=()
inst() {
  for pkg in "$@"; do
    echo "    -> installo: $pkg"
    if ! apt-get install -y "$pkg"; then
      echo "    !! attenzione: $pkg non installato"
      FAILED+=("$pkg")
    fi
  done
}

echo "==> [2/4] Strumenti core (presenti nella maggior parte degli annunci)..."

# --- Network scanning & discovery ---
inst nmap masscan netdiscover arp-scan dnsutils whois netcat-traditional \
     tcpdump traceroute

# --- Vulnerability assessment / scanning ---
# OpenVAS/Greenbone e' lo scanner di vulnerabilita' open source di riferimento.
inst nikto wapiti
inst openvas || inst gvm    # Greenbone Vulnerability Management (ex OpenVAS)

# --- Analisi del traffico ---
inst wireshark tshark termshark ettercap-graphical bettercap

# --- Web application testing ---
inst burpsuite zaproxy sqlmap wfuzz ffuf gobuster dirb dirbuster commix \
     whatweb wpscan

# --- Exploitation framework ---
inst metasploit-framework exploitdb

# --- Password cracking / brute force ---
inst john hashcat hydra medusa crunch hashid wordlists

# --- Wireless ---
inst aircrack-ng reaver wifite kismet

# --- OSINT / recon ---
inst theharvester recon-ng maltego dmitry sublist3r amass spiderfoot

# --- Forensics ---
inst autopsy sleuthkit binwalk foremost testdisk volatility3 ddrescue \
     exiftool steghide

# --- Reverse engineering ---
inst radare2 gdb ghidra apktool jadx

# --- Container / cloud / DevSecOps (sempre piu' richiesti) ---
inst docker.io docker-compose
inst trivy || true

echo "==> [3/4] Utility di supporto e sviluppo..."
inst git curl wget vim nano tmux htop tree jq unzip p7zip-full \
     python3 python3-pip python3-venv build-essential \
     dialog whiptail figlet lolcat firefox-esr seclists

# Python: alcune utility utili (best effort)
pip3 install --break-system-packages --quiet \
     requests rich shodan censys 2>/dev/null || true

echo "==> [4/4] Configurazioni finali..."
# Abilita docker per l'utente vagrant
usermod -aG docker vagrant 2>/dev/null || true
# Permette a wireshark di catturare senza root
groupadd -f wireshark
usermod -aG wireshark vagrant 2>/dev/null || true

# Aggiorna il database degli exploit (best effort)
searchsploit -u 2>/dev/null || true

# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Installazione strumenti completata."
if [ ${#FAILED[@]} -gt 0 ]; then
  echo " Pacchetti NON installati (verranno saltati nel menu):"
  printf '   - %s\n' "${FAILED[@]}"
  # Salva la lista per il menu, cosi' nasconde i tool mancanti
  printf '%s\n' "${FAILED[@]}" > /opt/cybersec/missing_tools.txt 2>/dev/null || \
    { mkdir -p /opt/cybersec && printf '%s\n' "${FAILED[@]}" > /opt/cybersec/missing_tools.txt; }
else
  echo " Tutti i pacchetti installati correttamente."
fi
echo "============================================================"
