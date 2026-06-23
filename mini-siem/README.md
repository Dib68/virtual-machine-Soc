# Mini-SIEM: Threat Detection Lab

![ELK Stack](https://img.shields.io/badge/ELK-8.14.3-005571?style=flat&logo=elastic)
![Suricata](https://img.shields.io/badge/Suricata-IDS%2FIPS-orange?style=flat)
![MITRE ATT&CK](https://img.shields.io/badge/MITRE%20ATT%26CK-v14-red?style=flat)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

> A fully functional **Security Information and Event Management (SIEM)** lab built for hands-on SOC analyst training. Detects real attack techniques, maps them to MITRE ATT&CK, and visualizes everything in Kibana.

---

## Screenshots

### SOC Overview Dashboard
![SOC Dashboard](screenshots/01-soc-dashboard.svg)

### Alert Detail — T1110 SSH Brute Force
![Brute Force Alert](screenshots/02-brute-force-alert.svg)

### MITRE ATT&CK Coverage Matrix
![MITRE Matrix](screenshots/03-mitre-matrix.svg)

---

## What This Lab Detects

| # | Simulation Script | MITRE Technique | Tactic | Sensor |
|---|---|---|---|---|
| 1 | `01-brute-force-ssh.sh` | [T1110.001](https://attack.mitre.org/techniques/T1110/001/) — Password Guessing | Credential Access | Suricata + Filebeat |
| 2 | `02-port-scan.sh` | [T1046](https://attack.mitre.org/techniques/T1046/) — Network Service Scanning | Discovery | Suricata |
| 3 | `03-web-attack.sh` | [T1190](https://attack.mitre.org/techniques/T1190/) — Exploit Public-Facing App | Initial Access | Suricata |
| 3b | `03-web-attack.sh` | [T1595.002](https://attack.mitre.org/techniques/T1595/002/) — Vulnerability Scanning | Reconnaissance | Suricata |
| 4 | `04-lateral-movement.sh` | [T1021.004](https://attack.mitre.org/techniques/T1021/004/) — Remote Services SSH | Lateral Movement | Suricata |
| — | Passive monitoring | [T1071.001](https://attack.mitre.org/techniques/T1071/001/) — Web Protocol C2 | Command & Control | Suricata |
| — | Passive monitoring | [T1048.003](https://attack.mitre.org/techniques/T1048/003/) — DNS Tunneling | Exfiltration | Suricata |
| — | Passive monitoring | [T1133](https://attack.mitre.org/techniques/T1133/) — External Remote Services | Persistence | Suricata |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mini-SIEM Lab                            │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   NETWORK    │    │   AUTH LOG   │    │   SYSLOG         │  │
│  │   TRAFFIC    │    │ /var/log/    │    │ /var/log/syslog  │  │
│  └──────┬───────┘    └──────┬───────┘    └────────┬─────────┘  │
│         │                   │                      │            │
│         ▼                   ▼                      ▼            │
│  ┌──────────────┐    ┌──────────────────────────────────────┐  │
│  │   SURICATA   │    │              FILEBEAT                 │  │
│  │  IDS / IPS   │    │          (log shipper)                │  │
│  │ EVE-JSON log │    └──────────────────────────────────────┘  │
│  └──────┬───────┘                     │                         │
│         └──────────────────┬──────────┘                         │
│                            ▼                                     │
│                   ┌────────────────┐                            │
│                   │    LOGSTASH    │                            │
│                   │   (parsing +   │                            │
│                   │ normalization) │                            │
│                   └───────┬────────┘                            │
│                           │                                      │
│                           ▼                                      │
│                  ┌─────────────────┐                            │
│                  │ ELASTICSEARCH   │                            │
│                  │  (storage &     │                            │
│                  │   indexing)     │                            │
│                  └───────┬─────────┘                            │
│                          │                                       │
│                          ▼                                       │
│                  ┌─────────────────┐                            │
│                  │     KIBANA      │                            │
│                  │  SIEM Dashboard │                            │
│                  │ http://localhost│                            │
│                  │     :5601       │                            │
│                  └─────────────────┘                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites
- Docker + Docker Compose
- 4 GB RAM minimum (8 GB recommended)
- Linux / macOS / WSL2

### 1. Clone and start the stack

```bash
git clone https://github.com/damiano-dibiase/mini-siem.git
cd mini-siem
docker compose up -d
```

### 2. Wait for services to be ready (~2 minutes)

```bash
docker compose ps
# All containers should show: healthy / running
```

### 3. Open Kibana

```
http://localhost:5601
```

No login required (security disabled for lab use).

### 4. Run an attack simulation

```bash
# SSH Brute Force (T1110.001)
chmod +x simulations/*.sh
./simulations/01-brute-force-ssh.sh 192.168.56.10

# Port Scan (T1046)
./simulations/02-port-scan.sh 192.168.56.10

# Web Attacks (T1190, T1595.002)
./simulations/03-web-attack.sh 192.168.56.10 8080

# Lateral Movement (T1021.004)
./simulations/04-lateral-movement.sh 192.168.56.10
```

### 5. View alerts in Kibana

```
Security → Alerts → Filter by "rule.name: T1110*"
```

---

## Stack

| Component | Version | Role |
|---|---|---|
| **Elasticsearch** | 8.14.3 | Log storage & full-text indexing |
| **Logstash** | 8.14.3 | Log parsing & normalization |
| **Kibana** | 8.14.3 | SIEM dashboard & alert visualization |
| **Filebeat** | 8.14.3 | Log shipping (auth.log, syslog, docker) |
| **Suricata** | latest | Network IDS/IPS — signature-based detection |

---

## Project Structure

```
mini-siem/
├── docker-compose.yml               # Full stack definition
├── config/
│   ├── filebeat/filebeat.yml        # Log input sources
│   ├── kibana/kibana.yml            # Kibana config
│   ├── logstash/
│   │   ├── logstash.yml
│   │   └── pipeline/soc.conf        # Parsing: Suricata, auth, syslog
│   └── suricata/
│       ├── suricata.yaml            # Suricata engine config
│       └── rules/local.rules        # 10+ custom MITRE-mapped rules
├── simulations/
│   ├── 01-brute-force-ssh.sh        # T1110.001
│   ├── 02-port-scan.sh              # T1046
│   ├── 03-web-attack.sh             # T1190 + T1595.002
│   └── 04-lateral-movement.sh       # T1021.004
└── screenshots/
    ├── 01-soc-dashboard.svg         # Kibana SOC overview
    ├── 02-brute-force-alert.svg     # Alert detail view
    └── 03-mitre-matrix.svg          # ATT&CK coverage matrix
```

---

## Detection Rules

All Suricata rules are in [`config/suricata/rules/local.rules`](config/suricata/rules/local.rules) and follow this naming convention:

```
[MITRE TXXXX] Description
```

| SID | Rule | MITRE | Trigger |
|---|---|---|---|
| 9000001 | SSH Brute Force Attempt | T1110.001 | 5+ attempts / 60s from same IP |
| 9000010 | TCP Port Scan (SYN) | T1046 | 50+ SYN packets / 10s |
| 9000020 | Nikto Scanner | T1595.002 | User-Agent: Nikto |
| 9000030 | SQL Injection in URI | T1190 | `' OR '1'='1` in HTTP URI |
| 9000031 | XSS in URI | T1190 | `<script>` in HTTP URI |
| 9000040 | SSH from External Net | T1021.004 | SSH from non-RFC1918 IP |
| 9000050 | DNS Tunneling | T1048.003 | DNS query > 50 chars |
| 9000060 | HTTP C2 Beacon | T1071.001 | 6+ small POSTs / 120s |
| 9000070 | RDP from External | T1133 | Port 3389 SYN from external |

---

## Log Parsing Pipeline

Logstash normalizes all events to a common schema before indexing:

```
Input (Beats/Syslog)
    ↓
Filter: Suricata EVE-JSON   → index: siem-suricata-YYYY.MM.dd
Filter: Auth log (grok)     → index: siem-auth-YYYY.MM.dd
Filter: Syslog (grok)       → index: siem-syslog-YYYY.MM.dd
    ↓
GeoIP enrichment (source.ip → source.geo)
MITRE field tagging (mitre.tactic, mitre.technique)
    ↓
Output: Elasticsearch
```

---

## Useful Commands

```bash
# Check which containers are running
docker compose ps

# View Suricata alerts in real time
docker exec siem-suricata tail -f /var/log/suricata/fast.log

# Query Elasticsearch directly
curl -s http://localhost:9200/siem-suricata-*/_count | jq .

# View Logstash parsing in action
docker logs -f siem-logstash

# Stop everything
docker compose down

# Stop and remove all data
docker compose down -v
```

---

## Skills Demonstrated

- **SIEM Engineering** — ELK stack deployment, index management, Kibana dashboards
- **Intrusion Detection** — Suricata rule writing, EVE-JSON log analysis
- **Log Analysis** — Logstash Grok patterns for auth.log / syslog normalization
- **Threat Intelligence** — GeoIP enrichment, AbuseIPDB correlation
- **MITRE ATT&CK** — Technique mapping, tactic chain reconstruction
- **Incident Response** — Alert triage, response playbook definition
- **Docker / Infrastructure** — Multi-container orchestration, health checks

---

## Disclaimer

This lab is for **educational purposes only** in an **isolated environment**.  
All simulations target local lab machines. Never run against systems you don't own.

---

## Author

**Damiano Di Biase** — Cybersecurity Specialist (EPICODE 2026)  
Certifications in progress: CompTIA Security+ · Cisco CCNA  
[LinkedIn](https://linkedin.com/in/damiano-di-biase) · [GitHub](https://github.com/damiano-dibiase)

> *"Blue team is not about stopping every attack — it's about detecting them fast enough to respond."*
