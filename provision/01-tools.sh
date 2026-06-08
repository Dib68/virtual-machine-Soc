#!/usr/bin/env bash
# ============================================================================
#  01-tools.sh  -  Installa TUTTI gli strumenti di cybersecurity.
#  Strategia: prima il metapacchetto ufficiale di Kali (centinaia di tool in
#  un colpo), poi gli strumenti extra non inclusi. Robusto e idempotente.
# ============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

apt_retry() {  # apt-get install con piccoli tentativi
  local i
  for i in 1 2 3; do
    apt-get install -y "$@" && return 0
    echo "   (tentativo $i fallito, riprovo...)"; sleep 5; apt-get update -y || true
  done
  return 1
}

FAILED=()
inst() { for p in "$@"; do echo "    -> $p"; apt_retry "$p" || { echo "    !! $p"; FAILED+=("$p"); }; done; }

echo "==> Aggiornamento del sistema..."
apt-get update -y
apt-get upgrade -y || true

# ----------------------------------------------------------------------------
# 1) METAPACCHETTO KALI: installa in blocco gli strumenti piu' usati
#    (nmap, metasploit, burpsuite, wireshark, sqlmap, hydra, john, aircrack,
#     nikto, ecc.). E' il modo piu' affidabile per avere "tutti i tool".
# ----------------------------------------------------------------------------
echo "==> [1/3] Installazione metapacchetto Kali (puo' richiedere molto tempo)..."
if apt_retry kali-linux-default; then
  echo "    [OK] kali-linux-default installato (centinaia di strumenti)."
else
  echo "    !! metapacchetto non installato del tutto: procedo con i singoli tool."
fi

# ----------------------------------------------------------------------------
# 2) Strumenti specifici/extra (idempotente: se gia' presenti, salta)
# ----------------------------------------------------------------------------
echo "==> [2/3] Strumenti aggiuntivi e di supporto..."
inst nmap masscan netdiscover dnsutils whois netcat-traditional tcpdump
inst nikto wapiti
inst wireshark tshark
inst burpsuite zaproxy sqlmap wfuzz ffuf gobuster dirb whatweb wpscan
inst metasploit-framework exploitdb
inst john hashcat hydra medusa crunch wordlists
inst aircrack-ng
inst theharvester recon-ng dmitry
inst sleuthkit binwalk foremost exiftool steghide
inst radare2 gdb
inst git curl wget vim nano tmux htop tree jq unzip p7zip-full \
     python3 python3-pip python3-venv build-essential \
     dialog whiptail figlet firefox-esr seclists qterminal

# Threat hunting moderno (ProjectDiscovery)
inst nuclei httpx-toolkit subfinder naabu feroxbuster || true

pip3 install --break-system-packages --quiet requests rich 2>/dev/null || true

echo "==> [3/3] Configurazioni finali..."
groupadd -f wireshark; usermod -aG wireshark vagrant 2>/dev/null || true
searchsploit -u 2>/dev/null || true

mkdir -p /opt/cybersec
[ ${#FAILED[@]} -gt 0 ] && printf '%s\n' "${FAILED[@]}" > /opt/cybersec/missing_tools.txt || : > /opt/cybersec/missing_tools.txt

echo ""
echo "============================================================"
echo " Installazione strumenti completata."
echo " Strumenti rilevati: $(for t in nmap msfconsole burpsuite wireshark sqlmap hydra john nuclei; do command -v $t >/dev/null 2>&1 && echo -n "$t "; done)"
echo "============================================================"
