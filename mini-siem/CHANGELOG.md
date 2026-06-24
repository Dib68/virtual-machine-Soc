# Changelog — Mini-SIEM Lab

All notable changes to this project are documented here.  
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [v6] — 2026-06-25

### Added
- `simulations/Dockerfile` — Kali Linux attacker container with nmap, hydra, nikto, curl, sshpass; simulation scripts auto-build and exec into it when tools are missing locally
- `scripts/integration-test.sh` — End-to-end detection pipeline test: sends T1190 web payloads + T1110 SSH attempts → waits 45s → queries ES for alerts, MITRE enrichment, GeoIP fields; exits 0 only if all checks pass; `--quick` mode skips SSH
- `LICENSE` — MIT license

### Fixed
- **Critical:** all 4 simulation scripts defaulted to `192.168.56.10` (Vagrant IP) — target container is at `172.20.0.10` in the Docker lab; `make attack-all` was attacking a non-existent host
- **Critical:** `02-port-scan.sh` had no tool check — called nmap directly, crashing with pipefail if not installed
- **Critical:** `03-web-attack.sh` called nikto as mandatory — with `set -euo pipefail` a missing nikto aborted the entire script; now nikto is optional with curl fallback
- **Critical:** `04-lateral-movement.sh` hardcoded `192.168.56.0/24` subnet for nmap discovery — wrong network for Docker lab; now uses `SUBNET` env var (default `172.20.0.0/24`)
- `enrich-iocs.sh` — `LIMIT="${2:-10}"` bug: should be `$1`; also respects `ES_URL` env var
- SSH port in simulations updated from `22` to `2222` (actual Docker target port)

### Improved
- All simulation scripts now auto-detect missing tools (nmap/hydra/nikto) and fall back to Docker attacker container (`siem-attacker`) transparently; first run builds the image automatically
- `make attack-all` now works on any machine with Docker, even without attack tools installed
- Makefile: new targets `build-attacker`, `integration-test`, `integration-test-quick`, `demo`; `TARGET` default fixed from `192.168.56.10` → `172.20.0.10`
- All 11 shell scripts verified with `bash -n` syntax check (0 errors)

---

## [v5] — 2026-06-25

### Added
- `setup.sh` — one-command lab setup: prerequisite checks (Docker, RAM ≥ 4GB, disk ≥ 10GB, vm.max_map_count), auto `.env` creation, Python deps, stack health polling, colored summary
- `scripts/ioc-lookup.py` — multi-source IOC enrichment: AbuseIPDB (confidence score, Tor detection), ip-api.com (GeoIP/ASN, no key), VirusTotal (engine detections), Shodan (ports, CVEs); risk score 0–100; rich terminal output; bulk stdin mode
- `docs/interview-prep.md` — 20 SOC analyst interview Q&A with answers referencing specific code in this lab
- `docs/hardening/post-incident-hardening.md` — Phase 4 NIST IR: SSH hardening, fail2ban, iptables, credential rotation, persistence checks, auditd
- `screenshots/07-architecture-diagram.svg` — full network topology: attack paths, detection layers, data pipeline, response components, CI/CD

### Fixed
- `.gitignore` created — `.env` and generated files now excluded from git
- `config/suricata/rules/threat-intel.rules` placeholder created — Suricata no longer starts with a missing rule file
- `config/suricata/suricata.yaml` — added `threat-intel.rules` to `rule-files` so live feed rules load on startup
- `config/target/setup.sh` created — resolves docker-compose volume mount error
- `config/kibana/dashboards/` directory created with real NDJSON — `load-dashboards.sh` now imports index patterns (siem-*, siem-suricata-*, siem-auth-*) and saved searches
- `reports/.gitkeep` — directory now tracked in git so `generate-report.py` can write to it

### Improved
- GitHub Actions CI: added `validate-python` job (py_compile syntax check + ruff lint + Sigma YAML validation); ShellCheck now mandatory (removed `|| true`)
- Makefile: +4 targets (`setup`, `setup-fast`, `ioc-lookup`, `ioc-bulk`)

---

## [v4] — 2026-06-25

### Added
- `scripts/threat-intel-sync.sh` — downloads IOC feeds from AbuseCH Feodo Tracker, SSL Blacklist, Emerging Threats, CINS Army; generates Suricata rules SIDs 8000001+; reloads Suricata via `suricatasc`; supports `--dry-run`
- `scripts/generate-report.py` — queries Elasticsearch, produces HTML + Markdown weekly threat report with KPIs, 7-day trend, top threats, MITRE techniques, risk level, auto action items
- `screenshots/06-weekly-report.svg` — executive report mockup: KPI cards, trend chart, top threats table, MITRE activity, risk badge, IR actions, infrastructure status
- `docs/tuning/false-positives.md` — FP reduction guide: per-SID analysis, suppress directives, threshold calibration, Sigma filter patterns, weekly tuning workflow
- `.env.example` — all configurable variables with defaults
- `requirements.txt` — Python dependencies (requests, python-dateutil, PyYAML, rich)

### Improved
- Makefile: +8 targets (`threat-intel`, `threat-intel-dry`, `report`, `report-30d`, `soar-bot`, `soar-bot-dry`, `tuning-check`, `sigma-convert`)
- README: new sections (TI feeds, report generator, rule tuning, 6th screenshot, updated skills table)

---

## [v3] — 2026-06-24

### Added
- `rules/sigma/*.yml` — 4 Sigma rules in universal format (T1110, T1046, T1190, T1021); pySigma conversion guide for Splunk SPL, Sentinel KQL, QRadar AQL
- `docs/hunting/eql-queries.md` — 7 EQL threat hunting queries with hypothesis-driven methodology
- `screenshots/05-threat-hunting.svg` — EQL hunting dashboard showing 2 successful logins missed by alert-only detection
- `scripts/thehive-bot.py` — Python SOAR bot: polls ES → groups by source.ip → deduplicates → creates TheHive v5 cases with IP observables; supports `--dry-run`, `--loop`
- `docs/WALKTHROUGH.md` — 23-minute complete attack scenario (5 phases): attacker perspective → detection → containment → eradication → post-incident (MTTD: 9:10, MTTR: 1:38)
- `config/metricbeat/metricbeat.yml` — system (CPU/RAM/disk/process) + Docker + Elasticsearch cluster metrics

---

## [v2] — 2026-06-23

### Added
- `rules/detection/*.toml` — 4 Elastic Security detection rules in elastic/detection-rules TOML format (T1110, T1046, T1190, T1021)
- `docs/playbooks/` — 3 IR playbooks (T1110 SSH BruteForce, T1046 Network Scan, T1190 Web Exploit) following NIST IR framework
- `screenshots/04-timeline-investigation.svg` — 3-lane event timeline with MTTD/MTTR measurement
- `.github/workflows/validate-siem.yml` — CI with 5 jobs: validate-yaml, validate-detection-rules, validate-suricata-rules, validate-scripts, smoke-test-elk
- `scripts/enrich-iocs.sh` — AbuseIPDB + ip-api.com IOC enrichment for alert source IPs
- `scripts/reset-lab.sh` — full lab reset (delete all ES data, restart containers)

---

## [v1] — 2026-06-22

### Added
- `docker-compose.yml` — 7-container stack: Elasticsearch 8.14.3, Logstash, Kibana, Filebeat, Suricata, Target (Ubuntu 22.04 with SSH+nginx), dashboard-loader
- `config/logstash/pipeline/soc.conf` — parsing pipeline: Suricata EVE-JSON, auth.log Grok, GeoIP enrichment, MITRE field tagging
- `config/suricata/rules/local.rules` — 13 custom Suricata rules (SIDs 9000001–9000070) covering 8 MITRE ATT&CK techniques
- `simulations/` — 4 attack scripts: brute force SSH, Nmap port scan, web attacks (SQLi/XSS/traversal), lateral movement
- `Makefile` — 15+ targets for stack lifecycle, attack simulations, monitoring, maintenance
- `screenshots/` — 3 Kibana mockups: SOC dashboard, brute force alert detail, MITRE ATT&CK coverage matrix
- `scripts/check-alerts.sh` — ES query to show alert summary

---

*See [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md) for a detailed attack scenario walk-through.*  
*See [docs/interview-prep.md](docs/interview-prep.md) for SOC analyst interview preparation.*
