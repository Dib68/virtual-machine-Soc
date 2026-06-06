#!/usr/bin/env bash
# ============================================================================
#  04-blueteam.sh  -  Strumenti Blue Team / SOC Analyst / DFIR
#  Installa cio' che gli HR chiedono piu' spesso per ruoli SOC:
#  IDS/NSM, threat intel, DFIR, scripting, analisi log.
#  I SIEM "pesanti" (Wazuh, ELK, MISP, TheHive) sono gestiti via Docker
#  dal comando 'soclab' (vedi soc-lab/), per non appesantire la VM.
# ============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

FAILED=()
inst() {
  for pkg in "$@"; do
    echo "    -> installo: $pkg"
    apt-get install -y "$pkg" || { echo "    !! $pkg non installato"; FAILED+=("$pkg"); }
  done
}

apt-get update -y

echo "==> Blue Team: IDS / Network Security Monitoring..."
inst suricata snort zeek

echo "==> Blue Team: DFIR / analisi malware..."
inst yara clamav clamav-daemon chkrootkit rkhunter lynis
inst sleuthkit autopsy   # gia' presenti, idempotente
inst inetsim             # simulatore di servizi per analisi malware

echo "==> Blue Team: analisi log / endpoint..."
# OSQuery (interrogazioni SQL sullo stato dell'endpoint - molto richiesto)
if ! command -v osqueryi >/dev/null 2>&1; then
  curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/osquery.gpg 2>/dev/null || true
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/osquery.gpg] https://pkg.osquery.io/deb deb main" \
    > /etc/apt/sources.list.d/osquery.list
  apt-get update -y || true
  inst osquery
fi

# Velociraptor (DFIR endpoint - binario singolo da GitHub)
if ! command -v velociraptor >/dev/null 2>&1; then
  echo "    -> scarico Velociraptor..."
  VR_URL=$(curl -fsSL https://api.github.com/repos/Velocidex/velociraptor/releases/latest \
    | grep -o 'https://[^"]*linux-amd64' | head -n1 || true)
  if [ -n "${VR_URL:-}" ]; then
    curl -fsSL "$VR_URL" -o /usr/local/bin/velociraptor && chmod +x /usr/local/bin/velociraptor \
      || echo "    !! Velociraptor non scaricato"
  fi
fi

echo "==> Threat hunting / web vuln moderni (ProjectDiscovery)..."
# nuclei, httpx, subfinder, naabu: usatissimi negli annunci recenti
inst nuclei httpx-toolkit subfinder naabu feroxbuster || true

echo "==> Scripting richiesto negli annunci (Python / PowerShell)..."
inst python3-pip python3-venv
# PowerShell su Linux (molti SOC usano PowerShell per IR su Windows)
if ! command -v pwsh >/dev/null 2>&1; then
  inst powershell || {
    echo "    -> provo installazione PowerShell da pacchetto Microsoft..."
    curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
      -o /tmp/ms.deb 2>/dev/null && dpkg -i /tmp/ms.deb 2>/dev/null && apt-get update -y \
      && inst powershell || echo "    !! PowerShell non installato"
  }
fi

# Librerie Python utili a un SOC analyst
pip3 install --break-system-packages --quiet \
  scapy yara-python pefile oletools requests rich pandas 2>/dev/null || true

echo "==> Aggiorno le firme antivirus (ClamAV)..."
systemctl stop clamav-freshclam 2>/dev/null || true
freshclam 2>/dev/null || true
systemctl start clamav-freshclam 2>/dev/null || true

# Registra i pacchetti mancanti per il menu
mkdir -p /opt/cybersec
if [ ${#FAILED[@]} -gt 0 ]; then
  printf '%s\n' "${FAILED[@]}" >> /opt/cybersec/missing_tools.txt
fi

echo "==> Blue Team / SOC: installazione completata."
