# SOC Analyst Interview Prep — Based on This Lab

> These are real interview questions you'll face after showing this project on your CV.
> Every answer references specific code, configs, or scenarios from this lab.
> Practice explaining them out loud — fluency matters as much as accuracy.

---

## Section 1: SIEM & ELK Stack

### Q1. Walk me through your SIEM architecture. What does each component do?

**Answer:**

The stack has four tiers:

1. **Data collection** — Filebeat ships logs (auth.log, syslog, Docker containers) and Suricata ships EVE-JSON via the Beats protocol to Logstash port 5044. Suricata is inline on the network, so it sees every packet.

2. **Normalization** — Logstash's pipeline (`config/logstash/pipeline/soc.conf`) parses the raw logs:
   - Suricata EVE-JSON → `json` filter → already structured
   - auth.log → `grok` filter with pattern `SSHD_FAIL` → extracts `source.ip`, `auth.user`, `event.outcome`
   - Then GeoIP enrichment: `source.ip → source.geo`
   - Then MITRE tagging: adds `mitre.tactic`, `mitre.technique` based on the rule category

3. **Storage** — Elasticsearch stores in daily indices: `siem-suricata-2026.06.24`, `siem-auth-2026.06.24`. Index-per-day allows easy time-range queries and retention management.

4. **Analysis** — Kibana Security for dashboards + alert management. EQL for threat hunting.

---

### Q2. What is ECS and why does it matter?

**Answer:**

ECS (Elastic Common Schema) is a standard field naming convention for Elasticsearch. Instead of every log source using different field names (`src_ip`, `source_address`, `client_ip`), ECS normalizes everything to `source.ip`.

In my Logstash pipeline, I normalize auth.log and Suricata fields to ECS:
- `auth.ip` → `source.ip`
- `auth.user` → `user.name`
- `event_type: alert` → `event.category: intrusion_detection`

This matters because:
- **Cross-source correlation**: I can write one EQL query that searches across Suricata AND auth logs by the same field (`source.ip`)
- **Sigma rules**: The Sigma rules I wrote assume ECS field names — `sigma convert -t elasticsearch -p ecs_linux` requires ECS compliance
- **Elastic Security**: The TOML detection rules use ECS fields — they won't work otherwise

---

### Q3. How does Logstash handle a Suricata EVE-JSON alert? Show me the pipeline.

**Answer:**

In `config/logstash/pipeline/soc.conf`:

```
input { beats { port => 5044 } }

filter {
  if [fields][log_type] == "suricata" {
    json { source => "message" }        # Parse the JSON blob
    
    if [event_type] == "alert" {
      mutate {
        add_field => {
          "mitre.technique" => "%{[alert][category]}"
          "event.category"  => "intrusion_detection"
        }
      }
    }
    
    geoip { source => "source.ip" target => "source.geo" }
  }
}

output {
  elasticsearch {
    index => "siem-%{[@metadata][index]}-%{+YYYY.MM.dd}"
  }
}
```

The `[@metadata][index]` is set by Filebeat's `fields.index` to either `suricata`, `auth`, or `syslog` — so the output dynamically routes to the right index.

---

### Q4. How would you handle a spike in Logstash lag? Elasticsearch is falling behind.

**Answer:**

First, diagnose: `curl localhost:9600/_node/stats/pipelines` — check `events.in` vs `events.out`. If `events.filtered` is high, a filter is CPU-bound.

Options in order of invasiveness:
1. **Increase pipeline workers**: `pipeline.workers: 4` in `logstash.yml` (one per CPU core)
2. **Increase batch size**: `pipeline.batch.size: 250` (more events per Elasticsearch bulk request)
3. **Add a persistent queue**: `queue.type: persisted` in case of Logstash crash
4. **Scale horizontally**: add a second Logstash instance behind a load balancer
5. **Optimize heavy filters**: GeoIP and date parsing are expensive — move them to ingest pipelines in Elasticsearch if Logstash is the bottleneck

In this lab I set `-Xms512m -Xmx512m` in `LS_JAVA_OPTS` — in production I'd size to 4GB heap for a 100k event/day load.

---

## Section 2: Detection Engineering

### Q5. How did you write your Suricata rules? Walk me through SID 9000001.

**Answer:**

```suricata
alert tcp any any -> $HOME_NET 22 (
  msg:"[MITRE T1110] SSH Brute Force Attempt";
  flow:to_server,established;
  content:"SSH";
  threshold: type both, track by_src, count 5, seconds 60;
  classtype:attempted-user;
  sid:9000001; rev:1;
  metadata:mitre_technique T1110, mitre_tactic TA0006;
)
```

Breaking it down:
- `threshold: type both, track by_src, count 5, seconds 60` — fires when the SAME source IP makes 5+ failed connections within 60 seconds. `type both` means it suppresses repetition after firing.
- `flow:to_server,established` — only established TCP connections, not SYN floods
- `metadata: mitre_technique T1110` — custom field I added to map to ATT&CK. Logstash reads this and populates `mitre.technique` in Elasticsearch.

I chose 5 failures in 60 seconds as the threshold based on the ELK CIS benchmark for SSH brute force detection. Too low → false positives from users mistyping passwords. Too high → slow brute force (1 attempt/min) evades detection — which I address in the EQL hunt.

---

### Q6. What's the difference between a Suricata rule, an Elastic Security TOML rule, and a Sigma rule? When would you use each?

**Answer:**

| Format | Where it runs | Good for |
|---|---|---|
| Suricata rule | Network layer (packet) | Real-time blocking (IPS mode), network signatures, pattern matching in packets |
| Elastic TOML | Elasticsearch (post-ingestion) | Threshold across multiple events, cross-source correlation, long time windows |
| Sigma YAML | Any SIEM (via conversion) | Portable detection that works in Splunk, Sentinel, QRadar — write once, run anywhere |

In this lab, I use all three in layers:
- **Suricata** catches the network signature in real-time (can drop the packet in IPS mode)
- **Elastic TOML** fires a persistent alert in the SIEM that persists across sessions and can trigger SOAR
- **Sigma** gives me the same detection exportable to any other SIEM the employer uses

In a real SOC, you'd maintain Sigma as the source of truth and convert to whatever SIEM you use. The Suricata rules stay separate because no SIEM query language can inspect raw packet payloads.

---

### Q7. How would you detect a brute force attack that uses only 1 attempt per minute to evade your threshold rule?

**Answer:**

This is exactly what EQL threat hunting is for. My threshold rule (SID 9000001) requires 5 failures in 60 seconds — a slow brute force at 1/min evades it.

The EQL query in `docs/hunting/eql-queries.md`:

```eql
sequence by source.ip with maxspan=2h
  [authentication where event.outcome == "failure"] with runs=10
  [authentication where event.outcome == "success"]
```

This finds any source IP that had 10+ failed logins within 2 hours followed by a success — regardless of rate. I run this manually as a scheduled hunt (weekly or after incidents).

The lesson: **detection rules catch known patterns at speed; threat hunting finds what the rules missed.** Both are required. Rules can't catch everything by design — otherwise the FP rate becomes unmanageable.

---

### Q8. One of your Suricata rules has a 38% false positive rate. How do you tune it?

**Answer:**

I documented this exact scenario in `docs/tuning/false-positives.md` for SID 9000010 (network scan threshold).

Step-by-step:
1. **Measure**: `make tuning-check` — shows alert volume per SID in the last 24h
2. **Sample 20 random alerts** from that SID in Kibana
3. **Classify**: Is `source.ip` a known internal scanner? Is the traffic to an expected port?
4. **Root cause**: In this case, Docker health checks (172.20.0.1) trigger the SYN threshold
5. **Tune**: Add a suppress directive:
   ```suricata
   suppress gen_id 1, sig_id 9000010, track by_src, ip 172.20.0.1
   ```
6. **Validate**: Run 48h, re-check FP rate
7. **Document**: Add to the tuning log in false-positives.md

I prefer `suppress` over raising the threshold because raising the threshold creates a blind spot — an attacker scanning at 49 SYN/10s would evade a threshold of 50.

---

## Section 3: Threat Hunting

### Q9. What's the difference between alert-based detection and threat hunting?

**Answer:**

Alert-based detection is **reactive**: a rule fires when a known pattern occurs. It's fast and automated but can only catch what it was designed for.

Threat hunting is **proactive**: an analyst formulates a hypothesis about attacker behavior that isn't covered by current rules, then searches for evidence. It's slower and manual but finds what rules miss.

In this lab, both work together:
- The Suricata rule fires when 5+ failures in 60s → alert
- The EQL hunt finds attacks that used 1 attempt/min and succeeded → no alert would have fired without the hunt
- Screenshot 5 (`05-threat-hunting.svg`) shows the hunt finding 2 successful logins that the alert-only view missed

In practice, hunts should be scheduled regularly (weekly, post-incident) and the findings should be converted into new detection rules to close the gap.

---

### Q10. Explain EQL. How is it different from KQL?

**Answer:**

EQL (Event Query Language) is Elasticsearch's language for **sequence** and **behavioral** queries. KQL (Kibana Query Language) is for **single-event** filtering.

The difference:
- **KQL**: "Find all events where source.ip = 1.2.3.4 AND event.outcome = failure" → returns individual events
- **EQL**: "Find source IPs that had a failure FOLLOWED BY a success within 10 minutes" → returns correlated sequences

EQL example from my lab:
```eql
sequence by source.ip with maxspan=10m
  [authentication where event.outcome == "failure"] with runs=5
  [authentication where event.outcome == "success"]
```

This cannot be expressed in KQL. You'd need a threshold rule + manual correlation, or ES SQL, or scripted fields. EQL does it natively and is very fast on large datasets because Elasticsearch optimizes sequence matching.

I use EQL for threat hunting (temporal correlations) and KQL for quick ad-hoc searches in Kibana.

---

## Section 4: Incident Response

### Q11. Walk me through how you responded to the SSH brute force in the walkthrough.

**Answer:**

This is documented in `docs/WALKTHROUGH.md`. The scenario:
- Attacker: Nmap → Hydra (SSH brute force) → success (password: "toor")
- My MTTD was 9 min 10 sec, MTTR was 1 min 38 sec

The response flow (NIST framework):

1. **Detect**: Suricata SID 9000001 fires at T+9:10. Kibana alert: 89 failures from 203.0.113.42 in 60s
2. **Contain**: `iptables -I INPUT -s 203.0.113.42 -j DROP` (immediate block). Kill active SSH session: `pkill -u root -t pts/0`
3. **Investigate**: Kibana timeline shows failure burst → success → root login. EQL confirms it's a single campaign. GeoIP: RU exit node.
4. **Eradicate**: Rotate root credentials, disable root SSH login, add fail2ban rule for this IP
5. **Recover**: Verify no persistence (crontabs, authorized_keys, systemd units). Restore to known-good state.
6. **Document**: TheHive case created by SOAR bot. Post-incident report with MTTD/MTTR.

Key point: the 1:38 MTTR was possible because the containment command was pre-written in the IR playbook. If I'd had to look it up in the moment, it would have been 10 minutes.

---

### Q12. What's MTTD and MTTR? How did you measure them?

**Answer:**

- **MTTD** (Mean Time to Detect): time from when the attack started to when the first alert fired
- **MTTR** (Mean Time to Respond): time from alert to the attacker being blocked

I measured them from Elasticsearch timestamps:
- Attack start: first failure event in `siem-suricata-*` from attacker IP → `@timestamp: 2026-06-24T14:00:00`
- Alert fired: Suricata alert SID 9000001 → `@timestamp: 2026-06-24T14:09:10`
- MTTD = 9 min 10 sec

- Containment confirmed: iptables rule applied, verified via `curl --connect-timeout 2 http://203.0.113.42` timeout
- MTTR = 1 min 38 sec from first alert to confirmed block

In production, MTTD < 15 minutes is a typical SLA target. Our sub-10-minute MTTD is good for a single-analyst lab without 24/7 coverage.

---

### Q13. How does your TheHive SOAR bot decide when to create a case?

**Answer:**

The `scripts/thehive-bot.py` logic:

1. **Poll**: Every 5 minutes (in `--loop` mode), query ES for new alerts above a severity threshold
2. **Group**: Group by `source.ip` — multiple alerts from the same IP are one campaign, not 10 separate cases
3. **Dedup**: Before creating, check if an open TheHive case already exists for that IP (to avoid duplicates)
4. **Create**: POST to TheHive v5 API with:
   - Title: `[SIEM] T1110 Brute Force — 203.0.113.42`
   - Tags: `MITRE:T1110`, `severity:HIGH`, `source:mini-siem`
   - Observable: IP with TLP:AMBER, PAP:AMBER, `ioc=True`

The grouping logic is crucial — without it, a single brute force attempt (89 alerts) would create 89 TheHive cases and overwhelm the SOC. This is why I group by `source.ip` and use deduplication.

---

## Section 5: MITRE ATT&CK

### Q14. What is MITRE ATT&CK and how did you use it in this lab?

**Answer:**

MITRE ATT&CK is a knowledge base of adversary tactics, techniques, and procedures (TTPs) based on real-world observations. It organizes attacks into 14 tactics (the "why") and 200+ techniques (the "how").

I used it in 3 ways:
1. **Rule naming**: Every Suricata rule starts with `[MITRE TXXX]` — makes it immediately clear what the rule detects
2. **Field tagging**: Logstash adds `mitre.tactic` and `mitre.technique` to every alert — enables ATT&CK-based dashboards and filtering
3. **Coverage mapping**: Screenshot 3 (`03-mitre-matrix.svg`) shows which ATT&CK cells are red (detected), blue (monitored), or gray (blind spot) — this is what a real detection coverage review looks like

The lab covers 8 techniques across 6 tactics: Reconnaissance → Initial Access → Credential Access → Discovery → Lateral Movement → Exfiltration → Command & Control.

A coverage matrix is what you'd present to management to prioritize where to add detection next.

---

### Q15. How would you detect a Living-off-the-Land attack using only built-in Windows tools?

**Answer:**

LoTL attacks use legitimate tools (PowerShell, WMI, certutil, bitsadmin) to avoid triggering AV/EDR. Suricata won't see these because they're process-level, not network.

Detection requires endpoint telemetry:
1. **Sysmon + Winlogbeat** feeding into the ELK stack — logs process creation with command lines
2. **Elastic Security EQL rules** looking for suspicious PowerShell patterns:
   ```eql
   process where process.name == "powershell.exe"
     and process.command_line like~ "*-enc*" or process.command_line like~ "*bypass*"
   ```
3. **Sigma rules** — there are hundreds of community Sigma rules for LoTL techniques

This lab focuses on Linux/network detection, but the pipeline (Beats → Logstash → ES) scales to Windows with Winlogbeat replacing Filebeat. The Sigma rules in `rules/sigma/` would be converted to ES queries that work on Sysmon events.

---

## Section 6: Threat Intelligence

### Q16. What threat intel feeds do you use and how do you integrate them?

**Answer:**

In `scripts/threat-intel-sync.sh` I pull 4 public feeds:
- **AbuseCH Feodo Tracker**: botnet C2 IPs (Emotet, QakBot, TrickBot infrastructure)
- **AbuseCH SSL Blacklist**: malicious TLS certificate servers
- **Emerging Threats compromised-ips**: ProofPoint's list of known-compromised hosts
- **CINS Army**: scanners and brute force sources

Integration is two-pronged:
1. **Preventive**: Convert IPs to Suricata `drop` rules → blocks known malicious IPs before they connect
2. **Detective**: The `enrich-iocs.sh` script enriches existing alerts by querying AbuseIPDB/GeoIP at triage time

The SID range 8000001–8999999 is separate from my lab rules (9000001+) so auto-generated rules never conflict with hand-written ones.

A more advanced implementation would use Elasticsearch Ingest Pipelines to enrich at index time using a lookup index of known bad IPs — but that requires Platinum license or a custom lookup plugin.

---

### Q17. An alert fires for an IP. What do you do first?

**Answer:**

Triage checklist (in order):

1. **Is it internal or external?** — check `source.ip` against RFC1918 ranges. Internal source = potential lateral movement or compromised host.
2. **What else has this IP done?** — KQL: `source.ip: "X.X.X.X"` across all `siem-*` indexes. How many events, over how long?
3. **Threat intel enrichment** — `python3 scripts/ioc-lookup.py X.X.X.X` → AbuseIPDB confidence score, GeoIP, Shodan open ports
4. **Context**: what was the target port? What Suricata signature fired? Is this part of a sequence?
5. **Decision**: False positive (known scanner) → suppress. Real threat → open TheHive case and escalate.

I document this in `docs/playbooks/T1110-SSH-BruteForce.md` as a triage checklist — having a written process ensures you don't miss steps under pressure at 2am.

---

## Section 7: General SOC

### Q18. What's your process for writing a new detection rule from scratch?

**Answer:**

1. **Hypothesis**: What attacker behavior am I trying to detect? (e.g., "attacker uses encoded PowerShell to download a payload")
2. **Log source**: Which logs capture this? (auth.log for SSH, Suricata for network, Sysmon for process)
3. **Field mapping**: What ECS fields will have the relevant data?
4. **Pattern**: Write the detection logic — start broad, then narrow
5. **Test**: Run against historical data. How many FPs? Tune the threshold/filter.
6. **Format**: Write as Sigma (portable) and convert to the target SIEM
7. **CI**: The GitHub Actions pipeline validates new rules on every push — `make validate` catches syntax errors locally

In this lab, I follow this exact process. The Sigma rules in `rules/sigma/` are the "source of truth" and the TOML rules in `rules/detection/` are the Elastic-specific deployment format.

---

### Q19. How do you prioritize which alerts to investigate first?

**Answer:**

Priority order:
1. **Severity**: CRITICAL before HIGH before MEDIUM (defined in the Elastic TOML rules by the `severity` field)
2. **Impact potential**: Alerts involving authentication success after failures (brute force → login) > alerts involving scans with no success
3. **Asset value**: Alerts targeting high-value systems (domain controllers, databases) > alerts targeting DMZ assets
4. **MITRE tactic stage**: Exfiltration/Impact/Command & Control alerts > Reconnaissance alerts — the later the tactic, the further the attacker has progressed
5. **Correlation**: An IP that appears in 3 different alert types (scan + brute force + success) > an IP that only port-scanned

In this lab, I use Kibana's alert severity filter to triage CRITICAL first. The weekly report (`make report`) shows trends so I can spot if a previously low-priority IP is escalating.

---

### Q20. This is a lab — how would you scale this to a real enterprise environment?

**Answer:**

The architecture is designed to scale:

**Data volume**: Replace single-node Elasticsearch with a multi-node cluster (2 hot nodes + 1 warm + 1 master). Add ILM (Index Lifecycle Management) to move data from hot→warm→delete after 90 days.

**Log sources**: Filebeat agents on every endpoint → Logstash pipeline → ES. Add Winlogbeat for Windows + Auditbeat for Linux process monitoring. The existing pipeline handles any Beats input.

**Rules**: The Sigma rules already convert to Splunk SPL, Microsoft Sentinel KQL, and QRadar AQL — if the employer uses a different SIEM, the detection logic is portable.

**Alerting**: Replace TheHive with ServiceNow or Jira (change the API endpoint in `thehive-bot.py`). Add PagerDuty for on-call rotation.

**Performance**: At 10k events/second, replace Logstash with Elasticsearch Ingest Pipelines (lower latency, no JVM overhead). Use Kafka as a buffer between Filebeat and Logstash for spikes.

**Access control**: Enable Elasticsearch security (`xpack.security.enabled=true`), add role-based access (analysts see their team's data, not other teams').

The core design (Beats → normalize → ES → Kibana) is the same pattern used at companies with petabytes of security data. The difference is operational maturity, not architecture.

---

## Cheat Sheet — Key Numbers to Know

| Metric | This Lab | Typical Enterprise Target |
|---|---|---|
| MTTD | 9 min 10 sec | < 15 minutes |
| MTTR | 1 min 38 sec | < 60 minutes |
| MITRE ATT&CK coverage | 8 techniques / 19% | 40–60% for mature SOCs |
| False positive rate | ~5% (after tuning) | Target < 10% per rule |
| Detection rules | 13 Suricata + 4 Elastic + 4 Sigma | Hundreds to thousands |
| Threat intel feeds | 4 (AbuseCH, ET, CINS) | 10–50+ feeds in enterprise |

---

*Tip: When asked a question you don't know, say: "In this lab I handled X by doing Y — in a production environment I'd also consider Z." Shows you understand the gap between lab and production.*
