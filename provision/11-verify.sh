#!/usr/bin/env bash
# ============================================================================
#  11-verify.sh  -  Verifica finale del provisioning. Eseguito per ULTIMO.
#  Segnala in modo chiaro cosa manca (niente fallimenti silenziosi) e lascia
#  un marcatore /opt/cybersec/provision_incomplete che GUI/cyberdoctor leggono.
# ============================================================================
set -uo pipefail
mkdir -p /opt/cybersec
MISS=0
echo "============================================================"
echo " VERIFICA FINALE - CyberSec AI VM"
echo "============================================================"
chk(){ if command -v "$1" >/dev/null 2>&1; then echo "  [OK] $1"; else echo "  [--] $1 MANCANTE"; MISS=$((MISS+1)); fi; }
echo "-- Strumenti chiave --"
for t in nmap msfconsole sqlmap hydra wireshark nuclei suricata yara trivy aws kubectl bloodhound; do chk "$t"; done
echo "-- AI locale --"
if command -v ollama >/dev/null 2>&1 && ollama list 2>/dev/null | grep -q '^cyberai'; then
  echo "  [OK] AI (modello cyberai)"
else
  echo "  [--] AI (cyberai) MANCANTE"; MISS=$((MISS+1))
fi
echo "-- Docker / SOC lab --"
if command -v docker >/dev/null 2>&1; then echo "  [OK] docker"; else echo "  [--] docker MANCANTE"; MISS=$((MISS+1)); fi
echo "------------------------------------------------------------"
if [ "$MISS" -eq 0 ]; then
  echo " TUTTO INSTALLATO CORRETTAMENTE."
  rm -f /opt/cybersec/provision_incomplete 2>/dev/null || true
else
  echo " ATTENZIONE: $MISS componenti risultano MANCANTI."
  echo " Per completare:"
  echo "   - GUI: pulsanti 'Installa i mancanti' e 'Installa/Ripara AI'"
  echo "   - oppure: sudo bash /vagrant/provision/02-ollama.sh   (per l'AI)"
  echo "   - oppure: COMPLETA-INSTALLAZIONE (icona sul Desktop)   (per tutto)"
  echo "$MISS componenti mancanti (vedi cyberdoctor)" > /opt/cybersec/provision_incomplete
fi
echo "============================================================"
# Non fallisce il provisioning: la diagnosi e' informativa.
exit 0
