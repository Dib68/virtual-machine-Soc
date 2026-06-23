#!/usr/bin/env bash
# Reset completo del lab: ferma tutto, cancella i dati, ricomincia
set -euo pipefail

RED='\033[0;31m'; YLW='\033[1;33m'; GRN='\033[0;32m'; NC='\033[0m'

echo -e "${YLW}Reset Mini-SIEM Lab${NC}"
echo -e "${RED}Attenzione: tutti i dati Elasticsearch verranno cancellati.${NC}"
read -rp "Continuare? (yes/no): " confirm
[ "$confirm" = "yes" ] || { echo "Annullato."; exit 0; }

echo -e "\n${GRN}[1/3] Fermo i container...${NC}"
docker compose down -v

echo -e "${GRN}[2/3] Riavvio lo stack...${NC}"
docker compose up -d

echo -e "${GRN}[3/3] Attendo che i servizi siano pronti...${NC}"
sleep 30
docker compose ps

echo -e "\n${GRN}Lab resettato. Kibana: http://localhost:5601${NC}"
