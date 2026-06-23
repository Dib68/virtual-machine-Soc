# Threat Hunting — EQL Queries

> **EQL (Event Query Language)** is Elastic's native language for threat hunting,
> sequence detection, and behavioral analytics. Unlike KQL (which filters individual
> events), EQL can detect **sequences of related events** across time — making it
> ideal for reconstructing attack chains.
>
> Run these queries in: **Kibana → Security → Timelines → + New → EQL**

---

## Hunt 1 — Detect Brute Force Followed by Successful Login

Reconstructs the full credential attack chain: failed attempts → success.

```eql
sequence by source.ip with maxspan=30m
  [authentication where event.outcome == "failure"]  with runs=5
  [authentication where event.outcome == "success"]
```

**What it finds:** Any IP that had 5+ failed SSH logins followed by a successful
login within 30 minutes — a strong indicator of a successful brute force attack.

**MITRE:** T1110 → T1078 (Valid Accounts)

---

## Hunt 2 — Reconnaissance → Initial Access Chain

Detects the classic attacker workflow: scan → probe → exploit.

```eql
sequence by source.ip with maxspan=1h
  [network where suricata.event_type == "alert"
   and suricata.alert.signature like~ "*Port Scan*"]
  [network where suricata.event_type == "alert"
   and suricata.alert.signature like~ "*Nikto*"]
  [network where suricata.event_type == "alert"
   and suricata.alert.signature like~ "*SQL Injection*"]
```

**What it finds:** A source IP that scanned ports, then ran a web vulnerability
scanner, then attempted SQL injection — a textbook Initial Access chain.

**MITRE:** T1046 → T1595.002 → T1190

---

## Hunt 3 — Beaconing Detection (C2 over HTTP)

Identifies periodic small HTTP POSTs that suggest C2 communication.

```eql
sequence by source.ip with maxspan=10m
  [network where suricata.event_type == "flow"
   and suricata.proto == "TCP"
   and suricata.app_proto == "http"
   and suricata.flow.bytes_toserver < 500] with runs=6
```

**What it finds:** A host sending 6+ small HTTP requests (< 500 bytes each)
within 10 minutes to the same destination — typical C2 beacon behavior.

**MITRE:** T1071.001 (Web Protocols)

**Refine with:** Group by `destination.ip` to see what external server is being beaconed to.

---

## Hunt 4 — Lateral Movement After Initial Compromise

Detects host A being compromised, then connecting outward to host B.

```eql
sequence with maxspan=2h
  [authentication where event.outcome == "success"
   and source.ip != null
   and not cidr_match(source.ip, "10.0.0.0/8", "192.168.0.0/16")]
    by destination.ip as pivot_host
  [network where suricata.dest_port in (22, 3389, 445, 5985)
   and suricata.event_type == "flow"]
    by source.ip as pivot_host
```

**What it finds:** A host that received a successful external login, then
initiated connections to other internal machines on admin ports — the pivot
pattern of lateral movement.

**MITRE:** T1021.004 → T1021.006 (Lateral Tool Transfer)

---

## Hunt 5 — Rare Process / Port Anomaly

Find destination ports that appear in very few flows — potential covert channels.

```eql
network where suricata.event_type == "flow"
  and suricata.dest_port not in (
    22, 80, 443, 8080, 8443, 53, 123, 3389,
    25, 587, 465, 110, 143, 993, 995
  )
  and not cidr_match(destination.ip, "10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12")
| stats count() by suricata.dest_port, destination.ip
| filter count < 3
| sort count asc
```

**What it finds:** Destination ports that appear fewer than 3 times — unusual
ports may indicate custom C2 channels, data exfiltration, or misconfigured services.

---

## Hunt 6 — Same Source IP Across Multiple Indexes

Pivot on a suspicious IP to see everything it touched, across all log sources.

```eql
any where source.ip == "185.220.101.42"
```

**In Kibana Timeline:** Set the time range to 24h, run this query, then
sort by `@timestamp` ascending to reconstruct the full attack chronology.

---

## Hunt 7 — Failed Logins for Privileged Accounts

Monitor attempts against accounts that, if compromised, would be catastrophic.

```eql
authentication where event.outcome == "failure"
  and auth.user in ("root", "admin", "administrator", "sa", "postgres", "ubuntu")
| stats count() by auth.user, source.ip
| filter count > 2
| sort count desc
```

**MITRE:** T1078 (Valid Accounts) — attackers often specifically target
known privileged account names.

---

## Using EQL in Kibana

### Via Security → Timelines

1. **Kibana → Security → Timelines → + New**
2. Click **EQL** tab (next to KQL/Lucene)
3. Set time range (e.g., last 24h)
4. Paste any query above
5. Click **Search** → examine the sequence graph

### Via Dev Tools

```
GET siem-suricata-*/_eql/search
{
  "query": "network where suricata.event_type == 'alert'",
  "size": 10
}
```

### Via Python (elasticsearch-py)

```python
from elasticsearch import Elasticsearch

es = Elasticsearch("http://localhost:9200")
result = es.eql.search(
    index="siem-suricata-*",
    body={
        "query": "sequence by source.ip with maxspan=30m "
                 "[authentication where event.outcome == 'failure'] with runs=5 "
                 "[authentication where event.outcome == 'success']"
    }
)
for seq in result["hits"]["sequences"]:
    print(seq)
```

---

## Hunting Hypothesis Framework

Good threat hunting starts with a **hypothesis**, not a query.

| Step | Question |
|---|---|
| **1. Hypothesis** | "I believe attackers are brute-forcing SSH after scanning open ports" |
| **2. Data** | What logs would capture this? → Suricata + auth.log |
| **3. Query** | Hunt 1 + Hunt 2 combined |
| **4. Analyze** | Are there sequences matching? Are they from the same IP? |
| **5. Validate** | Confirm in the timeline — is this a real attack or a false positive? |
| **6. Act** | Block IP, create TheHive case, update Suricata rule threshold |
| **7. Document** | Add findings to playbook, measure MTTD |

---

## References

- [Elastic EQL documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/eql.html)
- [EQL for threat hunting (Elastic blog)](https://www.elastic.co/blog/hunting-for-lateral-movement-using-event-query-language)
- [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)
- [Sigma → EQL conversion](https://github.com/SigmaHQ/pySigma-backend-elasticsearch)
