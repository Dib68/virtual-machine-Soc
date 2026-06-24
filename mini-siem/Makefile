# ============================================================
#  Mini-SIEM Lab — Makefile
#  Uso: make <target>
# ============================================================

.PHONY: help up down status attack-all attack-bruteforce attack-scan \
        attack-web attack-lateral check reset clean logs \
        threat-intel report soar-bot tuning-check sigma-convert \
        ioc-lookup setup

COMPOSE = docker compose
ES      = http://localhost:9200
KIBANA  = http://localhost:5601
TARGET ?= 192.168.56.10

# Colori
RED    = \033[0;31m
GREEN  = \033[0;32m
YELLOW = \033[1;33m
BLUE   = \033[0;34m
NC     = \033[0m

help: ## Mostra questo messaggio di aiuto
	@echo ""
	@echo "  $(YELLOW)Mini-SIEM Lab$(NC) — comandi disponibili:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "  Variabili: TARGET=$(TARGET)  (default: 192.168.56.10)"
	@echo ""

# ── Stack lifecycle ─────────────────────────────────────────

up: ## Avvia lo stack ELK + Suricata + target
	@echo "$(BLUE)Avvio Mini-SIEM stack...$(NC)"
	$(COMPOSE) up -d
	@echo "$(YELLOW)Attendo che i servizi siano pronti (~60s)...$(NC)"
	@sleep 20
	@$(MAKE) status

down: ## Ferma tutti i container
	$(COMPOSE) down
	@echo "$(GREEN)Stack fermato.$(NC)"

status: ## Stato dei container e URL dei servizi
	@echo ""
	@echo "  $(YELLOW)Container status:$(NC)"
	@$(COMPOSE) ps
	@echo ""
	@echo "  $(YELLOW)Servizi:$(NC)"
	@echo "  Kibana SIEM ......... $(GREEN)$(KIBANA)$(NC)"
	@echo "  Elasticsearch ....... $(GREEN)$(ES)$(NC)"
	@echo "  Target SSH .......... $(GREEN)ssh://$(TARGET):22$(NC)"
	@echo ""

logs: ## Mostra i log in tempo reale (Ctrl+C per uscire)
	$(COMPOSE) logs -f --tail=50

# ── Attack simulations ──────────────────────────────────────

attack-all: ## Lancia tutte le simulazioni in sequenza
	@echo "$(RED)Lanciando tutte le simulazioni MITRE ATT&CK...$(NC)"
	@$(MAKE) attack-scan
	@sleep 10
	@$(MAKE) attack-bruteforce
	@sleep 10
	@$(MAKE) attack-web
	@sleep 10
	@$(MAKE) attack-lateral
	@echo "$(GREEN)Tutte le simulazioni completate. Controlla Kibana: $(KIBANA)$(NC)"

attack-bruteforce: ## T1110.001 — SSH Brute Force
	@echo "$(RED)[►] T1110.001 SSH Brute Force → $(TARGET)$(NC)"
	@bash simulations/01-brute-force-ssh.sh $(TARGET)

attack-scan: ## T1046 — Network Service Scanning (Nmap)
	@echo "$(RED)[►] T1046 Port Scan → $(TARGET)$(NC)"
	@bash simulations/02-port-scan.sh $(TARGET)

attack-web: ## T1190 + T1595.002 — Web Application Attacks
	@echo "$(RED)[►] T1190 Web Attack → $(TARGET):8080$(NC)"
	@bash simulations/03-web-attack.sh $(TARGET) 8080

attack-lateral: ## T1021.004 — Lateral Movement via SSH
	@echo "$(RED)[►] T1021.004 Lateral Movement → $(TARGET)$(NC)"
	@bash simulations/04-lateral-movement.sh $(TARGET)

# ── Monitoring ──────────────────────────────────────────────

check: ## Mostra riepilogo alert delle ultime 24h
	@bash scripts/check-alerts.sh

suricata-alerts: ## Alert Suricata in tempo reale (fast.log)
	@echo "$(YELLOW)Suricata alerts (Ctrl+C per uscire):$(NC)"
	docker exec siem-suricata tail -f /var/log/suricata/fast.log 2>/dev/null || \
	docker logs -f siem-suricata 2>&1 | grep -i "alert\|drop\|warning"

es-health: ## Stato del cluster Elasticsearch
	@curl -s $(ES)/_cluster/health | python3 -m json.tool

es-indices: ## Elenco degli indici Elasticsearch
	@curl -s "$(ES)/_cat/indices/siem-*?h=index,docs.count,store.size&s=index" | \
		awk '{printf "  %-45s %8s docs  %s\n", $$1, $$2, $$3}'

enrich-iocs: ## Arricchisce gli IP trovati negli alert con AbuseIPDB
	@bash scripts/enrich-iocs.sh

# ── Maintenance ─────────────────────────────────────────────

reset: ## Reset completo: cancella tutti i dati e riparte
	@bash scripts/reset-lab.sh

clean: ## Rimuove container, volumi e immagini del lab
	$(COMPOSE) down -v --rmi local
	@echo "$(GREEN)Pulizia completata.$(NC)"

validate: ## Valida le regole Suricata e i file di configurazione
	@echo "$(YELLOW)Validazione configurazioni...$(NC)"
	@python3 -c "import yaml; [yaml.safe_load(open(f)) for f in \
		['config/filebeat/filebeat.yml','config/kibana/kibana.yml','config/logstash/logstash.yml']]" \
		&& echo "$(GREEN)YAML configs OK$(NC)" || echo "$(RED)YAML ERRORE$(NC)"
	@python3 -c "import tomllib; [tomllib.load(open(f,'rb')) for f in \
		__import__('glob').glob('rules/detection/*.toml')]" \
		&& echo "$(GREEN)TOML detection rules OK$(NC)" || echo "$(RED)TOML ERRORE$(NC)"
	@docker run --rm -v "$$(pwd)/config/suricata:/etc/suricata:ro" \
		jasonish/suricata:latest -T -c /etc/suricata/suricata.yaml 2>&1 \
		| grep -E "Configuration OK|error|Error" || true

load-dashboards: ## Carica i dashboard Kibana via API
	@bash scripts/load-dashboards.sh

# ── Threat Intelligence ─────────────────────────────────────

threat-intel: ## Scarica feed IOC (AbuseCH/ET/CINS) e genera regole Suricata
	@echo "$(YELLOW)Sincronizzazione threat intelligence feeds...$(NC)"
	@bash scripts/threat-intel-sync.sh
	@echo "$(GREEN)Feed sincronizzati. Regole salvate in config/suricata/rules/threat-intel.rules$(NC)"

threat-intel-dry: ## Preview delle regole generate (non salva, non ricarica)
	@bash scripts/threat-intel-sync.sh --dry-run

# ── Reporting ────────────────────────────────────────────────

report: ## Genera il report settimanale HTML+Markdown (ultimi 7 giorni)
	@echo "$(YELLOW)Generazione Weekly Threat Report...$(NC)"
	@python3 scripts/generate-report.py --format both
	@echo "$(GREEN)Report salvato in reports/$(NC)"

report-30d: ## Report mensile (ultimi 30 giorni)
	@python3 scripts/generate-report.py --days 30 --format both

# ── SOAR Automation ──────────────────────────────────────────

soar-bot: ## Avvia TheHive bot (polling ES → crea casi in TheHive)
	@echo "$(YELLOW)Avvio TheHive SOAR bot...$(NC)"
	@python3 scripts/thehive-bot.py --loop

soar-bot-dry: ## Preview delle operazioni SOAR senza creare casi reali
	@python3 scripts/thehive-bot.py --dry-run

# ── Rule Quality ─────────────────────────────────────────────

tuning-check: ## Mostra il volume degli alert per regola (ultime 24h)
	@echo "$(YELLOW)False positive analysis — alert volume per SID:$(NC)"
	@curl -s "$(ES)/siem-suricata-*/_search" \
		-H 'Content-Type: application/json' \
		-d '{"size":0,"query":{"bool":{"must":[{"term":{"suricata.event_type":"alert"}},{"range":{"@timestamp":{"gte":"now-24h"}}}]}},"aggs":{"by_sig":{"terms":{"field":"suricata.alert.signature_id","size":20}}}}' \
		| python3 -c "import json,sys; d=json.load(sys.stdin); \
		[print(f'  SID {b[\"key\"]:>10} | {b[\"doc_count\"]:>5} alerts/24h') \
		for b in d.get('aggregations',{}).get('by_sig',{}).get('buckets',[])]"
	@echo "$(YELLOW)Regole con > 50 alert/24h: candidati per tuning$(NC)"
	@echo "$(BLUE)Guida: docs/tuning/false-positives.md$(NC)"

# ── Setup ────────────────────────────────────────────────────

setup: ## One-command lab setup (prerequisites check + start + threat intel)
	@bash setup.sh

setup-fast: ## Fast setup without threat intel feed download
	@bash setup.sh --skip-threat-intel

# ── IOC Lookup ───────────────────────────────────────────────

ioc-lookup: ## Multi-source IOC lookup — usage: make ioc-lookup IOC=1.2.3.4
	@python3 scripts/ioc-lookup.py $(IOC)

ioc-bulk: ## Bulk IOC lookup from file — usage: make ioc-bulk FILE=ips.txt
	@cat $(FILE) | python3 scripts/ioc-lookup.py --bulk

sigma-convert: ## Converte le Sigma rules in ElasticSearch KQL (richiede pySigma)
	@echo "$(YELLOW)Conversione Sigma → Elasticsearch KQL:$(NC)"
	@for f in rules/sigma/*.yml; do \
		echo "$(BLUE)$$f$(NC)"; \
		sigma convert -t elasticsearch -p ecs_linux "$$f" 2>/dev/null || \
		echo "  (installa pySigma: pip install sigma-cli pySigma-backend-elasticsearch)"; \
	done
