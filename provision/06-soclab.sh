#!/usr/bin/env bash
# ============================================================================
#  06-soclab.sh  -  Installa il laboratorio SOC (stack Docker) e il comando
# ============================================================================
set -uo pipefail

echo "==> Installazione laboratorio SOC..."
mkdir -p /opt/cybersec/soc-lab

# Copia i compose e il manager dal progetto montato in /vagrant
cp -rf /vagrant/soc-lab/* /opt/cybersec/soc-lab/ 2>/dev/null || true
install -m 0755 /vagrant/soc-lab/soclab.sh /usr/local/bin/soclab

# MOTORE Docker (daemon): senza questo gli stack SOC non partono. Il box Kali
# di base ha solo la CLI, quindi installiamo esplicitamente l'engine.
export DEBIAN_FRONTEND=noninteractive
if ! systemctl list-unit-files 2>/dev/null | grep -q '^docker\.service' && ! command -v dockerd >/dev/null 2>&1; then
  echo "==> Installo il motore Docker (docker.io)..."
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y docker.io >/dev/null 2>&1 || true
fi
systemctl enable --now docker 2>/dev/null || true
# L'utente del desktop puo' usare docker senza sudo
usermod -aG docker vagrant 2>/dev/null || true
usermod -aG docker kali 2>/dev/null || true

# Assicura docker-compose v2 plugin
if ! docker compose version >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y docker-compose-plugin 2>/dev/null || \
    apt-get install -y docker-compose 2>/dev/null || true
fi

echo "==> Lab SOC installato. Comando disponibile: soclab"
echo "    Esempi: soclab targets up   |   soclab splunk up   |   soclab wazuh up"
