# Detection Gap Analysis — Mini-SIEM Lab

> Knowing what you **cannot** detect is as important as knowing what you can.  
> This document maps current coverage against MITRE ATT&CK v14 and identifies
> the highest-risk blind spots.

---

## Coverage Overview

| Metric | Value |
|---|---|
| MITRE Tactics covered | 6 / 14 (43%) |
| MITRE Techniques detected | 8 (network-layer) |
| Sensor types active | 2 (Suricata IDS, Filebeat auth.log) |
| Endpoint visibility | **None** |
| Identity / AD visibility | **None** |
| Encrypted traffic inspection | **None** |

---

## What This Lab Detects

| Technique | Sub-technique | Tactic | Confidence | SID / Rule |
|---|---|---|---|---|
| T1110 | T1110.001 Password Guessing | Credential Access | **High** | SID 9000001–9000002 |
| T1046 | — Network Scan | Discovery | **High** | SID 9000010–9000011 |
| T1190 | — Exploit Web App | Initial Access | **Medium** | SID 9000020–9000032 |
| T1595 | T1595.002 Active Scanning | Reconnaissance | **Medium** | SID 9000020 (Nikto UA) |
| T1021 | T1021.004 SSH Lateral Mvmt | Lateral Movement | **Medium** | SID 9000040 |
| T1133 | — External Remote Services | Persistence | **Low** | SID 9000070 (RDP) |
| T1071 | T1071.001 HTTP C2 | Command & Control | **Low** | SID 9000060 |
| T1048 | T1048.003 DNS Exfiltration | Exfiltration | **Low** | SID 9000050 |

**Confidence ratings:**  
- High = reliable detection, low FP rate, tested in lab  
- Medium = pattern-based, evasion possible (different UA, encrypted payload)  
- Low = heuristic only (beacon interval, DNS query volume), high FP risk

---

## Blind Spots by Domain

### 1. Endpoint (Highest Risk — 0% coverage)

We have **no EDR or endpoint agent**. An attacker who passes the network layer
is effectively invisible once on-host.

| Technique | Risk | Why we miss it | Fix |
|---|---|---|---|
| T1055 Process Injection | CRITICAL | No memory inspection | Wazuh + sysmon-like rules |
| T1059 Scripting (PowerShell/Bash) | CRITICAL | No process logging | auditd + Wazuh |
| T1053 Scheduled Tasks / Cron | HIGH | No file change monitoring | auditd `watch -w /etc/cron*` |
| T1543 Systemd service persistence | HIGH | No service change alerts | auditd `-w /etc/systemd` |
| T1070 Log Tampering | HIGH | Attacker can clear logs | WORM log shipping / remote syslog |
| T1003 Credential Dumping | HIGH | No `/proc` or memory monitoring | osquery / Falco |
| T1082 System Info Discovery | LOW | Benign-looking commands | Process audit logs |
| T1057 Process Discovery | LOW | `ps aux` looks normal | Process audit logs |

**Immediate mitigation in this lab:**  
`config/target/setup.sh` deploys auditd with basic rules. However, auditd logs
are not currently shipped to Elasticsearch. To close this gap:
```bash
# Add to config/filebeat/filebeat.yml:
- /var/log/audit/audit.log

# Add to config/logstash/pipeline/soc.conf:
if [fields][log_type] == "audit" { ... }
```

---

### 2. Encrypted Traffic (High Risk — partial coverage)

Suricata operates on unencrypted traffic. Any C2 or exfiltration over TLS is
opaque to our IDS rules.

| Scenario | Risk | Why we miss it |
|---|---|---|
| C2 over HTTPS (T1071.001) | CRITICAL | TLS payload encrypted; we only see JA3 hash |
| DNS-over-HTTPS (DoH) | HIGH | Standard port 443, standard TLS |
| Exfiltration via SFTP/SCP | HIGH | Encrypted SSH channel |
| Cobalt Strike HTTPS beaconing | CRITICAL | Custom TLS, malleable C2 profiles |

**Partial detection available:**  
- JA3/JA3S TLS fingerprinting (`eve-log: tls` already enabled in suricata.yaml)
- Certificate issuer anomalies (self-signed, unusual O= field)
- Domain-based: look up SNI against threat feeds even for encrypted traffic

**To add:**
```yaml
# In suricata.yaml app-layer.protocols.tls:
ja3-fingerprints: yes
```
```
# Add to local.rules:
alert tls $HOME_NET any -> $EXTERNAL_NET any (msg:"T1071 Self-Signed Cert C2"; \
  tls.cert_issuer; content:"CN="; isdataat:!1,relative; \
  sid:9000061; rev:1;)
```

---

### 3. Identity & Active Directory (High Risk — 0% coverage)

This is a Linux-only lab. No Windows DC means zero AD attack surface.  
In a real SOC, these would be top-priority detections.

| Technique | Risk | Detection (if AD existed) |
|---|---|---|
| T1558.003 Kerberoasting | CRITICAL | Windows Security 4769 (RC4 TGS) |
| T1550.002 Pass-the-Hash | CRITICAL | Windows Security 4624 LogonType 9 |
| T1003.006 DCSync | CRITICAL | Windows Security 4662 DRSUAPI |
| T1078 Valid Accounts | HIGH | Unusual hours / geo / device |
| T1136 Create Account | HIGH | Security 4720 + 4728 |

**Lab roadmap:** Add a Windows Server 2022 VM to the Docker network as a DC.  
Ship Windows event logs via Winlogbeat → Logstash.

---

### 4. Insider Threat & Data Exfiltration (0% coverage)

| Scenario | Risk | Why we miss it |
|---|---|---|
| Large data transfer over HTTP | MEDIUM | We see byte counts in flow but no DLP policy |
| Printing / USB exfiltration | HIGH | No DLP agent |
| Abnormal login hours | MEDIUM | No UEBA baseline |
| Privilege escalation via sudo | HIGH | auditd not shipped to ES (see §1) |

---

### 5. Supply Chain & Software Integrity (0% coverage)

| Scenario | Risk |
|---|---|
| Malicious pip/npm package | HIGH — no software integrity check |
| Tampered Docker image | MEDIUM — no image signing |
| Compromised CI/CD pipeline | HIGH — our GitHub Actions lacks artifact signing |

---

## Risk Prioritization Matrix

```
         LIKELIHOOD
              Low      Medium     High
         ┌─────────┬──────────┬──────────┐
    High │ Monitor │ CRITICAL │ CRITICAL │
         ├─────────┼──────────┼──────────┤
IMPACT  Med  │   LOW   │  HIGH    │  HIGH    │
         ├─────────┼──────────┼──────────┤
    Low  │ Accept  │  LOW     │  MEDIUM  │
         └─────────┴──────────┴──────────┘
```

| Blind Spot | Impact | Likelihood | Priority |
|---|---|---|---|
| Process injection / memory malware | High | High | **CRITICAL** |
| Encrypted C2 (HTTPS) | High | High | **CRITICAL** |
| Credential dumping on-host | High | Medium | **CRITICAL** |
| Kerberoasting / Pass-the-Hash | High | Medium | **HIGH** (no AD in lab) |
| Log tampering (attacker clears logs) | High | Medium | **HIGH** |
| Exfiltration over SFTP | High | Low | **HIGH** |
| DNS tunneling (DoH) | Medium | Medium | **HIGH** |
| Insider bulk data export | Medium | Low | **MEDIUM** |
| USB / print exfiltration | Medium | Low | **LOW** (out of scope for network lab) |

---

## Roadmap to Close Priority Gaps

### Phase 1 — Quick Wins (0–2 weeks)

1. **Ship auditd logs to ES** — covers T1053, T1543, T1070, T1082
   - Edit `config/filebeat/filebeat.yml`: add `/var/log/audit/audit.log`
   - Add `audit` branch to Logstash pipeline

2. **JA3 TLS fingerprinting in Suricata** — partial C2 detection
   - Enable `ja3-fingerprints: yes` in `suricata.yaml`
   - Add rule: alert on known-bad JA3 hashes from abuse feeds

3. **Wazuh agent on target container** — endpoint visibility
   - Add `wazuh-agent` service to `docker-compose.yml`
   - Ship Wazuh alerts to ES via Filebeat

### Phase 2 — Medium Term (1–4 weeks)

4. **Zeek (Bro)** as a second network sensor
   - DNS analytics: detect DGA, high-entropy domains, unusual query rates
   - TLS cert anomalies: self-signed, short validity, unusual issuer

5. **Process audit pipeline**
   - `auditd` rules for execve, ptrace, /proc reads
   - Parse with Logstash `kv` filter for key=value audit log format

6. **UEBA baseline (basic)**
   - Track login hours per user in ES, alert on ±3σ deviation
   - ES Painless script or Kibana transform

### Phase 3 — Long Term (1–3 months)

7. **Windows VM in the lab**
   - Winlogbeat → ship Security/System/Sysmon events
   - Add AD attack detection rules (Kerberoasting, DCSync, etc.)

8. **Zeek SSL inspection + JA3S correlation**

9. **MITRE D3FEND mappings**
   - For each detection technique: document the corresponding D3FEND countermeasure
   - Helps communicate defensive posture to management

---

## How to Interpret This Document in an Interview

> "I built this lab to learn end-to-end detection, but I also documented what it **can't** detect.  
> For example, we have zero endpoint visibility — if an attacker gets past the network layer,  
> we're blind. In a real environment I would close this gap with Wazuh or a commercial EDR.  
> The detection gap analysis shows I understand that a SIEM is only as good as its data sources."

---

*Coverage last updated: 2026-06-25 — MITRE ATT&CK v14*  
*See [docs/WALKTHROUGH.md](WALKTHROUGH.md) for a full attack scenario with detection timeline.*
