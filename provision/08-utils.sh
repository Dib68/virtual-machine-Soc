#!/usr/bin/env bash
# ============================================================================
#  08-utils.sh  -  Installa le utility della VM come comandi globali
# ============================================================================
set -uo pipefail
echo "==> Installazione utility (cyberdoctor, ai-explain, cyberreport, cyberupdate, cyberhelp)..."
install -m 0755 /vagrant/tools/cyberdoctor.sh /usr/local/bin/cyberdoctor
install -m 0755 /vagrant/tools/ai-explain.sh  /usr/local/bin/ai-explain
install -m 0755 /vagrant/tools/cyberreport.sh /usr/local/bin/cyberreport
install -m 0755 /vagrant/tools/cyberupdate.sh /usr/local/bin/cyberupdate
install -m 0755 /vagrant/tools/cyberhelp.sh   /usr/local/bin/cyberhelp
echo "==> Utility installate: cyberdoctor | ai-explain | cyberreport | cyberupdate | cyberhelp"
