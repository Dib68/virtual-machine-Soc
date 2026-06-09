#!/usr/bin/env bash
# ============================================================================
#  cybermenu  -  Menu interattivo dei tool di cybersecurity con tutorial
# ============================================================================
set -uo pipefail

TUT_DIR="/opt/cybersec/tutorials"
BACKTITLE="CyberSec AI VM  -  menu interattivo"

if ! command -v whiptail >/dev/null 2>&1; then
  echo "whiptail non trovato. Installa con: sudo apt-get install -y whiptail"
  exit 1
fi

declare -A CATS
CATS["Network Scanning"]="
nmap|Nmap (scanner di rete e porte)|sudo nmap|nmap
masscan|Masscan (scanner ultra-veloce)|sudo masscan|masscan
netdiscover|Netdiscover (host discovery ARP)|sudo netdiscover|netdiscover
"
CATS["Vulnerability Assessment"]="
nikto|Nikto (scanner web server)|nikto -h|nikto
gvm-start|OpenVAS / Greenbone (vuln scanner)|sudo gvm-start|openvas
wapiti|Wapiti (vuln scanner web)|wapiti -u|wapiti
"
CATS["Web App Testing"]="
burpsuite|Burp Suite (proxy/web pentest)|burpsuite|burpsuite
zaproxy|OWASP ZAP (proxy/web pentest)|zaproxy|zaproxy
sqlmap|SQLmap (SQL injection)|sqlmap -u|sqlmap
gobuster|Gobuster (brute force directory/DNS)|gobuster|gobuster
"
CATS["Traffico & MITM"]="
wireshark|Wireshark (analisi pacchetti GUI)|wireshark|wireshark
tcpdump|tcpdump (sniffer da terminale)|sudo tcpdump|tcpdump
bettercap|Bettercap (attacchi MITM)|sudo bettercap|bettercap
"
CATS["Exploitation"]="
msfconsole|Metasploit Framework|msfconsole|metasploit
searchsploit|SearchSploit (database exploit)|searchsploit|searchsploit
"
CATS["Password Cracking"]="
john|John the Ripper|john|john
hashcat|Hashcat (cracking GPU/CPU)|hashcat|hashcat
hydra|Hydra (brute force login)|hydra|hydra
"
CATS["Wireless"]="
aircrack-ng|Aircrack-ng (Wi-Fi)|sudo aircrack-ng|aircrack-ng
wifite|Wifite (Wi-Fi automatico)|sudo wifite|wifite
"
CATS["OSINT & Recon"]="
theharvester|theHarvester (email/domini)|theHarvester|theharvester
recon-ng|Recon-ng (framework OSINT)|recon-ng|recon-ng
spiderfoot|SpiderFoot (OSINT automatico)|spiderfoot -l 127.0.0.1:5001|spiderfoot
"
CATS["Forensics"]="
autopsy|Autopsy (forensics GUI)|autopsy|autopsy
binwalk|Binwalk (analisi firmware/file)|binwalk|binwalk
exiftool|ExifTool (metadati)|exiftool|exiftool
volatility3|Volatility3 (analisi memoria)|vol|volatility
"
CATS["Reverse Engineering"]="
radare2|Radare2 (RE da terminale)|r2|radare2
ghidra|Ghidra (RE GUI - NSA)|ghidra|ghidra
gdb|GDB (debugger)|gdb|gdb
"
CATS["Active Directory / Pentest"]="
netexec|NetExec (ex CrackMapExec)|netexec|netexec
responder|Responder (LLMNR/NBT-NS)|sudo responder -I eth0|responder
evil-winrm|Evil-WinRM (shell remota WinRM)|evil-winrm|evil-winrm
enum4linux-ng|enum4linux-ng (enum SMB)|enum4linux-ng|enum4linux-ng
smbmap|SMBMap (enum condivisioni SMB)|smbmap -H|smbmap
bloodhound|BloodHound (percorsi attacco AD)|bloodhound|bloodhound
kerbrute|Kerbrute (brute Kerberos)|kerbrute|kerbrute
"
CATS["CTF / Exploit Dev"]="
pwntools|pwntools (exploit dev Python)|python3 -c 'import pwn;print(pwn.__version__)'|pwntools
ROPgadget|ROPgadget (ricerca gadget ROP)|ROPgadget|ropgadget
gdb|GDB + GEF (debugger)|gdb|gdb
radare2|Radare2|r2|radare2
"
CATS["Blue Team / SOC"]="
suricata|Suricata (IDS/IPS)|sudo suricata|suricata
snort|Snort (IDS)|sudo snort|snort
zeek|Zeek (network monitoring)|zeek|zeek
yara|YARA (regole anti-malware)|yara|yara
osqueryi|OSQuery (SQL endpoint)|osqueryi|osquery
velociraptor|Velociraptor (DFIR endpoint)|velociraptor|velociraptor
clamscan|ClamAV (antivirus)|clamscan|clamav
lynis|Lynis (audit hardening)|sudo lynis audit system|lynis
"
CATS["Threat Hunting (web moderno)"]="
nuclei|Nuclei (scanner template-based)|nuclei|nuclei
httpx|httpx (probe HTTP)|httpx|httpx
subfinder|Subfinder (sottodomini)|subfinder|subfinder
naabu|Naabu (port scanner veloce)|naabu|naabu
feroxbuster|Feroxbuster (content discovery)|feroxbuster|feroxbuster
"
CATS["Cloud & DevSecOps"]="
aws|AWS CLI|aws|awscli
az|Azure CLI|az|azurecli
gcloud|Google Cloud CLI|gcloud|gcloud
kubectl|kubectl (Kubernetes)|kubectl|kubectl
terraform|Terraform (IaC)|terraform|terraform
trivy|Trivy (scanner container/IaC)|trivy|trivy
scout|ScoutSuite (audit cloud)|scout|scoutsuite
prowler|Prowler (audit cloud)|prowler|prowler
"

CAT_ORDER=(
  "Network Scanning"
  "Vulnerability Assessment"
  "Web App Testing"
  "Traffico & MITM"
  "Exploitation"
  "Password Cracking"
  "Wireless"
  "OSINT & Recon"
  "Forensics"
  "Reverse Engineering"
  "Active Directory / Pentest"
  "CTF / Exploit Dev"
  "Blue Team / SOC"
  "Threat Hunting (web moderno)"
  "Cloud & DevSecOps"
)

is_installed() { command -v "$1" >/dev/null 2>&1; }

show_tutorial() {
  local tut="$TUT_DIR/$1.md"
  if [ -f "$tut" ]; then
    if command -v less >/dev/null 2>&1; then less -R "$tut"
    else whiptail --backtitle "$BACKTITLE" --scrolltext --title "Tutorial: $1" --textbox "$tut" 25 90; fi
  else
    whiptail --backtitle "$BACKTITLE" --title "Tutorial" --msgbox "Tutorial non disponibile per: $1" 8 60
  fi
}

launch_tool() {
  local name="$1" cmd="$2"
  clear
  echo "============================================================"
  echo " Avvio: $name"; echo " Comando: $cmd"
  echo "============================================================"; echo ""
  # rileva il binario (ignorando un eventuale 'sudo')
  local b; b=$(echo "$cmd" | awk '{ if ($1=="sudo") print $2; else print $1 }')
  b="${b##*/}"
  local GUI="burpsuite|zaproxy|wireshark|autopsy|ghidra|bloodhound|firefox|firefox-esr"
  if echo "$b" | grep -qE "^($GUI)$"; then
    setsid bash -lc "$cmd" >/dev/null 2>&1 &
    echo " Applicazione grafica avviata in una nuova finestra."
  else
    eval "$cmd"
  fi
  echo ""; read -rp "Premi Invio per tornare al menu..."
}

tool_menu() {
  local bin="$1" name="$2" cmd="$3" tut="$4"
  while true; do
    local status="[installato]"; is_installed "$bin" || status="[NON installato]"
    CH=$(whiptail --backtitle "$BACKTITLE" --title "$name $status" \
      --menu "Cosa vuoi fare?" 15 70 4 \
      "1" "Leggi il tutorial" \
      "2" "Avvia lo strumento" \
      "3" "Chiedi all AI come usarlo" \
      "B" "Indietro" 3>&1 1>&2 2>&3) || return
    case "$CH" in
      1) show_tutorial "$tut" ;;
      2) if is_installed "$bin"; then launch_tool "$name" "$cmd"
         else whiptail --title "Non installato" --msgbox "$name non risulta installato." 8 60; fi ;;
      3) clear; ai "Spiegami come usare $name in cybersecurity, con esempi di comando."
         read -rp "Premi Invio per continuare..." ;;
      B|"") return ;;
    esac
  done
}

category_menu() {
  local cat="$1"
  while true; do
    local args=() i=0
    local lines; lines=$(echo "${CATS[$cat]}" | sed '/^[[:space:]]*$/d')
    declare -A MAP_BIN MAP_NAME MAP_CMD MAP_TUT
    while IFS='|' read -r bin name cmd tut; do
      [ -z "$bin" ] && continue
      i=$((i+1)); local tag="$i"
      local mark="o"; is_installed "$bin" && mark="*"
      args+=("$tag" "[$mark] $name")
      MAP_BIN[$tag]="$bin"; MAP_NAME[$tag]="$name"; MAP_CMD[$tag]="$cmd"; MAP_TUT[$tag]="$tut"
    done <<< "$lines"
    args+=("B" "<< Indietro")
    SEL=$(whiptail --backtitle "$BACKTITLE" --title "$cat" \
      --menu "* = installato   o = non installato" 22 76 13 \
      "${args[@]}" 3>&1 1>&2 2>&3) || return
    [ "$SEL" = "B" ] && return
    tool_menu "${MAP_BIN[$SEL]}" "${MAP_NAME[$SEL]}" "${MAP_CMD[$SEL]}" "${MAP_TUT[$SEL]}"
  done
}

soclab_menu() {
  while true; do
    SEL=$(whiptail --backtitle "$BACKTITLE" --title "Laboratorio SOC (Docker)" \
      --menu "Avvia/ferma SIEM, threat intel e bersagli:" 24 78 15 \
      "1"  "Bersagli vulnerabili  ON  (DVWA/JuiceShop/WebGoat)" \
      "2"  "Bersagli vulnerabili  OFF" \
      "3"  "Splunk (SIEM)         ON" \
      "4"  "Splunk (SIEM)         OFF" \
      "5"  "ELK / Kibana          ON" \
      "6"  "ELK / Kibana          OFF" \
      "7"  "Wazuh (SIEM+EDR)      ON  (8+ GB RAM)" \
      "8"  "Wazuh (SIEM+EDR)      OFF" \
      "9"  "MISP (threat intel)   ON" \
      "10" "MISP (threat intel)   OFF" \
      "11" "TheHive+Cortex (IR)   ON" \
      "12" "TheHive+Cortex (IR)   OFF" \
      "13" "OpenWebUI (AI web)    ON" \
      "14" "OpenWebUI (AI web)    OFF" \
      "S"  "Stato container + indirizzi web" \
      "X"  "Ferma TUTTI gli stack" \
      "B"  "Indietro" 3>&1 1>&2 2>&3) || return
    case "$SEL" in
      1) clear; soclab targets up;   read -rp "Invio..." ;;
      2) clear; soclab targets down; read -rp "Invio..." ;;
      3) clear; soclab splunk up;    read -rp "Invio..." ;;
      4) clear; soclab splunk down;  read -rp "Invio..." ;;
      5) clear; soclab elk up;       read -rp "Invio..." ;;
      6) clear; soclab elk down;     read -rp "Invio..." ;;
      7) clear; soclab wazuh up;     read -rp "Invio..." ;;
      8) clear; soclab wazuh down;   read -rp "Invio..." ;;
      9) clear; soclab misp up;      read -rp "Invio..." ;;
      10) clear; soclab misp down;   read -rp "Invio..." ;;
      11) clear; soclab thehive up;  read -rp "Invio..." ;;
      12) clear; soclab thehive down;read -rp "Invio..." ;;
      13) clear; soclab webui up;    read -rp "Invio..." ;;
      14) clear; soclab webui down;  read -rp "Invio..." ;;
      S) clear; soclab status; soclab urls; read -rp "Invio..." ;;
      X) clear; soclab stopall;      read -rp "Invio..." ;;
      B|"") return ;;
    esac
  done
}

utility_menu() {
  while true; do
    SEL=$(whiptail --backtitle "$BACKTITLE" --title "Utility della VM" \
      --menu "Strumenti di supporto:" 18 72 8 \
      "1" "CyberDoctor (diagnostica VM)" \
      "2" "Genera report Pentest" \
      "3" "Genera report Incident Response" \
      "4" "Aggiorna tutto (sistema, DB, AI)" \
      "5" "AI: spiega un file" \
      "B" "Indietro" 3>&1 1>&2 2>&3) || return
    case "$SEL" in
      1) clear; cyberdoctor; read -rp "Invio..." ;;
      2) clear; cyberreport pentest; read -rp "Invio..." ;;
      3) clear; cyberreport ir; read -rp "Invio..." ;;
      4) clear; cyberupdate; read -rp "Invio..." ;;
      5) F=$(whiptail --inputbox "Percorso del file da spiegare:" 8 60 3>&1 1>&2 2>&3) && \
         { clear; ai-explain "$F"; read -rp "Invio..."; } ;;
      B|"") return ;;
    esac
  done
}

main_menu() {
  while true; do
    local args=() i=0
    for c in "${CAT_ORDER[@]}"; do i=$((i+1)); args+=("$i" "$c"); done
    args+=("A" "Assistente AI (CyberAI)")
    args+=("L" "Laboratorio SOC (Docker: SIEM + bersagli)")
    args+=("T" "Utility (diagnostica, report, update)")
    args+=("J" "Tool richiesti dagli annunci di lavoro")
    args+=("G" "Guida introduttiva alla VM")
    args+=("Q" "Esci")
    SEL=$(whiptail --backtitle "$BACKTITLE" --title "MENU PRINCIPALE - CyberSec AI VM" \
      --menu "Scegli una categoria di strumenti:" 26 76 19 \
      "${args[@]}" 3>&1 1>&2 2>&3) || exit 0
    case "$SEL" in
      Q|"") clear; exit 0 ;;
      A) clear; ai ;;
      L) soclab_menu ;;
      T) utility_menu ;;
      J) show_tutorial "00-tool-richiesti-lavoro" ;;
      G) show_tutorial "00-introduzione" ;;
      *) idx=$((SEL-1)); category_menu "${CAT_ORDER[$idx]}" ;;
    esac
  done
}

main_menu
