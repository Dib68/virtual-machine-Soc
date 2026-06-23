# Mini-SIEM: Threat Detection Lab

![CI](https://github.com/damiano-dibiase/mini-siem/actions/workflows/validate-siem.yml/badge.svg)
![ELK Stack](https://img.shields.io/badge/ELK-8.14.3-005571?style=flat&logo=elastic)
![Suricata](https://img.shields.io/badge/Suricata-IDS%2FIPS-orange?style=flat)
![MITRE ATT&CK](https://img.shields.io/badge/MITRE%20ATT%26CK-v14-red?style=flat)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker)
![Rules](https://img.shields.io/badge/Detection%20Rules-10%20active-brightgreen?style=flat)
![Playbooks](https://img.shields.io/badge/IR%20Playbooks-3-blue?style=flat)

> A fully-functional **blue team detection lab**: real attacks, real alerts, real MITRE ATT&CK coverage.  
> Built by a SOC Analyst candidate to demonstrate end-to-end threat detection skills.

---

## Screenshots

### 1 — SOC Overview Dashboard (Kibana)
![SOC Dashboard](screenshots/01-soc-dashboard.svg)

### 2 — Alert Detail: T1110.001 SSH Brute Force
![Brute Force Alert](screenshots/02-brute-force-alert.svg)

### 3 — MITRE ATT&CK Coverage Matrix
![MITRE Matrix](screenshots/03-mitre-matrix.svg)

### 4 — Timeline Investigation (MTTD: 9 min → MTTR: 1 min 38 sec)
![Timeline](screenshots/04-timeline-investigation.svg)

---

## What This Lab Detects

| Simulation | MITRE Technique | Tactic | Sensor | Detection Rule |
|---|---|---|---|---|
| SSH Brute Force | [T1110.001](https://attack.mitre.org/techniques/T1110/001/) | Credential Access | Suricata + Filebeat | [t1110-brute-force.toml](rules/detection/t1110-brute-force.toml) |
| Nmap Port Scan | [T1046](https://attack.mitre.org/techniques/T1046/) | Discovery | Suricata | [t1046-network-scan.toml](rules/detection/t1046-network-scan.toml) |
| SQLi / XSS / Traversal | [T1190](https://attack.mitre.org/techniques/T1190/) | Initial Access | Suricata | [t1190-web-exploit.toml](rules/detection/t1190-web-exploit.toml) |
| Nikto / sqlmap | [T1595.002](https://attack.mitre.org/techniques/T1595/002/) | Reconnaissance | Suricata | [t1190-web-exploit.toml](rules/detection/t1190-web-exploit.toml) |
| Lateral Movement SSH | [T1021.004](https://attack.mitre.org/techniques/T1021/004/) | Lateral Movement | Suricata | [t1021-lateral-movement.toml](rules/detection/t1021-lateral-movement.toml) |
| External Remote (RDP) | [T1133](https://attack.mitre.org/techniques/T1133/) | Persistence | Suricata | SID 9000070 |
| HTTP C2 Beacon | [T1071.001](https://attack.mitre.org/techniques/T1071/001/) | Command & Control | Suricata | SID 9000060 |
| DNS Tunneling | [T1048.003](https://attack.mitre.org/techniques/T1048/003/) | Exfiltration | Suricata | SID 9000050 |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Mini-SIEM Lab                                │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   ATTACK SIMULATIONS                         │    │
│  │  simulations/01-brute-force-ssh.sh  → Target :2222 (SSH)   │    │
│  │  simulations/02-port-scan.sh        → Target :any           │    │
│  │  simulations/03-web-attack.sh       → Target :8080 (HTTP)  │    │
│  │  simulations/04-lateral-movement.sh → Target :22            │    │
│  └───────┬──────────────────────────────────────┬──────────────┘    │
│          │ network traffic                       │ auth.log          │
│          ▼                                       ▼                   │
│  ┌──────────────┐                    ┌──────────────────────┐       │
│  │  SURICATA    │                    │      FILEBEAT        │       │
│  │  IDS / IPS   │                    │   /var/log/auth.log  │       │
│  │  EVE-JSON    │                    │   /var/log/syslog    │       │
│  └──────┬───────┘                    └──────────┬───────────┘       │
│         └──────────────────┬───────────────────┘                    │
│                            ▼                                         │
│                   ┌────────────────┐                                 │
│                   │   LOGSTASH     │  Grok parsing · GeoIP ·        │
│                   │   Pipeline     │  MITRE field tagging            │
│                   └───────┬────────┘                                 │
│                           ▼                                          │
│                  ┌─────────────────┐                                 │
│                  │ ELASTICSEARCH   │  Indices: siem-suricata-*       │
│                  │                 │           siem-auth-*           │
│                  │                 │           siem-syslog-*         │
│                  └───────┬─────────┘                                 │
│                          ▼                                           │
│                  ┌─────────────────┐                                 │
│                  │     KIBANA      │  http://localhost:5601          │
│                  │  SIEM Dashboard │  Security Alerts · Timelines   │
│                  │  + Alert Rules  │  MITRE ATT&CK coverage         │
│                  └─────────────────┘                                 │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites
- Docker + Docker Compose v2
- 4 GB RAM minimum (8 GB recommended)
- Linux / macOS / WSL2

### Option A — Makefile (recommended)

```bash
git clone https://github.com/damiano-dibiase/mini-siem.git
cd mini-siem

make up            # Start the full stack
make attack-all    # Run all 4 attack simulations
make check         # Show alert summary
```

Open Kibana: **http://localhost:5601**

### Option B — Docker Compose directly

```bash
docker compose up -d
# Wait ~60 seconds for all services to be healthy
docker compose ps
```

### Target machine

The stack includes a pre-configured **vulnerable target** container:

```bash
# SSH target (for brute force simulations)
ssh labuser@localhost -p 2222   # password: labpass
ssh root@localhost -p 2222      # password: toor

# HTTP target (for web attack simulations)
curl http://localhost:8080
```

---

## All Make Commands

```
make help              Show all available commands

── Stack ──────────────────────────────────────────────────
make up                Start the full stack
make down              Stop all containers
make status            Show container status + service URLs
make logs              Tail logs from all services
make reset             Full reset (delete all data)
make clean             Remove containers, volumes, images

── Attack Simulations ─────────────────────────────────────
make attack-all        Run all 4 simulations in sequence
make attack-bruteforce T1110.001 SSH Brute Force
make attack-scan       T1046 Nmap Port Scan
make attack-web        T1190 + T1595.002 Web Attacks
make attack-lateral    T1021.004 Lateral Movement

── Monitoring ─────────────────────────────────────────────
make check             Alert summary (last 24h)
make suricata-alerts   Live Suricata alert stream
make es-health         Elasticsearch cluster health
make es-indices        List SIEM indexes with document counts
make enrich-iocs       Enrich alert IPs with AbuseIPDB + GeoIP

── Maintenance ────────────────────────────────────────────
make validate          Validate all configs + detection rules
make load-dashboards   Import Kibana dashboards via API
```

---

## Detection Rules

Rules are in two formats, reflecting real SOC tooling:

### Suricata Network Signatures (`config/suricata/rules/local.rules`)

10 custom rules covering 8 MITRE techniques:

```
[MITRE T1110] SSH Brute Force Attempt              SID: 9000001
[MITRE T1110] SSH Login Failure Burst              SID: 9000002
[MITRE T1046] TCP Port Scan Detected               SID: 9000010
[MITRE T1046] Nmap SYN Scan Signature              SID: 9000011
[MITRE T1595.002] Nikto Web Scanner                SID: 9000020
[MITRE T1595.002] sqlmap SQL Injection Scanner     SID: 9000021
[MITRE T1190] SQL Injection Attempt                SID: 9000030
[MITRE T1190] XSS Attempt in URI                  SID: 9000031
[MITRE T1190] Directory Traversal                  SID: 9000032
[MITRE T1021.004] SSH from External Network        SID: 9000040
[MITRE T1048.003] DNS Tunneling                    SID: 9000050
[MITRE T1071.001] HTTP C2 Beacon                   SID: 9000060
[MITRE T1133] RDP from External                    SID: 9000070
```

### Elastic Security Rules (`rules/detection/*.toml`)

4 detection rules in the [elastic/detection-rules](https://github.com/elastic/detection-rules) TOML format — the same format used in production Elastic Security deployments:

| Rule File | Technique | Type | Threshold |
|---|---|---|---|
| `t1110-brute-force.toml` | T1110.001 | threshold | 5 failures / IP |
| `t1046-network-scan.toml` | T1046 | query | signature match |
| `t1190-web-exploit.toml` | T1190 + T1595.002 | query | signature match |
| `t1021-lateral-movement.toml` | T1021.004 + T1133 | query | signature match |

---

## Incident Response Playbooks

3 actionable IR playbooks in `docs/playbooks/`:

| Playbook | Covers | Includes |
|---|---|---|
| [T1110-SSH-BruteForce.md](docs/playbooks/T1110-SSH-BruteForce.md) | SSH brute force triage → containment → eradication | Triage questions, containment commands, lessons learned template |
| [T1046-NetworkScan.md](docs/playbooks/T1046-NetworkScan.md) | Port scan analysis and response | Port interpretation table, internal vs external decision tree |
| [T1190-WebExploit.md](docs/playbooks/T1190-WebExploit.md) | Web attack triage (SQLi, XSS, traversal) | HTTP status interpretation, database forensics, recovery steps |

Each playbook follows the NIST IR Framework: **Detect → Contain → Investigate → Eradicate → Recover → Document**.

---

## Log Parsing Pipeline

Logstash normalizes all events to ECS (Elastic Common Schema):

```
Input (Beats:5044 / Syslog TCP:5000 / UDP:5140)
    │
    ├── Suricata EVE-JSON  →  siem-suricata-YYYY.MM.dd
    │     Fields: source.ip, destination.ip, suricata.alert.signature,
    │             suricata.alert.severity, suricata.event_type
    │
    ├── Auth log (Grok)    →  siem-auth-YYYY.MM.dd
    │     Fields: source.ip, auth.user, event.outcome, rule.name,
    │             mitre.tactic, mitre.technique
    │
    └── Syslog (Grok)      →  siem-syslog-YYYY.MM.dd
          Fields: syslog.program, syslog.message, syslog.host
    │
    ├── GeoIP enrichment: source.ip → source.geo.*
    └── MITRE tagging: alert.severity_label, mitre.tactic, mitre.technique
```

---

## Project Structure

```
mini-siem/
├── Makefile                          ← All lab commands
├── docker-compose.yml                ← Full stack: ELK + Suricata + Target
│
├── config/
│   ├── filebeat/filebeat.yml         ← Log inputs (auth, syslog, suricata)
│   ├── kibana/kibana.yml
│   ├── logstash/
│   │   ├── logstash.yml
│   │   └── pipeline/soc.conf         ← Parsing: EVE-JSON + Grok + GeoIP
│   └── suricata/
│       ├── suricata.yaml
│       └── rules/local.rules         ← 13 MITRE-mapped Suricata signatures
│
├── rules/detection/                  ← Elastic Security rules (TOML)
│   ├── t1110-brute-force.toml
│   ├── t1046-network-scan.toml
│   ├── t1190-web-exploit.toml
│   └── t1021-lateral-movement.toml
│
├── simulations/                      ← Attack simulation scripts
│   ├── 01-brute-force-ssh.sh         ← T1110.001
│   ├── 02-port-scan.sh               ← T1046
│   ├── 03-web-attack.sh              ← T1190 + T1595.002
│   └── 04-lateral-movement.sh        ← T1021.004
│
├── scripts/
│   ├── check-alerts.sh               ← Alert summary via ES API
│   ├── enrich-iocs.sh                ← AbuseIPDB + GeoIP enrichment
│   ├── load-dashboards.sh            ← Kibana dashboard import
│   └── reset-lab.sh                  ← Full lab reset
│
├── docs/playbooks/                   ← IR Playbooks (NIST framework)
│   ├── T1110-SSH-BruteForce.md
│   ├── T1046-NetworkScan.md
│   └── T1190-WebExploit.md
│
├── screenshots/                      ← Kibana dashboards (SVG)
│   ├── 01-soc-dashboard.svg
│   ├── 02-brute-force-alert.svg
│   ├── 03-mitre-matrix.svg
│   └── 04-timeline-investigation.svg ← MTTD/MTTR measurement
│
└── .github/workflows/
    └── validate-siem.yml             ← CI: YAML + TOML + Suricata validation
```

---

## CI / CD

GitHub Actions runs on every push to `mini-siem/**`:

| Job | What it checks |
|---|---|
| `validate-yaml` | Filebeat, Kibana, Logstash YAML + docker-compose config |
| `validate-detection-rules` | All TOML rules: required fields, MITRE mapping |
| `validate-suricata-rules` | Suricata config test (`suricata -T`) |
| `validate-scripts` | ShellCheck on all `.sh` files |
| `smoke-test-elk` | Elasticsearch + Kibana actually start healthy |

---

## Skills Demonstrated

| Skill | How |
|---|---|
| **SIEM Engineering** | ELK 8.x deployment, index lifecycle, Kibana dashboards |
| **Intrusion Detection** | Suricata rule authoring with threshold detection |
| **Log Analysis** | Logstash Grok patterns: EVE-JSON, syslog, auth.log |
| **Threat Intelligence** | GeoIP enrichment, AbuseIPDB integration |
| **MITRE ATT&CK** | 8 techniques mapped, tactic chain reconstruction |
| **Incident Response** | NIST-based playbooks, MTTD/MTTR measurement |
| **Detection Engineering** | Elastic Security TOML rules (production format) |
| **DevSecOps** | CI/CD pipeline validating security configs |
| **Docker / IaC** | Multi-container orchestration with health checks |

---

## Useful Commands

```bash
# Real-time Suricata alerts
docker exec siem-suricata tail -f /var/log/suricata/fast.log

# Query Elasticsearch: count all alerts last 24h
curl -s 'http://localhost:9200/siem-suricata-*/_count?q=event_type:alert'

# Enrich attacker IPs with threat intel
export ABUSEIPDB_KEY="your-api-key"
make enrich-iocs

# Check MTTD across all incidents (last 7 days)
curl -s http://localhost:9200/siem-suricata-*/_search \
  -H 'Content-Type: application/json' \
  -d '{"aggs":{"avg_severity":{"avg":{"field":"suricata.alert.severity"}}},"size":0}'

# Validate all detection rules before committing
make validate
```

---

## Disclaimer

This lab is for **educational purposes only** in an **isolated environment**.  
All simulations target the included lab container (`siem-target`).  
Never run attack scripts against systems you do not own.

---

## Author

**Damiano Di Biase** — Cybersecurity Specialist (EPICODE 2026)  
Certifications in progress: CompTIA Security+ · Cisco CCNA  
[LinkedIn](https://linkedin.com/in/damiano-di-biase) · [GitHub](https://github.com/damiano-dibiase)

> *"Detection is not about seeing every packet — it's about knowing which ones matter."*
